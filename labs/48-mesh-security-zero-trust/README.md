# Lab 48 — Zero-trust security with a mesh

- **Phase:** 11 — Service mesh
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d with Istio
- **Builds on:** Labs 37, 46

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Make every call authenticated, encrypted, and authorised by service identity, not by network location.

## Done when

- [ ] **STRICT mTLS** for the whole mesh with PeerAuthentication; show that a pod outside the mesh can no longer connect
- [ ] Explain mesh identity: Kubernetes ServiceAccount → SPIFFE ID → workload certificate, and how certificates rotate
- [ ] **AuthorizationPolicy**: frontend may call quotes and hello-api; nothing else may call anything (default deny)
- [ ] L7 rules: allow only `GET` on certain paths for a given caller
- [ ] JWT validation at the ingress gateway (RequestAuthentication), so only signed tokens reach the app

## Steps

## Code

## What broke

## Lessons learned

## References
