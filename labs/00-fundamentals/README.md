# Lab 00 — Fundamentals before the labs

- **Phase:** 0 — Before you start
- **Status:** 🟨 in progress
- **Started / finished:** YYYY-MM-DD / —

> 📖 **Learn first:** this lab *is* the learning. It covers Level 1 of the Linux, Networking, Scripting, and Git domains in the [learning roadmap](../../docs/learning-roadmap.md), which labs 01–03 assume.

## Goal

Get comfortable with the shell, permissions, services, basic networking, and SSH before touching a real VPS, so Lab 01 is about hardening, not about remembering what `chmod 600` means.

Time: about 1–2 weeks at the [weekly rhythm](../../docs/learning-roadmap.md#a-weekly-rhythm). Everything here runs on your Mac or a local VM.

## Done when

- [ ] You can answer every question in [Ready for Lab 01?](#ready-for-lab-01) without notes
- [ ] You can explain what happens when you type a URL and press Enter, down to TCP and TLS
- [ ] You wrote one Bash script that passes `shellcheck` and committed it through a branch and PR

## Topics

| # | Topic | What to know | Why labs 01–03 need it |
|---|---|---|---|
| 1 | **Shell and filesystem** | `cd`, `ls`, `cat`, `less`, absolute vs relative paths, pipes `\|`, redirection `>` `>>` `2>&1`, `man`, `grep` | Everything on the VPS happens in a shell |
| 2 | **Users, groups, permissions** | `rwx`, octal modes (`600`, `700`, `644`), `chown`, `sudo`, root vs normal user | `~/.ssh` permissions; creating a sudo user |
| 3 | **Packages and editing files** | `apt update/upgrade/install`, editing config with `nano` or basic `vim` | Changing `sshd_config`; installing `ufw` and `fail2ban` |
| 4 | **Processes, services, logs** | `ps`, `top`, signals (SIGTERM vs SIGKILL), `systemctl status/restart/enable`, `journalctl -u` | Restarting sshd and nginx; finding out why a service failed |
| 5 | **Networking basics** | IP addresses, ports, TCP vs UDP, `127.0.0.1` vs `0.0.0.0`, DNS, HTTP status codes, what a firewall does | `ufw`, the reverse proxy, debugging a `502` |
| 6 | **SSH and public-key crypto** | Public vs private key, which half goes on the server, `ssh-keygen`, `~/.ssh/config` | All of Lab 01 depends on it |
| 7 | **Bash scripting and Git** | Variables, `if`/loops, exit codes, `set -euo pipefail`; commit, branch, PR | Lab 03 backup scripts; one PR per lab |

## Resources (free)

- [The Missing Semester](https://missing.csail.mit.edu/) (MIT): lectures 1–2 and 5–6 cover topics 1, 2, and 7
- [The Linux Command Line](https://linuxcommand.org/tlcl.php), Part 1: topics 1–4
- [High Performance Browser Networking](https://hpbn.co/), chapter 1, and Julia Evans' [networking zines](https://wizardzines.com/): topic 5
- [Pro Git](https://git-scm.com/book/en/v2), chapters 1–3, and the [ShellCheck wiki](https://www.shellcheck.net/wiki/): topic 7

## Ready for Lab 01?

Taken from the "Before you start" sections of labs [01](../01-vps-hardening/knowledge.md) and [02](../02-nginx-ssl-reverse-proxy/knowledge.md):

1. Why is key-based login safer than a strong password? Which half of the key pair goes on the server?
2. Why must you open the new SSH port in `ufw` **before** changing the port?
3. Why should an app listen on `127.0.0.1` rather than `0.0.0.0`?
4. What does a `502` tell you, and where do you look first?
5. What's the difference between `systemctl stop` and `kill -9` from the app's point of view?

## Steps

What I actually studied and tried, in order.

## What broke

## Lessons learned

## References

- [docs/learning-roadmap.md](../../docs/learning-roadmap.md), domains 1–4, Level 1
