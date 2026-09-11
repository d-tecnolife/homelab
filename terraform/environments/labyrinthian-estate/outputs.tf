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
  value       = proxmox_virtual_environment_vm.workload["apps"].vm_id
}

output "apps_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent after startup."
  value       = proxmox_virtual_environment_vm.workload["apps"].ipv4_addresses
}

output "gateway_vm_id" {
  description = "VMID assigned to the OPNsense Gateway."
  value       = proxmox_virtual_environment_vm.gateway.vm_id
}

output "gateway_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent for the Gateway."
  value       = proxmox_virtual_environment_vm.gateway.ipv4_addresses
}

output "gitea_vm_id" { value = proxmox_virtual_environment_vm.workload["gitea"].vm_id }
output "gitea_ipv4_addresses" { value = proxmox_virtual_environment_vm.workload["gitea"].ipv4_addresses }
output "monitoring_vm_id" { value = proxmox_virtual_environment_vm.workload["monitoring"].vm_id }
output "monitoring_ipv4_addresses" { value = proxmox_virtual_environment_vm.workload["monitoring"].ipv4_addresses }
output "k3s_vm_id" { value = proxmox_virtual_environment_vm.workload["k3s"].vm_id }
output "k3s_ipv4_addresses" { value = proxmox_virtual_environment_vm.workload["k3s"].ipv4_addresses }
output "nolife_vm_id" { value = proxmox_virtual_environment_vm.workload["nolife"].vm_id }
output "nolife_ipv4_addresses" { value = proxmox_virtual_environment_vm.workload["nolife"].ipv4_addresses }

output "games_vm_id" { value = proxmox_virtual_environment_vm.workload["games"].vm_id }
output "games_ipv4_addresses" { value = proxmox_virtual_environment_vm.workload["games"].ipv4_addresses }

output "workload_vm_ids" {
  description = "VMIDs indexed by the canonical workload catalog name."
  value       = { for name, vm in proxmox_virtual_environment_vm.workload : name => vm.vm_id }
}
