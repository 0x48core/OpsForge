# Lab 27 — GCP project structure with Terraform

- **Phase:** 9 — Google Cloud (GCP)
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** GCP + Terraform (lab 10) + GitHub Actions (lab 07)
- **Builds on:** Labs 07, 10, 26

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Lay out OpsForge on GCP the way a team would: separate projects per environment, Terraform with remote state, and CI that deploys without any long-lived keys.

## Done when

- [ ] Projects created as code: `opsforge-shared` (state, registry, CI identity), `opsforge-dev`, `opsforge-prod` ([ADR 0004](../../docs/decisions/0004-gcp-project-structure.md))
- [ ] Terraform remote state in a GCS bucket with versioning; layout `terraform/gcp/{bootstrap,modules,envs/dev,envs/prod}`
- [ ] A Terraform service account per environment with only the roles it needs
- [ ] **Workload Identity Federation**: GitHub Actions authenticates to GCP with OIDC, no JSON key ever created
- [ ] `terraform plan` runs in CI on PRs; `apply` only from `main` and only for that environment

## Steps

## Code

## What broke

## Lessons learned

## References
