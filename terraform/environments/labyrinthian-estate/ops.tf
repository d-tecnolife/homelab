# Copy this file to <vm-name>.tf, replace "ops" in resource and variable
# names, then declare the matching VM-specific variables in variables.tf.

resource "proxmox_virtual_environment_vm" "ops" {
  name        = "ops"
  description = "ops VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "ops"]

  node_name = var.node_name
  vm_id     = var.ops_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.ops_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.ops_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.ops_disk_size_gb
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
        address = var.ops_ipv4_address
        gateway = var.ops_ipv4_address == "dhcp" ? null : var.ops_ipv4_gateway
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
      condition     = var.ops_ipv4_address == "dhcp" || var.ops_ipv4_gateway != null
      error_message = "ops_ipv4_gateway must be set when ops_ipv4_address is static."
    }
  }
}
