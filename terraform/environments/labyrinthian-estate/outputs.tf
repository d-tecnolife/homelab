output "core_vm_id" {
  description = "VMID assigned to core."
  value       = proxmox_virtual_environment_vm.core.vm_id
}

output "core_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent after startup."
  value       = proxmox_virtual_environment_vm.core.ipv4_addresses
}

output "netbird_vm_id" {
  description = "VMID assigned to netbird."
  value       = proxmox_virtual_environment_vm.netbird.vm_id
}

output "netbird_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent after startup."
  value       = proxmox_virtual_environment_vm.netbird.ipv4_addresses
}