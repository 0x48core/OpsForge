output "ip" {
  description = "Reserved (stable) public IP."
  value       = digitalocean_reserved_ip.server.ip_address
}

output "ssh_bootstrap" {
  description = "Log in to the fresh droplet (before Ansible)."
  value       = "ssh root@${digitalocean_reserved_ip.server.ip_address}"
}

output "nameservers" {
  description = "Set these at your domain registrar."
  value       = ["ns1.digitalocean.com", "ns2.digitalocean.com", "ns3.digitalocean.com"]
}

output "ansible_command" {
  description = "Configure the droplet (run in ansible/)."
  value       = "ansible-playbook -i inventory/production site.yml --ask-vault-pass"
}
