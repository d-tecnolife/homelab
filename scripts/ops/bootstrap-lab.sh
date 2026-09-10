#!/usr/bin/env bash

# Run from the Ops VM's Proxmox console after the repository has been cloned.
# Ops uses a local Ansible connection; every other VM is reached with the
# Ops-generated management key.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ansible_directory="$repository_root/ansible"

if ! command -v ansible-playbook >/dev/null 2>&1; then
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "Ansible is not installed and this bootstrap supports Ubuntu/Debian apt hosts only." >&2
        exit 1
    fi

    echo "Installing Ansible for the first bootstrap run..."
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install --yes ansible-core
fi

if [[ ! -f "$ansible_directory/inventory/hosts.yml" ]]; then
    cp "$ansible_directory/inventory/hosts.yml.example" "$ansible_directory/inventory/hosts.yml"
    echo "Created ansible/inventory/hosts.yml from the example. Review it if this is a non-default environment."
fi

cd "$ansible_directory"
bootstrap_key_file="$HOME/.ssh/id_ed25519_bootstrap"

if [[ ! -r "$bootstrap_key_file" ]]; then
    echo "Missing the first-run Ops bootstrap key at $bootstrap_key_file." >&2
    echo "Recreate Ops through Terraform before running this script." >&2
    exit 1
fi

ansible-playbook playbooks/bootstrap-ssh-host-keys.yml "$@"
ansible-playbook \
    -e "ansible_ssh_private_key_file=$bootstrap_key_file" \
    playbooks/bootstrap-ops-ssh.yml "$@"
exec ansible-playbook playbooks/bootstrap-lab.yml "$@"
