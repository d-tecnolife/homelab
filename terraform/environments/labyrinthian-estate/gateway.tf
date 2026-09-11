moved {
  from = proxmox_virtual_environment_vm.pfsense
  to   = proxmox_virtual_environment_vm.gateway
}

resource "proxmox_virtual_environment_vm" "gateway" {
  name        = "gateway"
  description = "OPNsense firewall and VLAN router managed by Terraform"
  tags        = ["terraform", "opnsense", "gateway", "firewall"]
  node_name   = var.node_name
  vm_id       = var.gateway_vm_id

  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 2048
  }
  vga {
    # Keep the Proxmox graphical console available for the OPNsense installer.
    type = "virtio"
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    size         = 24
  }

  cdrom {
    # A configured but empty drive is retained after the attended install. The
    # conditional boot order makes each phase explicit and Terraform-owned.
    file_id   = var.gateway_bootstrap_media_attached ? var.gateway_bootstrap_iso_file_id : "none"
    interface = "ide2"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }
  network_device {
    bridge = proxmox_network_linux_bridge.internal.name
    model  = "virtio"
    trunks = "10;20;30"
  }

  on_boot = true
  started = true
  boot_order = var.gateway_bootstrap_media_attached ? [
    "ide2",
    "virtio0",
    "net0",
    ] : [
    "virtio0",
    "ide2",
    "net0",
  ]
}
