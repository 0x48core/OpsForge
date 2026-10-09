# terraform

Creates the infrastructure: the server, its firewall, IP, and DNS (lab 10). [Ansible](../ansible/) then configures what runs on it.

```
terraform apply  ──▶  server + firewall + DNS  ──▶  ansible/inventory/<env>/…yml  ──▶  ansible-playbook site.yml
```

| Environment | Creates | Cost |
|---|---|---|
| [envs/local](envs/local/) | The lab 09 fake VPS as a Docker container, for practice | free |
| [envs/digitalocean](envs/digitalocean/) | Droplet (sgp1, 2 vCPU / 4 GB), reserved IP, cloud firewall, DNS zone with `@` and `*` records | ~$24/month while it exists |

Both write an Ansible inventory from the real resources, using [templates/ansible-inventory.yml.tftpl](templates/ansible-inventory.yml.tftpl).

## Local practice

```bash
cd terraform/envs/local
terraform init
terraform plan
terraform apply
ssh-keyscan -p 2201 -t ed25519 127.0.0.1 >> ~/.ssh/known_hosts   # trust the new "server"
cd ../../../ansible && ansible-playbook -i inventory/test/terraform.yml site.yml
cd ../terraform/envs/local && terraform destroy
```

Don't run it at the same time as `ansible/test/fake-vps.sh`: both use ports 2201, 2202, 8080, and 8443.

## DigitalOcean

```bash
export DIGITALOCEAN_TOKEN=dop_v1_...        # never in a file in git
cd terraform/envs/digitalocean
cp terraform.tfvars.example terraform.tfvars   # set domain
terraform init
terraform plan
terraform apply
```

Then follow [lab 10, step 6](../labs/10-terraform/README.md#6-the-real-thing-digitalocean).

## Rules

- **State** (`terraform.tfstate`) holds every resource's details, including secrets. It's git-ignored. Use a remote backend for real infrastructure ([backend.tf.example](envs/digitalocean/backend.tf.example)).
- **Commit `.terraform.lock.hcl`**: it pins exact provider versions and checksums, like `go.sum`.
- **Secrets** come from environment variables (`DIGITALOCEAN_TOKEN`), not `.tf` or `.tfvars` files.
- **Always read the plan** before `apply`, especially lines with `must be replaced` or `destroy`.
- CI runs `fmt` and `validate` on every change ([workflow](../.github/workflows/terraform.yml)); it never applies.
