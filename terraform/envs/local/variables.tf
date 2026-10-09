variable "docker_host" {
  description = "Docker daemon to use. null = DOCKER_HOST or the default socket."
  type        = string
  default     = null
}

variable "ssh_public_key_path" {
  description = "Public key installed for root, like a cloud provider does."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "name" {
  description = "Container (\"server\") name."
  type        = string
  default     = "opsforge-tf-vps"
}

# Same ports as ansible/test/fake-vps.sh, so inventory/test's settings apply.
# Don't run both fake VPSs at once.
variable "ports" {
  description = "Container port => port on 127.0.0.1."
  type        = map(number)
  default = {
    22   = 2201 # sshd before hardening
    2202 = 2202 # hardened sshd (ssh_port in inventory/test)
    80   = 8080
    443  = 8443
  }
}
