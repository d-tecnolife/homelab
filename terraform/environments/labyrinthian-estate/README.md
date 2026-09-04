# Labyrinthian Estate environment

This environment provisions the VLAN-aware Proxmox network, Edge router, Ops
controller, and workload VMs from the Ubuntu Resolute Cloud-Init template.

Follow the
[complete environment bootstrap](../../../docs/environment-bootstrap.md) for
the required Terraform, routing, and Ansible sequence.

## Prerequisites

- Terraform 1.5 or newer
- the template exists on the target Proxmox node (VMID `9001` by default)
- a Proxmox API token with permission to clone and manage VMs
- the Proxmox template was built with `scripts/proxmox/ubuntu-resolute-cloudinit.sh`,
  which enables `snippets` on the configured snippet datastore
- the Terraform runner's SSH agent can authenticate as `root` on Proxmox
- the SSH public key referenced by `ssh_public_key_file`

## Network layout

VLAN 10 carries `10.100.1.0/24` management workloads and VLAN 20 carries
`10.200.1.0/24` services workloads. Edge is attached to `vmbr0` for the Rogers
LAN and to both internal VLANs, where it owns `.1` as the routed gateway. Its
Edge-only Cloud-Init configuration enables IPv4 forwarding on first boot, so
the management VLAN is reachable before Ansible is running on Ops.

The initial apply authorizes the Terraform runner's public key. After the Ops
bootstrap, Terraform automatically adds the committed
`keys/ops-management.pub` key to future VM creations without placing its
private key in Terraform state.
