output "ops_vm_id" {
  description = "VMID assigned to ops."
  value       = proxmox_virtual_environment_vm.ops.vm_id
}

output "ops_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent for ops."
  value       = proxmox_virtual_environment_vm.ops.ipv4_addresses
}

output "apps_vm_id" {
  description = "VMID assigned to apps."
  value       = proxmox_virtual_environment_vm.apps.vm_id
}

output "apps_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent after startup."
  value       = proxmox_virtual_environment_vm.apps.ipv4_addresses
}

output "edge_vm_id" {
  description = "VMID assigned to edge."
  value       = proxmox_virtual_environment_vm.edge.vm_id
}

output "edge_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent for edge."
  value       = proxmox_virtual_environment_vm.edge.ipv4_addresses
}

output "gitea_vm_id" { value = proxmox_virtual_environment_vm.gitea.vm_id }
output "gitea_ipv4_addresses" { value = proxmox_virtual_environment_vm.gitea.ipv4_addresses }
output "monitoring_vm_id" { value = proxmox_virtual_environment_vm.monitoring.vm_id }
output "monitoring_ipv4_addresses" { value = proxmox_virtual_environment_vm.monitoring.ipv4_addresses }
output "k3s_vm_id" { value = proxmox_virtual_environment_vm.k3s.vm_id }
output "k3s_ipv4_addresses" { value = proxmox_virtual_environment_vm.k3s.ipv4_addresses }
output "dev_vm_id" { value = proxmox_virtual_environment_vm.dev.vm_id }
output "dev_ipv4_addresses" { value = proxmox_virtual_environment_vm.dev.ipv4_addresses }

output "games_vm_id" { value = proxmox_virtual_environment_vm.games.vm_id }
output "games_ipv4_addresses" { value = proxmox_virtual_environment_vm.games.ipv4_addresses }
