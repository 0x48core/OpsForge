# Lab 24 — Caching and database scaling

- **Phase:** 8 — Scalability & reliability
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker Compose or k3d
- **Builds on:** Labs 04, 22, 23

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Make the data layer keep up: correct caching, connection pooling, indexes, and read replicas.

## Done when

- [ ] Fix the lab 04 partial-write bug: Postgres as the source of truth, Redis as a cache-aside with a TTL
- [ ] Measure cache hit ratio and the latency difference with and without the cache
- [ ] PgBouncer in front of Postgres; show the effect on connections under load
- [ ] An index found with `EXPLAIN ANALYZE` that speeds up a slow query
- [ ] A Postgres streaming replica for reads; explain replication lag and what it means for the app

## Steps

## Code

## What broke

## Lessons learned

## References
