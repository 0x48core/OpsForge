# Lab 12 — K3s, Helm & GitOps

- **Phase:** 5 — Observability & Kubernetes
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** a K3s cluster in Docker on the Mac (k3d); the same manifests work on K3s on the VPS

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Run hello-api on Kubernetes three ways (plain manifests, a Helm chart, then GitOps), until a git commit is the only thing needed to change what runs in the cluster.

## Done when

- [ ] K3s cluster running (3 nodes) with Traefik as the Ingress controller
- [ ] hello-api + Postgres (with a persistent volume) + Redis deployed with plain manifests, reachable through the Ingress
- [ ] Rolling update and rollback under load with zero failed requests
- [ ] The same app as a Helm chart: install, upgrade, history, rollback
- [ ] Argo CD syncs the chart from this repo (`Synced` / `Healthy`)
- [ ] Self-heal: a manual `kubectl` change is reverted by Argo CD
- [ ] A **git commit** changes what runs in the cluster, with no manual `kubectl apply`

## Measured while preparing this lab

k3d 5.9 (K3s v1.35.5), Helm 4.3, Argo CD 3.5.4, kubectl 1.37:

| Test | Result |
|---|---|
| Cluster create | 3 nodes Ready in 63 s; Traefik Ingress, `local-path` storage |
| Plain manifests | all pods Running; app pods restarted once (Postgres not ready yet: no `depends_on` in Kubernetes) |
| Service load balancing | 10 requests → 5 per pod |
| `kubectl set image` under load | **398,866 requests, 0 errors** |
| `kubectl rollout undo` under load | **293,127 requests, 0 errors** |
| Helm | lint ok, 8 resources; install → upgrade → history → rollback |
| Argo CD | Synced + Healthy from GitHub; 8 resources |
| Self-heal | `scale --replicas=5` + `set image` reverted in **~2 s** |
| GitOps change | commit `19485e8` (image tag) → serving the new version **13 s** after push; **613,457 requests during rollout, 0 errors** |
| RAM | ~2.4 GiB for the 3 nodes, of which Argo CD ~500 MiB |

## Steps

### 0. Tools

```bash
brew install k3d helm kubectl
brew install argocd        # optional: the Argo CD CLI
```

### 1. Create the cluster

```bash
k3d cluster create --config k8s/cluster/k3d.yaml
kubectl config current-context        # k3d-opsforge
kubectl get nodes
kubectl get pods -A                   # what K3s runs out of the box: CoreDNS, Traefik, metrics-server, local-path
kubectl get ingressclass,storageclass
```

Each "node" is a Docker container (`docker ps | grep k3d`). The k3d load balancer forwards `127.0.0.1:8081` to Traefik inside the cluster.

### 2. The database Secret (never in git)

```bash
kubectl create namespace hello-api
kubectl -n hello-api create secret generic hello-api-db \
  --from-literal=POSTGRES_USER=hello \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 16)" \
  --from-literal=POSTGRES_DB=hello
kubectl -n hello-api get secret hello-api-db -o yaml    # base64, NOT encrypted: anyone who can read Secrets can decode it
```

### 3. Part 1: plain manifests

Read [k8s/manifests/hello-api/](../../k8s/manifests/hello-api/) first. For each resource, ask: what Compose feature from lab 04 does this replace?

```bash
kubectl apply -k k8s/manifests/hello-api
kubectl -n hello-api get pods -w        # Ctrl+C when all are Running
kubectl -n hello-api get pods,svc,ingress,pvc
curl -H 'Host: api.k8s.opsforge.localhost' http://127.0.0.1:8081/ready
curl -X POST -H 'Host: api.k8s.opsforge.localhost' http://127.0.0.1:8081/visits
```

Check the `RESTARTS` column. If the app pods restarted once, find out why:

```bash
kubectl -n hello-api logs deploy/hello-api --previous
```

Explore:

```bash
kubectl -n hello-api describe pod -l app=hello-api     # events, probes, limits
kubectl -n hello-api logs -l app=hello-api --tail=5
kubectl -n hello-api exec postgres-0 -- psql -U hello -d hello -c 'SELECT count(*) FROM visits;'
kubectl -n hello-api delete pod -l app=hello-api       # what happens? (a ReplicaSet recreates them)
```

### 4. Rolling update and rollback under load

```bash
hey -z 40s -c 10 -host api.k8s.opsforge.localhost http://127.0.0.1:8081/ > /tmp/roll.txt &
sleep 5; kubectl -n hello-api set image deploy/hello-api hello-api=ghcr.io/0x48core/hello-api:sha-db2a6db
kubectl -n hello-api rollout status deploy/hello-api; wait
grep -A3 'Status code distribution' /tmp/roll.txt
kubectl -n hello-api rollout history deploy/hello-api
kubectl -n hello-api rollout undo deploy/hello-api
```

Compare with lab 08: `maxUnavailable: 0`, the readiness probe, and `SHUTDOWN_DELAY` replace everything `deploy.sh` did by hand.

Read the warning `rollout undo` prints. It says the cluster no longer matches your YAML files. Keep that in mind for part 3.

Remove part 1. This deletes the whole namespace, **including the Secret and Postgres' volume**, so create the Secret again:

```bash
kubectl delete -k k8s/manifests/hello-api --ignore-not-found
kubectl create namespace hello-api && kubectl -n hello-api create secret generic hello-api-db …   # as in step 2
```

### 5. Part 2: Helm

Read [charts/hello-api/](../../k8s/charts/hello-api/): [values.yaml](../../k8s/charts/hello-api/values.yaml), then the templates. What became a value, and why?

```bash
helm lint k8s/charts/hello-api
helm template hello-api k8s/charts/hello-api | less     # the YAML Helm would apply
helm install hello-api k8s/charts/hello-api -n hello-api --wait
helm list -n hello-api
helm upgrade hello-api k8s/charts/hello-api -n hello-api --set image.tag=sha-db2a6db --wait
helm history hello-api -n hello-api
helm rollback hello-api 1 -n hello-api --wait
helm get values hello-api -n hello-api --all
```

Two things to notice:
- Right after `helm upgrade --wait` returns, a request can still reach an **old** pod: it's terminating, but serving during its 5-second drain. Check with `kubectl -n hello-api get pods`.
- `helm history` shows the chart's `appVersion`, not your `--set image.tag`. Values set on the command line are easy to lose track of, which is what part 3 fixes.

Then hand over to Argo CD:

```bash
helm uninstall hello-api -n hello-api --wait     # the Secret and PVC stay
```

### 6. Part 3: GitOps with Argo CD

**Install Argo CD:**

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.4/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
```

**Open the UI:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8090:443
```

Go to `https://localhost:8090` and log in as `admin` with that password. Accept the self-signed certificate.

**Create the Application:**

```bash
kubectl apply -f k8s/argocd/hello-api.yaml
kubectl -n argocd get application hello-api -w      # until Synced / Healthy
```

It syncs `k8s/charts/hello-api` with `values.yaml` + [values-k3d.yaml](../../k8s/charts/hello-api/values-k3d.yaml) from `main` on GitHub. In the UI, click the app to see the resource tree.

To test a branch before merging, point the app at it:

```bash
kubectl -n argocd patch application hello-api --type merge -p '{"spec":{"source":{"targetRevision":"<branch>"}}}'
```

**Self-heal:**

```bash
kubectl -n hello-api scale deploy hello-api --replicas=5
kubectl -n hello-api get deploy hello-api -w     # back to 2 within seconds
```

**Deploy with a commit:**

1. Change `image.tag` (or `replicaCount`) in [values-k3d.yaml](../../k8s/charts/hello-api/values-k3d.yaml).
2. `git commit -am "deploy(k3d): hello-api <tag>"` and `git push`.
3. Watch: Argo CD polls git every ~3 minutes (or click **Refresh** in the UI), syncs, and Kubernetes rolls the pods.

```bash
curl -s -H 'Host: api.k8s.opsforge.localhost' http://127.0.0.1:8081/ | grep -o '"version":"[^"]*"'
```

To roll back: `git revert <commit>` and push. Rolling back is just another commit, with an audit trail.

### 7. Clean up

```bash
k3d cluster delete opsforge            # everything: nodes, volumes, Argo CD
```

## On the VPS

K3s installs with one command (`curl -sfL https://get.k3s.io | sh -`) and runs the same chart and Argo CD Application. Before adding it to the Ansible playbook, think about:
- **RAM:** this cluster used ~2.4 GiB. On a 4 GB VPS, K3s + Argo CD + the observability stack don't all fit next to the Docker stacks. K3s would *replace* Docker Compose for the apps, not run beside it.
- **Ingress:** K3s' Traefik would take ports 80/443 instead of the Docker Traefik (lab 05).
- **Secrets:** use Sealed Secrets or External Secrets, so even the Secret can live in git, encrypted.

## Code

- [k8s/](../../k8s/): cluster config, manifests, Helm chart, Argo CD Application

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- **App pods restarted once on first deploy:** they started before Postgres' DNS name existed (`lookup postgres … no such host`), the startup migration failed, and the process exited. Kubernetes retried and they came up. There's no `depends_on`: apps must tolerate dependencies starting later (retry, or crash and let Kubernetes restart).
- **A `kubectl server dry-run` failed with `namespaces "hello-api" not found`:** a dry run can't create the namespace it depends on. Create the namespace first.
- **"After upgrade" still showed the old version:** `helm --wait` returned while old pods were draining and still serving. Not a bug: zero-downtime behaviour.
- **`kubectl rollout undo` warning about `last-applied-configuration`:** imperative changes drift from the YAML in git. GitOps solves this.
- `-o custom-columns=…[0]…` failed in zsh: `[` is a glob character. Quote the argument.

## Lessons learned

## References

- [Kubernetes basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [k3d](https://k3d.io/) and [K3s](https://docs.k3s.io/)
- [Kubernetes: probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/)
- [Helm: chart template guide](https://helm.sh/docs/chart_template_guide/)
- [Argo CD: getting started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [OpenGitOps principles](https://opengitops.dev/)
