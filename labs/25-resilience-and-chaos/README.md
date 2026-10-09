# Lab 25 — Resilience and chaos engineering

- **Phase:** 8 — Scalability & reliability
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d cluster and Docker on the Mac
- **Builds on:** Labs 08, 11, 12, 22

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Make failures boring: timeouts, retries, rate limits, and SLOs, proven by breaking things on purpose.

## Done when

- [ ] Timeouts and retries with backoff and jitter in hello-api; explain retry storms
- [ ] Rate limiting with a Traefik middleware, tested with k6
- [ ] Inject latency and packet loss (`tc netem` or Toxiproxy) between the app and Postgres; observe and handle it
- [ ] Chaos experiments: kill pods, a node, and the database; record what users would have seen
- [ ] Define an SLO for hello-api with an error budget and a burn-rate alert in Prometheus (lab 11)

## Steps

## Code

## What broke

## Lessons learned

## References
