resource "proxmox_virtual_environment_vm" "apps" {
  name        = "apps"
  description = "Primary Docker application host managed by Terraform"
  tags        = ["terraform", "ubuntu", "apps"]

  node_name = var.node_name
  vm_id     = var.apps_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.apps_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.apps_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.apps_disk_size_gb
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
        address = var.apps_ipv4_address
        gateway = var.apps_ipv4_address == "dhcp" ? null : var.apps_ipv4_gateway
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
      condition     = var.apps_ipv4_address == "dhcp" || var.apps_ipv4_gateway != null
      error_message = "apps_ipv4_gateway must be set when apps_ipv4_address is static."
    }
  }
}
