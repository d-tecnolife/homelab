# Copy this file to <vm-name>.tf, replace "dev" in resource and variable
# names, then declare the matching VM-specific variables in variables.tf.

resource "proxmox_virtual_environment_vm" "dev" {
  depends_on = [proxmox_virtual_environment_vm.edge]

  name        = "dev"
  description = "On-demand development VM managed by Terraform"
  tags        = ["terraform", "ubuntu", "dev"]

  node_name = var.node_name
  vm_id     = var.dev_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.dev_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.dev_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.dev_disk_size_gb
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
        address = var.dev_ipv4_address
        gateway = var.dev_ipv4_address == "dhcp" ? null : var.dev_ipv4_gateway
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
      condition     = var.dev_ipv4_address == "dhcp" || var.dev_ipv4_gateway != null
      error_message = "dev_ipv4_gateway must be set when dev_ipv4_address is static."
    }
  }
}

