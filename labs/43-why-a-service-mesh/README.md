# Lab 43 — Why a service mesh?

- **Phase:** 11 — Service mesh
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d (lab 12)
- **Builds on:** Labs 12, 22, 33, 35, 38

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Feel the problems a mesh solves before installing one: run a small multi-service app on plain Kubernetes and measure what's missing.

## Done when

- [ ] Write two small Go services next to hello-api: `apps/frontend` (calls hello-api and quotes) and `apps/quotes` (with a v1 and a v2)
- [ ] Deploy all three on k3d with plain manifests or Helm, plus a k6 traffic generator
- [ ] Show with `tcpdump` that pod-to-pod traffic is **unencrypted**
- [ ] Show what you *can't* see or control without code changes: per-call success rate and latency between services, retries, timeouts, traffic splitting
- [ ] Write the baseline: latency, RAM, and the list of missing features, to compare in labs 45–50

## Steps

## Code

## What broke

## Lessons learned

## References
