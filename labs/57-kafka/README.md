# Lab 57 — Apache Kafka

- **Phase:** 12 — Data services and messaging
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** k3d with **Strimzi** (KRaft mode, no ZooKeeper)
- **Builds on:** Labs 51, 56; Go

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Event streaming with Kafka: the log, partitions, consumer groups, and running it on Kubernetes.

## Done when

- [ ] Explain topics, partitions, offsets, consumer groups, and why Kafka is a log, not a queue
- [ ] A 3-broker cluster with **Strimzi** in KRaft mode; topics and users as Kubernetes resources
- [ ] Go producer and consumer: keys and ordering, `acks=all`, idempotent producer, commit strategies
- [ ] Replication factor and `min.insync.replicas`: kill a broker during writes and explain what's safe
- [ ] Retention vs log compaction, **consumer lag** monitoring in Grafana, and a partition reassignment

## Steps

## Code

## What broke

## Lessons learned

## References
