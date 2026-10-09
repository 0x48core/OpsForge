# Lab 23 — Horizontal scaling and autoscaling

- **Phase:** 8 — Scalability & reliability
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d cluster (lab 12)
- **Builds on:** Labs 12, 22

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Scale out instead of up: stateless replicas behind a load balancer, added and removed automatically under load.

## Done when

- [ ] Explain why hello-api is stateless and what would break if it kept state in memory
- [ ] Compare load-balancing behaviour (round robin vs least connections) under uneven load
- [ ] Horizontal Pod Autoscaler on CPU: pods scale up during a k6 test and back down afterwards
- [ ] Autoscaling on a custom metric (requests/s from Prometheus) with KEDA or the Prometheus Adapter
- [ ] Show where scaling stops helping (a shared bottleneck such as the single Postgres)

## Steps

## Code

## What broke

## Lessons learned

## References
