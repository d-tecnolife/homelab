# Copy this file to <vm-name>.tf, replace "ops" in resource and variable
# names, then declare the matching VM-specific variables in variables.tf.

resource "proxmox_virtual_environment_file" "ops_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.node_name

  source_raw {
    data = join("\n", ["#cloud-config", yamlencode({
      hostname         = "ops"
      manage_etc_hosts = true
      disable_root     = true
      ssh_pwauth       = false
      users = [{
        name                = var.vm_username
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        ssh_authorized_keys = [trimspace(file(pathexpand(var.ssh_public_key_file)))]
      }]
      package_update = true
      packages       = ["ansible-core", "git", "qemu-guest-agent"]
      runcmd = [
        ["systemctl", "enable", "--now", "qemu-guest-agent"]
      ]
    })])

    file_name = "ops-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "ops" {
  depends_on = [proxmox_virtual_environment_vm.edge]

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
    bridge  = proxmox_network_linux_bridge.internal.name
    model   = "virtio"
    vlan_id = var.management_vlan_id
  }

  initialization {
    datastore_id      = var.datastore_id
    interface         = "scsi1"
    user_data_file_id = proxmox_virtual_environment_file.ops_cloud_config.id

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.ops_ipv4_address
        gateway = var.ops_ipv4_address == "dhcp" ? null : var.ops_ipv4_gateway
      }
    }

  }

  on_boot = true
  started = true

  lifecycle {
    ignore_changes = [initialization[0].user_data_file_id]

    precondition {
      condition     = var.ops_ipv4_address == "dhcp" || var.ops_ipv4_gateway != null
      error_message = "ops_ipv4_gateway must be set when ops_ipv4_address is static."
    }
  }
}
