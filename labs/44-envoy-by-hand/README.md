# Lab 44 — Envoy by hand

- **Phase:** 11 — Service mesh
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker Compose on the Mac
- **Builds on:** Labs 05, 08, 43

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Understand the data plane before automating it: configure Envoy yourself, as a sidecar in front of a service.

## Done when

- [ ] Run Envoy in Docker Compose in front of hello-api with a static config you write: listeners, filter chains, routes, clusters
- [ ] Add retries, timeouts, and a circuit breaker (outlier detection) in the Envoy config, and test them by killing the backend
- [ ] Use the Envoy admin API (`/clusters`, `/stats`, `/config_dump`) to see what it's doing
- [ ] Put Envoy as a sidecar next to *two* services and route between them: the sidecar pattern
- [ ] Explain xDS: how a control plane (istiod) would push this config dynamically instead of a file

## Steps

## Code

## What broke

## Lessons learned

## References
