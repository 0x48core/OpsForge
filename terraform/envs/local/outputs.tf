output "ssh_bootstrap" {
  description = "Log in to the fresh server (before Ansible)."
  value       = "ssh -p ${var.ports[22]} root@127.0.0.1"
}

output "ansible_command" {
  description = "Configure it (run in ansible/)."
  value       = "ansible-playbook -i inventory/test/terraform.yml site.yml"
}

output "container_id" {
  value = docker_container.vps.id
}
