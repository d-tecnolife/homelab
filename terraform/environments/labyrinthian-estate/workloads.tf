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
    precondition {
      condition     = var.gateway_policy_ready
      error_message = "Gateway policy is not verified; refusing workload creation."
    }
  }
}

moved {
  from = proxmox_virtual_environment_vm.apps
  to   = proxmox_virtual_environment_vm.workload["apps"]
}
moved {
  from = proxmox_virtual_environment_vm.door
  to   = proxmox_virtual_environment_vm.workload["door"]
}
moved {
  from = proxmox_virtual_environment_vm.games
  to   = proxmox_virtual_environment_vm.workload["games"]
}
moved {
  from = proxmox_virtual_environment_vm.gitea
  to   = proxmox_virtual_environment_vm.workload["gitea"]
}
moved {
  from = proxmox_virtual_environment_vm.k3s
  to   = proxmox_virtual_environment_vm.workload["k3s"]
}
moved {
  from = proxmox_virtual_environment_vm.monitoring
  to   = proxmox_virtual_environment_vm.workload["monitoring"]
}
moved {
  from = proxmox_virtual_environment_vm.nolife
  to   = proxmox_virtual_environment_vm.workload["nolife"]
}
