resource "proxmox_virtual_environment_vm" "netbird" {
  name        = "netbird"
  description = "NetBird routing peer managed by Terraform"
  tags        = ["terraform", "ubuntu", "netbird", "network"]

  node_name = var.node_name
  vm_id     = var.netbird_vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.netbird_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.netbird_memory_mb
  }

  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = var.netbird_disk_size_gb
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
        address = var.netbird_ipv4_address
        gateway = var.netbird_ipv4_address == "dhcp" ? null : var.netbird_ipv4_gateway
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
      condition     = var.netbird_ipv4_address == "dhcp" || var.netbird_ipv4_gateway != null
      error_message = "netbird_ipv4_gateway must be set when netbird_ipv4_address is static."
    }
  }
}
