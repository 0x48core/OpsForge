# Lab 09 — Ansible: rebuild the server in one command

- **Phase:** 4 — Infrastructure as Code
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** a disposable "fake VPS" container on the Mac; the same playbook runs on a real VPS

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Everything done by hand in labs 01 and 05–08 becomes code. The server becomes **disposable**: destroy it, create a new one, run one command, and it's back.

## Done when

- [ ] Roles for hardening (common, users, firewall, ssh, fail2ban), Docker, and the OpsForge stacks
- [ ] One command takes a **fresh** server to the full setup
- [ ] Idempotent: a second run reports `changed=0`
- [ ] Destroyed the (fake) VPS, created a new one, ran one command, and everything came back
- [ ] Secrets in `ansible-vault` for production (test values only in `inventory/test`)
- [ ] An app deploy (`deploy.sh`) works on the Ansible-built server
- [ ] On a real VPS: the same command, with Let's Encrypt via `traefik_acme_email`

## Measured while preparing this lab

On the fake VPS (Docker Desktop, Apple Silicon):

| Run | Detected as | Result | Time |
|---|---|---|---|
| Fresh server | `root@…:2201` (fresh) | ok=45, **changed=35**, failed=0 | 97 s |
| Same command again | `ops@…:2202` (hardened) | ok=39, **changed=0** | 20 s |

Then verified on the server:
- root login denied, the old port closed, only `ops` allowed
- ufw allows only 2202, 80, 443
- fail2ban counting failures
- Docker 29.9, with `deploy` in the docker group
- Traefik: `401` without auth, `200` with it, HTTP → `301`
- `deploy.sh main` as `deploy` pulled CI's GHCR image `sha-db2a6db`, and `/ready` reported Postgres and Redis ok

## Files

See [ansible/README.md](../../ansible/README.md) for the layout and roles. Key files:

| File | Role |
|---|---|
| [site.yml](../../ansible/site.yml) | Connection detection + all roles in order |
| [group_vars/all.yml](../../ansible/group_vars/all.yml) | Defaults: users, ports, domain, secret variable names |
| [inventory/test/](../../ansible/inventory/test/) | The fake VPS, with test values |
| [inventory/production/](../../ansible/inventory/production/) | Templates for your VPS and vault |
| [roles/ssh/tasks/main.yml](../../ansible/roles/ssh/tasks/main.yml) | The trickiest role: changes the port it's connected through |
| [test/fake-vps.sh](../../ansible/test/fake-vps.sh) | Create and destroy the fake VPS |

The stacks now take their domain from `DOMAIN` (default `opsforge.localhost`), so the same compose files work locally and on a server.

## Steps

### 0. Install Ansible

```bash
brew install ansible          # includes the community.* and ansible.posix collections
ansible --version
```

### 1. Start a fresh fake VPS

```bash
ansible/test/fake-vps.sh up
ssh -p 2201 root@127.0.0.1 'hostnamectl; whoami'     # a "fresh cloud server": root, port 22
```

It's Ubuntu 24.04 with systemd and OpenSSH in a privileged container. Port mapping: `127.0.0.1:2201` → its port 22, `:2202` → the hardened SSH port, `:8080`/`:8443` → its 80/443.

### 2. Read before you run

```bash
cd ansible
ansible-inventory --graph                      # which hosts, which groups
ansible-inventory --host fake-vps --yaml       # variables from the inventory
```

Read [site.yml](../../ansible/site.yml), then each role in order. For each task, ask: **what does this do the second time it runs?**

### 3. Dry run

```bash
ansible-playbook site.yml --check --diff
```

`--check` predicts changes without making them. On a **fresh** server it stops at the first `apt` task (`python3-apt must be installed to use check mode`): check mode can't predict steps that depend on things earlier steps would install. On a **hardened** server, `--check` works fully, and `changed=0` means no drift. Try it again after step 4.

### 4. The real run

```bash
time ansible-playbook site.yml
```

Watch the first play print `root@127.0.0.1:2201 (fresh server)`, then the `ssh` role switch to `ops@…:2202` partway through.

### 5. Verify like an attacker, then like an admin

```bash
ssh -p 2202 root@127.0.0.1            # denied
ssh -p 2201 root@127.0.0.1            # times out: port 22 is closed
ssh -p 2202 ops@127.0.0.1 'sudo sshd -T | grep -Ei "^(port|permitroot|passwordauth|allowusers)"; sudo ufw status; sudo fail2ban-client status sshd; sudo docker ps'
curl -sk -u admin:test -H 'Host: traefik.opsforge.localhost' -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8443/dashboard/
```

### 6. Idempotency

```bash
ansible-playbook site.yml             # look at the PLAY RECAP: changed=0
```

If anything shows `changed`, find out why. It's a bug: a task that doesn't really converge.

### 7. Deploy the app on the new server

As the `deploy` user, like CI would (lab 07). The GHCR image is public:

```bash
ssh -p 2202 ops@127.0.0.1 'sudo -iu deploy ~/opsforge/stacks/hello-api/deploy.sh main'
curl -sk -H 'Host: api.opsforge.localhost' https://127.0.0.1:8443/ready
```

### 8. Destroy and rebuild, the real test

```bash
cd ..
ansible/test/fake-vps.sh recreate     # the server is gone; a fresh one replaces it
cd ansible && time ansible-playbook site.yml
```

Everything comes back with the same command. That's the point of the lab: **the server is cattle, not a pet.** Note the time in "Lessons learned".

### 9. Change something the Ansible way

Pick one, and make the change **only in the repo**, never on the server:
- add port `8000` to `firewall_allowed_tcp_ports` in `inventory/test/group_vars/servers.yml`
- change `fail2ban_maxretry` to `3`

Run the playbook, check that only the related tasks show `changed`, then revert. Also try `--tags firewall`.

Then try **drift**: change something by hand on the server (e.g. `sudo ufw allow 9999`), and re-run. Does Ansible remove it? Why not? (Hint: Ansible enforces what's *declared*, and doesn't remove what isn't.)

### 10. Production, when you have a VPS

```bash
cd ansible
cp inventory/production/hosts.yml.example inventory/production/hosts.yml        # set <VPS_IP>
cp inventory/production/group_vars/servers/vault.yml.example inventory/production/group_vars/servers/vault.yml
#   fill in: htpasswd -nB admin   and   openssl rand -hex 24
ansible-vault encrypt inventory/production/group_vars/servers/vault.yml
head -1 inventory/production/group_vars/servers/vault.yml                      # $ANSIBLE_VAULT;1.1;AES256
#   edit inventory/production/group_vars/servers/main.yml: domain, traefik_acme_email, deploy_ssh_pubkey
ssh root@<VPS_IP> true                                                          # accept the host key once (compare with the provider's console)
ansible-playbook -i inventory/production site.yml --ask-vault-pass
```

DNS `A` records for `<domain>` subdomains must point to the VPS **before** this run, or Let's Encrypt can't validate them.

### 11. Clean up

```bash
ansible/test/fake-vps.sh down
```

## Code

- [ansible/](../../ansible/)
- Stack labels now use `${DOMAIN:-opsforge.localhost}` (all files in [stacks/](../../stacks/))

## What broke

_Write down errors and fixes here as you go._

Found while preparing this lab:
- **Test overrides ignored** (Ansible tried ports 2222 and 22): the playbook's `group_vars/all.yml` takes precedence over the inventory's `group_vars/all`. Fixed by putting hosts in a `servers` group and overriding in `group_vars/servers`.
- **"Hardened" detected on a fresh server:** Docker Desktop's port forwarding accepts TCP on `127.0.0.1:2202` even with nothing listening behind it. Fixed by testing an actual SSH login instead of an open port.
- **New SSH port = unknown host:** `known_hosts` is per host *and* port. Fixed by copying the server's host key to the new port entry during the switch (no `StrictHostKeyChecking=no`).
- **`--check` on a fresh server connected as `ops@:2202`:** check mode *skips* `command` tasks, so the login test never ran, and its missing result counted as "hardened". Fixed with `check_mode: false` on that read-only task, and `rc | default(1)`.
- **`python3-debian is not installed`** for `deb822_repository`: added to the base packages.
- **`'ansible_managed' is undefined`** in a `copy` task: that variable only exists in templates.
- **Docker-in-Docker** `overlay … invalid argument` in the fake VPS: overlay can't nest on overlay. Fixed with volumes for `/var/lib/docker` and `/var/lib/containerd`.

## Lessons learned

## References

- [Ansible: getting started](https://docs.ansible.com/ansible/latest/getting_started/index.html)
- [Ansible: variable precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
- [Ansible: roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [ansible-lint](https://ansible.readthedocs.io/projects/lint/)
