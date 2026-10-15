# Lab 17 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

Everything you've deployed so far (Nginx, hello-api, Docker, Traefik, Postgres) is, in the end, **a Linux process**, and on a server almost always one started and watched by **systemd**. When something hangs, won't stop, eats all the memory, or restarts in a loop, you need to know what a process is, how signals reach it, and how systemd supervises and limits it. Labs 02 (systemd service), 04 (PID 1 and signals in containers), 08 (graceful shutdown), and 11 (OOM, cgroups) all touched this. This lab explains it properly.

## Core concepts

### What a process is

A process is a **running program** with its own:

| Part | What it is | Where to see it |
|---|---|---|
| PID | A number that identifies it | `ps`, `echo $$` |
| PPID | Its parent's PID | `ps -o pid,ppid,cmd` |
| Memory | Its own (virtual) address space | `/proc/<pid>/maps`, `status` |
| Open files | Numbered file descriptors: 0 stdin, 1 stdout, 2 stderr, then others | `ls -l /proc/<pid>/fd` |
| Environment | Variables like `PATH`, `HOME` | `/proc/<pid>/environ` |
| Credentials | User and group it runs as | `ps -o user`, `/proc/<pid>/status` |
| Limits | Max open files, processes… | `/proc/<pid>/limits`, `ulimit -a` |

**Everything about a process is visible in `/proc/<pid>/`.** Tools like `ps` and `top` just read those files.

### How processes are born: fork and exec

```
bash (pid 100)
  │ fork()  → an almost identical copy: bash (pid 200), parent = 100
  │            │ exec("/usr/bin/sleep") → pid 200 now runs sleep instead of bash
  │            │ … exits with a status code
  │ wait()  ← parent collects the exit status; the kernel removes pid 200
```

- **fork** copies the process. **exec** replaces the program inside it (same PID). Running any command in a shell is a fork + exec.
- `exec cmd` in a shell skips the fork: the shell *becomes* `cmd`. That's why Dockerfiles use exec-form `ENTRYPOINT` and scripts end with `exec "$@"` (lab 04): the app becomes PID 1 and receives signals directly.
- **PID 1** is the first process (systemd on a server, your app in a container). Every process descends from it: `pstree -p`.

### Process states

`ps -o stat` shows one letter:

| State | Meaning | Typical cause |
|---|---|---|
| `R` | Running or ready to run | Using CPU |
| `S` | Sleeping, can be interrupted | Waiting for input, a timer, a network packet (most processes, most of the time) |
| `D` | Uninterruptible sleep | Waiting for disk or NFS I/O; can't even be killed until the I/O returns. Many `D` processes = storage problem |
| `T` | Stopped | `SIGSTOP`, Ctrl+Z, a debugger |
| `Z` | **Zombie** | Exited, but the parent hasn't collected its exit status yet |

### Zombies and orphans

- A **zombie** has finished; only its entry (PID + exit code) remains, waiting for the parent to `wait()` for it. It uses no CPU or memory, but holds a PID. Thousands of zombies = a buggy parent that never waits. Fix the parent (or kill it, so the zombies get adopted and cleaned up).
- An **orphan** is a process whose parent died. The kernel re-parents it to PID 1 (or a "subreaper"), which collects it when it exits. That's why PID 1 must reap children, and why containers use an init like `tini` (`docker run --init`) when the app doesn't.

### Signals

A signal is a small asynchronous message from the kernel or another process.

| Signal | Number | Default action | Used for |
|---|---|---|---|
| `SIGTERM` | 15 | Terminate | "Please stop": `kill`, `systemctl stop`, `docker stop`. **Can be caught**: clean up, then exit (graceful shutdown, lab 08) |
| `SIGINT` | 2 | Terminate | Ctrl+C |
| `SIGHUP` | 1 | Terminate | Terminal closed; by convention many daemons **reload config** on HUP (`nginx -s reload`) |
| `SIGKILL` | 9 | Terminate | Immediate. **Can't be caught or ignored**: no cleanup. Last resort |
| `SIGSTOP` / `SIGCONT` | 19 / 18 | Stop / continue | Pause and resume (Ctrl+Z sends `SIGTSTP`, the catchable version) |
| `SIGCHLD` | 17 | Ignore | Tells a parent a child changed state, so it can `wait()` |
| `SIGUSR1/2` | 10 / 12 | Terminate | App-defined, e.g. reopen log files, dump stats |

- In a shell script, `trap 'cleanup' TERM` catches a signal. Bash runs the trap only **after the current foreground command finishes**, so a script stuck in a long `sleep` reacts late. Use `sleep N & wait $!` for scripts that must react quickly.
- **Exit codes:** 0 = success, 1–125 = the program's own errors, **128 + N = killed by signal N**. `137` = 128 + 9 (SIGKILL, often the OOM killer), `143` = 128 + 15 (SIGTERM).

### systemd: PID 1 on modern Linux

systemd starts the system, then **supervises** services: starts them in the right order, restarts them, collects their logs, and limits their resources.

**Units** are its objects, described by files:

| Unit type | Describes | Example |
|---|---|---|
| `.service` | A process to run and supervise | `nginx.service`, `hello-api.service` (lab 02) |
| `.socket` | A socket that starts a service on demand | `ssh.socket` (lab 01) |
| `.timer` | A schedule that starts a service | `certbot.timer` |
| `.target` | A group of units; a synchronisation point | `multi-user.target`, `network-online.target` |
| `.mount` | A mount point (often generated from `/etc/fstab`) | `mnt-data.mount` (lab 19) |
| `.slice` / `.scope` | Resource-control groups (cgroups) | `system.slice`, `user.slice` |

**Where unit files live** (later wins):

| Path | Owner |
|---|---|
| `/usr/lib/systemd/system/` | Packages: never edit |
| `/etc/systemd/system/` | You: your own units, and overrides |
| `/etc/systemd/system/<unit>.d/*.conf` | **Drop-ins**: change one setting without copying the whole file (`systemctl edit <unit>`) |

**The key `[Service]` settings:**

| Setting | Meaning |
|---|---|
| `Type=simple` / `exec` / `notify` / `oneshot` / `forking` | When systemd considers the service "started". `oneshot` = runs to completion (scripts, timers) |
| `ExecStart=`, `ExecReload=`, `ExecStop=` | The commands |
| `Restart=no` / `on-failure` / `always` | Restart policy; `RestartSec=` waits between attempts |
| `StartLimitBurst=` / `StartLimitIntervalSec=` | Give up after N restarts in T seconds (crash-loop protection) |
| `User=`, `Group=`, `WorkingDirectory=`, `Environment=`, `EnvironmentFile=` | How it runs |
| `KillSignal=` (default SIGTERM), `TimeoutStopSec=` (default 90 s) | How it's stopped: SIGTERM, wait, then SIGKILL |

**Dependencies vs ordering** are separate ideas, which confuses many people:
- `Wants=` / `Requires=`: *start this other unit too* (soft / hard).
- `After=` / `Before=`: *in which order*. `Requires=b` without `After=b` starts both **at the same time**.
- `WantedBy=multi-user.target` in `[Install]` is what `systemctl enable` uses: it creates a symlink so the unit starts at boot.

### Timers instead of cron

| | cron | systemd timer |
|---|---|---|
| Logs | Mail or nothing | `journalctl -u <unit>`, with exit status |
| Missed runs (machine was off) | Lost | `Persistent=true` runs it at the next boot |
| Overlap | Two copies can run at once | A unit runs once at a time |
| Resource limits, sandboxing | No | All service settings apply |
| Random delay (avoid every server at 03:00) | No | `RandomizedDelaySec=` |
| Check the schedule | Mental arithmetic | `systemd-analyze calendar '…'`, `systemctl list-timers` |

`OnCalendar=*-*-* 03:15:00` = daily at 03:15; `OnCalendar=*:0/15` = every 15 minutes; `OnBootSec=5min` = 5 minutes after boot.

### journald: the logs

Everything a service writes to stdout/stderr goes to the **journal**, with metadata (unit, PID, priority, time).

- `journalctl -u nginx -f` (follow), `--since "10 min ago"`, `-p err` (priority error and worse), `-b` (this boot), `-o json-pretty` (all fields).
- Storage: `/run/log/journal` (lost on reboot) or `/var/log/journal` (persistent). Size limits in `/etc/systemd/journald.conf` (`SystemMaxUse=`); check with `journalctl --disk-usage`.

### cgroups: how systemd limits resources

Every unit runs in its own **control group** (cgroup v2), a kernel feature that accounts for and limits CPU, memory, I/O, and the number of processes for a group of processes. It's the same mechanism Docker uses for `--memory` and Kubernetes for `limits` (labs 04, 11, 12).

| systemd setting | Kernel file in the unit's cgroup | Effect |
|---|---|---|
| `MemoryMax=64M` | `memory.max` | Above this, the **OOM killer** kills a process in the unit |
| `MemoryHigh=` | `memory.high` | Soft limit: throttled and reclaimed before the hard limit |
| `CPUQuota=20%` | `cpu.max` = `20000 100000` | At most 20 ms of CPU every 100 ms |
| `CPUWeight=` | `cpu.weight` | Share of CPU when there's competition |
| `TasksMax=` | `pids.max` | Max processes/threads: stops fork bombs |
| `IOWeight=`, `IOReadBandwidthMax=` | `io.weight`, `io.max` | Disk I/O share and limits |

Find a unit's cgroup directory: `/sys/fs/cgroup$(systemctl show <unit> -p ControlGroup --value)`. `systemd-cgtop` shows usage per group live. `systemd-run -p MemoryMax=… cmd` runs any command as a temporary limited unit.

### Sandboxing (preview of lab 21)

`systemd-analyze security <unit>` scores how exposed a service is (0 = locked down, 10 = unsafe). Settings like `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true`, and `NoNewPrivileges=true` (used in lab 02's [hello-api.service](../../apps/hello-api/hello-api.service)) lower it.

## Key terms

| Term | Meaning |
|---|---|
| PID / PPID | Process ID / parent's process ID |
| fork / exec | Copy a process / replace its program |
| File descriptor | A numbered handle to an open file, socket, or pipe |
| Zombie / orphan | Exited but not reaped / parent gone, adopted by PID 1 |
| Signal | Asynchronous notification to a process |
| Unit | Anything systemd manages (service, timer, mount…) |
| Drop-in | A partial override file for a unit |
| Target | A group of units used for ordering and boot stages |
| cgroup | Kernel grouping for resource accounting and limits |
| OOM killer | Kernel mechanism that kills a process when memory runs out |

## Commands to know

| Command | What it does |
|---|---|
| `ps -eo pid,ppid,user,stat,%cpu,%mem,cmd --forest` | All processes as a tree, with state |
| `pstree -p`, `pgrep -a <name>` | Process tree / find PIDs by name |
| `top`, `htop` | Live view; `htop` lets you send signals interactively |
| `cat /proc/<pid>/status`, `ls -l /proc/<pid>/fd` | Details and open files of a process |
| `strace -f -e trace=process <cmd>` | Watch fork/exec/exit system calls |
| `kill -TERM <pid>`, `kill -l`, `pkill`, `killall` | Send signals |
| `systemctl status / start / stop / restart / reload / enable --now <unit>` | Manage units |
| `systemctl cat <unit>`, `systemctl show <unit> -p <Prop>` | Show the effective unit file / a property |
| `systemctl edit <unit>`, `systemctl daemon-reload` | Create a drop-in / reload unit files |
| `systemctl list-units --failed`, `systemctl list-timers` | What's broken / what's scheduled |
| `systemd-analyze verify <file>`, `calendar '<spec>'`, `security <unit>`, `blame` | Check a unit / a schedule / sandboxing / boot time |
| `journalctl -u <unit> -f --since … -p err` | Logs |
| `systemd-run -p MemoryMax=64M <cmd>`, `systemd-cgtop` | Run limited / watch cgroups |

## Before you start, can you answer these?

1. What's the difference between `fork` and `exec`, and what does `exec` in a shell script do?
2. A process shows state `Z`. Is it using CPU or memory? How do you get rid of it?
3. Why can't `SIGKILL` be caught, and why should you still prefer `SIGTERM`?
4. What does exit code 137 tell you?
5. What's the difference between `Requires=` and `After=`?
6. How does systemd enforce `MemoryMax=`?

## After the lab, check yourself

1. Create a zombie and an orphan on demand, and explain each `ps` line.
2. What happened when you sent `SIGHUP`, `SIGSTOP`, `SIGTERM`, `SIGKILL` to the trap script?
3. How many times did the crashing service restart, and what would stop an endless crash loop?
4. Why is a drop-in better than editing the unit file?
5. Show the kernel files behind `CPUQuota=20%` and `MemoryMax=64M`, and the measured effect.
6. What security score did the demo service get, and which three settings would lower it most?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [The Linux Command Line](https://linuxcommand.org/tlcl.php): chapters on processes
- `man 7 signal`, `man 5 proc`, `man 5 systemd.service`, `man 5 systemd.timer`, `man 5 systemd.resource-control`
- [systemd for Administrators](https://www.freedesktop.org/wiki/Software/systemd/) (blog series by Lennart Poettering)
- [Arch Wiki: systemd](https://wiki.archlinux.org/title/Systemd) and [systemd/Timers](https://wiki.archlinux.org/title/Systemd/Timers) (excellent, distro-neutral)
- [Kernel docs: cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)
- *How Linux Works* (Brian Ward): processes, boot, and systemd chapters
