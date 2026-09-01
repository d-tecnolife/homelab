resource "proxmox_virtual_environment_vm" "core" {
  name        = "core"
  description = "Primary Docker host managed by Terraform"
  tags        = ["terraform", "ubuntu", "core"]

  node_name = var.node_name
  vm_id     = var.core_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.core_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.core_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.core_disk_size_gb
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "scsi1"

    ip_config {
      ipv4 {
        address = var.core_ipv4_address
        gateway = var.core_ipv4_address == "dhcp" ? null : var.core_ipv4_gateway
      }
    }

    user_account {
      username = var.vm_username
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_file)))]
    }
  }

  on_boot = true
  started = true

  lifecycle {
    precondition {
      condition     = var.core_ipv4_address == "dhcp" || var.core_ipv4_gateway != null
      error_message = "core_ipv4_gateway must be set when core_ipv4_address is static."
    }
  }
}
