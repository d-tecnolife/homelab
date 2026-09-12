#!/usr/bin/env bash
# Rotate the homelab-automation API key through OPNsense's own addApiKey REST
# action, authenticated with a real GUI-style session login (the Gateway root
# console password from the attended install). The key is generated and hashed
# entirely by OPNsense's own code, the same mechanism the GUI's "+" button uses,
# and this script writes it to both encrypted inputs.
#
# This is for ROTATION, not repair. The bootstrap ISO's hand-rendered apikeys
# entry does authenticate -- the credential from the first version of
# ansible/secrets/gateway.sops.env still works today. An earlier comment here
# claimed the opposite; the 401 that prompted it came from rewriting the secret
# file alone, which cannot change the key Gateway stores in config.xml. Use this
# script whenever the key itself must change, because it changes it on the box.
#
# Must run from a host with a network route to Gateway's Infra-VLAN address
# (Ops) -- see docs/gateway-configuration.md.
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
