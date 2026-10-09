# ansible

Turns a fresh Ubuntu 24.04 server into the OpsForge server with one command (lab 09).

```bash
ansible-playbook site.yml                                      # fake VPS (inventory/test)
ansible-playbook -i inventory/production site.yml --ask-vault-pass
```

Safe to re-run: a second run reports `changed=0`. The first play detects whether the server is fresh (root on port 22) or already hardened (admin user on `ssh_port`), so the same command works for both.

## Roles

Run in this order by [site.yml](site.yml):

| Role | Does | From lab |
|---|---|---|
| [common](roles/common/) | apt upgrade, base packages, timezone, hostname, automatic security updates | 01 |
| [users](roles/users/) | Admin user with SSH key only, passwordless sudo | 01 |
| [firewall](roles/firewall/) | ufw: deny incoming; allow SSH, 80, 443 | 01 |
| [ssh](roles/ssh/) | Hardened sshd on `ssh_port`, reconnects, closes port 22 | 01 |
| [fail2ban](roles/fail2ban/) | sshd jail, systemd backend | 01 |
| [docker](roles/docker/) | Docker Engine + Compose from Docker's repo, log rotation | 04 |
| [opsforge](roles/opsforge/) | `deploy` user, `proxy` network, Traefik (+ Let's Encrypt), hello-api files and `.env` for CI deploys | 05, 07, 08 |

Run a subset with tags: `ansible-playbook site.yml --tags ssh,firewall`.

## Layout

```
ansible/
├── site.yml                 # the playbook
├── ansible.cfg              # defaults to inventory/test
├── group_vars/all.yml       # defaults for every server
├── inventory/
│   ├── test/                # fake VPS: hosts.yml + group_vars/servers.yml (test values)
│   └── production/          # your VPS: hosts.yml + group_vars/servers/{main,vault}.yml
├── roles/<role>/{tasks,handlers,templates,defaults}/
└── test/                    # fake VPS: Dockerfile + fake-vps.sh
```

Overrides go in `inventory/<env>/group_vars/servers…`, not `group_vars/all`: a playbook's `group_vars/all` takes precedence over an inventory's `group_vars/all`.

## Test locally (no VPS needed)

```bash
ansible/test/fake-vps.sh up          # fresh Ubuntu 24.04 with systemd + sshd, as root on 127.0.0.1:2201
cd ansible && ansible-playbook site.yml
ansible/test/fake-vps.sh recreate    # destroy and start fresh
ansible/test/fake-vps.sh down
```

The fake VPS is a privileged container. Fine for testing on your Mac; never a real server.

## Production

```bash
cp inventory/production/hosts.yml.example inventory/production/hosts.yml
cp inventory/production/group_vars/servers/vault.yml.example inventory/production/group_vars/servers/vault.yml
ansible-vault encrypt inventory/production/group_vars/servers/vault.yml
# edit inventory/production/group_vars/servers/main.yml (domain, email, deploy key)
ansible-playbook -i inventory/production site.yml --ask-vault-pass
```

`hosts.yml` and `vault.yml` are git-ignored. Commit `vault.yml` only if it's encrypted (`git add -f`).
