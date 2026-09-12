#!/usr/bin/env bash
# One-off diagnostic: is the os-tailscale plugin's settings/get 404 still
# present now that Unbound is running? (Expected: yes, unrelated -- the 404
# is Gateway's own local API routing, not outbound DNS resolution -- but
# verify with real evidence instead of assuming.)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
secret_file="$repo_root/secrets/infrastructure.sops.env"
gateway_url="https://172.16.10.1"

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

echo "--- Tailscale plugin API: is the settings/get 404 still present? ---"
sops exec-env "$secret_file" 'curl -sk -i -u "$OPNSENSE_API_KEY:$OPNSENSE_API_SECRET" "'"$gateway_url"'/api/tailscale/settings/get"' | head -5
