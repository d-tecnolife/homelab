resource "proxmox_network_linux_bridge" "internal" {
  node_name = var.node_name
  name      = var.internal_network_bridge
  comment   = "Terraform-managed internal VLAN bridge"

  vlan_aware = true
  vids       = "${var.management_vlan_id} ${var.services_vlan_id}"
}
