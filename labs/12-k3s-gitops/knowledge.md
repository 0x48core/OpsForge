# Lab 12 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

Labs 04–08 built, by hand and with scripts, what Kubernetes provides as standard: health checks, rolling updates, restarts, service discovery, load balancing, and declared desired state. Kubernetes is the industry's common platform for running containers across many machines, and most DevOps jobs touch it. **GitOps** takes lab 07's CI/CD one step further: git doesn't just *trigger* deploys, git **is** the description of what runs.

## Core concepts

### What Kubernetes is

A system that keeps a **desired state** true across a cluster of machines:

```
you: "3 replicas of hello-api:v2"  ──▶  API server  ──▶  stored in etcd
                                             │
          controllers watch and act:  ──▶  scheduler places pods on nodes
                                         ──▶  kubelet on each node starts containers
                                         ──▶  pod dies? replicaset controller makes a new one
```

This is the **reconciliation loop**: controllers constantly compare desired with actual and fix the difference. The idea is the same as Ansible's idempotency and Terraform's plan, but running all the time.

| Part | Role |
|---|---|
| **Control plane** (k3d-opsforge-server-0) | API server, scheduler, controllers, datastore |
| **Nodes** (agents) | Run your pods via the kubelet and a container runtime |
| **kubectl** | Talks to the API server; everything is an API object |

**K3s** is a lightweight, certified Kubernetes in one binary, which suits a 2–4 GB VPS. **k3d** runs K3s nodes as Docker containers, for local practice.

### Compose → Kubernetes

| Compose (labs 04–08) | Kubernetes |
|---|---|
| `service:` with `image:` | **Deployment** → ReplicaSet → **Pods** |
| `--scale app=2` | `replicas: 2` |
| Service name DNS (`db`) | **Service**: stable name + virtual IP, load-balances over ready pods |
| Traefik labels | **Ingress** (here handled by K3s' Traefik) |
| Named volume | **PersistentVolumeClaim**, provisioned by a StorageClass (`local-path`) |
| `.env` / `environment:` | **ConfigMap** / **Secret** + `env` |
| `healthcheck` | **Probes**: startup, liveness, readiness |
| `restart: unless-stopped` | Built in: controllers always recreate |
| `depends_on: service_healthy` | **None**: apps must cope with dependencies starting later |
| `deploy.sh` rolling deploy (lab 08) | `strategy: RollingUpdate` with `maxSurge` / `maxUnavailable` |

### Pods, ReplicaSets, Deployments

- A **Pod** is one or more containers sharing a network and volumes. It's the smallest unit, and **disposable**: it gets a new name and IP when recreated.
- A **ReplicaSet** keeps N identical pods running.
- A **Deployment** manages ReplicaSets: changing the pod template creates a new ReplicaSet and shifts pods over gradually. That's a rolling update, and `rollout undo` switches back.

### StatefulSet: for things with an identity

Postgres needs a **stable name** (`hello-api-postgres-0`) and **its own disk** that follows it. A StatefulSet gives each pod an ordinal name and a PVC from `volumeClaimTemplates`. The PVC **outlives** the pod, and even the StatefulSet: in this lab the data survived a Helm uninstall and a switch to Argo CD.

### The three probes

| Probe | Question | On failure | hello-api |
|---|---|---|---|
| **startupProbe** | Has it finished starting? | Keep waiting, up to the limit | `/health`, up to 30 × 1 s |
| **livenessProbe** | Is it stuck? | **Restart** the container | `/health` |
| **readinessProbe** | Can it take traffic? | Remove from Service endpoints, **no** restart | `/ready` (Postgres + Redis) |

This is lab 04's liveness/readiness split, built in. With the DB down, pods go *not ready* (no traffic) but aren't restarted in a loop.

### Resources and security context

- **`requests`**: what the scheduler reserves on a node. **`limits.memory`**: going over gets the container OOM-killed. The same idea as Compose's `mem_limit` in lab 11.
- **Security context:** `runAsNonRoot`, a numeric `runAsUser` (Kubernetes can't verify a name like `nonroot`), `readOnlyRootFilesystem`, `drop: [ALL]` capabilities, and `seccompProfile: RuntimeDefault`. The distroless image (lab 04) makes all of these easy.
- **PodDisruptionBudget:** during *voluntary* disruptions (draining a node for maintenance), keep at least `minAvailable` pods.

### Secrets

A Kubernetes Secret is **base64-encoded, not encrypted**: anyone allowed to read Secrets can decode them. That's why this lab creates it with `kubectl create secret` and keeps it out of git. For GitOps with secrets *in* git, there are:
- **Sealed Secrets:** encrypt with the cluster's public key; only the cluster can decrypt.
- **External Secrets Operator:** sync from a vault (1Password, AWS Secrets Manager…).
- **SOPS:** encrypted files that tools like Argo CD can decrypt.

### Kustomize and Helm

| | Kustomize | Helm |
|---|---|---|
| Idea | Plain YAML + patches/overlays | Templates + values |
| Built into | `kubectl apply -k` | `helm` CLI |
| Good for | Small differences between environments | Reusable, configurable packages, and installing others' software |
| Tracks releases | No | Yes: `helm history`, `helm rollback` |

A Helm **chart** = `Chart.yaml` + `values.yaml` + `templates/`. `helm template` shows the rendered YAML: always check what you'd apply. Keep **environment-specific values in files in git** (`values-k3d.yaml`), not in `--set` flags someone typed once.

### GitOps

The [OpenGitOps](https://opengitops.dev/) principles, applied here:

1. **Declarative:** the desired state is YAML/Helm, not scripts.
2. **Versioned and immutable:** it lives in git. Every change is a commit, and rollback is `git revert`.
3. **Pulled automatically:** an agent in the cluster (Argo CD) pulls from git. CI doesn't push into the cluster.
4. **Continuously reconciled:** drift is detected and corrected (self-heal).

**Push vs pull deploys:**

| | Push (lab 07) | Pull (GitOps) |
|---|---|---|
| Who deploys | CI, over SSH | An agent inside the cluster |
| Credentials | CI holds keys to production | The cluster only needs *read* access to git |
| Drift | Unnoticed until the next deploy | Corrected in seconds |
| Audit | CI logs | git history |

The full flow becomes: commit code → CI tests and pushes `sha-…` image (lab 07) → commit the new tag to `values-k3d.yaml` (by hand, or automated with Argo CD Image Updater) → Argo CD syncs → Kubernetes rolls out with zero downtime.

### Argo CD vocabulary

| Term | Meaning |
|---|---|
| Application | "Sync this git path into this cluster/namespace" |
| Sync status | **Synced** / **OutOfSync**: does the cluster match git? |
| Health status | **Healthy** / Progressing / Degraded: are the resources working? |
| `automated.prune` | Delete resources that were removed from git |
| `automated.selfHeal` | Revert manual changes |
| Refresh | Re-read git now (otherwise every ~3 minutes, or via webhook) |

### The cost

This 3-node cluster used ~2.4 GiB, Argo CD ~500 MiB of it. Kubernetes brings power and standardisation, and also overhead. For a single small VPS running a few apps, Compose plus the scripts from labs 07–08 is a perfectly good choice. Knowing **when not to use Kubernetes** is part of the skill.

## Key terms

| Term | Meaning |
|---|---|
| Pod | Smallest deployable unit: one or more containers |
| Deployment / ReplicaSet | Manages replicas and rolling updates |
| StatefulSet | Pods with stable names and their own volumes |
| Service | Stable name + load balancing over ready pods |
| Ingress | HTTP routing from outside to Services |
| PVC / StorageClass | A request for a disk / how disks are provisioned |
| Probe | Startup, liveness, or readiness check |
| Namespace | A scope for names, access rules, and quotas |
| Chart / release | A Helm package / one installed instance of it |
| Reconciliation | Continuously making actual state match desired state |
| Drift | Actual state changed outside the declared source |

## Commands to know

| Command | What it does |
|---|---|
| `kubectl get pods -A` / `-w` | List pods in all namespaces / watch |
| `kubectl describe pod <p>` | Details and **events** (why isn't it starting?) |
| `kubectl logs <p> [--previous]` | Logs (of the crashed container) |
| `kubectl exec -it <p> -- sh` | Shell in a container (if it has one) |
| `kubectl apply -f / -k` | Apply YAML / Kustomize |
| `kubectl rollout status / history / undo deploy/<d>` | Watch / list / revert rollouts |
| `kubectl port-forward svc/<s> 8090:443` | Reach a Service locally |
| `kubectl top nodes / pods` | Resource use (metrics-server) |
| `helm template / install / upgrade / rollback / history` | Render / manage releases |
| `kubectl -n argocd get applications` | Argo CD app status |

## Before you start, can you answer these?

1. What's the difference between a liveness and a readiness probe, and what happens when each fails?
2. Why does Postgres use a StatefulSet and hello-api a Deployment?
3. Why isn't a Kubernetes Secret safe to commit to git?
4. In GitOps, how do you deploy a new version, and how do you roll back?
5. What's the security advantage of pull-based deploys over CI pushing via SSH?

## After the lab, check yourself

1. Why did the app pods restart once on the first deploy, and why did it fix itself?
2. Map five Compose features from lab 04 to their Kubernetes equivalents.
3. What did `maxUnavailable: 0` + readiness + `SHUTDOWN_DELAY` replace from lab 08?
4. Why did the visit count survive the Helm uninstall?
5. What did Argo CD do when you scaled the Deployment by hand, and why?
6. On a 4 GB VPS, would you run K3s or Docker Compose? Why?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Kubernetes concepts](https://kubernetes.io/docs/concepts/)
- [Kubernetes: Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) and [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Helm best practices](https://helm.sh/docs/chart_best_practices/)
- [Argo CD: automated sync and self-heal](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) (to see what K3s hides)
