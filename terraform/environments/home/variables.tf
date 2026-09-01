variable "node_name" {
  description = "Name of the Proxmox node that will host the VM."
  type        = string
}

variable "template_vm_id" {
  description = "VMID of the Ubuntu Resolute cloud-init template."
  type        = number
  default     = 9001
}

variable "core_vm_id" {
  description = "Unused VMID to assign to the core VM."
  type        = number
}

variable "datastore_id" {
  description = "Proxmox datastore for the cloned VM disks."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox bridge connected to the core VM."
  type        = string
  default     = "vmbr0"
}

variable "core_cpu_cores" {
  description = "Number of virtual CPU cores assigned to core."
  type        = number
  default     = 2

  validation {
    condition     = var.core_cpu_cores >= 1
    error_message = "core_cpu_cores must be at least 1."
  }
}

variable "core_memory_mb" {
  description = "Dedicated memory assigned to core, in MiB."
  type        = number
  default     = 4096

  validation {
    condition     = var.core_memory_mb >= 1024
    error_message = "core_memory_mb must be at least 1024."
  }
}

variable "core_disk_size_gb" {
  description = "Size of the core boot disk, in GiB. Must not be smaller than the template disk."
  type        = number
  default     = 32

  validation {
    condition     = var.core_disk_size_gb >= 8
    error_message = "core_disk_size_gb must be at least the template's 8 GiB disk size."
  }
}

variable "core_username" {
  description = "Bootstrap account created by cloud-init."
  type        = string
}

variable "ssh_public_key_file" {
  description = "Local path to the SSH public key installed for the bootstrap account."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "core_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.core_ipv4_address == "dhcp" || can(cidrnetmask(var.core_ipv4_address))
    error_message = "core_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "core_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = null
  nullable    = true
}
