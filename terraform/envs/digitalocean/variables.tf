variable "name" {
  description = "Droplet name (also its hostname)."
  type        = string
  default     = "opsforge"
}

variable "region" {
  description = "DigitalOcean region. sgp1 = Singapore, closest to Vietnam."
  type        = string
  default     = "sgp1"
}

variable "size" {
  description = "Droplet size slug. s-2vcpu-4gb fits every lab, including K3s."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "image" {
  description = "OS image. The Ansible playbook expects Ubuntu 24.04."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "ssh_public_key_path" {
  description = "Public key installed for root on the new droplet."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "domain" {
  description = "Domain to manage in DigitalOcean DNS (its nameservers must point to DigitalOcean)."
  type        = string
}

variable "ssh_port" {
  description = "Hardened SSH port; must match ssh_port in the Ansible inventory."
  type        = number
  default     = 2222
}

variable "admin_cidrs" {
  description = "Who may reach SSH. Narrow this to your own IP (x.x.x.x/32) if it is stable."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}
