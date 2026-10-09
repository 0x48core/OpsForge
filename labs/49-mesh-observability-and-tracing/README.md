# Lab 49 — Mesh observability and distributed tracing

- **Phase:** 11 — Service mesh
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d with Istio, plus the lab 11 stack
- **Builds on:** Labs 11, 38, 46

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

See the whole system: a live service graph, metrics for every call, and traces that follow one request across services.

## Done when

- [ ] Envoy proxy metrics scraped by Prometheus; RED dashboards per service pair in Grafana
- [ ] **Kiali** service graph with health and traffic animation; spot the broken edge after a fault injection
- [ ] **Distributed tracing** with OpenTelemetry → Jaeger or Tempo: frontend and quotes propagate trace headers (the mesh can't do that part for you)
- [ ] Find one slow request's cause from a trace, and link it to its logs in Loki
- [ ] Access logs from the proxies into Loki (lab 11), with sensible sampling

## Steps

## Code

## What broke

## Lessons learned

## References
