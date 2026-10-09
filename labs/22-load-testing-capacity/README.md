# Lab 22 — Load testing and capacity planning

- **Phase:** 8 — Scalability & reliability
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker or k3d on the Mac, with the observability stack
- **Builds on:** Labs 08, 11, 12

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Know how much traffic hello-api can handle, what breaks first, and what the 4 GB VPS can really run.

## Done when

- [ ] k6 scripts for ramp-up, spike, and soak tests, with thresholds (p95 latency, error rate) that pass or fail
- [ ] Find hello-api's breaking point and the bottleneck (CPU, DB connections, memory) using the lab 11 dashboards
- [ ] Explain throughput, latency, concurrency, and Little's law with your own numbers
- [ ] Show the effect of one improvement (e.g. resource limits, connection pool size) with before/after results
- [ ] A capacity plan for the VPS: which stacks fit in 2 vCPU / 4 GB, with headroom

## Steps

## Code

## What broke

## Lessons learned

## References
