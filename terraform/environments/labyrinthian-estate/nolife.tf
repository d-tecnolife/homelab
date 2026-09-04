resource "proxmox_virtual_environment_vm" "nolife" {
  depends_on = [proxmox_virtual_environment_vm.edge]

  name        = "nolife"
  description = "Always-on development VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "nolife"]

  node_name = var.node_name
  vm_id     = var.nolife_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.nolife_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.nolife_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.nolife_disk_size_gb
  }

  network_device {
    bridge  = proxmox_network_linux_bridge.internal.name
    model   = "virtio"
    vlan_id = var.management_vlan_id
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "scsi1"

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.nolife_ipv4_address
        gateway = var.nolife_ipv4_address == "dhcp" ? null : var.nolife_ipv4_gateway
      }
    }

    user_account {
      username = var.vm_username
      keys     = local.vm_ssh_authorized_keys
    }
  }

  on_boot = true
  started = true

  lifecycle {
    precondition {
      condition     = var.nolife_ipv4_address == "dhcp" || var.nolife_ipv4_gateway != null
      error_message = "nolife_ipv4_gateway must be set when nolife_ipv4_address is static."
    }
  }
}

