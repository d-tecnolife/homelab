# Environment-wide variables

variable "proxmox_endpoint" {
  description = "Secret storing the Proxmox host location."
  type        = string
}

variable "proxmox_api_token" {
  description = "Secret storing the Proxmox API key."
  type        = string
}

variable "proxmox_ssh_username" {
  description = "SSH account used to upload Cloud-Init snippets to the Proxmox node."
  type        = string
  default     = "terraform"
}

variable "node_name" {
  description = "Name of the Proxmox node that will host the VM."
  type        = string
  default     = "labyrinthian-estate"
}

variable "vm_username" {
  description = "Bootstrap account created by cloud-init on all VMs."
  type        = string
  default     = "dtec"
}

variable "datastore_id" {
  description = "Proxmox datastore for the cloned VM disks."
  type        = string
  default     = "local-lvm"
}

variable "snippet_datastore_id" {
  description = "Proxmox directory datastore with snippets enabled."
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Proxmox bridge used by the Gateway WAN-facing NIC."
  type        = string
  default     = "vmbr0"
}

variable "internal_network_bridge" {
  description = "VLAN-aware Proxmox bridge used only by internal VM networks."
  type        = string
  default     = "vmbr1"
}

variable "infra_vlan_id" {
  description = "VLAN ID for infrastructure services."
  type        = number
  default     = 10
}

variable "internal_vlan_id" {
  description = "VLAN ID for internal workloads."
  type        = number
  default     = 20
}

variable "dmz_vlan_id" {
  description = "VLAN ID for internet-facing workloads."
  type        = number
  default     = 30
}

variable "vga_type" {
  description = "Default virtual display adapter for VMs."
  type        = string
  default     = "virtio"
}

variable "ssh_public_key_file" {
  description = "Local path to the SSH public key installed for the bootstrap account."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "dns_servers" {
  description = "DNS resolvers supplied persistently to every VM by Cloud-Init."
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]

  validation {
    condition     = length(var.dns_servers) > 0
    error_message = "dns_servers must contain at least one resolver."
  }
}

# VM IDs

variable "template_vm_id" {
  description = "VMID of the Ubuntu Resolute cloud-init template."
  type        = number
  default     = 9001
}

variable "ops_vm_id" {
  description = "VMID to assign to the ops VM."
  type        = number
  default     = 1010
}

variable "gateway_vm_id" {
  description = "VMID to assign to the OPNsense Gateway."
  type        = number
  default     = 100
}

variable "gateway_iso_file_id" {
  description = "Proxmox ISO volume ID for the immutable OPNsense DVD source, for example local:iso/OPNsense-<version>-dvd-amd64.iso."
  type        = string
}

variable "gateway_bootstrap_iso_file_id" {
  description = "Generated OPNsense installer ISO containing the rendered Gateway config.xml."
  type        = string
}

variable "gateway_bootstrap_media_attached" {
  description = "Keep the generated Gateway installer ISO attached and first in boot order. Set false only after the attended OPNsense installation completes."
  type        = bool
  default     = true
}

variable "gateway_policy_ready" {
  description = "Set true only after the OPNsense baseline and declarative policy have been applied and verified. This gates workload creation."
  type        = bool
  default     = false
}

# Ops VM variables

variable "ops_cpu_cores" {
  description = "Number of virtual CPU cores assigned to ops."
  type        = number
  default     = 2

  validation {
    condition     = var.ops_cpu_cores >= 1
    error_message = "ops_cpu_cores must be at least 1."
  }
}

variable "ops_memory_mb" {
  description = "Dedicated memory assigned to ops, in MiB."
  type        = number
  default     = 2048

  validation {
    condition     = var.ops_memory_mb >= 1024
    error_message = "ops_memory_mb must be at least 1024."
  }
}

variable "ops_disk_size_gb" {
  description = "Size of the ops boot disk, in GiB. Must not be smaller than the template disk."
  type        = number
  default     = 60

  validation {
    condition     = var.ops_disk_size_gb >= 8
    error_message = "ops_disk_size_gb must be at least the template's 8 GiB disk size."
  }
}

variable "ops_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "172.16.10.10/24"

  validation {
    condition     = var.ops_ipv4_address == "dhcp" || can(cidrnetmask(var.ops_ipv4_address))
    error_message = "ops_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "ops_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = "172.16.10.1"
  nullable    = true
}

variable "ops_ipv4_internal_address" {
  description = "IPv4 address in CIDR notation for Ops's Internal-VLAN NIC (Tailscale subnet routing only, no default route)."
  type        = string
  default     = "172.16.20.2/24"

  validation {
    condition     = can(cidrnetmask(var.ops_ipv4_internal_address))
    error_message = "ops_ipv4_internal_address must be an IPv4 address in CIDR notation."
  }
}

variable "ops_ipv4_dmz_address" {
  description = "IPv4 address in CIDR notation for Ops's DMZ-VLAN NIC (Tailscale subnet routing only, no default route)."
  type        = string
  default     = "172.16.30.2/24"

  validation {
    condition     = can(cidrnetmask(var.ops_ipv4_dmz_address))
    error_message = "ops_ipv4_dmz_address must be an IPv4 address in CIDR notation."
  }
}

# Per-workload sizing, addressing, and VMIDs live in topology/workloads.yaml,
# consumed directly by workloads.tf's for_each. Do not add per-workload
# Terraform variables here; add or edit the catalog entry instead.

variable "backup_datastore_id" {
  description = "Proxmox storage that holds the weekly Apps rollback image."
  type        = string
  default     = "local-backup"
}
