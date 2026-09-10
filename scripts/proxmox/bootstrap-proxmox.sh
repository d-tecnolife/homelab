#!/usr/bin/env bash

# Prepare a fresh Proxmox node for this repository. Run as root on the node.
# Public keys committed under keys/ are authorized automatically; optional
# arguments add one-time keys without copying private material to the node.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script as root on the Proxmox node." >&2
    exit 1
fi

"$repository_root/scripts/proxmox/bootstrap-terraform-access.sh" "$@"

if qm status 9001 >/dev/null 2>&1; then
    echo "VMID 9001 already exists. Refusing to replace the Cloud-Init template." >&2
    echo "Remove or deliberately rebuild that template before rerunning this script." >&2
    exit 1
fi

"$repository_root/scripts/proxmox/ubuntu-resolute-cloudinit.sh"

echo "Proxmox bootstrap complete. Save any newly issued API token in the password manager."
