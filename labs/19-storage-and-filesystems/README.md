# Lab 19 — Storage and filesystems

- **Phase:** 7 — Linux & OS internals
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Fake VPS (loop devices: safe practice disks)
- **Builds on:** Labs 03, 17

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Manage disks like on a real server: partitions, LVM, filesystems, mounts, and the classic "disk full" problems.

## Done when

- [ ] Create practice disks with loop devices, partition them, and make ext4 and xfs filesystems
- [ ] Use LVM: create a volume group, extend a logical volume, and grow the filesystem online
- [ ] Mount persistently with `/etc/fstab` using UUIDs, and recover from a bad fstab entry
- [ ] Reproduce "disk full" two ways (out of space vs out of inodes) and a deleted-but-open file; fix each
- [ ] Measure disk I/O with `fio` and `iostat`, and explain what Docker volumes are on disk

## Steps

## Code

## What broke

## Lessons learned

## References
