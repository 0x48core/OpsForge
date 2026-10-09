# Lab 41 — Extending Kubernetes: CRDs and operators

- **Phase:** 10 — Kubernetes in depth
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d
- **Builds on:** Labs 33, 39; Go (hello-api)

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Teach Kubernetes new tricks: custom resources, controllers, and admission webhooks.

## Done when

- [ ] Write a CustomResourceDefinition with validation and `kubectl get` your new kind
- [ ] Build a small operator in Go with **kubebuilder** (e.g. a `HelloApp` resource that creates a Deployment + Service)
- [ ] Status, conditions, and finalizers; make the reconcile loop idempotent
- [ ] An admission webhook (or a Kyverno policy) that mutates or validates resources
- [ ] Explain how Argo CD, cert-manager, or the Prometheus Operator use the same pattern

## Steps

## Code

## What broke

## Lessons learned

## References
