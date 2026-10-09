# Lab 56 — RabbitMQ

- **Phase:** 12 — Data services and messaging
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Docker Compose, then k3d with the RabbitMQ Cluster Operator
- **Builds on:** Labs 25, 51; Go (hello-api)

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Reliable messaging with a classic broker: exchanges and queues, acknowledgements, dead letters, and a cluster.

## Done when

- [ ] The AMQP model: exchanges (direct, topic, fanout), queues, bindings, routing keys
- [ ] A Go producer and consumer: manual acks, prefetch, publisher confirms, and what happens when a consumer crashes
- [ ] Retries with a **dead-letter queue**, and idempotent consumers
- [ ] **Quorum queues** on a 3-node cluster via the operator; kill a node and check no message is lost
- [ ] Management UI and Prometheus metrics: queue depth, consumer utilisation; an alert on growing backlog

## Steps

## Code

## What broke

## Lessons learned

## References
