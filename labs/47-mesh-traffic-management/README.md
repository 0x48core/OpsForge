# Lab 47 — Traffic management

- **Phase:** 11 — Service mesh
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d with Istio
- **Builds on:** Labs 08, 22, 46

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Control traffic between services precisely, and test how the system behaves when parts of it fail.

## Done when

- [ ] **Canary**: send 90% of traffic to quotes v1 and 10% to v2, then shift gradually; check with k6 results
- [ ] Header-based routing (e.g. `x-user: tester` always gets v2) and traffic **mirroring** to v2 without affecting users
- [ ] **Fault injection**: add delays and HTTP errors to quotes, and see how frontend copes
- [ ] Retries, timeouts, and **circuit breaking** (outlier detection) so a failing quotes v2 is ejected automatically
- [ ] Explain the risk of retries at every hop (retry storms) and set sensible budgets

## Steps

## Code

## What broke

## Lessons learned

## References
