# Lab 18 — Containers from scratch

- **Phase:** 7 — Linux & OS internals
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Fake VPS
- **Builds on:** Labs 04, 14, 17

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Build a minimal container with `unshare`, cgroups v2, and an overlay filesystem, to see that a container is just a process with extra isolation.

## Done when

- [ ] Isolate a shell with PID, mount, UTS, network, and user namespaces (`unshare`)
- [ ] Give it its own root filesystem (Alpine minirootfs) with `chroot`/`pivot_root`
- [ ] Limit its memory and CPU with cgroups v2 by writing to `/sys/fs/cgroup`
- [ ] Layer a writable overlayfs on a read-only base, like image layers (lab 04)
- [ ] Map each step to what `docker run` does, in "Lessons learned"

## Steps

## Code

## What broke

## Lessons learned

## References
