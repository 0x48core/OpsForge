# Lab 10 — Knowledge base

Study this **before** the hands-on part in [README.md](README.md). Add your own notes as you learn.

## Why this matters

Lab 09 made the *inside* of a server reproducible. But someone still had to click "Create Droplet", pick a region, add DNS records, and set up the firewall in a web console. **Terraform** makes that part code too:

- `terraform apply`: the infrastructure exists, exactly as described.
- `terraform destroy`: it's all gone, so nothing forgotten keeps costing money.
- Changes go through git and review, and `plan` shows the effect **before** anything happens.

Together with Ansible, an empty cloud account becomes the full OpsForge server with two commands.

## Core concepts

### Terraform vs Ansible

| | Terraform | Ansible |
|---|---|---|
| Manages | Infrastructure: servers, IPs, DNS, firewalls, buckets | What's on servers: packages, users, configs |
| Talks to | Cloud **APIs** | Servers over **SSH** |
| Knows the current state from | Its **state file** | Checking each server live, every run |
| Typical change | Create, update, or **replace** a resource | Change a file, restart a service |

They meet at the **inventory**: Terraform knows the new server's IP, and writes the file Ansible reads.

### Declarative, with a plan

You write the **desired** infrastructure. Terraform works out the steps:

```
your .tf files  ──┐
                  ├──▶  terraform plan  ──▶  the diff: + create  ~ update  - destroy  -/+ replace
state + real API ─┘                                │
                                         terraform apply (after "yes")
```

- **`plan` is read-only.** Always read it, above all `-/+` (replace) and `-` (destroy) lines.
- **`(known after apply)`**: values only the cloud can decide, like IDs and IPs.
- **Dependencies are automatic.** `digitalocean_record.apex` uses `digitalocean_reserved_ip.server.ip_address`, so Terraform creates the IP first. You rarely need `depends_on`.

### State

- `terraform.tfstate` maps your code to real resource IDs: "`digitalocean_droplet.server` = droplet 123456".
- Without it, Terraform doesn't know what it created, and would try to create everything again.
- **It contains sensitive data** (IPs, sometimes passwords and keys), so it's never committed.
- **Remote state** (S3/Spaces, HCP Terraform) is the norm for real infrastructure: it's backed up, shared, and **locked**, so two `apply`s can't run at once and corrupt it.
- `terraform state list` / `state show <resource>` inspect it. Edit state only as a last resort.

### Update in place vs replace

Some attributes can be changed on a live resource (a droplet's tags). Others can't (its image, or a container's ports): the provider must **destroy and recreate** it. The plan marks this `forces replacement`.

For a server, replacing means **new disk, fresh OS, everything inside gone**. That's fine *only* because:
- the configuration is in Ansible (lab 09), so run it again, and
- the data is backed up (lab 03), or kept on separate volumes.

`lifecycle { prevent_destroy = true }` protects resources that must never be replaced by accident, such as a database volume.

### Stable addresses: the reserved IP

A new droplet gets a new IP. With a **reserved IP** assigned to it, DNS records and `known_hosts` keep pointing at the same address when the droplet is replaced: Terraform just moves the assignment. The IP has its own life cycle, separate from the server's.

### Providers, versions, and the lock file

- A **provider** is a plugin that speaks one API (`digitalocean`, `docker`, `local`…).
- `version = "~> 2.104"` allows 2.104.x and later 2.x minors, but not 3.0.
- **`.terraform.lock.hcl`** records the exact version and checksums chosen. **Commit it**, so everyone gets identical providers. `terraform init -upgrade` moves them forward deliberately.

### Variables, outputs, and secrets

- `variable` = input (region, size, domain). Set in `terraform.tfvars` (git-ignored), `-var`, or `TF_VAR_name` env vars.
- `output` = results to show or hand on (`terraform output -raw ip`).
- **Secrets stay out of files**: the provider reads `DIGITALOCEAN_TOKEN` from the environment.

### DNS as code

- `digitalocean_domain` creates the zone. Your registrar must **delegate** to DigitalOcean's nameservers, or the records are never seen.
- A **wildcard record** (`*` → IP) sends every subdomain to Traefik, so adding a service needs no DNS change, just a Traefik label.
- **TTL 300** means caches keep an answer up to 5 minutes. A low TTL makes changes visible quickly.

### Cloud firewall + ufw

The DigitalOcean firewall filters traffic **before it reaches the droplet**. ufw (lab 01) filters **on** the droplet. Two independent layers (defense in depth): a mistake in one doesn't expose the server. The cloud firewall also isn't bypassed by Docker's iptables rules (the Docker/ufw problem from lab 04).

### Drift

If someone changes infrastructure by hand (deletes a record in the console, resizes the droplet), the real world no longer matches the code. `terraform plan` refreshes state from the API, shows the difference, and offers to put things back. Rule: **after adopting Terraform, change infrastructure only through Terraform.**

### Practicing for free with a local provider

`envs/local` uses the Docker provider to create a "server" that is a container. The resources are different, but the **workflow is identical**: init, plan, apply, state, outputs, replacement, drift, destroy, and the hand-off to Ansible. Only the provider changes when you move to the cloud.

### Terraform and OpenTofu

HashiCorp changed Terraform's license to BSL in 2023, and the community forked it as **OpenTofu** (Linux Foundation). For this repo they're interchangeable: the same `.tf` files work with both.

## Key terms

| Term | Meaning |
|---|---|
| Provider | Plugin for one API (cloud, DNS, Docker…) |
| Resource | One piece of infrastructure Terraform manages |
| Data source | Read-only lookup of something that already exists |
| State | Terraform's record of what it manages, with real IDs |
| Backend | Where state is stored (local file, S3, HCP Terraform…) |
| Plan | The computed diff between code and reality |
| Replace (`-/+`) | Destroy and recreate, because the change can't be made in place |
| Drift | Reality changed outside Terraform |
| Lock file | Pinned provider versions and checksums |

## Commands to know

| Command | What it does |
|---|---|
| `terraform init` | Download providers, set up the backend |
| `terraform fmt -recursive` / `validate` | Format / check the code |
| `terraform plan` / `plan -out=x` | Show the diff / save it to apply exactly that |
| `terraform apply` / `apply x` | Make it so / apply a saved plan |
| `terraform destroy` | Delete everything in this state |
| `terraform output [-raw name]` | Show outputs |
| `terraform state list` / `state show <addr>` | Inspect state |
| `terraform providers lock -platform=…` | Add checksums for other OSes |
| `terraform apply -replace=<addr>` | Force-recreate one resource |

## Before you start, can you answer these?

1. What's the difference between what Terraform manages and what Ansible manages?
2. What is the state file for, and why is it never committed?
3. What does `forces replacement` mean for a server?
4. Why does the DigitalOcean config use a reserved IP instead of the droplet's own IP?
5. Why must a domain's nameservers point to DigitalOcean before the DNS records work?

## After the lab, check yourself

1. List the resources each environment created, in the order Terraform created them.
2. Why did `plan` show "No changes" after Ansible?
3. What would you need to do after applying a change that replaces the server?
4. What happened when you deleted the container behind Terraform's back?
5. How would two people (or you and CI) share state safely?
6. After `terraform destroy` on DigitalOcean, how would you check that nothing is still billed?

## My notes

_Your own explanations, analogies, and "aha" moments._

## Further reading

- [Terraform: core workflow](https://developer.hashicorp.com/terraform/intro/core-workflow)
- [Terraform: state](https://developer.hashicorp.com/terraform/language/state)
- [Terraform: dependency lock file](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [DigitalOcean: reserved IPs](https://docs.digitalocean.com/products/networking/reserved-ips/)
- [OpenTofu](https://opentofu.org/)
