# Environment-wide variables

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

variable "network_bridge" {
  description = "Proxmox bridge connected to the VMs."
  type        = string
  default     = "vmbr0"
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

# VM IDs

variable "template_vm_id" {
  description = "VMID of the Ubuntu Resolute cloud-init template."
  type        = number
  default     = 9001
}

variable "ops_vm_id" {
  description = "Unused VMID to assign to the ops VM."
  type        = number
  default     = 1010
}

variable "netbird_vm_id" {
  description = "Unused VMID to assign to the NetBird VM."
  type        = number
  default     = 1011
}

variable "edge_vm_id" {
  description = "Unused VMID to assign to the edge VM."
  type        = number
  default     = 1099
}

variable "apps_vm_id" {
  description = "Unused VMID to assign to the apps VM."
  type        = number
  default     = 1100
}

# Apps VM variables

variable "apps_cpu_cores" {
  description = "Number of virtual CPU cores assigned to apps."
  type        = number
  default     = 8

  validation {
    condition     = var.apps_cpu_cores >= 1
    error_message = "apps_cpu_cores must be at least 1."
  }
}

variable "apps_memory_mb" {
  description = "Dedicated memory assigned to apps, in MiB."
  type        = number
  default     = 8192

  validation {
    condition     = var.apps_memory_mb >= 1024
    error_message = "apps_memory_mb must be at least 1024."
  }
}

variable "apps_disk_size_gb" {
  description = "Size of the apps boot disk, in GiB. Must not be smaller than the template disk."
  type        = number
  default     = 100

  validation {
    condition     = var.apps_disk_size_gb >= 8
    error_message = "apps_disk_size_gb must be at least the template's 8 GiB disk size."
  }
}

variable "apps_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.apps_ipv4_address == "dhcp" || can(cidrnetmask(var.apps_ipv4_address))
    error_message = "apps_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "apps_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = null
  nullable    = true
}

# Netbird VM variables

variable "netbird_cpu_cores" {
  description = "Number of virtual CPU cores assigned to netbird."
  type        = number
  default     = 2

  validation {
    condition     = var.netbird_cpu_cores >= 1
    error_message = "netbird_cpu_cores must be at least 1."
  }
}

variable "netbird_memory_mb" {
  description = "Dedicated memory assigned to netbird, in MiB."
  type        = number
  default     = 1024

  validation {
    condition     = var.netbird_memory_mb >= 1024
    error_message = "netbird_memory_mb must be at least 1024."
  }
}

variable "netbird_disk_size_gb" {
  description = "Size of the netbird boot disk, in GiB. Must not be smaller than the template disk."
  type        = number
  default     = 16

  validation {
    condition     = var.netbird_disk_size_gb >= 8
    error_message = "netbird_disk_size_gb must be at least the template's 8 GiB disk size."
  }
}

variable "netbird_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.netbird_ipv4_address == "dhcp" || can(cidrnetmask(var.netbird_ipv4_address))
    error_message = "netbird_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "netbird_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = null
  nullable    = true
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
  default     = "dhcp"

  validation {
    condition     = var.ops_ipv4_address == "dhcp" || can(cidrnetmask(var.ops_ipv4_address))
    error_message = "ops_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "ops_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = null
  nullable    = true
}

# Edge VM variables

variable "edge_cpu_cores" {
  description = "Number of virtual CPU cores assigned to edge."
  type        = number
  default     = 2

  validation {
    condition     = var.edge_cpu_cores >= 1
    error_message = "edge_cpu_cores must be at least 1."
  }
}

variable "edge_memory_mb" {
  description = "Dedicated memory assigned to edge, in MiB."
  type        = number
  default     = 1024

  validation {
    condition     = var.edge_memory_mb >= 1024
    error_message = "edge_memory_mb must be at least 1024."
  }
}

variable "edge_disk_size_gb" {
  description = "Size of the edge boot disk, in GiB. Must not be smaller than the template disk."
  type        = number
  default     = 16

  validation {
    condition     = var.edge_disk_size_gb >= 8
    error_message = "edge_disk_size_gb must be at least the template's 8 GiB disk size."
  }
}

variable "edge_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.edge_ipv4_address == "dhcp" || can(cidrnetmask(var.edge_ipv4_address))
    error_message = "edge_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "edge_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = null
  nullable    = true
}
