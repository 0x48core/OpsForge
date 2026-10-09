# Lab 50 — Sidecarless meshes and running in production

- **Phase:** 11 — Service mesh
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d (two clusters for multi-cluster), optionally GKE (lab 31)
- **Builds on:** Labs 31, 45–49

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Compare where meshes are going (sidecarless) and what it takes to run one for real.

## Done when

- [ ] Move the demo app to **Istio ambient mode**: ztunnel for L4 mTLS, a waypoint proxy only where L7 features are needed
- [ ] Try **Cilium**'s service mesh (eBPF) on a fresh k3d cluster, and compare features
- [ ] Measure and compare: RAM and latency for no mesh, Linkerd, Istio sidecars, Istio ambient (with lab 43's baseline)
- [ ] Upgrade the Istio control plane safely with revisions (canary upgrade), and explain multi-cluster with an east-west gateway on two k3d clusters
- [ ] A written decision: **when not to use a service mesh**, using your own measurements

## Steps

## Code

## What broke

## Lessons learned

## References
