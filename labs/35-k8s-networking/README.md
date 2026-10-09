# Lab 35 — Kubernetes networking

- **Phase:** 10 — Kubernetes in depth
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d
- **Builds on:** Labs 13, 14, 33

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Understand how traffic reaches a pod, inside and from outside the cluster, and how to restrict it.

## Done when

- [ ] Service types: ClusterIP, NodePort, LoadBalancer, headless; explain what kube-proxy does for each
- [ ] Cluster DNS (CoreDNS): resolve `svc.namespace.svc.cluster.local` and debug a DNS failure
- [ ] Ingress vs **Gateway API**: route by host and path, TLS termination
- [ ] **NetworkPolicies**: default-deny a namespace, then allow only app → db
- [ ] Explain the CNI's job and trace a packet from one pod to a pod on another node

## Steps

## Code

## What broke

## Lessons learned

## References
