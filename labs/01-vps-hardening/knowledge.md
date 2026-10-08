# Lab 01 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

A new VPS with a public IP gets automated login attempts within **minutes**. Bots scan the whole internet for port 22 and try common usernames and passwords. Hardening shrinks the **attack surface** (what an attacker can reach) and adds several layers of defense, so one mistake doesn't mean a lost server. This idea is called **defense in depth**.

| Layer | Protects against | Tool |
|---|---|---|
| Key-only SSH | Password guessing | `sshd_config` |
| No root login | Attackers getting full power on a single login | `sshd_config` |
| Non-default port | Noise from basic scanners (it's *not* real security) | `sshd_config` |
| Firewall | Services you didn't mean to expose | `ufw` |
| Ban repeat offenders | Brute force | `fail2ban` |
| Automatic patches | Known vulnerabilities | `unattended-upgrades` |

## Core concepts

### Users, groups, and sudo

- Linux decides what you can do based on your **user** and its **groups**. `root` (UID 0) can do anything.
- Working as root all the time is dangerous: one typo like `rm -rf / tmp` (note the space) can wreck the system, and an attacker who gets in as root gets everything.
- **sudo** lets a normal user run a single command as root, after typing their *own* password. Each use is logged in the journal. On Ubuntu, members of the `sudo` group may use it.
- Key files: `/etc/passwd` (users), `/etc/group` (groups), `/etc/shadow` (password hashes, root-only).

### File permissions (just enough for SSH)

`ls -l` shows `-rw-------`: the **owner**, **group**, and **other** permissions, each made of **r**ead, **w**rite, and e**x**ecute.

- `~/.ssh` must be `700` (`drwx------`).
- `~/.ssh/authorized_keys` must be `600` (`-rw-------`).
- If these are too open, `sshd` **silently refuses** key login. This is a classic "why doesn't my key work" problem.

### SSH and public-key authentication

SSH gives you an encrypted channel to a remote shell. A **key pair** has two halves:

- **Private key** (`~/.ssh/id_ed25519`) stays on your Mac. Never share or commit it.
- **Public key** (`~/.ssh/id_ed25519.pub`) goes into `~/.ssh/authorized_keys` on the server. It is safe to share.

How key login works, simplified:

```
Mac (client)                                Server (sshd)
    │ ── "I'm <USER>, here's my public key" ──▶ │  Is it in authorized_keys? ✔
    │ ◀── "Prove it: sign this challenge" ───── │
    │ ── signature made with the private key ─▶ │  Check with the public key ✔
    │ ◀────────── logged in ─────────────────── │
```

The private key never leaves your Mac, so there's nothing to guess or steal over the network. That's why disabling passwords removes brute force as a threat.

There's also **`known_hosts`**, which works in the other direction: your Mac remembers each server's *host key*. If it changes, SSH warns "REMOTE HOST IDENTIFICATION HAS CHANGED". That can mean a man-in-the-middle attack, or simply that you rebuilt the server.

**Ed25519** is the modern key type: short, fast, and secure. Prefer it over RSA.

### sshd configuration

- `/etc/ssh/sshd_config` is the main file, and it `Include`s `/etc/ssh/sshd_config.d/*.conf` first.
- **For most options, the first value wins.** Settings in drop-in files load before the main file, in alphabetical order. That's why the guide names the file `00-hardening.conf`.
- `sshd -t` tests the config. `sshd -T` prints the **effective** values. Always trust `-T` over what you think you wrote.
- On Ubuntu 24.04, `sshd` is **socket-activated**: systemd listens on the port (`ssh.socket`) and starts `sshd` when someone connects. Changing the port therefore means reloading systemd and restarting the socket.

### Ports and firewalls

- A **port** is a number (0–65535) that identifies a service on a host: 22 = SSH, 80 = HTTP, 443 = HTTPS.
- A process **listens** on an address and port. `ss -tlnp` shows what's listening. A service on `127.0.0.1` can only be reached locally, while `0.0.0.0` means every network interface.
- A **firewall** decides which packets get in. **Default deny** means block everything, then allow only what you need.
- **ufw** ("uncomplicated firewall") is a friendly front end. Underneath, the Linux kernel filters packets with **nftables/iptables**.
- Many providers also have a **cloud firewall** in front of the VPS. Traffic must pass both.
- ⚠️ Docker publishes container ports by editing iptables directly, which **bypasses ufw**. Remember this for lab 04.

### fail2ban

It watches logs (here, the systemd journal), counts failures per IP, and adds a temporary firewall rule to ban IPs that fail too often.

- **jail**: one protected service (e.g. `sshd`).
- **filter**: the patterns that recognize a failed attempt.
- **action**: what to do on a ban (add a firewall rule).
- `maxretry` failures within `findtime` lead to a ban for `bantime`.

With key-only SSH, brute force can't succeed anyway. fail2ban mainly cuts log noise and wasted resources. It's still a useful pattern to know for web logins later.

### Automatic security updates

`unattended-upgrades` installs **security** updates daily. Most real-world break-ins use *known*, already-patched vulnerabilities on servers nobody updated. Some updates (like a new kernel) only take effect after a reboot. Check `/var/run/reboot-required`.

### Recovery access

If you break SSH, the provider's **web console (VNC/serial)** acts as a monitor and keyboard attached to the machine. It doesn't use SSH or the network firewall. Know where it is before you start.

## Key terms

| Term | Meaning |
|---|---|
| Attack surface | Everything an attacker can reach or interact with |
| Defense in depth | Several independent layers of protection |
| UID / GID | Numeric user and group IDs; root is UID 0 |
| sshd | The SSH server daemon |
| Host key | A server's identity key, remembered in `known_hosts` |
| Socket activation | systemd listens on a port and starts the service on demand |
| Default deny | Block everything unless explicitly allowed |
| Jail (fail2ban) | Monitoring and ban rules for one service |

## Commands to know

| Command | What it does |
|---|---|
| `adduser` / `usermod -aG sudo <USER>` | Create a user / add it to the sudo group |
| `id <USER>` | Show a user's UID, GID, and groups |
| `ssh-keygen -t ed25519` | Create a key pair |
| `ssh-copy-id -p <PORT> <USER>@<HOST>` | Install your public key on a server |
| `ssh -v ...` | Verbose SSH; shows *why* a login fails |
| `sshd -t` / `sshd -T` | Test config / print the effective config |
| `ss -tlnp` | List listening TCP ports and their processes |
| `ufw status verbose` / `ufw allow` / `ufw delete` | Manage the firewall |
| `journalctl -u ssh -f` | Follow SSH logs live |
| `fail2ban-client status sshd` | Show bans for the sshd jail |

## Before you start, can you answer these?

1. Why is key-based login safer than a strong password?
2. Which half of the key pair goes on the server?
3. Why must you open the new port in `ufw` **before** changing the SSH port?
4. Why does changing the port from 22 *not* count as real security?
5. What do you do if you lock yourself out?

## After the lab, check yourself

1. Explain the SSH key login flow to someone else without notes.
2. What does `sshd -T` show that reading `sshd_config` doesn't?
3. What happens if `~/.ssh/authorized_keys` is world-writable?
4. What is the difference between `ufw` and your provider's firewall?
5. Why might fail2ban not protect a port that Docker published?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [DigitalOcean: SSH essentials](https://www.digitalocean.com/community/tutorials/ssh-essentials-working-with-ssh-servers-clients-and-keys)
- [Ubuntu Server docs: OpenSSH](https://documentation.ubuntu.com/server/how-to/security/openssh-server/)
- [Ubuntu Server docs: Firewalls](https://documentation.ubuntu.com/server/how-to/security/firewalls/)
- `man sshd_config`, `man ufw`, `man jail.conf`
- [The Linux Command Line (free book)](https://linuxcommand.org/tlcl.php): chapters on permissions and users
