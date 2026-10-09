# Lab 10 — Terraform: provision VPS, DNS, firewall

- **Phase:** 4 — Infrastructure as Code
- **Status:** 🟨 in progress
- **Started / finished:** — / —
- **Environment:** Docker on the Mac for practice (`envs/local`); DigitalOcean for the real VPS (`envs/digitalocean`)

> 📖 **Learn first:** read [knowledge.md](knowledge.md) before starting the steps below.

## Goal

Create the server itself from code: VPS, IP, firewall, and DNS. Then `terraform apply` + `ansible-playbook` takes you from nothing to the full OpsForge server, and `terraform destroy` cleans it all up.

## Done when

**Local (free)**
- [ ] `plan` → `apply` → Ansible → `destroy` completed with `envs/local`
- [ ] Explained why `plan` said "No changes" after Ansible changed the server
- [ ] Saw a change that `forces replacement`, and what that means for the server's configuration

**DigitalOcean**
- [ ] VPS, reserved IP, firewall, and DNS records defined in Terraform
- [ ] Remote state (not committed)
- [ ] `terraform apply` + the Ansible playbook from lab 09 = full environment from zero
- [ ] `terraform destroy` cleans everything up (check the DigitalOcean console: nothing left, no more charges)

## Measured while preparing this lab

| Step | Result |
|---|---|
| `envs/local` plan | 5 to add (image, 2 volumes, container, inventory file) |
| `envs/local` apply | 5 added in 3 s; inventory generated |
| Ansible on it (`-i inventory/test/terraform.yml`) | ok=45, changed=35, failed=0, 91 s |
| `plan` after Ansible | **No changes** |
| `plan` with a different port | container **must be replaced** (`forces replacement`) |
| `destroy` | 5 destroyed; no containers, volumes, or inventory left |
| `envs/digitalocean` plan (dummy token, no account) | 9 to add: droplet, SSH key, reserved IP + assignment, firewall, domain, 2 records, inventory |

Terraform 1.16.5; providers `kreuzwerker/docker` 4.6, `digitalocean/digitalocean` 2.104, `hashicorp/local` 2.9.

## Files

| File | What |
|---|---|
| [terraform/envs/local/main.tf](../../terraform/envs/local/main.tf) | Fake VPS: image, volumes, container, inventory |
| [terraform/envs/digitalocean/main.tf](../../terraform/envs/digitalocean/main.tf) | Droplet, reserved IP, firewall, DNS, inventory |
| [variables.tf](../../terraform/envs/digitalocean/variables.tf) / [outputs.tf](../../terraform/envs/digitalocean/outputs.tf) | Inputs (region, size, domain…) / results (IP, nameservers…) |
| [terraform.tfvars.example](../../terraform/envs/digitalocean/terraform.tfvars.example) | Your values (copy to `terraform.tfvars`, git-ignored) |
| [backend.tf.example](../../terraform/envs/digitalocean/backend.tf.example) | Remote state in DigitalOcean Spaces |
| [templates/ansible-inventory.yml.tftpl](../../terraform/templates/ansible-inventory.yml.tftpl) | Inventory both environments generate |
| [.github/workflows/terraform.yml](../../.github/workflows/terraform.yml) | CI: `fmt` + `validate` for both environments |

## Steps

### 0. Install Terraform

Terraform is no longer in Homebrew's main repository (license change in 2023), so install it from HashiCorp's tap:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

Alternative: `brew install opentofu` (the open-source fork; same language, the command is `tofu`).

### 1. Init and read the plan

```bash
cd terraform/envs/local
terraform init        # downloads providers, verifies them against .terraform.lock.hcl
terraform plan
```

Read every `+` line. Which 5 resources will be created? Which values are `(known after apply)`, and why can't Terraform know them yet?

### 2. Apply

```bash
terraform apply       # shows the plan again, asks for "yes"
terraform output
terraform state list
cat ../../../ansible/inventory/test/terraform.yml
docker ps --filter name=opsforge-tf-vps
```

### 3. Configure it with Ansible

```bash
ssh-keyscan -p 2201 -t ed25519 127.0.0.1 >> ~/.ssh/known_hosts   # first-use trust of the new server
ssh -p 2201 root@127.0.0.1 hostname
cd ../../../ansible
ansible-playbook -i inventory/test/terraform.yml site.yml
cd ../terraform/envs/local
```

Terraform created the machine; Ansible made it an OpsForge server.

### 4. Plan again: who owns what?

```bash
terraform plan        # "No changes". Why, when Ansible changed so much?
```

Then simulate a change Terraform can't make in place:

```bash
terraform plan -var 'ports={"22"=2201,"2202"=2202,"80"=8080,"443"=9443}'
```

You'll see `must be replaced` / `forces replacement`. Applying that would give you a **new, unconfigured** server, so you'd run Ansible again. Don't apply it; just read it.

Optional: drift. Delete the container behind Terraform's back (`docker rm -f opsforge-tf-vps`), then `terraform plan`. What does Terraform want to do?

### 5. Destroy

```bash
terraform destroy
docker ps -a --filter name=opsforge-tf-vps        # nothing
ls ../../../ansible/inventory/test/                # terraform.yml is gone too
ssh-keygen -R "[127.0.0.1]:2201"; ssh-keygen -R "[127.0.0.1]:2202"
```

### 6. The real thing: DigitalOcean

> 💸 This creates resources that cost money (~$24/month for the droplet, billed hourly) until you `terraform destroy`.

**Prepare:**
1. A DigitalOcean account, then **API → Generate New Token** (read + write). Keep it in your password manager.
2. A domain. At your registrar, set its nameservers to `ns1.digitalocean.com`, `ns2.digitalocean.com`, `ns3.digitalocean.com`. Changes can take hours to spread.
3. Optional but recommended, **remote state**: create a Spaces bucket and a Spaces access key, then `cp backend.tf.example backend.tf` and fill in the bucket.

**Create:**

```bash
export DIGITALOCEAN_TOKEN=dop_v1_...
cd terraform/envs/digitalocean
cp terraform.tfvars.example terraform.tfvars        # set domain (and admin_cidrs to your IP, if stable)
terraform init
terraform plan                                      # read it: 9 to add
terraform apply
terraform output
```

**Configure** (lab 09, step 10). The inventory `ansible/inventory/production/hosts.yml` was just generated:

```bash
ssh root@$(terraform output -raw ip) true           # accept the host key (check the fingerprint in the droplet console)
cd ../../../ansible
ansible-playbook -i inventory/production site.yml --ask-vault-pass
dig +short api.<your-domain>                        # the reserved IP
curl -I https://api.<your-domain>                   # a real Let's Encrypt certificate
```

Make sure `ssh_port` in the Ansible inventory matches `ssh_port` in `terraform.tfvars` (both default to 2222). The cloud firewall only lets those ports through.

**Destroy** when you're done practicing, then check the DigitalOcean console for leftovers:

```bash
cd ../terraform/envs/digitalocean && terraform destroy
```

## Code

- [terraform/](../../terraform/)
- [.github/workflows/terraform.yml](../../.github/workflows/terraform.yml)

## What broke

_Write down errors and fixes here as you go._

Notes from preparing this lab:
- `brew install terraform` no longer gives a current Terraform: use `hashicorp/tap/terraform` (or OpenTofu).
- The lock files were first created on macOS only. `terraform providers lock -platform=…` added Linux checksums, so CI and Linux machines can verify the providers too.
- A changed port list shows extra port "swaps" in the plan: diff noise from ordering. Read the `forces replacement` lines, not the noise.

## Lessons learned

## References

- [Terraform: get started](https://developer.hashicorp.com/terraform/tutorials)
- [Terraform language](https://developer.hashicorp.com/terraform/language)
- [DigitalOcean provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [Docker provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- [Backend: S3 (works with Spaces)](https://developer.hashicorp.com/terraform/language/backend/s3)
