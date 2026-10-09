# Lab 37 — Kubernetes security

- **Phase:** 10 — Kubernetes in depth
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d
- **Builds on:** Labs 21, 33, 35

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Lock a cluster down: who can do what, what pods may do, and which images may run.

## Done when

- [ ] **RBAC**: Roles, ClusterRoles, bindings, ServiceAccounts; test with `kubectl auth can-i`
- [ ] Pod Security Standards (baseline, restricted) enforced per namespace
- [ ] securityContext in depth: non-root, read-only filesystem, capabilities, seccomp
- [ ] Policy as code with **Kyverno** (or OPA Gatekeeper): reject `:latest` tags and privileged pods
- [ ] Secrets: encryption at rest, and keeping them out of git (Sealed Secrets or External Secrets with GCP Secret Manager)

## Steps

## Code

## What broke

## Lessons learned

## References
