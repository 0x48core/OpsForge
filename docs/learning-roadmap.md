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
| 3 | Container and Kubernetes networking internals, VPNs, BGP basics, cloud networking (VPCs) | [14](../labs/14-linux-network-namespaces/), Phase 9 | - [ ] Draw how a packet reaches a pod in Kubernetes, rule by rule |

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
| 3 | Trunk-based development, release strategy, monorepos, branch protection | Phase 11 | - [ ] Design a branching and release process for a team |

**Resources:** [Pro Git](https://git-scm.com/book/en/v2) (free) · [Conventional Commits](https://www.conventionalcommits.org/) · [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/).

### 5. Containers

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Images, containers, volumes, ports, Compose | [04](../labs/04-dockerize-app/), [06](../labs/06-self-hosted-tools/) | - [ ] Containerize an app with its database from scratch |
| 2 | Multi-stage, small and non-root images, layer caching, multi-arch, healthchecks, registries | [04](../labs/04-dockerize-app/), [07](../labs/07-cicd-pipeline/) | - [ ] Get an image under 30 MB that runs as non-root |
| 3 | What a container *is* (namespaces, cgroups, overlayfs), runtimes (containerd), image security | [18](../labs/18-containers-from-scratch/), Phase 10 | - [ ] Build a container by hand with `unshare` |

**Resources:** [Docker docs](https://docs.docker.com/get-started/) · *Docker Deep Dive* (Nigel Poulton) · [What even is a container?](https://jvns.ca/blog/2016/10/10/what-even-is-a-container/).

### 6. CI/CD and delivery

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Pipelines: test, build, push, deploy; secrets in CI | [07](../labs/07-cicd-pipeline/) | - [ ] Build a pipeline from an empty repo to a running deploy |
| 2 | Zero-downtime deploys, rollback, immutable artifacts, GitOps | [08](../labs/08-zero-downtime-deploy/), [12](../labs/12-k3s-gitops/) | - [ ] Deploy under load with zero errors, and roll back in one command |
| 3 | Multiple environments and promotion, canary and feature flags, DORA metrics | Phase 11 | - [ ] Measure your deployment frequency, lead time, change failure rate, recovery time |

**Resources:** *Continuous Delivery* (Humble & Farley) · *Accelerate* (Forsgren, Humble, Kim) · [dora.dev](https://dora.dev/) · [GitHub Actions docs](https://docs.github.com/actions).

### 7. Infrastructure as Code and configuration management

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Declarative vs imperative, idempotency, Ansible playbooks | [09](../labs/09-ansible/) | - [ ] Rebuild a server from zero with one command |
| 2 | Terraform: state, plan, providers, modules; secrets (Vault, ansible-vault) | [10](../labs/10-terraform/) | - [ ] Create and destroy a cloud environment from code, with remote state |
| 3 | Reusable modules, testing IaC, policy as code, drift detection at team scale | Phases 9–10 | - [ ] Write a Terraform module others reuse, with tests |

**Resources:** [Ansible docs](https://docs.ansible.com/) · *Terraform: Up & Running* (Yevgeniy Brikman) · [Terraform tutorials](https://developer.hashicorp.com/terraform/tutorials).

### 8. Cloud (AWS first): *the biggest gap in the labs so far*

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Regions and AZs, IAM (users, roles, policies), EC2, S3, VPC basics, billing alerts | Phase 9 | - [ ] Run a VM in a private subnet, reached only through a load balancer |
| 2 | VPC design, ALB, auto-scaling groups, RDS, managed Kubernetes (EKS), CloudWatch, cost | Phase 9 | - [ ] Explain your monthly bill line by line, and cut it |
| 3 | Multi-account setup, least-privilege IAM, disaster recovery across regions, FinOps | Phase 9 | - [ ] Design an architecture for a given budget and availability target |

**Resources:** [AWS Skill Builder](https://skillbuilder.aws/) (free courses) · [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) · Adrian Cantrill's courses · **AWS Solutions Architect Associate** certification.

⚠️ Set a **billing alarm** before creating anything. Cloud mistakes cost real money.

### 9. Kubernetes

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Pods, Deployments, Services, Ingress, ConfigMaps, Secrets, probes | [12](../labs/12-k3s-gitops/) | - [ ] Deploy an app with a database, from YAML you write yourself |
| 2 | Helm, GitOps, StatefulSets, PVCs, resources, autoscaling, debugging (`describe`, events) | [12](../labs/12-k3s-gitops/), [23](../labs/23-horizontal-scaling/) | - [ ] Fix a pod that's `CrashLoopBackOff`, `Pending`, and `ImagePullBackOff` |
| 3 | RBAC, NetworkPolicies, cluster upgrades, operators, service mesh, multi-cluster | Phase 11 | - [ ] Upgrade a cluster without downtime; pass **CKA** |

**Resources:** [Kubernetes docs](https://kubernetes.io/docs/) · *Kubernetes Up & Running* · [Killercoda](https://killercoda.com/) (free browser labs) · [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) · **CKA**, then **CKS**.

### 10. Observability

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | Metrics vs logs vs traces, dashboards, basic alerts | [11](../labs/11-observability/) | - [ ] Build a dashboard that answers "is it healthy?" at a glance |
| 2 | PromQL, LogQL, RED/USE, cardinality, alert design, SLOs | [11](../labs/11-observability/), [25](../labs/25-resilience-and-chaos/) | - [ ] Write alerts that fire on user-facing symptoms, with no noise |
| 3 | **Distributed tracing (OpenTelemetry)**, profiling, observability at scale | Phase 11 | - [ ] Trace one slow request across services to its cause |

**Resources:** [Prometheus docs](https://prometheus.io/docs/) · [OpenTelemetry docs](https://opentelemetry.io/docs/) · *Observability Engineering* (Majors, Fong-Jones, Miranda) · [Google SRE books](https://sre.google/books/) (free).

### 11. Security / DevSecOps

| Level | Learn | Practice | Checkpoint |
|---|---|---|---|
| 1 | SSH keys, firewalls, least privilege, secrets out of git, updates | [01](../labs/01-vps-hardening/), [07](../labs/07-cicd-pipeline/) | - [ ] Explain every secret in this repo: where it lives, who can read it |
| 2 | TLS/PKI, vulnerability scanning (Trivy), secrets managers (Vault), OWASP Top 10 | [21](../labs/21-linux-security-hardening/), Phase 10 | - [ ] Make CI fail on critical vulnerabilities in your image |
| 3 | Supply chain (SBOM, cosign signatures, SLSA), policy as code (OPA/Kyverno), threat modelling | Phase 10 | - [ ] Only signed images can run in your cluster |

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
| 3 | SLOs and error budgets, chaos engineering, **incident response and postmortems** | [25](../labs/25-resilience-and-chaos/), Phase 11 | - [ ] Lead a (practice) incident and write a blameless postmortem |

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

These fill the gaps above. They're listed here only, not as lab folders yet:

| Phase | Labs |
|---|---|
| **9 — Cloud (AWS)** | AWS account and IAM done right · VPC with public/private subnets · ALB + auto-scaling group · RDS + S3 · EKS (or ECS) · cost and FinOps |
| **10 — DevSecOps** | Image scanning and SBOMs in CI · signing images with cosign · Vault for secrets · policy as code (Kyverno) · threat modelling one system |
| **11 — SRE and delivery** | OpenTelemetry tracing · dev/staging/prod promotion · canary releases with Argo Rollouts · incident simulation and postmortem · Kubernetes RBAC, NetworkPolicies, cluster upgrade |

---

## Suggested path (about 12 months at 8–10 hours a week)

| Stage | Months | Focus | Labs | Milestone |
|---|---|---|---|---|
| **A. Foundations** | 1–3 | Linux, networking, Bash, Git, containers | 01–06, 13, 17 | All Level 1 checkpoints |
| **B. Automation** | 4–6 | CI/CD, IaC, observability, backups, a real VPS online | 03, 07–11 | The VPS rebuilt from code; alerts on your phone |
| **C. Platforms** | 7–9 | Kubernetes, cloud (AWS), scaling | 12, 22–24, Phase 9 | **AWS SAA** certification |
| **D. Depth** | 10–12 | OS internals, security, reliability, SRE | 14–16, 18–21, 25, Phases 10–11 | **CKA** certification; a public portfolio |

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
| AWS Solutions Architect Associate | After Stage C | The most asked-for cloud certification |
| CKA (Certified Kubernetes Administrator) | Stage D | Hands-on exam, highly respected |
| HashiCorp Terraform Associate | Any time after lab 10 | Quick, validates IaC basics |
| CKS (Kubernetes Security) | After CKA | Security depth |

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
