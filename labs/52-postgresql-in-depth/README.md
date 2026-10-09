# Lab 52 — PostgreSQL in depth

- **Phase:** 12 — Data services and messaging
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker Compose, then k3d with **CloudNativePG**
- **Builds on:** Labs 24, 51

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Run PostgreSQL like a DBA: tuning, replication, automatic failover, point-in-time recovery, and upgrades.

## Done when

- [ ] Key settings explained and tuned (`shared_buffers`, `work_mem`, `max_connections`, WAL), checked with `pg_stat_statements`
- [ ] Streaming replication: a primary and a replica; measure replication lag
- [ ] **CloudNativePG** on k3d: a 3-instance cluster, kill the primary, watch automatic failover
- [ ] **Point-in-time recovery**: continuous WAL archiving to object storage, then restore to a timestamp before a `DROP TABLE`
- [ ] PgBouncer connection pooling, and a **major version upgrade** with minimal downtime

## Steps

## Code

## What broke

## Lessons learned

## References
