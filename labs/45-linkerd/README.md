# Lab 45 — Linkerd: a mesh in 15 minutes

- **Phase:** 11 — Service mesh
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d
- **Builds on:** Labs 43, 44

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Learn the core mesh features with the simplest mesh: automatic mTLS, golden metrics, and reliability without touching app code.

## Done when

- [ ] Install Linkerd (CLI + Helm), check it (`linkerd check`), and inject the demo app's namespace
- [ ] **Automatic mTLS** between all services, proven with `tcpdump` and `linkerd viz edges`
- [ ] Golden metrics per route (success rate, requests/s, latency percentiles) in Linkerd Viz, and `linkerd viz tap` on live traffic
- [ ] Retries and timeouts configured with Gateway API HTTPRoute (or ServiceProfiles), tested by breaking quotes
- [ ] Measure the overhead against the lab 43 baseline: extra RAM per pod and added latency

## Steps

## Code

## What broke

## Lessons learned

## References
