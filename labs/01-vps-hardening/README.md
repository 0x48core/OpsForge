# Lab 01 — VPS hardening

- **Phase:** 1 — Linux & server foundations
- **Status:** 🟨 in progress
- **Started / finished:** YYYY-MM-DD / —

## Goal

Lock down a fresh VPS before running anything on it.

## Done when

- [ ] Non-root sudo user created; root login disabled
- [ ] SSH accepts keys only, on a non-default port
- [ ] `ufw` allows only required ports
- [ ] `fail2ban` bans repeated failed SSH logins (verified)
- [ ] Automatic security updates enabled

## Before you start

Placeholders used below: `<VPS_IP>`, `<USER>` (your new username), `<SSH_PORT>` (pick something between 1024 and 65535, e.g. 2222 — but choose your own).

> ⚠️ **Golden rule: never close your working SSH session until a *new* terminal has logged in successfully with the new settings.**
> Find your provider's **web console / VNC** before you begin — it's your way back in if you lock yourself out.

## Steps

### 1. First login and system update

```bash
# on your Mac
ssh root@<VPS_IP>
```

```bash
# on the VPS
apt update && apt full-upgrade -y
timedatectl set-timezone Asia/Ho_Chi_Minh
hostnamectl set-hostname opsforge
reboot   # if a kernel update was installed
```

### 2. Create a sudo user

```bash
# on the VPS, as root
adduser <USER>                 # set a strong password — needed for sudo
usermod -aG sudo <USER>

# copy root's authorized key to the new user
rsync --archive --chown=<USER>:<USER> ~/.ssh /home/<USER>
```

**Test in a NEW terminal** (keep the root one open):

```bash
ssh <USER>@<VPS_IP>
sudo whoami     # should print: root
```

From here on, work as `<USER>` with `sudo`.

### 3. Open the new SSH port in the firewall *first*

Do this before changing SSH, so the new port is already allowed.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp            # temporary — removed in step 5
sudo ufw allow <SSH_PORT>/tcp
sudo ufw enable
sudo ufw status verbose
```

If your provider has a cloud firewall too, allow `<SSH_PORT>` there as well.

### 4. Harden SSH

Use a drop-in file instead of editing the main config. Name it `00-…` so it loads first — in `sshd`, **the first value wins**, and cloud images often ship `50-cloud-init.conf` with `PasswordAuthentication yes`.

```bash
sudo nano /etc/ssh/sshd_config.d/00-hardening.conf
```

```
Port <SSH_PORT>
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers <USER>
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
```

Validate, then apply. On Ubuntu 24.04 SSH is **socket-activated**, so the port change needs `daemon-reload` + restarting the socket:

```bash
sudo sshd -t                                  # no output = config OK
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket ssh.service
sudo ss -tlnp | grep ssh                      # should show <SSH_PORT>
```

**Test in a NEW terminal:**

```bash
ssh -p <SSH_PORT> <USER>@<VPS_IP>                       # should work
ssh -p <SSH_PORT> root@<VPS_IP>                         # should be denied
ssh -p <SSH_PORT> -o PubkeyAuthentication=no <USER>@<VPS_IP>   # should be denied (no password login)
```

Check which values are actually active:

```bash
sudo sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication)'
```

### 5. Close port 22

Only after step 4 works in a new terminal:

```bash
sudo ufw delete allow 22/tcp
sudo ufw status numbered
```

Remove port 22 from the provider firewall too.

### 6. Make SSH easy from your Mac

Add to `~/.ssh/config` on your Mac (this file stays local, never commit it):

```
Host opsforge
    HostName <VPS_IP>
    User <USER>
    Port <SSH_PORT>
    IdentityFile ~/.ssh/id_ed25519
```

Now just: `ssh opsforge`

### 7. Install fail2ban

```bash
sudo apt install -y fail2ban
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = <SSH_PORT>
```

`backend = systemd` matters on Ubuntu 24.04: there is no `/var/log/auth.log` by default, so fail2ban fails to start without it.

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

**Verify it bans** — test from a *different network* (e.g. phone hotspot) so you don't ban your own IP:

```bash
# from the other network, fail on purpose 5+ times
ssh -p <SSH_PORT> fakeuser@<VPS_IP>
```

```bash
# on the VPS
sudo fail2ban-client status sshd              # "Banned IP list" should show it
sudo fail2ban-client set sshd unbanip <IP>    # undo
```

If you ban yourself: wait for `bantime`, use another network, or unban via the provider web console.

### 8. Automatic security updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades    # answer "Yes"
cat /etc/apt/apt.conf.d/20auto-upgrades            # both values should be "1"
sudo unattended-upgrade --dry-run --debug | tail
```

### 9. Final check

```bash
sudo ufw status verbose
sudo sshd -T | grep -Ei '^(port|permitrootlogin|passwordauthentication|allowusers)'
sudo fail2ban-client status sshd
systemctl status unattended-upgrades --no-pager
```

Tick the **Done when** boxes, update the roadmap in the root README to ✅, and update the **Open ports** table in `docs/architecture.md`.

## Code

Manual this time, on purpose. These exact settings become the `hardening` role in [lab 09](../09-ansible/).

## What broke

_Write down errors and fixes here as you go._

## Lessons learned

## References

- `man sshd_config`
- [Ubuntu Server docs: OpenSSH](https://documentation.ubuntu.com/server/how-to/security/openssh-server/)
- [Ubuntu Server docs: Firewall (ufw)](https://documentation.ubuntu.com/server/how-to/security/firewalls/)
- [fail2ban](https://github.com/fail2ban/fail2ban)
