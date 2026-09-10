#!/usr/bin/env bash

# Run from the Ops VM's Proxmox console after the repository has been cloned.
# Ops uses a local Ansible connection; every other VM is reached with the
# Ops-generated management key.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ansible_directory="$repository_root/ansible"

if [[ ! -f "$ansible_directory/inventory/hosts.yml" ]]; then
    cp "$ansible_directory/inventory/hosts.yml.example" "$ansible_directory/inventory/hosts.yml"
    echo "Created ansible/inventory/hosts.yml from the example. Review it if this is a non-default environment."
fi

cd "$ansible_directory"
exec ansible-playbook playbooks/bootstrap-lab.yml "$@"
