#!/usr/bin/env bash
# Repository-only checks; no plans, playbook execution, or secret decryption.
set -euo pipefail
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

for root in terraform/environments/labyrinthian-estate{,/tailscale}; do
    terraform -chdir="$root" fmt -check
    terraform -chdir="$root" init -backend=false -input=false -lockfile=readonly -no-color
    terraform -chdir="$root" validate -no-color
done

python3 -m unittest discover -s tests -v
inventory="$(mktemp --suffix=.yml)"
trap 'rm -f "$inventory"' EXIT
python3 scripts/ops/render-inventory.py --catalog topology/workloads.yaml --output "$inventory"
cd ansible
ansible-inventory -i "$inventory" --list >/dev/null
for playbook in playbooks/*.yml; do
    ansible-playbook -i "$inventory" --syntax-check "$playbook"
done
