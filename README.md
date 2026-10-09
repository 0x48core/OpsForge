# OpsForge

Where I forge my DevOps and infrastructure skills through hands-on projects.

> A personal lab for building, breaking, and learning infrastructure — starting on a single real VPS.

## How this repo works

OpsForge has two layers:

| Layer | Where | What it is |
|---|---|---|
| **Journal** | [`labs/`](labs/) | One folder per lab: `knowledge.md` (concepts to learn first) and `README.md` (goal, steps, what broke, what I learned). |
| **Infrastructure** | `ansible/`, `terraform/`, `stacks/`, `k8s/`, `apps/`, `scripts/` | The real, reusable code that runs my server. Labs *produce* this code; later labs *replace* earlier manual work with it. |

Rule of thumb: if I'd want to run it again next month, it belongs in an infrastructure folder, and the lab links to it. See [docs/conventions.md](docs/conventions.md).

**Learning path:** [docs/learning-roadmap.md](docs/learning-roadmap.md) is the curriculum behind the labs: 14 skill domains (plus service mesh and data tracks) in levels, with checkpoints, resources, certifications, fundamentals and career skills, and a 21-month plan.

## Roadmap

Status: ⬜ todo · 🟨 in progress · ✅ done

### Phase 1 — Linux & server foundations
| # | Lab | Status |
|---|---|---|
| 01 | [VPS hardening](labs/01-vps-hardening/) | 🟨 |
| 02 | [Nginx, SSL & reverse proxy](labs/02-nginx-ssl-reverse-proxy/) | 🟨 |
| 03 | [Automated backup & restore](labs/03-automated-backup/) | ⬜ |

### Phase 2 — Containers
| # | Lab | Status |
|---|---|---|
| 04 | [Dockerize an app](labs/04-dockerize-app/) | 🟨 |
| 05 | [Multi-service reverse proxy](labs/05-multi-service-proxy/) | 🟨 |
| 06 | [Self-hosted tools](labs/06-self-hosted-tools/) | 🟨 |

### Phase 3 — CI/CD
| # | Lab | Status |
|---|---|---|
| 07 | [CI/CD pipeline](labs/07-cicd-pipeline/) | 🟨 |
| 08 | [Zero-downtime deployment](labs/08-zero-downtime-deploy/) | 🟨 |

### Phase 4 — Infrastructure as Code
| # | Lab | Status |
|---|---|---|
| 09 | [Ansible: rebuild the server in one command](labs/09-ansible/) | 🟨 |
| 10 | [Terraform: provision VPS, DNS, firewall](labs/10-terraform/) | 🟨 |

### Phase 5 — Observability & Kubernetes
| # | Lab | Status |
|---|---|---|
| 11 | [Observability stack](labs/11-observability/) | 🟨 |
| 12 | [K3s, Helm & GitOps](labs/12-k3s-gitops/) | 🟨 |

### Phase 6 — Networking
| # | Lab | Status |
|---|---|---|
| 13 | [Network fundamentals](labs/13-network-fundamentals/) | ⬜ |
| 14 | [Container networking by hand](labs/14-linux-network-namespaces/) | ⬜ |
| 15 | [DNS deep dive](labs/15-dns-deep-dive/) | ⬜ |
| 16 | [WireGuard VPN and private access](labs/16-wireguard-vpn/) | ⬜ |

### Phase 7 — Linux & OS internals
| # | Lab | Status |
|---|---|---|
| 17 | [Processes, signals, and systemd](labs/17-processes-and-systemd/) | ⬜ |
| 18 | [Containers from scratch](labs/18-containers-from-scratch/) | ⬜ |
| 19 | [Storage and filesystems](labs/19-storage-and-filesystems/) | ⬜ |
| 20 | [Performance troubleshooting](labs/20-performance-troubleshooting/) | ⬜ |
| 21 | [Linux security hardening](labs/21-linux-security-hardening/) | ⬜ |

### Phase 8 — Scalability & reliability
| # | Lab | Status |
|---|---|---|
| 22 | [Load testing and capacity planning](labs/22-load-testing-capacity/) | ⬜ |
| 23 | [Horizontal scaling and autoscaling](labs/23-horizontal-scaling/) | ⬜ |
| 24 | [Caching and database scaling](labs/24-caching-and-databases/) | ⬜ |
| 25 | [Resilience and chaos engineering](labs/25-resilience-and-chaos/) | ⬜ |

Phases 6–8 deepen the foundations: each lab lists what it **builds on**, and all of them run locally (fake VPS, Docker, or k3d).

### Phase 9 — Google Cloud (GCP)
| # | Lab | Status |
|---|---|---|
| 26 | [GCP foundations: account, billing, IAM](labs/26-gcp-foundations/) | ⬜ |
| 27 | [GCP project structure with Terraform](labs/27-gcp-project-structure/) | ⬜ |
| 28 | [GCP networking: VPC, firewall, private access](labs/28-gcp-networking/) | ⬜ |
| 29 | [Compute Engine, instance groups, load balancing](labs/29-gcp-compute-and-load-balancing/) | ⬜ |
| 30 | [Cloud Run, Artifact Registry, Cloud SQL](labs/30-gcp-cloud-run-and-cloud-sql/) | ⬜ |
| 31 | [GKE: Google Kubernetes Engine](labs/31-gke/) | ⬜ |
| 32 | [Cloud operations and FinOps](labs/32-gcp-operations-and-cost/) | ⬜ |

How the GCP projects are structured: [ADR 0004](docs/decisions/0004-gcp-project-structure.md).

### Phase 10 — Kubernetes in depth
| # | Lab | Status |
|---|---|---|
| 33 | [Kubernetes core objects and kubectl](labs/33-k8s-core-objects/) | ⬜ |
| 34 | [Config, storage, and workload types](labs/34-k8s-config-storage-workloads/) | ⬜ |
| 35 | [Kubernetes networking](labs/35-k8s-networking/) | ⬜ |
| 36 | [Scheduling, resources, and disruptions](labs/36-k8s-scheduling-and-resources/) | ⬜ |
| 37 | [Kubernetes security](labs/37-k8s-security/) | ⬜ |
| 38 | [Observability and troubleshooting](labs/38-k8s-observability-and-troubleshooting/) | ⬜ |
| 39 | [Kubernetes internals: the control plane](labs/39-k8s-internals/) | ⬜ |
| 40 | [Cluster lifecycle: upgrades, backup, HA](labs/40-k8s-cluster-lifecycle/) | ⬜ |
| 41 | [Extending Kubernetes: CRDs and operators](labs/41-k8s-extending/) | ⬜ |
| 42 | [Advanced delivery: canary and multiple environments](labs/42-k8s-advanced-delivery/) | ⬜ |

Labs 33–38 run free on k3d; 39–40 need real VMs (GCE, lab 29); 31 and 42 use GKE.

### Phase 11 — Service mesh
| # | Lab | Status |
|---|---|---|
| 43 | [Why a service mesh?](labs/43-why-a-service-mesh/) | ⬜ |
| 44 | [Envoy by hand](labs/44-envoy-by-hand/) | ⬜ |
| 45 | [Linkerd: a mesh in 15 minutes](labs/45-linkerd/) | ⬜ |
| 46 | [Istio basics](labs/46-istio-basics/) | ⬜ |
| 47 | [Traffic management](labs/47-mesh-traffic-management/) | ⬜ |
| 48 | [Zero-trust security with a mesh](labs/48-mesh-security-zero-trust/) | ⬜ |
| 49 | [Mesh observability and distributed tracing](labs/49-mesh-observability-and-tracing/) | ⬜ |
| 50 | [Sidecarless meshes and running in production](labs/50-mesh-ambient-and-production/) | ⬜ |

Demo app: `frontend` → `hello-api` + `quotes` (v1/v2), all on k3d. Learn the concepts with Linkerd, go deep with Istio, then compare sidecarless options (Istio ambient, Cilium).

### Phase 12 — Data services and messaging
| # | Lab | Status |
|---|---|---|
| 51 | [Operating data services: the playbook](labs/51-operating-data-services/) | ⬜ |
| 52 | [PostgreSQL in depth](labs/52-postgresql-in-depth/) | ⬜ |
| 53 | [MySQL](labs/53-mysql/) | ⬜ |
| 54 | [Redis and Valkey](labs/54-redis-and-valkey/) | ⬜ |
| 55 | [MongoDB](labs/55-mongodb/) | ⬜ |
| 56 | [RabbitMQ](labs/56-rabbitmq/) | ⬜ |
| 57 | [Apache Kafka](labs/57-kafka/) | ⬜ |
| 58 | [Event-driven OpsForge](labs/58-event-driven-opsforge/) | ⬜ |
| 59 | [Schema migrations and disaster recovery](labs/59-data-migrations-and-dr/) | ⬜ |

Each data service is run with Docker Compose first, then on k3d with its operator, through the same checklist: deploy, HA, backup + restore, monitoring, upgrades, security. Run one at a time: Kafka and MongoDB clusters need a few GB of RAM each.

### Beyond
New labs get the next number (60, 61, …) and a new phase heading if needed: DevSecOps and SRE (phases 13–14, planned in the [learning roadmap](docs/learning-roadmap.md)), or whatever comes next.

## Repository layout

```
OpsForge/
├── labs/            # one folder per lab: knowledge.md (learn) + README.md (practice)
├── apps/            # sample applications deployed during the labs
├── stacks/          # Docker Compose stacks (proxy, self-hosted tools, monitoring)
├── scripts/         # standalone shell scripts (backup, helpers)
├── ansible/         # server configuration as code
├── terraform/       # cloud resources as code
├── k8s/             # Kubernetes manifests, Helm charts, GitOps apps
├── .github/workflows/  # CI/CD pipelines
└── docs/
    ├── learning-roadmap.md  # curriculum: domains, levels, checkpoints, plan
    ├── architecture.md  # what currently runs on the server
    ├── conventions.md   # naming, secrets, workflow rules
    └── decisions/       # why I chose X over Y (ADRs)
```

## Environment

- **Server:** 1 VPS, 2 vCPU / 4 GB RAM (enough for every lab, including K3s)
- **Provider / OS / domain:** see [docs/architecture.md](docs/architecture.md)

## References

- [roadmap.sh/devops](https://roadmap.sh/devops)
- [90DaysOfDevOps](https://github.com/MichaelCade/90DaysOfDevOps)

## License

[Apache 2.0](LICENSE)
