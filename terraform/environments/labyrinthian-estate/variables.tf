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
  description = "Proxmox bridge used by edge's home LAN-facing NIC."
  type        = string
  default     = "vmbr0"
}

variable "internal_network_bridge" {
  description = "VLAN-aware Proxmox bridge used only by internal VM networks."
  type        = string
  default     = "vmbr1"
}

variable "management_vlan_id" {
  description = "VLAN ID for the management network."
  type        = number
  default     = 100
}

variable "services_vlan_id" {
  description = "VLAN ID for the services network."
  type        = number
  default     = 200
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

variable "edge_vm_id" {
  description = "VMID to assign to the edge VM."
  type        = number
  default     = 1999
}

variable "apps_vm_id" {
  description = "VMID to assign to the apps VM."
  type        = number
  default     = 2010
}

variable "gitea_vm_id" {
  description = "VMID to assign to the Gitea VM."
  type        = number
  default     = 1020
}

variable "monitoring_vm_id" {
  description = "VMID to assign to the monitoring VM."
  type        = number
  default     = 1030
}

variable "k3s_vm_id" {
  description = "VMID to assign to the k3s VM."
  type        = number
  default     = 1040
}

variable "nolife_vm_id" {
  description = "VMID to assign to the Nolife development VM."
  type        = number
  default     = 1050
}

variable "games_vm_id" {
  description = "VMID to assign to the game-server VM."
  type        = number
  default     = 2020
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
  default     = 4096

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
  default     = "10.200.1.10/24"

  validation {
    condition     = var.apps_ipv4_address == "dhcp" || can(cidrnetmask(var.apps_ipv4_address))
    error_message = "apps_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "apps_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = "10.200.1.1"
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
  default     = "10.100.1.10/24"

  validation {
    condition     = var.ops_ipv4_address == "dhcp" || can(cidrnetmask(var.ops_ipv4_address))
    error_message = "ops_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "ops_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = "10.100.1.1"
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
  default     = 2048

  validation {
    condition     = var.edge_memory_mb >= 1024
    error_message = "edge_memory_mb must be at least 1024."
  }
}

variable "edge_disk_size_gb" {
  description = "Size of the edge boot disk, in GiB. Must not be smaller than the template disk."
  type        = number
  default     = 24

  validation {
    condition     = var.edge_disk_size_gb >= 8
    error_message = "edge_disk_size_gb must be at least the template's 8 GiB disk size."
  }
}

variable "edge_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "192.0.2.10/24"

  validation {
    condition     = var.edge_ipv4_address == "dhcp" || can(cidrnetmask(var.edge_ipv4_address))
    error_message = "edge_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "edge_ipv4_gateway" {
  description = "IPv4 gateway for a static address; leave null when using DHCP."
  type        = string
  default     = "192.168.1.1"
  nullable    = true
}

variable "edge_wan_mac_address" {
  description = "Stable MAC address for Edge's Rogers LAN-facing interface."
  type        = string
  default     = "BC:24:11:47:C7:97"

  validation {
    condition     = can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.edge_wan_mac_address))
    error_message = "edge_wan_mac_address must be a colon-separated MAC address."
  }
}

variable "edge_management_ipv4_address" {
  description = "Static management-side address for Edge in CIDR notation."
  type        = string
  default     = "10.100.1.1/24"
}

variable "edge_services_ipv4_address" {
  description = "Static services-side address for Edge in CIDR notation."
  type        = string
  default     = "10.200.1.1/24"
}

# Gitea VM variables

variable "gitea_cpu_cores" {
  type    = number
  default = 2
}

variable "gitea_memory_mb" {
  type    = number
  default = 2048
}

variable "gitea_disk_size_gb" {
  type    = number
  default = 32
}

variable "gitea_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "10.100.1.20/24"

  validation {
    condition     = var.gitea_ipv4_address == "dhcp" || can(cidrnetmask(var.gitea_ipv4_address))
    error_message = "gitea_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "gitea_ipv4_gateway" {
  type     = string
  default  = "10.100.1.1"
  nullable = true
}

# Monitoring VM variables

variable "monitoring_cpu_cores" {
  type    = number
  default = 2
}

variable "monitoring_memory_mb" {
  type    = number
  default = 2048
}

variable "monitoring_disk_size_gb" {
  type    = number
  default = 40
}

variable "monitoring_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "10.100.1.30/24"

  validation {
    condition     = var.monitoring_ipv4_address == "dhcp" || can(cidrnetmask(var.monitoring_ipv4_address))
    error_message = "monitoring_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "monitoring_ipv4_gateway" {
  type     = string
  default  = "10.100.1.1"
  nullable = true
}

# k3s VM variables

variable "k3s_cpu_cores" {
  type    = number
  default = 4
}

variable "k3s_memory_mb" {
  type    = number
  default = 4096
}

variable "k3s_disk_size_gb" {
  type    = number
  default = 60
}

variable "k3s_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "10.100.1.40/24"

  validation {
    condition     = var.k3s_ipv4_address == "dhcp" || can(cidrnetmask(var.k3s_ipv4_address))
    error_message = "k3s_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "k3s_ipv4_gateway" {
  type     = string
  default  = "10.100.1.1"
  nullable = true
}

# Nolife development VM variables

variable "nolife_cpu_cores" {
  type    = number
  default = 4
}

variable "nolife_memory_mb" {
  type    = number
  default = 4096
}

variable "nolife_disk_size_gb" {
  type    = number
  default = 80
}

variable "nolife_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "10.100.1.50/24"

  validation {
    condition     = var.nolife_ipv4_address == "dhcp" || can(cidrnetmask(var.nolife_ipv4_address))
    error_message = "nolife_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "nolife_ipv4_gateway" {
  type     = string
  default  = "10.100.1.1"
  nullable = true
}

# Game-server VM variables

variable "games_cpu_cores" {
  type    = number
  default = 6
}

variable "games_memory_mb" {
  type    = number
  default = 10240
}

variable "games_disk_size_gb" {
  type    = number
  default = 150
}

variable "games_ipv4_address" {
  description = "IPv4 address in CIDR notation, or dhcp."
  type        = string
  default     = "10.200.1.20/24"

  validation {
    condition     = var.games_ipv4_address == "dhcp" || can(cidrnetmask(var.games_ipv4_address))
    error_message = "games_ipv4_address must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "games_ipv4_gateway" {
  type     = string
  default  = "10.200.1.1"
  nullable = true
}
