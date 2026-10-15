# Lab 17 — Processes, signals, and systemd

- **Phase:** 7 — Linux & OS internals
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Fake VPS (Ubuntu 24.04 with systemd, from lab 09)
- **Builds on:** Labs 01, 02, 08

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Understand how Linux runs programs: processes, signals, and how systemd supervises and limits services.

## Done when

- [ ] Explain fork/exec, PIDs, parent/child, and read a process's state from `/proc/<pid>/`
- [ ] Create and clean up a zombie and an orphan process on purpose
- [ ] Send SIGTERM, SIGKILL, SIGHUP, SIGSTOP to a test program and explain each reaction
- [ ] Write a systemd service with a timer (replacing cron), and use `journalctl` filters
- [ ] Limit a service's CPU and memory with systemd (`CPUQuota`, `MemoryMax`) and watch it get throttled / OOM-killed

## Verified while preparing this lab

On the fake VPS (Ubuntu 24.04.5, systemd, cgroup v2, kernel 7.0):

| Experiment | Result |
|---|---|
| Zombie | `Z  [sleep] <defunct>` |
| Orphan | re-parented: `PPID 1` |
| Trap script | `SIGHUP` → "reloading", `SIGSTOP` → state `T`, `SIGTERM` → "cleaning up", exit 0 |
| `SIGKILL` | exit code **137** |
| Crashing service, `Restart=on-failure` | 2 restarts in 9 s; "Scheduled restart job" in the journal |
| Timer `*:*:0/20` | fired every 20 s; visible in `list-timers` |
| `MemoryMax=64M`, allocating 200M | `Result=oom-kill` |
| `CPUQuota=20%` vs no limit | **20%** vs **100%** of one CPU (from `CPUUsageNSec`) |
| `systemd-analyze security` on the demo service | **9.6 UNSAFE** |

## Steps

All commands run **inside the fake VPS**, as root.

### 0. Start the fake VPS

```bash
ansible/test/fake-vps.sh up
ansible/test/fake-vps.sh ssh          # a root shell inside it
apt-get update && apt-get install -y strace psmisc procps lsof stress-ng sysstat nano
```

### 1. Look at processes

```bash
ps -eo pid,ppid,user,stat,cmd --forest | head -30
pstree -p | head -20                         # everything descends from PID 1 (systemd)
echo "my shell is $$"; cat /proc/$$/status | head -10
ls -l /proc/$$/fd                             # 0, 1, 2 = stdin, stdout, stderr
tr '\0' '\n' < /proc/$$/environ | head -5
cat /proc/$$/limits | grep -E "open files|processes"
```

**fork and exec, seen live:**

```bash
strace -f -e trace=process bash -c 'ls /tmp > /dev/null'   # clone() = fork, execve() = exec, exit_group
bash -c 'echo "bash pid $$"; exec sleep 30' &              # exec: same PID, new program
sleep 1; ps -o pid,cmd -p $!                               # shows "sleep 30" with the PID bash printed
```

### 2. Zombies and orphans

**Zombie:** a child exits, but its parent (here `sleep 30`, after `exec`) never calls `wait()`:

```bash
( sleep 1 & exec sleep 30 ) &
P=$!; sleep 2
ps -o pid,ppid,stat,cmd --ppid $P          # STAT Z, "[sleep] <defunct>"
kill $P                                    # parent gone → zombie adopted by PID 1 → reaped
ps -o pid,stat,cmd --ppid $P               # empty
```

**Orphan:** the parent exits while the child keeps running:

```bash
bash -c 'sleep 300 & echo "child $!"'      # bash exits immediately
ps -o pid,ppid,cmd -C sleep                # PPID 1: adopted by systemd
pgrep -af "sleep 300"                      # check what -f would match first
pkill -f "sleep 300"
```

### 3. Signals

Save this as `/root/sig.sh` and make it executable (`chmod +x /root/sig.sh`):

```bash
#!/bin/bash
trap 'echo "got SIGTERM, cleaning up"; exit 0' TERM
trap 'echo "got SIGHUP, reloading"' HUP
echo "pid $$"
while true; do sleep 1; done
```

```bash
/root/sig.sh & S=$!
kill -HUP $S                      # "reloading", keeps running
kill -STOP $S; ps -o stat= -p $S  # T: stopped
kill -CONT $S                     # running again
kill -TERM $S; wait $S; echo "exit code $?"     # "cleaning up", exit 0

sleep 300 & K=$!; kill -9 $K; wait $K; echo "exit code $?"   # 137 = 128 + 9
kill -l | head -3                 # all signal names and numbers
```

Notice that the trap runs only after the current `sleep 1` ends (up to a second later). Bash waits for the foreground command first. Change the loop to `sleep 1 & wait $!` and compare.

### 4. A systemd service that crashes and restarts

```bash
cat > /usr/local/bin/ticker.sh <<'EOF'
#!/bin/bash
n=0
while true; do
  n=$((n+1)); echo "tick $n"
  [ "$n" -ge "${CRASH_AFTER:-1000000}" ] && { echo "crashing" >&2; exit 1; }
  sleep 1
done
EOF
chmod +x /usr/local/bin/ticker.sh

cat > /etc/systemd/system/ticker.service <<'EOF'
[Unit]
Description=Ticker demo (lab 17)

[Service]
ExecStart=/usr/local/bin/ticker.sh
Environment=CRASH_AFTER=3
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemd-analyze verify /etc/systemd/system/ticker.service    # no output = OK
systemctl daemon-reload
systemctl enable --now ticker
sleep 10
systemctl status ticker --no-pager
systemctl show ticker -p NRestarts           # how many restarts so far
journalctl -u ticker --no-pager -n 15        # ticks, "crashing", "Scheduled restart job"
```

**Change it with a drop-in**, not by editing the file:

```bash
systemctl edit ticker            # opens nano; between the comment lines, add:
#   [Service]
#   Environment=CRASH_AFTER=1000000
systemctl restart ticker
systemctl cat ticker             # the original file + your drop-in, in order
```

Without an editor, this is exactly what `systemctl edit` creates:

```bash
mkdir -p /etc/systemd/system/ticker.service.d
printf '[Service]\nEnvironment=CRASH_AFTER=1000000\n' > /etc/systemd/system/ticker.service.d/override.conf
systemctl daemon-reload && systemctl restart ticker
```

Try: what does `StartLimitBurst=3` + `StartLimitIntervalSec=30` (in `[Unit]`) do to a service that crashes every 3 seconds?

### 5. A timer instead of cron

```bash
cat > /etc/systemd/system/hello-timer.service <<'EOF'
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo "timer fired at $(date +%%T)"'
EOF

cat > /etc/systemd/system/hello-timer.timer <<'EOF'
[Timer]
OnCalendar=*:*:0/20
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemd-analyze calendar '*:*:0/20'          # check the schedule before trusting it
systemctl daemon-reload
systemctl enable --now hello-timer.timer
systemctl list-timers hello-timer
sleep 45; journalctl -u hello-timer.service --no-pager -n 6
```

`%%` is needed because systemd itself treats `%` specially in unit files. Then try `OnCalendar=daily` and `RandomizedDelaySec=1h` with `systemd-analyze calendar`.

### 6. journald

```bash
journalctl -u ticker -f                         # follow (Ctrl+C)
journalctl -u ticker --since "5 min ago" --no-pager | tail
journalctl -p err -b --no-pager | tail          # errors since boot, all units
journalctl -u ticker -n 1 -o json-pretty        # every field stored with a line
journalctl --disk-usage
```

### 7. Limit resources with cgroups

**Memory:** allocate 200 MB under a 64 MB limit:

```bash
systemd-run --unit=memhog -p MemoryMax=64M -p MemorySwapMax=0 \
  stress-ng --vm 1 --vm-bytes 200M --timeout 20s
sleep 8
systemctl show memhog -p Result          # Result=oom-kill
journalctl -u memhog --no-pager | grep -i oom
```

**CPU:** two busy loops, one limited to 20%:

```bash
systemd-run --unit=cpu-limited -p CPUQuota=20% stress-ng --cpu 1 --timeout 30s
systemd-run --unit=cpu-free stress-ng --cpu 1 --timeout 30s
systemd-cgtop -n 3                        # watch both groups
measure() { a=$(systemctl show $1 -p CPUUsageNSec --value); sleep 5; b=$(systemctl show $1 -p CPUUsageNSec --value); echo "$1: $(( (b-a)/50000000 ))% of one CPU"; }
measure cpu-limited; measure cpu-free     # ~20% vs ~100%
```

**The kernel files behind it:**

```bash
systemd-run --unit=peek -p CPUQuota=20% -p MemoryMax=64M sleep 120
CG=/sys/fs/cgroup$(systemctl show peek -p ControlGroup --value)
cat $CG/cpu.max $CG/memory.max            # 20000 100000 / 67108864
cat $CG/cgroup.procs                      # the PID(s) in the group
systemctl stop peek cpu-limited cpu-free
```

On the fake VPS, the path includes `/docker/<id>/`, because the whole fake server is itself inside a container's cgroup. On a real server it's `/sys/fs/cgroup/system.slice/peek.service`.

### 8. How exposed is a service?

```bash
systemd-analyze security ticker.service | tail -1     # ~9.6 UNSAFE
systemd-analyze security ssh.service | tail -1
```

Add `NoNewPrivileges=true`, `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true` to ticker with `systemctl edit ticker`, restart it, and score it again. Lab 21 goes further.

### 9. Clean up

```bash
systemctl disable --now ticker hello-timer.timer
rm -rf /etc/systemd/system/ticker.service* /etc/systemd/system/hello-timer.* /usr/local/bin/ticker.sh /root/sig.sh
systemctl daemon-reload
exit                                       # leave the fake VPS
ansible/test/fake-vps.sh down
```

## Code

None: this lab is about understanding the system. The service and timer patterns appear in [apps/hello-api/hello-api.service](../../apps/hello-api/hello-api.service) (lab 02) and the backup timer (lab 03).

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- **`top -b -n1` and `pidstat` showed 0% CPU for a busy process:** a single `top` sample has no time window, and I read the wrong `pidstat` column. Measuring the unit's `CPUUsageNSec` over 5 seconds is exact. Always check that a measurement method can show the thing you're looking for.
- **`pkill -f "sleep 300"` killed my own script** (exit code 143 = SIGTERM): `-f` matches the full command line, and the script's own command line contained "sleep 300". Check with `pgrep -af <pattern>` before `pkill -f`.
- **`systemctl edit` needs an editor**, and the fake VPS has none: install `nano`, or write the drop-in file by hand.
- **The cgroup wasn't at `/sys/fs/cgroup/system.slice/…`** in the fake VPS: it's nested inside the container's cgroup. `systemctl show -p ControlGroup` gives the right path anywhere.

## Lessons learned

## References

- `man 7 signal`, `man 5 proc`, `man 5 systemd.service`, `man 5 systemd.timer`, `man 5 systemd.resource-control`
- [Arch Wiki: systemd](https://wiki.archlinux.org/title/Systemd)
- [Kernel docs: cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)
