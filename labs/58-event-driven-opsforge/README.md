# Lab 58 — Event-driven OpsForge

- **Phase:** 12 — Data services and messaging
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker Compose or k3d
- **Builds on:** Labs 24, 52, 54, 56 or 57

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Put it together: hello-api publishes events, a worker processes them, and the system stays correct when parts fail.

## Done when

- [ ] hello-api writes the visit and an event in **one Postgres transaction** (outbox pattern), fixing the lab 04 partial-write bug for good
- [ ] A relay publishes outbox events to RabbitMQ or Kafka; a **worker** service updates Redis counters
- [ ] Idempotent consumer: processing the same event twice changes nothing
- [ ] Chaos: stop the broker, the worker, and Redis in turn; show no visit is lost and counts converge
- [ ] A decision record: which datastore and which broker for which job, and why

## Steps

## Code

## What broke

## Lessons learned

## References
