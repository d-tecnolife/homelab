# Labyrinthian Estate environment

This environment provisions the VLAN-aware Proxmox network, pfSense firewall,
Ops controller, and workload VMs from the Ubuntu Resolute Cloud-Init template.

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
- the bootstrap SSH public key referenced by `ssh_public_key_file`

## Network layout

pfSense VMID `100` attaches to `vmbr0` for WAN (`192.168.1.2/24`, gateway
`192.168.1.1`) and to a tagged `vmbr1` trunk for VLANs 10, 20, and 30. pfSense
owns `172.16.10.1`, `172.16.20.1`, and `172.16.30.1` as the respective
gateways. The Ubuntu VMs use access ports on that bridge: Infra (10), Internal
(20), or DMZ (30). Caddy VMID `3010` is the DMZ web host.

Terraform creates the pfSense VM from the checked ISO but does not configure
the firewall. Complete its console installation and apply the reviewed policy
in [pfSense configuration](../../../docs/pfsense-configuration.md) before
booting dependent VMs.

The initial apply authorizes the Terraform runner's public key. Terraform also
adds every non-empty repository-root `keys/*.pub` file to each new VM. Public keys may be
committed; private keys must never enter the repository or Terraform state.
Rerun `ansible/playbooks/bootstrap-ops-ssh.yml` after adding a key so existing
VMs receive it as well.

Terraform intentionally disables Proxmox guest-agent integration during VM
creation so it never waits for cloud-init networking or the guest agent. The
template still installs the package; enable the integration later only after
verifying that the agent is running.

A fresh Ops VM uses temporary Proxmox-console auto-login for its first bootstrap
only; SSH remains key-only. The ordered Ansible bootstrap removes that override
after it completes.
