# Lab 30 — Cloud Run, Artifact Registry, Cloud SQL

- **Phase:** 9 — Google Cloud (GCP)
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** GCP (dev + prod projects)
- **Builds on:** Labs 04, 07, 27

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Run hello-api serverless: images in Artifact Registry, the app on Cloud Run, Postgres on Cloud SQL, and secrets in Secret Manager.

## Done when

- [ ] CI pushes hello-api to **Artifact Registry** (via Workload Identity Federation, lab 27)
- [ ] hello-api on **Cloud Run**: min/max instances, concurrency, revisions, and a traffic split between two revisions
- [ ] **Cloud SQL** for PostgreSQL with private IP; Cloud Run connects through the VPC
- [ ] Database password in **Secret Manager**, read by the service's own service account
- [ ] Compare Cloud Run vs a VM vs GKE for this app: cost, operations, cold starts

## Steps

## Code

## What broke

## Lessons learned

## References
