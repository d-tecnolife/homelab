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
      bootcmd = [
        ["install", "-d", "-m", "0755", "/etc/systemd/system/getty@tty1.service.d"],
        ["install", "-d", "-m", "0755", "/etc/systemd/system/serial-getty@ttyS0.service.d"]
      ]
      users = [{
        name                = var.vm_username
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        lock_passwd         = true
        ssh_authorized_keys = local.vm_ssh_authorized_keys
      }]
      write_files = [
        {
          path        = "/home/${var.vm_username}/.ssh/id_ed25519_bootstrap"
          owner       = "${var.vm_username}:${var.vm_username}"
          permissions = "0600"
          defer       = true
          content     = tls_private_key.ops_bootstrap.private_key_openssh
        },
        {
          path        = "/etc/systemd/system/getty@tty1.service.d/homelab-bootstrap.conf"
          permissions = "0644"
          content     = <<-EOT
            [Service]
            ExecStart=
            ExecStart=-/sbin/agetty --autologin ${var.vm_username} --noclear %I $TERM
          EOT
        },
        {
          path        = "/etc/systemd/system/serial-getty@ttyS0.service.d/homelab-bootstrap.conf"
          permissions = "0644"
          content     = <<-EOT
            [Service]
            ExecStart=
            ExecStart=-/sbin/agetty --autologin ${var.vm_username} --keep-baud 115200,57600,38400 - $TERM
          EOT
        }
      ]
      package_update = true
      packages       = ["ansible-core", "git", "qemu-guest-agent"]
      runcmd = [
        ["systemctl", "daemon-reload"],
        ["systemctl", "enable", "--now", "qemu-guest-agent"],
        ["systemctl", "enable", "serial-getty@ttyS0.service"],
        ["systemctl", "restart", "serial-getty@ttyS0.service"],
        ["systemctl", "restart", "getty@tty1.service"]
      ]
    })])

    file_name = "ops-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "ops" {
  depends_on = [proxmox_virtual_environment_vm.pfsense]

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
    # Cloud-init installs the guest agent, but Terraform must not block initial
    # creation on it. The Proxmox console is the supported bootstrap path.
    enabled = false
  }

  cpu {
    cores = var.ops_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.ops_memory_mb
  }

  vga {
    # Retain noVNC as the out-of-band fallback. The serial device below and
    # Cloud-Init serial-getty service provide paste-capable xterm.js access.
    type = var.vga_type
  }

  serial_device {
    device = "socket"
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
    vlan_id = var.infra_vlan_id
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
    # Cloud-init user data is first-boot-only; apply changed bootstrap data by
    # replacing Ops rather than mutating an already initialized guest.
    ignore_changes = [initialization[0].user_data_file_id]

    precondition {
      condition     = var.ops_ipv4_address == "dhcp" || var.ops_ipv4_gateway != null
      error_message = "ops_ipv4_gateway must be set when ops_ipv4_address is static."
    }
  }
}
