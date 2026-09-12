#!/usr/bin/env bash
# One-shot recovery/bootstrap: mint a working homelab-automation API key
# through OPNsense's own addApiKey REST action, authenticated with a real
# GUI-style session login (the Gateway root console password, already
# known-good from the attended install) instead of hand-rendering apikeys
# XML into the bootstrap ISO. The hand-rendered apikeys entry never
# authenticated (confirmed 401 on every endpoint via direct curl); a key
# minted this way is generated and hashed entirely by OPNsense's real code,
# the same mechanism the GUI's "+" button uses.
#
# Must run from a host with a network route to Gateway's Infra-VLAN address
# (Ops) -- see terraform/environments/labyrinthian-estate/opnsense/README.md.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gateway_secret_file="$repo_root/ansible/secrets/gateway.sops.env"
infra_secret_file="$repo_root/secrets/infrastructure.sops.env"

command -v sops >/dev/null || { echo "sops is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
[[ -f "$gateway_secret_file" ]] || { echo "missing $gateway_secret_file" >&2; exit 1; }
[[ -f "$infra_secret_file" ]] || { echo "missing $infra_secret_file" >&2; exit 1; }

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

result_file="$(mktemp)"
trap 'rm -f "$result_file"' EXIT

sops exec-env "$gateway_secret_file" "python3 '$repo_root/scripts/gateway/mint_automation_api_key.py' '$result_file'"

new_key="$(python3 -c "import json; print(json.load(open('$result_file'))['key'])")"
new_secret="$(python3 -c "import json; print(json.load(open('$result_file'))['secret'])")"

sops set "$gateway_secret_file" '["OPNSENSE_API_KEY"]' "\"$new_key\""
sops set "$gateway_secret_file" '["OPNSENSE_API_SECRET"]' "\"$new_secret\""
sops set "$infra_secret_file" '["OPNSENSE_API_KEY"]' "\"$new_key\""
sops set "$infra_secret_file" '["OPNSENSE_API_SECRET"]' "\"$new_secret\""

unset new_key new_secret

echo "New homelab-automation API key minted via OPNsense's own addApiKey action and stored in both secret files."
