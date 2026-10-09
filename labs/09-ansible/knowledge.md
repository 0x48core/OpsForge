# Lab 09 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

Your lab 01 server lives in your memory and your shell history. If it dies, or you need a second one, you redo everything by hand and probably miss a step. **Configuration management** writes the desired state of a server as code:

- **Reproducible:** a new server is one command away.
- **Reviewable:** changes go through git and PRs, like application code.
- **Documented:** the playbook *is* the documentation, and it can't go out of date.
- **Recoverable:** a broken server is replaced, not repaired.

This is the "**cattle, not pets**" idea. Pets get names and nursing; cattle are numbered and replaced. Your VPS should be cattle.

## Core concepts

### How Ansible works

```
Your Mac (control node)                         Server (managed node)
ansible-playbook site.yml ──── SSH ────────────▶ runs small Python modules, returns JSON
  inventory: which hosts                         nothing to install except Python + sshd
  playbook:  what state they should be in
```

- **Agentless:** it only needs SSH and Python on the server. Compare Puppet or Chef, which need an agent running.
- **Push-based:** you run it from your machine (or CI). Nothing on the server pulls config.
- Every task calls a **module** (`apt`, `user`, `template`, `ufw`…) that checks the current state and changes it only if needed.

### Vocabulary

| Term | Meaning | Here |
|---|---|---|
| **Inventory** | The hosts, grouped | `inventory/test/hosts.yml`: group `servers` |
| **Playbook** | Ordered plays: "these hosts → these tasks/roles" | `site.yml` |
| **Play** | One `hosts:` + tasks block | "Work out how to connect", "Configure the server" |
| **Task** | One module call | `ansible.builtin.apt: name=ufw` |
| **Module** | The code a task runs | `apt`, `template`, `community.general.ufw` |
| **Role** | A reusable bundle: tasks, handlers, templates, defaults | `roles/ssh/` |
| **Handler** | A task that runs only when notified, once, at the end (or at `flush_handlers`) | "Restart sshd" |
| **Facts** | Info gathered from the host | `ansible_facts['distribution_release']` = `noble` |
| **Collection** | A package of modules and roles | `community.docker`, `ansible.posix` |

### Declarative and idempotent

You describe **what should be true**, not the steps to get there:

```yaml
- ansible.builtin.user:
    name: ops
    groups: sudo
```

means "user `ops` exists and is in `sudo`". The first run creates it (`changed`); every later run finds it already true (`ok`). That's **idempotency**: running it once or a hundred times gives the same result. A second run reporting `changed=0` is your test that every task really converges.

Watch out for:
- `command:` / `shell:` always report `changed`, unless you set `changed_when:` (as the `sshd -t` check does).
- Tasks that generate random values or timestamps.
- "Converges but flips": two tasks that keep undoing each other.

### Templates and handlers

- **Templates** (`*.j2`, Jinja2) render files with variables: `Port {{ ssh_port }}`.
- A changed file usually needs a service restart. `notify: Restart sshd` runs the handler **once**, **only if** something changed.
- Handlers normally run at the end of the play. `meta: flush_handlers` runs them *now*. The ssh role needs that, because it must reconnect on the new port before continuing.

### Variables and precedence

Variables come from many places, and **the higher one wins**. The ones used here, simplified, from lowest to highest:

```
role defaults (roles/x/defaults/main.yml)          ← safest place for role defaults
inventory group_vars/all
playbook group_vars/all     (ansible/group_vars/all.yml)
inventory group_vars/<group> (inventory/test/group_vars/servers.yml)   ← per-environment overrides
host vars
set_fact / registered vars                          ← what the ssh role uses to switch port and user
extra vars (-e)                                     ← beats everything, even set_fact
```

This lab hit that trap: test overrides in the inventory's `group_vars/all` lost to the playbook's `group_vars/all`. Moving them to a named group (`servers`) fixed it.

### Changing the connection mid-play

The ssh role moves sshd from port 22 to `ssh_port`, while Ansible is connected through port 22. The safe order:

1. The firewall allows **both** ports.
2. Write the sshd config; validate it with `sshd -t`, so a typo can't lock you out.
3. `flush_handlers`: restart sshd now.
4. Copy the host key to the new port in `known_hosts`.
5. `set_fact` the new `ansible_port`/`ansible_user`, `reset_connection`, `wait_for_connection`.
6. Only then close port 22.

The first play detects which state the server is in by **really logging in** as the admin user. So the same command works on a fresh server and on a hardened one.

### Secrets: Ansible Vault

- `ansible-vault encrypt file.yml` encrypts it with AES-256. `--ask-vault-pass` (or `--vault-password-file`) decrypts it at run time.
- Convention: real values are `vault_*` in `vault.yml`, referenced from readable variables (`traefik_dashboard_users: "{{ vault_traefik_dashboard_users }}"`). Then you can grep where a secret is used without decrypting anything.
- `no_log: true` stops secrets from being printed in task output.
- An encrypted vault *can* be committed. A weak vault password, or an unencrypted file committed by mistake, can't be undone. Rotate the secret if that happens.

### Ansible vs Terraform vs Docker

| Tool | Manages | Question it answers |
|---|---|---|
| **Terraform** (lab 10) | Cloud resources: VPS, DNS, firewall | "Which machines exist?" |
| **Ansible** (this lab) | What's on a machine: users, packages, configs, services | "How is each machine configured?" |
| **Docker / Compose** | The apps, packaged | "What runs, in which version?" |
| **CI/CD** (lab 07) | Releases | "When does a new version go out?" |

In this repo: Terraform creates the VPS → Ansible configures it → CI deploys app releases onto it. Ansible deliberately **doesn't** deploy hello-api releases: it prepares the files and `.env`, and `deploy.sh` does the rollout.

### Drift

**Drift** is when a server no longer matches its code, e.g. someone ran `ufw allow 9999` by hand. Ansible fixes drift in what it *manages*, but doesn't remove what it doesn't know about. The cure is discipline (never change servers by hand) or rebuilding often from code, which makes drift impossible.

### Testing infrastructure code

- `ansible-playbook --syntax-check`, `ansible-lint` (style and common mistakes).
- `--check --diff`: a dry run that predicts changes.
- A **throwaway target**: this lab's fake VPS. The bigger version of that idea is **Molecule**, which creates containers or VMs, runs the role, checks idempotency, and destroys everything, often in CI.

## Key terms

| Term | Meaning |
|---|---|
| Idempotent | Same result whether run once or many times |
| Declarative | Describe the end state, not the steps |
| Agentless | No software installed on managed hosts |
| Convergence | Repeated runs bring the system to the declared state |
| Drift | Differences between real state and declared state |
| Cattle vs pets | Replaceable, identical servers vs hand-cared-for unique ones |
| Handler | Runs once, only when notified by a change |
| Vault | Encrypted variables file |

## Commands to know

| Command | What it does |
|---|---|
| `ansible-inventory --graph` / `--host <h> --yaml` | Show hosts and groups / a host's variables |
| `ansible servers -m ping` | Check Ansible can reach and run Python on hosts |
| `ansible-playbook site.yml --syntax-check` | Parse only |
| `ansible-playbook site.yml --check --diff` | Dry run, show file diffs |
| `ansible-playbook site.yml --tags ssh` / `--skip-tags docker` | Run part of a playbook |
| `ansible-playbook site.yml --start-at-task "Install fail2ban"` | Resume from a task |
| `ansible-playbook site.yml -v` / `-vvv` | More output, down to SSH details |
| `ansible-vault encrypt / edit / view <file>` | Manage encrypted files |
| `ansible-lint` | Lint playbooks and roles |

## Before you start, can you answer these?

1. What does "idempotent" mean, and how do you prove a playbook is?
2. Why must the firewall role run **before** the ssh role?
3. Why doesn't Ansible need anything installed on the server except Python and sshd?
4. When does a handler run, and why does the ssh role call `flush_handlers`?
5. Which tool creates the VPS, which configures it, and which deploys the app?

## After the lab, check yourself

1. How long did a full rebuild from a fresh server take?
2. What did the first play detect on the first run, and on the second?
3. Which tasks changed on the second run, if any, and why?
4. What happened to your hand-made `ufw allow 9999` after re-running the playbook?
5. Why are the test secrets in `inventory/test` acceptable, and the production ones not?
6. Name two things on the server Ansible doesn't manage yet (hint: lab 03, lab 06).

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Ansible: playbook guide](https://docs.ansible.com/ansible/latest/playbook_guide/index.html)
- [Ansible: best practices / tips and tricks](https://docs.ansible.com/ansible/latest/tips_tricks/index.html)
- [Variable precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
- [Molecule: testing Ansible roles](https://ansible.readthedocs.io/projects/molecule/)
- [The history of pets vs cattle](https://cloudscaling.com/blog/cloud-computing/the-history-of-pets-vs-cattle/)
