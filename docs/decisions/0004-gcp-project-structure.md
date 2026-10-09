# 0004 — Google Cloud as the cloud, and how its projects are structured

- **Status:** accepted (applied in labs 26–32)
- **Date:** 2026-10-09

## Context

The labs so far run on one VPS or locally. The next step is a hyperscale cloud. **Google Cloud (GCP)** was chosen: GKE is a strong managed Kubernetes for the Kubernetes track (labs 33–42), Cloud Run is a simple serverless target, and the free trial ($300) covers the labs. The concepts carry over to AWS and Azure.

On a hyperscaler, **structure decides cost control, security, and blast radius**, so it's designed before anything is created.

## Decisions

### 1. Resource hierarchy: one project per environment

```
Organization (optional: free Cloud Identity on your own domain)
└── Folder: opsforge
    ├── opsforge-shared-<suffix>   Terraform state, Artifact Registry, CI identity (Workload Identity Federation), billing export
    ├── opsforge-dev-<suffix>      everything for dev; safe to delete and recreate
    └── opsforge-prod-<suffix>     production
```

- A **project** is GCP's boundary for billing, quotas, IAM, and APIs. Separate projects mean a mistake in dev can't touch prod, and the bill per environment is visible.
- Without an Organization (a plain Gmail account), use the same three projects without the folder. Cloud Identity Free + a domain you own gives you an Organization and folders, which is closer to how companies work.
- Project IDs are **globally unique and permanent**, so add a short random suffix: `opsforge-dev-4f2a`.

### 2. Naming, region, labels

| What | Convention | Example |
|---|---|---|
| Project | `opsforge-<env>-<suffix>` | `opsforge-prod-4f2a` |
| Resources | `<env>-<component>[-<detail>]` | `prod-vpc`, `prod-gke`, `dev-sql-main` |
| Region | `asia-southeast1` (Singapore): lowest latency from Vietnam | zones `asia-southeast1-a/b/c` |
| Labels (every resource) | `env`, `app`, `managed-by`, `owner` | `env=prod, app=opsforge, managed-by=terraform` |

Labels flow into the billing export, so cost per environment and component can be queried.

### 3. Billing guard rails

- One billing account; a **budget with alerts at 50%, 90%, 100%** on each project.
- Budgets only *alert*, they don't stop spending. dev resources are destroyed after each lab (`terraform destroy`).
- Billing export to BigQuery in `opsforge-shared` (lab 32).

### 4. IAM: least privilege, no keys

| Who | Gets | Where |
|---|---|---|
| You (daily work) | Predefined roles you need (e.g. `roles/container.developer`), not `Owner` | dev; read-only in prod |
| Terraform (per environment) | A service account with only the roles that environment's resources need | its own project |
| GitHub Actions | **Workload Identity Federation**: GitHub's OIDC token is exchanged for short-lived credentials, restricted to `0x48core/OpsForge` (and `main` for prod) | `opsforge-shared` pool, impersonating the env's Terraform SA |
| Workloads | One service account per app (Cloud Run service identity, GKE Workload Identity) | dev / prod |

**No service account JSON keys are created**, ever. They're long-lived secrets that leak. Federation and impersonation replace them.

### 5. Terraform state and layout

```
terraform/gcp/
├── bootstrap/        # applied once, by hand: shared project, state bucket, WIF pool, Terraform SAs
├── modules/          # reusable building blocks
│   ├── network/      # VPC, subnets, firewall, Cloud NAT
│   ├── gke/
│   ├── cloud-run-service/
│   └── cloud-sql/
└── envs/
    ├── dev/          # backend "gcs" { bucket = "<shared-state-bucket>", prefix = "envs/dev" }
    └── prod/         # same modules, prod values, prefix "envs/prod"
```

- State: one GCS bucket in `opsforge-shared`, **object versioning on** (recover a corrupted state), uniform bucket-level access, one prefix per environment.
- `bootstrap/` solves the chicken-and-egg problem (the state bucket must exist before other configs can use it). It runs with your own credentials, once.
- `envs/dev` and `envs/prod` call the same modules with different variables, so prod is dev with bigger numbers, not a different design.
- CI: `terraform plan` on every PR for both environments; `apply` to dev on merge, to prod only after approval (a GitHub `production` environment, lab 07).

## Consequences

- More setup up front (three projects, federation) than one project with a key. In return: limited blast radius, no secrets to leak, a clear bill.
- dev can be destroyed after every lab to keep costs near zero.
- The existing `terraform/envs/local` and `terraform/envs/digitalocean` (lab 10) stay as they are; GCP lives under `terraform/gcp/`.
