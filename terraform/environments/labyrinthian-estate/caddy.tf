moved {
  from = proxmox_virtual_environment_vm.caddy
  to   = proxmox_virtual_environment_vm.door
}

resource "proxmox_virtual_environment_vm" "door" {
  depends_on = [proxmox_virtual_environment_vm.gateway]

  name        = "door"
  description = "DMZ Door reverse-proxy VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "door", "caddy", "dmz"]

  node_name = var.node_name
  vm_id     = var.door_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = false
  }

  cpu {
    cores = var.door_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.door_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.door_disk_size_gb
  }

  network_device {
    bridge  = proxmox_network_linux_bridge.internal.name
    model   = "virtio"
    vlan_id = var.dmz_vlan_id
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "scsi1"

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.door_ipv4_address
        gateway = var.door_ipv4_address == "dhcp" ? null : var.door_ipv4_gateway
      }
    }

    user_account {
      username = var.vm_username
      keys     = local.workload_ssh_authorized_keys
    }
  }

  on_boot = true
  started = true

  lifecycle {
    precondition {
      condition     = var.gateway_policy_ready
      error_message = "Gateway policy is not verified. Complete docs/gateway-configuration.md before creating workloads."
    }
    precondition {
      condition     = var.door_ipv4_address == "dhcp" || var.door_ipv4_gateway != null
      error_message = "door_ipv4_gateway must be set when door_ipv4_address is static."
    }
  }
}
