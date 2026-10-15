# Lab 19 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

"Disk full" is one of the most common production incidents, and it's often not what it seems: `df` says 100%, but `du` finds nothing; or there's plenty of space, but "No space left on device". Databases (labs 04, 52), container images (lab 04), logs (lab 11), and backups (lab 03) all live on filesystems. Knowing how a disk becomes a mounted directory, how to grow it without downtime, and how to read the symptoms makes these incidents short and boring.

## Core concepts

### The storage stack

```
files and directories       /var/lib/postgresql/data/…
        │
filesystem                  ext4, xfs: turns blocks into files, permissions, journaling
        │
(optional) LVM              logical volumes: resizable, spanning disks, snapshots
        │
partition                   a slice of a disk: /dev/sda1, /dev/nvme0n1p1
        │
block device                a whole disk: /dev/sda, /dev/nvme0n1, /dev/vda (cloud), /dev/loop0 (a file used as a disk)
        │
hardware / cloud            SSD, NVMe, a cloud persistent disk
```

- **Everything is a file.** Disks are device files in `/dev`, identified by a **major:minor** number pair the kernel publishes in `/sys/class/block/<name>/dev`. **udev** creates the `/dev` entries automatically when the kernel announces a device; without udev you'd create them with `mknod` (you'll see this in the fake VPS).
- `lsblk` shows the stack: disks → partitions → LVM volumes → mount points.

### Partitions and partition tables

- **GPT** is the modern partition table (MBR is the old one, limited to 2 TB and 4 primary partitions). Cloud images use GPT.
- Partition tools: `fdisk` / `sfdisk` (scriptable), `parted`, `gdisk`. On Ubuntu 24.04, `fdisk` and `sfdisk` are in the **`fdisk`** package.
- After changing a partition table on a disk in use, the kernel must re-read it: `partx -u`, `partprobe`.

### Filesystems

| | ext4 | xfs |
|---|---|---|
| Default on | Debian, Ubuntu | RHEL, Rocky |
| Grow | Online (mounted) | Online (mounted) |
| **Shrink** | Offline only | **Never** |
| Inodes | **Fixed at `mkfs`** | Allocated dynamically |
| Good for | General use | Large files, parallel I/O |

- **Journaling:** changes are written to a journal first, so a crash leaves the filesystem consistent (no long `fsck`). Data written by an app but not yet `fsync`ed can still be lost, which is why databases call `fsync` (lab 52).
- **Inodes:** every file and directory needs one inode (its metadata: owner, permissions, size, block pointers). ext4 creates a fixed number at `mkfs`. **Millions of tiny files can exhaust inodes while plenty of space is free**: "No space left on device" with `df -h` at 20%. Check with `df -i`.
- **Reserved blocks:** ext4 keeps 5% for root by default, so normal users see "full" earlier than root (`tune2fs -m`).

### Mounting

- `mount /dev/x /mnt/data` attaches a filesystem to a directory. There's one tree; disks are grafted into it.
- **`/etc/fstab`** lists mounts to make at boot: `<what> <where> <type> <options> <dump> <fsck order>`.
  - Use **`UUID=`** (from `blkid`), not `/dev/sdb1`: device names can change between boots, especially in clouds.
  - **`nofail`** for non-essential disks: without it, a missing disk can stop the server from booting.
  - systemd turns each fstab line into a `.mount` unit (lab 17).
- A broken fstab line can leave a server stuck in emergency mode at the next boot. **Check before rebooting:** `findmnt --verify` and `mount -a`.
- `findmnt` shows the mount tree; `mount` and `/proc/mounts` list all mounts with options (`ro`, `noexec`, `nosuid`…).

### LVM: Logical Volume Manager

```
PV (physical volume)     /dev/loop1          /dev/loop2         ← disks or partitions handed to LVM
        └───────────── VG (volume group) "lab19" ─────────────┘  ← a pool of space
                 LV "data"  (grows into free space)              ← what you mkfs and mount: /dev/lab19/data
```

- **Grow online:** add a disk (`pvcreate` + `vgextend`), then `lvextend -r` grows the LV **and** the filesystem in one step, while it's mounted and in use.
- **Snapshots:** a point-in-time copy (copy-on-write) for a consistent backup. Needs the kernel's `dm-snapshot` module. Snapshots slow writes down and fill up, so they're temporary.
- Cloud disks can usually be resized directly, but LVM is still common on bare metal and in VM images.

### "Disk full": three different problems

| Symptom | Cause | Find it | Fix |
|---|---|---|---|
| `df -h` 100% | Really out of space | `du -xh / \| sort -h \| tail`, `ncdu` | Delete or rotate (logs!), grow the disk |
| `df -h` fine, `df -i` 100% | **Out of inodes** (millions of small files) | `df -i`, then count files per directory | Delete files; recreate the fs with more inodes, or use xfs |
| `df` says full, **`du` doesn't add up** | **Deleted but still open** file: space isn't freed until the last process closes it | `lsof +L1` (open files with 0 links) | Restart or signal the process (log rotation: send `HUP`), or truncate `/proc/<pid>/fd/<n>` |

The third one is classic: someone `rm`s a 50 GB log file that a service still writes to. The name is gone, the space isn't.

Also watch out for failed operations that leave partial files behind (a failed `fallocate` or download), and for Docker: images, stopped containers, build cache, and volumes live under `/var/lib/docker` (`docker system df`).

### I/O performance basics

| Metric | Meaning |
|---|---|
| **IOPS** | Operations per second (small random I/O, databases) |
| **Throughput** | MB/s (big sequential I/O, backups, video) |
| **Latency** | Time per operation; what users feel |
| **Queue depth** | Operations in flight at once |

- `iostat -x 1`: `%util` near 100% and a high `await` (ms per I/O) mean the disk is the bottleneck. Processes in state `D` (lab 17) confirm it.
- **The page cache:** Linux keeps recently used file data in free RAM (the `buff/cache` column in `free -h`). Second reads come from memory. That's why benchmarks need `--direct=1`, and why a benchmark on a file that's itself cached (a loop device on a laptop) gives impossibly good numbers.
- `fio` is the standard benchmark: choose the pattern (`randread`, `write`), block size (`4k` for databases), and queue depth to match the real workload.

### Swap

Swap is disk space used as overflow for RAM. It prevents sudden OOM kills, but heavy swapping makes everything slow. On servers, a small swap file plus monitoring is common. Kubernetes nodes traditionally run without swap. `vm.swappiness` controls how eagerly Linux swaps.

## Key terms

| Term | Meaning |
|---|---|
| Block device | A disk-like device accessed in blocks (`/dev/sda`, `/dev/loop0`) |
| Loop device | A regular file presented as a block device |
| Partition table | GPT or MBR: how a disk is divided |
| Filesystem | Structure that turns blocks into files and directories |
| Inode | Per-file metadata record; fixed count on ext4 |
| Mount point | Directory where a filesystem is attached |
| UUID | Unique filesystem ID, stable across boots |
| PV / VG / LV | LVM physical volume / volume group / logical volume |
| Page cache | File data cached in RAM |
| IOPS / throughput / latency | Operations per second / MB per second / time per operation |

## Commands to know

| Command | What it does |
|---|---|
| `lsblk -f`, `blkid` | Disks, partitions, filesystems, UUIDs |
| `df -hT`, `df -i` | Space / inodes per filesystem |
| `du -xh --max-depth=1 /var \| sort -h` | What's using space (stays on one filesystem) |
| `findmnt`, `findmnt --verify` | Mount tree / check fstab |
| `losetup -fP --show <file>`, `losetup -d` | Attach / detach a file as a disk |
| `sfdisk`, `parted`, `partx -u` | Partition / re-read partitions |
| `mkfs.ext4`, `mkfs.xfs`, `tune2fs -l` | Create / inspect a filesystem |
| `mount`, `umount`, `mount -a` | Mount / unmount / mount everything in fstab |
| `pvcreate`, `vgcreate`, `vgextend`, `lvcreate`, `lvextend -r`, `pvs`/`vgs`/`lvs` | LVM |
| `lsof +L1` | Deleted files still held open |
| `iostat -x 1`, `fio`, `free -h` | I/O load / benchmark / memory and cache |

## Before you start, can you answer these?

1. Why use `UUID=` instead of `/dev/sdb1` in `/etc/fstab`?
2. How can "No space left on device" happen when `df -h` shows free space?
3. You deleted a 10 GB log, but `df` didn't change. Why, and how do you fix it?
4. What do PV, VG, and LV mean, and which one do you mount?
5. Why can't you shrink an xfs filesystem, and why does that matter for planning?
6. Why do benchmarks need `--direct=1`?

## After the lab, check yourself

1. At which file did inode exhaustion hit, and how much space was still free?
2. What did `df` and `du` show for the deleted-but-open file, and what freed the space?
3. How big was the volume before and after `lvextend -r`, and was the filesystem mounted the whole time?
4. What did `findmnt --verify` report for the broken fstab line?
5. Why were the fio numbers on the loop device unrealistic?
6. Which of these problems would hit a Postgres server (lab 52) first, and how would you alert on it (lab 11)?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- *How Linux Works* (Brian Ward): disks and filesystems chapter
- [Arch Wiki: File systems](https://wiki.archlinux.org/title/File_systems), [fstab](https://wiki.archlinux.org/title/Fstab), [LVM](https://wiki.archlinux.org/title/LVM)
- [Red Hat: Configuring and managing logical volumes](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/index)
- `man 5 fstab`, `man 8 lvm`, `man 8 lsof`
- [fio documentation](https://fio.readthedocs.io/)
- Brendan Gregg, *Systems Performance*: file systems and disks chapters
