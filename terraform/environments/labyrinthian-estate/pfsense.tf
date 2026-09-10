resource "proxmox_virtual_environment_vm" "pfsense" {
  name        = "pfsense"
  description = "pfSense firewall and VLAN router managed by Terraform"
  tags        = ["terraform", "pfsense", "firewall"]
  node_name   = var.node_name
  vm_id       = var.pfsense_vm_id

  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 2048
  }
  vga {
    # Keep the Proxmox graphical console available for attended pfSense setup.
    type = "virtio"
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    size         = 24
  }

  cdrom {
    file_id   = "local:iso/netgate-installer-amd64.iso"
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

  # pfSense is configured from its console; leave post-install media changes
  # to that workflow instead of reconciling them through the VM resource.
  lifecycle {
    ignore_changes = [cdrom]
  }
}
