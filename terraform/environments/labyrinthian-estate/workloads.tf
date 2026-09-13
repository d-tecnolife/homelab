locals {
  workload_catalog = yamldecode(file("${path.module}/../../../topology/workloads.yaml")).workloads
}

resource "proxmox_virtual_environment_vm" "workload" {
  for_each = local.workload_catalog

  depends_on  = [proxmox_virtual_environment_vm.gateway]
  name        = each.key
  description = each.value.description
  tags        = each.value.tags
  node_name   = var.node_name
  vm_id       = each.value.vm_id

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore_id
  }

  agent {
    enabled = false
  }
  cpu {
    cores = each.value.cores
    type  = "host"
  }
  memory {
    dedicated = each.value.memory_mb
  }
  vga {
    type = var.vga_type
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    file_format  = "raw"
    discard      = "on"
    size         = each.value.disk_gb
  }

  network_device {
    bridge  = proxmox_network_linux_bridge.internal.name
    model   = "virtio"
    vlan_id = each.value.vlan_id
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "scsi1"
    dns {
      servers = var.dns_servers
    }
    ip_config {
      ipv4 {
        address = each.value.address
        gateway = each.value.gateway
      }
    }
    user_account {
      username = var.vm_username
      keys     = local.workload_ssh_authorized_keys
    }
  }

  on_boot = true
  started = true

  lifecycle {
    # Cloud-init keys apply on first boot only; Ansible owns authorized_keys
    # afterwards. Proxmox derives the cloud-init instance ID from this config,
    # so changing the keys would make every guest re-run first boot and
    # regenerate its SSH host keys. New keys reach existing guests via Ansible.
    ignore_changes = [initialization[0].user_account]

    precondition {
      condition     = var.gateway_policy_ready
      error_message = "Gateway policy is not verified; refusing workload creation."
    }
  }
}
