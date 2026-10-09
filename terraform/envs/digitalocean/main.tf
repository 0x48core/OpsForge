# Lab 10: the real server on DigitalOcean.
# Terraform creates the infrastructure; Ansible (lab 09) configures what runs on it.

resource "digitalocean_ssh_key" "admin" {
  name       = "${var.name}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "digitalocean_droplet" "server" {
  name       = var.name
  region     = var.region
  size       = var.size
  image      = var.image
  ssh_keys   = [digitalocean_ssh_key.admin.fingerprint]
  ipv6       = true
  monitoring = true # free CPU/RAM/disk graphs in the DigitalOcean console
  tags       = ["opsforge"]
}

# A reserved IP survives rebuilding the droplet: DNS and known_hosts entries
# keep pointing at the same address when the server is replaced.
resource "digitalocean_reserved_ip" "server" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "server" {
  ip_address = digitalocean_reserved_ip.server.ip_address
  droplet_id = digitalocean_droplet.server.id
}

# Cloud firewall, in front of ufw on the droplet (defense in depth, lab 01).
resource "digitalocean_firewall" "server" {
  name        = "${var.name}-fw"
  droplet_ids = [digitalocean_droplet.server.id]

  # SSH from admin addresses only: 22 for the first (bootstrap) Ansible run,
  # ssh_port afterwards. ufw on the droplet closes 22 once sshd has moved.
  dynamic "inbound_rule" {
    for_each = toset([22, var.ssh_port])
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.admin_cidrs
    }
  }

  dynamic "inbound_rule" {
    for_each = toset([80, 443])
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  dynamic "outbound_rule" {
    for_each = toset(["tcp", "udp"])
    content {
      protocol              = outbound_rule.value
      port_range            = "1-65535"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# DNS: the apex and a wildcard, so every *.domain subdomain (api., git., status.…)
# reaches Traefik without adding records per service.
resource "digitalocean_domain" "main" {
  name = var.domain
}

resource "digitalocean_record" "apex" {
  domain = digitalocean_domain.main.id
  type   = "A"
  name   = "@"
  value  = digitalocean_reserved_ip.server.ip_address
  ttl    = 300
}

resource "digitalocean_record" "wildcard" {
  domain = digitalocean_domain.main.id
  type   = "A"
  name   = "*"
  value  = digitalocean_reserved_ip.server.ip_address
  ttl    = 300
}

# The bridge to Ansible (git-ignored file).
resource "local_file" "ansible_inventory" {
  filename        = abspath("${path.module}/../../../ansible/inventory/production/hosts.yml")
  file_permission = "0644"
  content = templatefile("${path.module}/../../templates/ansible-inventory.yml.tftpl", {
    env     = "digitalocean"
    host    = var.name
    address = digitalocean_reserved_ip.server.ip_address
  })
}
