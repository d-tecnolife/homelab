# Copy this file to <vm-name>.tf, replace "k3s" in resource and variable
# names, then declare the matching VM-specific variables in variables.tf.

resource "proxmox_virtual_environment_vm" "k3s" {
  name        = "k3s"
  description = "Single-node k3s VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "k3s"]

  node_name = var.node_name
  vm_id     = var.k3s_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.k3s_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.k3s_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.k3s_disk_size_gb
  }

  network_device {
    bridge  = proxmox_network_linux_bridge.internal.name
    model   = "virtio"
    vlan_id = var.management_vlan_id
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "scsi1"

    ip_config {
      ipv4 {
        address = var.k3s_ipv4_address
        gateway = var.k3s_ipv4_address == "dhcp" ? null : var.k3s_ipv4_gateway
      }
    }

    user_account {
      username = var.vm_username
      keys     = local.vm_ssh_authorized_keys
    }
  }

  on_boot = false
  started = false

  lifecycle {
    precondition {
      condition     = var.k3s_ipv4_address == "dhcp" || var.k3s_ipv4_gateway != null
      error_message = "k3s_ipv4_gateway must be set when k3s_ipv4_address is static."
    }
  }
}

