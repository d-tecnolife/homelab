# Copy this file to <vm-name>.tf, replace "gitea" in resource and variable
# names, then declare the matching VM-specific variables in variables.tf.

resource "proxmox_virtual_environment_vm" "gitea" {
  name        = "gitea"
  description = "Gitea VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "gitea"]

  node_name = var.node_name
  vm_id     = var.gitea_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.gitea_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.gitea_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.gitea_disk_size_gb
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
        address = var.gitea_ipv4_address
        gateway = var.gitea_ipv4_address == "dhcp" ? null : var.gitea_ipv4_gateway
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
      condition     = var.gitea_ipv4_address == "dhcp" || var.gitea_ipv4_gateway != null
      error_message = "gitea_ipv4_gateway must be set when gitea_ipv4_address is static."
    }
  }
}

