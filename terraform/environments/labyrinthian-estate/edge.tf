# Copy this file to <vm-name>.tf, replace "edge" in resource and variable
# names, then declare the matching VM-specific variables in variables.tf.

resource "proxmox_virtual_environment_vm" "edge" {
  name        = "edge"
  description = "edge VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "edge"]

  node_name = var.node_name
  vm_id     = var.edge_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.edge_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.edge_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.edge_disk_size_gb
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
        address = var.edge_ipv4_address
        gateway = var.edge_ipv4_address == "dhcp" ? null : var.edge_ipv4_gateway
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
      condition     = var.edge_ipv4_address == "dhcp" || var.edge_ipv4_gateway != null
      error_message = "edge_ipv4_gateway must be set when edge_ipv4_address is static."
    }
  }
}
