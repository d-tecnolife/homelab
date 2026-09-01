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

output "netbird_vm_id" {
  description = "VMID assigned to netbird."
  value       = proxmox_virtual_environment_vm.netbird.vm_id
}

output "netbird_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent after startup."
  value       = proxmox_virtual_environment_vm.netbird.ipv4_addresses
}

output "edge_vm_id" {
  description = "VMID assigned to edge."
  value       = proxmox_virtual_environment_vm.edge.vm_id
}

output "edge_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent for edge."
  value       = proxmox_virtual_environment_vm.edge.ipv4_addresses
}
