# Lab 19 — Storage and filesystems

- **Phase:** 7 — Linux & OS internals
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Fake VPS (loop devices: safe practice disks)
- **Builds on:** Labs 03, 17

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Manage disks like on a real server: partitions, LVM, filesystems, mounts, and the classic "disk full" problems.

## Done when

- [ ] Create practice disks with loop devices, partition them, and make ext4 and xfs filesystems
- [ ] Use LVM: create a volume group, extend a logical volume, and grow the filesystem online
- [ ] Mount persistently with `/etc/fstab` using UUIDs, and recover from a bad fstab entry
- [ ] Reproduce "disk full" two ways (out of space vs out of inodes) and a deleted-but-open file; fix each
- [ ] Measure disk I/O with `fio` and `iostat`, and explain what Docker volumes are on disk

## Verified while preparing this lab

On the fake VPS (Ubuntu 24.04.5):

| Experiment | Result |
|---|---|
| 1 GiB sparse image | apparent 1 GiB, real 0 bytes |
| GPT with 2 partitions on `/dev/loop0` | kernel saw them; device files had to be made with `mknod` (no udev) |
| ext4 with only 64 inodes | **"No space left on device" at file 54, with 170 MB still free** |
| Filling a filesystem | 100% used; a failed `fallocate` **left a 259 MB file behind** |
| Deleted but open 150 MB file | `df` 151M used vs `du` 20K; `(deleted)` in `/proc/<pid>/fd`; freed after the process ended |
| LVM `lvextend -r` while writing | 265M → 646M → 1.9G across 2 disks, mounted the whole time |
| Adding a partitioned disk to LVM | refused: "device is partitioned" |
| LVM snapshot | needs the `dm-snapshot` kernel module: **not possible in the fake VPS** (do it on a real VM) |
| `findmnt --verify` with a bad UUID | `[E] unreachable on boot required source` |
| `fio` 4k random read | 402k IOPS: **unrealistic**, the "disk" is a file cached in RAM |

## Before you start: why loop devices

A **loop device** turns a regular file into a disk (`/dev/loop0`), so you can partition, format, and break "disks" without touching real ones.

⚠️ In the fake VPS, loop devices belong to **Docker Desktop's Linux VM**, shared by every container. Always finish with the clean-up in step 9.

## Steps

All commands run **inside the fake VPS**, as root.

### 0. Start and look around

```bash
ansible/test/fake-vps.sh up
ansible/test/fake-vps.sh ssh
apt-get update && apt-get install -y fdisk lvm2 xfsprogs fio sysstat lsof

lsblk                      # disks the "server" sees
df -hT                     # mounted filesystems, types, usage
findmnt | head -15         # the mount tree
cat /proc/mounts | head -5
```

`/` is an `overlay` filesystem here, because the fake VPS is a container. On a real VPS you'd see `/dev/vda1` (or `sda1`, `nvme0n1p1`) with ext4.

### 1. Make practice disks

```bash
mkdir -p /var/lab19 && cd /var/lab19
truncate -s 1G disk1.img disk2.img disk3.img
ls -lsh disk1.img                 # apparent size 1G, real size 0: a sparse file
L1=$(losetup -fP --show disk1.img)
L2=$(losetup -fP --show disk2.img)
L3=$(losetup -f --show disk3.img)
echo "$L1 $L2 $L3"                # e.g. /dev/loop0 /dev/loop1 /dev/loop2
losetup -a
```

### 2. Partition a disk (GPT)

```bash
sfdisk $L1 <<'EOF'
label: gpt
size=300MiB, name=data
size=200MiB, name=tiny
EOF
partx -u $L1
lsblk -o NAME,SIZE,TYPE $L1
ls ${L1}p*                        # in the fake VPS: "No such file", see below
```

The kernel knows the partitions, but **no device files appeared**. On a real server **udev** creates `/dev/loop0p1` the moment the kernel announces it. The container has no udev, so create them by hand from the numbers the kernel publishes:

```bash
for p in $(lsblk -nro NAME $L1 | tail -n +2); do
  mm=$(cat /sys/class/block/$p/dev)                       # major:minor, e.g. 259:2
  [ -e /dev/$p ] || mknod /dev/$p b ${mm%%:*} ${mm##*:}
done
ls -l ${L1}p*                                             # "b" = block device, major, minor
```

### 3. Filesystems and inodes

```bash
mkfs.ext4 -L data ${L1}p1
mkfs.ext4 -L tiny -N 64 ${L1}p2        # deliberately only 64 inodes
mkdir -p /mnt/data /mnt/tiny
mount ${L1}p1 /mnt/data
mount ${L1}p2 /mnt/tiny
df -hT /mnt/data /mnt/tiny
df -i /mnt/tiny
tune2fs -l ${L1}p1 | grep -E "Inode count|Block count|Reserved block count"
```

Try `mkfs.xfs` on a spare partition or LV later, and compare `df -i`: xfs allocates inodes as needed.

### 4. "Disk full", three ways

**Out of inodes, with space free:**

```bash
for i in $(seq 1 100); do touch /mnt/tiny/f$i || { echo "failed at file $i"; break; }; done
df -h /mnt/tiny                  # lots of space free…
df -i /mnt/tiny                  # …but 0 inodes free
```

**Out of space:**

```bash
fallocate -l 400M /mnt/data/big          # bigger than the filesystem: fails…
ls -lh /mnt/data/big                     # …but leaves a partial file behind!
df -h /mnt/data
rm /mnt/data/big
```

**Deleted but still open** (the classic):

```bash
dd if=/dev/zero of=/mnt/data/app.log bs=1M count=150
sleep 600 < /mnt/data/app.log & H=$!     # a process holding the file open
rm /mnt/data/app.log
df -h /mnt/data                          # still ~151M used
du -sh /mnt/data                         # ~20K: df and du disagree
lsof -nP +L1 | grep app.log              # open files with 0 links
ls -l /proc/$H/fd/0                      # -> /mnt/data/app.log (deleted)
: > /proc/$H/fd/0                        # option 1: truncate it through /proc
kill $H                                  # option 2: end the process (or restart the service)
df -h /mnt/data                          # space is back
```

In real life the process is a service still writing its log. The usual fix is to make it reopen its files (`systemctl reload`, `SIGHUP`, lab 17), or truncate instead of `rm` (`: > file`).

### 5. Mount at boot with fstab

```bash
U=$(blkid -s UUID -o value ${L1}p1); echo $U
echo "UUID=$U  /mnt/data  ext4  defaults,nofail  0  2" >> /etc/fstab
umount /mnt/data
mount -a && findmnt /mnt/data           # mounted from fstab
```

**Break it, and catch it before a reboot would:**

```bash
echo "UUID=0000-bad  /mnt/broken  ext4  defaults  0  2" >> /etc/fstab
findmnt --verify                         # [E] unreachable on boot required source
sed -i '/0000-bad/d' /etc/fstab          # fix
findmnt --verify
```

Without `nofail`, a missing disk at boot drops a real server into emergency mode, reachable only through the provider's console (lab 01).

### 6. LVM: grow without downtime

```bash
umount /mnt/data /mnt/tiny; sed -i '/\/mnt\/data/d' /etc/fstab

# Fake VPS only: no udev, so let LVM create its own /dev entries.
cat >> /etc/lvm/lvm.conf <<'EOF'
activation {
    udev_sync = 0
    udev_rules = 0
    verify_udev_operations = 1
}
EOF

pvcreate $L2
vgcreate lab19 $L2
lvcreate -L 300M -n data lab19
mkfs.ext4 /dev/lab19/data
mount /dev/lab19/data /mnt/data
pvs; vgs; lvs; df -h /mnt/data
```

**Grow it while it's in use:**

```bash
(while true; do date >> /mnt/data/writing; sleep 0.2; done) & W=$!
lvextend -r -L +400M lab19/data          # -r: resize the filesystem too
df -h /mnt/data                          # bigger, still mounted, still being written
```

**Add a second disk:**

```bash
pvcreate $L1                             # refused: "device is partitioned"
wipefs -n $L1                            # what signatures are on it (-n = only show)
pvcreate $L3 && vgextend lab19 $L3       # a clean disk works
lvextend -r -l +100%FREE lab19/data
vgs; df -h /mnt/data
kill $W
```

Snapshots (`lvcreate -s -L 100M -n data-snap lab19/data`) need the kernel's `dm-snapshot` module, which the fake VPS can't load. Try them on a real VM (lab 29).

### 7. I/O performance

```bash
iostat -x 1 3                            # %util and await per device
fio --name=randread --filename=/mnt/data/fio.test --size=200M \
    --rw=randread --bs=4k --iodepth=16 --ioengine=libaio --direct=1 \
    --runtime=10 --time_based --group_reporting
free -h                                  # buff/cache: the page cache
```

You'll get hundreds of thousands of IOPS: **not realistic**. `--direct=1` skips the cache *inside* the fake VPS, but the "disk" is a file on Docker Desktop's VM, which caches it in RAM. Run the same `fio` on a real VPS disk to see real numbers, and write down both.

### 8. Where Docker keeps your data

On a Linux server with Docker (lab 09's fake VPS after `ansible-playbook`, or a real VPS):

```bash
docker system df                         # images, containers, volumes, build cache
docker volume inspect <volume> --format '{{ .Mountpoint }}'    # /var/lib/docker/volumes/<name>/_data
du -sh /var/lib/docker/*                 # what's using the space
```

A named volume is just a directory on the host's filesystem, which is why "Docker filled the disk" is a real incident, and why lab 03 backs up `/var/lib/docker/volumes`.

### 9. Clean up (important)

```bash
umount /mnt/data /mnt/tiny 2>/dev/null
lvremove -y lab19; vgremove -y lab19
pvremove -y $L2 $L3
losetup -d $L1 $L2 $L3
rm -f ${L1}p1 ${L1}p2; rm -rf /var/lab19
losetup -a                               # nothing left
exit
ansible/test/fake-vps.sh down
```

## Code

None: this lab is about understanding the system.

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- **`sfdisk: command not found`**: on Ubuntu 24.04 it's in the `fdisk` package.
- **No `/dev/loop0p1` after partitioning**: no udev in the container. Device files made with `mknod` from `/sys/class/block/*/dev`.
- **`lvcreate`: "device not cleared"**: LVM waits for udev too. `verify_udev_operations = 1` lets it create the nodes itself (fake VPS only).
- **A failed `fallocate` left a 259 MB file behind**: a failed command can still use space.
- **My first "deleted but open" test was misleading**: `exec 3>` in the shell made every later command inherit the file. A separate process (`sleep 600 < file`) holds it cleanly.
- **LVM snapshots impossible in the container**: no `dm-snapshot` module.
- **fio's 402k IOPS**: a loop file cached in RAM. Benchmark the real disk, and know what you're measuring.

## Lessons learned

## References

- `man 5 fstab`, `man 8 lvm`, `man 8 sfdisk`, `man 8 lsof`
- [Arch Wiki: fstab](https://wiki.archlinux.org/title/Fstab), [LVM](https://wiki.archlinux.org/title/LVM)
- [fio documentation](https://fio.readthedocs.io/)
