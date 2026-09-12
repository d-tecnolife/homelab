#!/usr/bin/env bash
# One-shot recovery/bootstrap: mint a working homelab-automation API key
# through OPNsense's own addApiKey REST action, authenticated with the
# Gateway root console password (already known-good, used for the attended
# install) instead of hand-rendering apikeys XML into the bootstrap ISO.
# The hand-rendered apikeys entry never authenticated (confirmed via direct
# curl 401s against every endpoint); a key minted this way is generated and
# hashed entirely by OPNsense's real code, the same as the GUI's "+" button.
#
# Must run from a host with a network route to Gateway's Infra-VLAN address
# (Ops) -- see terraform/environments/labyrinthian-estate/opnsense/README.md.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gateway_secret_file="$repo_root/ansible/secrets/gateway.sops.env"
infra_secret_file="$repo_root/secrets/infrastructure.sops.env"
gateway_url="https://172.16.10.1"
automation_user="homelab-automation"

command -v sops >/dev/null || { echo "sops is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
[[ -f "$gateway_secret_file" ]] || { echo "missing $gateway_secret_file" >&2; exit 1; }
[[ -f "$infra_secret_file" ]] || { echo "missing $infra_secret_file" >&2; exit 1; }

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

http_status="$(sops exec-env "$gateway_secret_file" "curl -sk -o '$response_file' -w '%{http_code}' -u \"root:\$GATEWAY_ROOT_PASSWORD\" -X POST '$gateway_url/api/auth/user/addApiKey/$automation_user'")"

if [[ "$http_status" != "200" ]]; then
  echo "addApiKey request failed: HTTP $http_status" >&2
  echo "response body:" >&2
  cat "$response_file" >&2
  exit 1
fi

result="$(python3 -c "import json,sys; print(json.load(open('$response_file')).get('result','?'))")"
if [[ "$result" != "ok" ]]; then
  echo "addApiKey did not report success (result=$result)" >&2
  cat "$response_file" >&2
  exit 1
fi

new_key="$(python3 -c "import json; print(json.load(open('$response_file'))['key'])")"
new_secret="$(python3 -c "import json; print(json.load(open('$response_file'))['secret'])")"

sops set "$gateway_secret_file" '["OPNSENSE_API_KEY"]' "\"$new_key\""
sops set "$gateway_secret_file" '["OPNSENSE_API_SECRET"]' "\"$new_secret\""
sops set "$infra_secret_file" '["OPNSENSE_API_KEY"]' "\"$new_key\""
sops set "$infra_secret_file" '["OPNSENSE_API_SECRET"]' "\"$new_secret\""

unset new_key new_secret

echo "New homelab-automation API key minted via OPNsense's own addApiKey action and stored in both secret files."
