output "ops_vm_id" {
  description = "VMID assigned to ops."
  value       = proxmox_virtual_environment_vm.ops.vm_id
}

output "ops_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent for ops."
  value       = proxmox_virtual_environment_vm.ops.ipv4_addresses
}

output "gateway_vm_id" {
  description = "VMID assigned to the OPNsense Gateway."
  value       = proxmox_virtual_environment_vm.gateway.vm_id
}

output "gateway_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent for the Gateway."
  value       = proxmox_virtual_environment_vm.gateway.ipv4_addresses
}

output "workload_vm_ids" {
  description = "VMIDs indexed by the canonical workload catalog name."
  value       = { for name, vm in proxmox_virtual_environment_vm.workload : name => vm.vm_id }
}

output "workload_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent, indexed by the canonical workload catalog name."
  value       = { for name, vm in proxmox_virtual_environment_vm.workload : name => vm.ipv4_addresses }
}
