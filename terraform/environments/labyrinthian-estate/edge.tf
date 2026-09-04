resource "proxmox_virtual_environment_file" "edge_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.node_name

  source_raw {
    data = join("\n", ["#cloud-config", yamlencode({
      hostname         = "edge"
      manage_etc_hosts = true
      disable_root     = true
      ssh_pwauth       = false
      users = [{
        name                = var.vm_username
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        ssh_authorized_keys = local.vm_ssh_authorized_keys
      }]
      package_update = true
      packages       = ["nftables", "qemu-guest-agent"]
      write_files = [
        {
          path        = "/etc/sysctl.d/99-edge-routing.conf"
          owner       = "root:root"
          permissions = "0644"
          content     = "# Managed by Cloud-Init; maintained later by Ansible.\nnet.ipv4.ip_forward = 1\n"
        },
        {
          path        = "/etc/nftables.conf"
          owner       = "root:root"
          permissions = "0644"
          content     = <<-EOT
            # Managed by Cloud-Init; maintained later by Ansible.
            flush ruleset

            table ip edge_nat {
              chain postrouting {
                type nat hook postrouting priority srcnat; policy accept;
                ip saddr { 10.100.1.0/24, 10.200.1.0/24 } oifname "eth0" masquerade
                iifname "wt0" oifname "eth1" ip daddr 10.100.1.0/24 masquerade
                iifname "wt0" oifname "eth2" ip daddr 10.200.1.0/24 masquerade
              }
            }
          EOT
        }
      ]
      runcmd = [
        ["sysctl", "--system"],
        ["systemctl", "enable", "--now", "nftables"],
        ["systemctl", "enable", "--now", "qemu-guest-agent"]
      ]
    })])

    file_name = "edge-cloud-config.yaml"
  }
}

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
    bridge      = var.network_bridge
    model       = "virtio"
    mac_address = var.edge_wan_mac_address
  }

  network_device {
    bridge  = proxmox_network_linux_bridge.internal.name
    model   = "virtio"
    vlan_id = var.management_vlan_id
  }

  network_device {
    bridge  = proxmox_network_linux_bridge.internal.name
    model   = "virtio"
    vlan_id = var.services_vlan_id
  }

  initialization {
    datastore_id      = var.datastore_id
    interface         = "scsi1"
    user_data_file_id = proxmox_virtual_environment_file.edge_cloud_config.id

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.edge_ipv4_address
        gateway = var.edge_ipv4_address == "dhcp" ? null : var.edge_ipv4_gateway
      }
    }

    ip_config {
      ipv4 {
        address = var.edge_management_ipv4_address
      }
    }

    ip_config {
      ipv4 {
        address = var.edge_services_ipv4_address
      }
    }
  }

  on_boot = true
  started = true

  lifecycle {
    ignore_changes = [initialization[0].user_data_file_id]

    precondition {
      condition     = var.edge_ipv4_address == "dhcp" || var.edge_ipv4_gateway != null
      error_message = "edge_ipv4_gateway must be set when edge_ipv4_address is static."
    }
  }
}
