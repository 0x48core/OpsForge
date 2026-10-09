# Lab 10, local practice: Terraform creates the "fake VPS" from lab 09 as a
# Docker container, and writes the Ansible inventory for it.
# Same workflow as the real cloud (envs/digitalocean): plan, apply, Ansible, destroy.

provider "docker" {
  host = var.docker_host
}

locals {
  repo_root = abspath("${path.module}/../../..")
}

# Like a cloud "image": built from the lab 09 Dockerfile.
resource "docker_image" "vps" {
  name         = "opsforge-fake-vps:24.04"
  keep_locally = false

  build {
    context = "${local.repo_root}/ansible/test"
  }

  # Rebuild when the Dockerfile changes.
  triggers = {
    dockerfile = filesha256("${local.repo_root}/ansible/test/Dockerfile")
  }
}

# Like attached disks: Docker-in-Docker needs real volumes (overlay can't nest).
resource "docker_volume" "docker" {
  name = "${var.name}-docker"
}

resource "docker_volume" "containerd" {
  name = "${var.name}-containerd"
}

# Like the server itself.
resource "docker_container" "vps" {
  name          = var.name
  hostname      = "tf-vps"
  image         = docker_image.vps.image_id
  privileged    = true
  cgroupns_mode = "host"

  tmpfs = {
    "/run"      = ""
    "/run/lock" = ""
  }

  volumes {
    host_path      = "/sys/fs/cgroup"
    container_path = "/sys/fs/cgroup"
  }

  volumes {
    volume_name    = docker_volume.docker.name
    container_path = "/var/lib/docker"
  }

  volumes {
    volume_name    = docker_volume.containerd.name
    container_path = "/var/lib/containerd"
  }

  dynamic "ports" {
    for_each = var.ports
    content {
      internal = ports.key
      external = ports.value
      ip       = "127.0.0.1"
    }
  }

  # Like a cloud provider's "SSH keys" setting: root gets our public key.
  upload {
    file    = "/root/.ssh/authorized_keys"
    content = file(pathexpand(var.ssh_public_key_path))
  }
}

# The bridge to Ansible: the inventory is generated from real resources.
resource "local_file" "ansible_inventory" {
  filename        = "${local.repo_root}/ansible/inventory/test/terraform.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/../../templates/ansible-inventory.yml.tftpl", {
    env     = "local"
    host    = docker_container.vps.hostname
    address = "127.0.0.1"
  })
}
