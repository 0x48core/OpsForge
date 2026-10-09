# Lab 51 — Operating data services: the playbook

- **Phase:** 12 — Data services and messaging
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker Compose, then k3d
- **Builds on:** Labs 03, 04, 12, 34

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Learn the questions every database or broker raises before you run one: state, storage, HA, backups, upgrades, security, and whether to run it yourself at all.

## Done when

- [ ] Explain what makes stateful services hard on containers and Kubernetes: identity, storage, ordering, failover
- [ ] Compare four ways to run a database: a container (Compose), a Helm chart, an **operator**, a **managed service** (Cloud SQL, lab 30), and choose for each OpsForge component
- [ ] Write the **operations checklist** used in labs 52–57: deploy, config, HA/replication, backup + restore test, monitoring + alerts, scaling, upgrades, security
- [ ] Storage on Kubernetes for databases: StorageClass, volume binding, expansion, what `local-path` can't do (lab 34)
- [ ] Explain RPO and RTO, and set targets for each OpsForge data service

## Steps

## Code

## What broke

## Lessons learned

## References
