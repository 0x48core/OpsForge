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

### Beyond
New labs get the next number (26, 27, …) and a new phase heading if needed: message queues, cloud-managed services, service mesh, whatever comes next.

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
