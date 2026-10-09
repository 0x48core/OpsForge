# Lab 59 — Schema migrations and disaster recovery

- **Phase:** 12 — Data services and messaging
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker Compose, k3d, and GCP (labs 30, 52)
- **Builds on:** Labs 03, 08, 52, 58

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Change databases safely while the app runs, and prove you can recover from losing everything.

## Done when

- [ ] Versioned schema migrations with a tool (e.g. goose, Atlas, or Flyway) run by CI before deploy
- [ ] A **zero-downtime migration** with expand → migrate → contract (lab 08): rename a column without errors under load
- [ ] A backup policy for every data service from labs 52–57, all in restic or native tools, with **restore tests** automated
- [ ] A **DR drill**: destroy the whole environment, restore from backups, and measure the real RPO and RTO
- [ ] A DR runbook someone else could follow

## Steps

## Code

## What broke

## Lessons learned

## References
