resource "proxmox_virtual_environment_vm" "caddy" {
  depends_on = [proxmox_virtual_environment_vm.pfsense]

  name        = "caddy"
  description = "DMZ Caddy VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "caddy", "dmz"]

  node_name = var.node_name
  vm_id     = var.caddy_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = false
  }

  cpu {
    cores = var.caddy_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.caddy_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.caddy_disk_size_gb
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
        address = var.caddy_ipv4_address
        gateway = var.caddy_ipv4_address == "dhcp" ? null : var.caddy_ipv4_gateway
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
      condition     = var.caddy_ipv4_address == "dhcp" || var.caddy_ipv4_gateway != null
      error_message = "caddy_ipv4_gateway must be set when caddy_ipv4_address is static."
    }
  }
}
