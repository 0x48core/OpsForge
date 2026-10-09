# Learning roadmap: from zero to DevOps mastery

The labs in this repo are the **practice**. This roadmap is the **curriculum**: every skill area a strong DevOps / SRE / platform engineer needs, in what order, how deep, and how you know you've got it.

## How to use it

1. **Work level by level.** Finish Level 1 in every domain before going deep into Level 3 of one. Breadth first, then depth.
2. **For each topic: learn → practice → prove.**
   - **Learn:** the resources listed, plus the lab's `knowledge.md`.
   - **Practice:** the linked lab, typed by you, not copy-pasted.
   - **Prove:** you can do the **checkpoint** without notes, and explain it to someone else.
3. **Write as you go.** Notes in each lab's `knowledge.md` ("My notes") and README ("What broke", "Lessons learned"). Writing is where understanding gets tested.
4. **Tick the checkpoints** in this file as you reach them. It's your progress tracker.

### Levels

| Level | Meaning | Roughly |
|---|---|---|
| **1. Foundation** | You can use it and explain the basics | Junior |
| **2. Practitioner** | You can build and run it on your own, and fix common problems | Mid-level |
| **3. Advanced** | You can design it, run it in production, and debug the hard problems | Senior |
| **4. Expert** | You know the internals and trade-offs, and you teach others | Staff / principal |

Levels 1–3 are the goal of this roadmap. Level 4 comes from years of running real systems.

---

## The domains

### 1. Linux and the operating system

| Level | Learn | Practice | Checkpoint: you can… |
|---|---|---|---|
| 1 | Shell, files and permissions, users and sudo, packages, processes, services, logs | [01](../labs/01-vps-hardening/), [02](../labs/02-nginx-ssl-reverse-proxy/) | - [ ] Harden a fresh server without notes, and explain each step |
| 2 | systemd in depth, signals, cron/timers, storage (partitions, LVM, mounts), boot process | [17](../labs/17-processes-and-systemd/), [19](../labs/19-storage-and-filesystems/), [03](../labs/03-automated-backup/) | - [ ] Fix a server whose disk is full, a service that won't start, and a bad `fstab` |
| 3 | Namespaces, cgroups, kernel tuning, performance analysis (USE, `perf`), security modules | [18](../labs/18-containers-from-scratch/), [20](../labs/20-performance-troubleshooting/), [21](../labs/21-linux-security-hardening/) | - [ ] Find why a server is slow within 15 minutes, with evidence |

**Resources:** [The Linux Command Line](https://linuxcommand.org/tlcl.php) (free book) · *How Linux Works* (Brian Ward) · *Systems Performance* (Brendan Gregg) · [Julia Evans' zines](https://wizardzines.com/) · `man` pages.

### 2. Networking

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | IP, ports, TCP vs UDP, DNS, HTTP(S), firewalls | [01](../labs/01-vps-hardening/), [02](../labs/02-nginx-ssl-reverse-proxy/), [05](../labs/05-multi-service-proxy/) | - [ ] Explain what happens when you type a URL and press Enter, down to TCP and TLS |
| 2 | Subnets/CIDR, routing, NAT, load balancing, TLS and certificates, packet capture | [13](../labs/13-network-fundamentals/), [15](../labs/15-dns-deep-dive/), [16](../labs/16-wireguard-vpn/) | - [ ] Debug "can't connect" by layer: DNS, route, firewall, port, TLS, app |
| 3 | Container and Kubernetes networking internals, VPNs, BGP basics, cloud networking (VPCs) | [14](../labs/14-linux-network-namespaces/), [28](../labs/28-gcp-networking/), [35](../labs/35-k8s-networking/) | - [ ] Draw how a packet reaches a pod in Kubernetes, rule by rule |

**Resources:** *Computer Networking: A Top-Down Approach* (Kurose & Ross) · [High Performance Browser Networking](https://hpbn.co/) (free) · [Beej's Guide to Network Programming](https://beej.us/guide/bgnet/) · Julia Evans' networking zines · Wireshark.

### 3. Scripting and programming

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Bash: variables, loops, conditionals, pipes, `set -euo pipefail`, exit codes | every lab's scripts ([deploy.sh](../stacks/hello-api/deploy.sh), [smoke-test.sh](../scripts/smoke-test.sh)) | - [ ] Write a script that passes `shellcheck` and fails safely |
| 2 | One real language: **Go** (you already have hello-api) or Python; HTTP, JSON, tests, CLIs | [apps/hello-api](../apps/hello-api/) | - [ ] Add a feature to hello-api with tests, through CI |
| 3 | Automation tools and services: API clients, a small CLI, a Kubernetes controller | your own project | - [ ] Ship a tool other people use |

**Resources:** [A Tour of Go](https://go.dev/tour/) · *Learning Go* (Jon Bodner) · [Automate the Boring Stuff with Python](https://automatetheboringstuff.com/) (free) · [ShellCheck wiki](https://www.shellcheck.net/wiki/).

### 4. Git and collaboration

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Commit, branch, merge, PRs, `.gitignore`, never committing secrets | this repo: a branch and PR per lab | - [ ] Write commit messages and PRs others understand |
| 2 | Rebase, conflicts, revert, bisect, tags and semantic versioning, code review | — | - [ ] Find a bad commit with `git bisect`; recover a "lost" commit with `reflog` |
| 3 | Trunk-based development, release strategy, monorepos, branch protection | Phase 13 | - [ ] Design a branching and release process for a team |

**Resources:** [Pro Git](https://git-scm.com/book/en/v2) (free) · [Conventional Commits](https://www.conventionalcommits.org/) · [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/).

### 5. Containers

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Images, containers, volumes, ports, Compose | [04](../labs/04-dockerize-app/), [06](../labs/06-self-hosted-tools/) | - [ ] Containerize an app with its database from scratch |
| 2 | Multi-stage, small and non-root images, layer caching, multi-arch, healthchecks, registries | [04](../labs/04-dockerize-app/), [07](../labs/07-cicd-pipeline/) | - [ ] Get an image under 30 MB that runs as non-root |
| 3 | What a container *is* (namespaces, cgroups, overlayfs), runtimes (containerd), image security | [18](../labs/18-containers-from-scratch/), [37](../labs/37-k8s-security/), Phase 12 | - [ ] Build a container by hand with `unshare` |

**Resources:** [Docker docs](https://docs.docker.com/get-started/) · *Docker Deep Dive* (Nigel Poulton) · [What even is a container?](https://jvns.ca/blog/2016/10/10/what-even-is-a-container/).

### 6. CI/CD and delivery

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Pipelines: test, build, push, deploy; secrets in CI | [07](../labs/07-cicd-pipeline/) | - [ ] Build a pipeline from an empty repo to a running deploy |
| 2 | Zero-downtime deploys, rollback, immutable artifacts, GitOps | [08](../labs/08-zero-downtime-deploy/), [12](../labs/12-k3s-gitops/) | - [ ] Deploy under load with zero errors, and roll back in one command |
| 3 | Multiple environments and promotion, canary and feature flags, DORA metrics | [27](../labs/27-gcp-project-structure/), [42](../labs/42-k8s-advanced-delivery/), Phase 13 | - [ ] Measure your deployment frequency, lead time, change failure rate, recovery time |

**Resources:** *Continuous Delivery* (Humble & Farley) · *Accelerate* (Forsgren, Humble, Kim) · [dora.dev](https://dora.dev/) · [GitHub Actions docs](https://docs.github.com/actions).

### 7. Infrastructure as Code and configuration management

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Declarative vs imperative, idempotency, Ansible playbooks | [09](../labs/09-ansible/) | - [ ] Rebuild a server from zero with one command |
| 2 | Terraform: state, plan, providers, modules; secrets (Vault, ansible-vault) | [10](../labs/10-terraform/) | - [ ] Create and destroy a cloud environment from code, with remote state |
| 3 | Reusable modules, testing IaC, policy as code, drift detection at team scale | [27](../labs/27-gcp-project-structure/), Phase 12 | - [ ] Write a Terraform module others reuse, with tests |

**Resources:** [Ansible docs](https://docs.ansible.com/) · *Terraform: Up & Running* (Yevgeniy Brikman) · [Terraform tutorials](https://developer.hashicorp.com/terraform/tutorials).

### 8. Cloud: Google Cloud (GCP)

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Resource hierarchy, projects, billing budgets, IAM (roles, service accounts), `gcloud`, Compute Engine, Cloud Storage | [26](../labs/26-gcp-foundations/), [29](../labs/29-gcp-compute-and-load-balancing/) | - [ ] A budget alert exists before anything else; SSH to a VM with no public IP (IAP) |
| 2 | Project structure as code, VPC and Cloud NAT, load balancing, instance groups, Artifact Registry, Cloud Run, Cloud SQL, Secret Manager, **Workload Identity Federation** | [27](../labs/27-gcp-project-structure/)–[30](../labs/30-gcp-cloud-run-and-cloud-sql/) | - [ ] CI deploys to GCP with no service account key anywhere |
| 3 | GKE in production, Workload Identity, Cloud Logging/Monitoring, FinOps, multi-region design | [31](../labs/31-gke/), [32](../labs/32-gcp-operations-and-cost/) | - [ ] Explain the bill line by line, and design for a given budget and availability target |

How the projects are laid out (one per environment, state, IAM, CI access): [ADR 0004](decisions/0004-gcp-project-structure.md).

**Resources:** [Google Cloud Skills Boost](https://www.cloudskillsboost.google/) (hands-on labs) · [Google Cloud documentation](https://cloud.google.com/docs) · [Google Cloud Architecture Framework](https://cloud.google.com/architecture/framework) · [Terraform Google provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs) · **Associate Cloud Engineer**, then **Professional Cloud DevOps Engineer** certification.

⚠️ Set a **budget alert** before creating anything, and `terraform destroy` dev after each lab. Cloud mistakes cost real money. The concepts (IAM, VPCs, managed services) carry over to AWS and Azure.

### 9. Kubernetes: from basics to deep dive

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Pods, Deployments, Services, namespaces, labels, kubectl fluency; ConfigMaps, Secrets, volumes, StatefulSets, Jobs | [12](../labs/12-k3s-gitops/), [33](../labs/33-k8s-core-objects/), [34](../labs/34-k8s-config-storage-workloads/) | - [ ] Deploy an app with a database from YAML you write yourself, without looking anything up |
| 2 | Networking (Services, DNS, Ingress, Gateway API, NetworkPolicies), scheduling and resources, Helm, GitOps, troubleshooting | [35](../labs/35-k8s-networking/), [36](../labs/36-k8s-scheduling-and-resources/), [38](../labs/38-k8s-observability-and-troubleshooting/), [23](../labs/23-horizontal-scaling/) | - [ ] Fix `CrashLoopBackOff`, `Pending`, `ImagePullBackOff`, and `OOMKilled` pods in minutes; pass **CKAD** |
| 3 | Security (RBAC, Pod Security, policy as code), control-plane internals, kubeadm, upgrades, etcd backup, GKE | [37](../labs/37-k8s-security/), [39](../labs/39-k8s-internals/), [40](../labs/40-k8s-cluster-lifecycle/), [31](../labs/31-gke/) | - [ ] Build a cluster with kubeadm, upgrade it, and restore etcd; pass **CKA** |
| 4 | Operators and CRDs, admission control, progressive delivery, multi-environment GitOps | [41](../labs/41-k8s-extending/), [42](../labs/42-k8s-advanced-delivery/) | - [ ] Write an operator in Go; canary with automatic rollback; pass **CKS** |

**Resources:** [Kubernetes docs](https://kubernetes.io/docs/) (also allowed during CKA/CKAD/CKS) · *Kubernetes Up & Running* · *Kubernetes in Action* (Marko Lukša) · [Killercoda](https://killercoda.com/) (free browser labs) · [killer.sh](https://killer.sh/) (exam simulator) · [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) · [The Kubebuilder Book](https://book.kubebuilder.io/) · *Programming Kubernetes* (Hausenblas & Schimanski).

#### Service mesh (Phase 11)

A mesh moves encryption, retries, traffic control, and per-call telemetry out of the app code and into proxies (or the kernel). Learn it after Kubernetes networking, security, and observability ([35](../labs/35-k8s-networking/), [37](../labs/37-k8s-security/), [38](../labs/38-k8s-observability-and-troubleshooting/)).

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Why meshes exist, sidecar pattern, L4 vs L7, Envoy listeners/routes/clusters, xDS | [43](../labs/43-why-a-service-mesh/), [44](../labs/44-envoy-by-hand/) | - [ ] Route and retry traffic with an Envoy config you wrote yourself |
| 2 | Linkerd and Istio basics: injection, automatic mTLS, golden metrics, Gateway API, ingress gateway | [45](../labs/45-linkerd/), [46](../labs/46-istio-basics/) | - [ ] Show encrypted pod-to-pod traffic and per-route success rates with zero code changes |
| 3 | Traffic management (canary, mirroring, fault injection, circuit breaking), zero-trust (SPIFFE, AuthorizationPolicy), tracing | [47](../labs/47-mesh-traffic-management/)–[49](../labs/49-mesh-observability-and-tracing/) | - [ ] A 90/10 canary with default-deny policies, and one slow request traced across services |
| 4 | Sidecarless meshes (Istio ambient, Cilium), overhead, control-plane upgrades, multi-cluster, when *not* to use a mesh | [50](../labs/50-mesh-ambient-and-production/) | - [ ] A measured comparison and a written recommendation; pass **ICA** |

**Resources:** [Istio docs](https://istio.io/latest/docs/) · [Linkerd docs](https://linkerd.io/2/overview/) · [Envoy docs](https://www.envoyproxy.io/docs) · *Istio in Action* (Posta, Maloku) · [Solo.io Academy](https://academy.solo.io/) and [Buoyant Service Mesh Academy](https://buoyant.io/service-mesh-academy) (free) · [Isovalent labs](https://isovalent.com/resource-library/labs/) for Cilium (free) · [Gateway API (GAMMA)](https://gateway-api.sigs.k8s.io/mesh/).

### 10. Observability

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Metrics vs logs vs traces, dashboards, basic alerts | [11](../labs/11-observability/) | - [ ] Build a dashboard that answers "is it healthy?" at a glance |
| 2 | PromQL, LogQL, RED/USE, cardinality, alert design, SLOs | [11](../labs/11-observability/), [25](../labs/25-resilience-and-chaos/) | - [ ] Write alerts that fire on user-facing symptoms, with no noise |
| 3 | **Distributed tracing (OpenTelemetry)**, profiling, observability at scale | [38](../labs/38-k8s-observability-and-troubleshooting/), [49](../labs/49-mesh-observability-and-tracing/) | - [ ] Trace one slow request across services to its cause |

**Resources:** [Prometheus docs](https://prometheus.io/docs/) · [OpenTelemetry docs](https://opentelemetry.io/docs/) · *Observability Engineering* (Majors, Fong-Jones, Miranda) · [Google SRE books](https://sre.google/books/) (free).

### 11. Security / DevSecOps

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | SSH keys, firewalls, least privilege, secrets out of git, updates | [01](../labs/01-vps-hardening/), [07](../labs/07-cicd-pipeline/) | - [ ] Explain every secret in this repo: where it lives, who can read it |
| 2 | TLS/PKI, vulnerability scanning (Trivy), secrets managers (Vault), OWASP Top 10 | [21](../labs/21-linux-security-hardening/), [37](../labs/37-k8s-security/), Phase 12 | - [ ] Make CI fail on critical vulnerabilities in your image |
| 3 | Supply chain (SBOM, cosign signatures, SLSA), policy as code (OPA/Kyverno), zero-trust service identity, threat modelling | [37](../labs/37-k8s-security/), [48](../labs/48-mesh-security-zero-trust/), Phase 12 | - [ ] Only signed images can run in your cluster |

**Resources:** [OWASP Top 10](https://owasp.org/www-project-top-ten/) · [SLSA](https://slsa.dev/) · [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) · *Container Security* (Liz Rice).

### 12. Data and databases (for operators)

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Running Postgres and Redis in containers, connections, basic SQL | [04](../labs/04-dockerize-app/) | - [ ] Connect, query, and explain what's in the database |
| 2 | **Backups and restore tests**, migrations, connection pooling, indexes | [03](../labs/03-automated-backup/), [24](../labs/24-caching-and-databases/) | - [ ] Restore production data onto a fresh server, timed |
| 3 | Replication, failover, consistency trade-offs, caching patterns | [24](../labs/24-caching-and-databases/) | - [ ] Explain what your system does during a database failover |

**Resources:** [PostgreSQL docs](https://www.postgresql.org/docs/) · *Designing Data-Intensive Applications* (Martin Kleppmann): the most valuable book on this list.

### 13. Scalability, reliability, and SRE

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Availability, redundancy, health checks, graceful shutdown | [04](../labs/04-dockerize-app/), [08](../labs/08-zero-downtime-deploy/) | - [ ] Explain why a deploy can cause errors and how to prevent it |
| 2 | Load testing, capacity planning, horizontal scaling, caching, queues | [22](../labs/22-load-testing-capacity/)–[24](../labs/24-caching-and-databases/) | - [ ] Find your system's breaking point and its bottleneck |
| 3 | SLOs and error budgets, chaos engineering, **incident response and postmortems** | [25](../labs/25-resilience-and-chaos/), [47](../labs/47-mesh-traffic-management/), Phase 13 | - [ ] Lead a (practice) incident and write a blameless postmortem |

**Resources:** [Site Reliability Engineering + The SRE Workbook](https://sre.google/books/) (free) · *Release It!* (Michael Nygard) · [incident.io guide](https://incident.io/guide).

### 14. Ways of working

| Level | Learn | Checkpoint |
|---|---|---|
| 1 | Documentation, clear PRs, asking good questions | - [ ] Every lab README lets someone else repeat it |
| 2 | DevOps culture, DORA, blameless postmortems, on-call | - [ ] Write a runbook someone else can follow at 3 a.m. |
| 3 | Platform engineering (internal platforms, "golden paths"), mentoring, technical writing | - [ ] Teach a lab to someone, or publish it as a blog post |

**Resources:** *The Phoenix Project* (novel) · *The DevOps Handbook* · *Team Topologies* · [platformengineering.org](https://platformengineering.org/).

---

## Labs still to create (future phases)

Phases 9 (GCP, labs 26–32), 10 (Kubernetes in depth, labs 33–42), and 11 (service mesh, labs 43–50) exist as lab stubs. Still listed here only:

| Phase | Labs |
|---|---|
| **12 — DevSecOps** | Image scanning and SBOMs in CI · signing images with cosign · Vault for secrets · supply-chain levels (SLSA) · threat modelling one system |
| **13 — SRE and delivery** | dev/staging/prod promotion · incident simulation and postmortem · DORA metrics for this repo |

---

## Suggested path (about 18 months at 8–10 hours a week)

| Stage | Months | Focus | Labs | Milestone |
|---|---|---|---|---|
| **A. Foundations** | 1–3 | Linux, networking, Bash, Git, containers | 01–06, 13, 17 | All Level 1 checkpoints |
| **B. Automation** | 4–6 | CI/CD, IaC, observability, backups, a real VPS online | 03, 07–11 | The VPS rebuilt from code; alerts on your phone |
| **C. Platforms** | 7–10 | Kubernetes basics, Google Cloud, scaling | 12, 22–24, 26–31, 33–36 | **Associate Cloud Engineer**; **CKAD** |
| **D. Depth** | 11–15 | Kubernetes deep dive, OS internals, security, reliability | 14–16, 18–21, 25, 32, 37–42 | **CKA**, then **CKS**; a public portfolio |
| **E. Service mesh** | 16–18 | Envoy, Linkerd, Istio in depth, sidecarless meshes | 43–50 | **ICA** (Istio Certified Associate); a measured mesh comparison in your portfolio |

### A weekly rhythm

| Time | Activity |
|---|---|
| ~2 h | **Learn:** read the lab's `knowledge.md` and one resource; answer "Before you start" |
| ~5 h | **Practice:** do the lab yourself; break things on purpose |
| ~1 h | **Write:** "What broke", "Lessons learned", "My notes"; tick checkpoints here |
| ~30 min | **Review:** what's next, and one thing you'd explain differently now |

Small and steady beats long and rare: five sessions of 1.5 hours teach more than one 8-hour day.

### Certifications (optional, in this order)

| Certification | When | Why |
|---|---|---|
| HashiCorp Terraform Associate | Any time after lab 10 | Quick, validates IaC basics |
| Google Associate Cloud Engineer | After labs 26–31 | The entry GCP certification: hands-on cloud operations |
| CKAD (Certified Kubernetes Application Developer) | After labs 33–36 | Hands-on, about using Kubernetes; a good first Kubernetes exam |
| CKA (Certified Kubernetes Administrator) | After labs 37–40 | Hands-on, about running clusters; highly respected |
| CKS (Kubernetes Security) | After CKA (required) | Security depth |
| Google Professional Cloud DevOps Engineer | After Stage D | Senior-level: SRE practices on GCP |
| ICA (Istio Certified Associate) | After labs 46–49 | Hands-on Istio: traffic, security, observability |
| CCA (Cilium Certified Associate) | Optional, after lab 50 | eBPF networking and Cilium's mesh |

Certificates open doors; the labs and your write-ups are what convince people once the door is open.

---

## What "mastery" really takes

- **Run something real, for a long time.** Keep the VPS online with real use (even just yours): upgrades, expired certificates, a full disk. Problems you didn't plan are the best teachers.
- **Break things on purpose**, then write down what you saw. Every lab does this; keep doing it.
- **Explain it.** If you can't explain it simply, you don't know it yet. Blog posts, a talk at a meetup, or helping someone online.
- **Read other people's systems.** Open-source Helm charts, Terraform modules, postmortems ([danluu/post-mortems](https://github.com/danluu/post-mortems)).
- **Go general, then deep:** be solid across all 14 domains (Level 2), and expert in two or three you enjoy most.

## Reference roadmaps

- [roadmap.sh/devops](https://roadmap.sh/devops) and [roadmap.sh/kubernetes](https://roadmap.sh/kubernetes)
- [90DaysOfDevOps](https://github.com/MichaelCade/90DaysOfDevOps)
