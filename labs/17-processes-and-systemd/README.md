# Lab 17 — Processes, signals, and systemd

- **Phase:** 7 — Linux & OS internals
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Fake VPS
- **Builds on:** Labs 01, 02, 08

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Understand how Linux runs programs: processes, signals, and how systemd supervises and limits services.

## Done when

- [ ] Explain fork/exec, PIDs, parent/child, and read a process's state from `/proc/<pid>/`
- [ ] Create and clean up a zombie and an orphan process on purpose
- [ ] Send SIGTERM, SIGKILL, SIGHUP, SIGSTOP to a test program and explain each reaction
- [ ] Write a systemd service with a timer (replacing cron), and use `journalctl` filters
- [ ] Limit a service's CPU and memory with systemd (`CPUQuota`, `MemoryMax`) and watch it get throttled / OOM-killed

## Steps

## Code

## What broke

## Lessons learned

## References
