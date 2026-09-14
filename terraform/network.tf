resource "proxmox_network_linux_bridge" "internal" {
  node_name = var.node_name
  name      = var.internal_network_bridge
  comment   = "Terraform-managed VLAN 10/20/30 trunk"

  vlan_aware = true
  vids       = "${var.infra_vlan_id} ${var.internal_vlan_id} ${var.dmz_vlan_id}"
}
