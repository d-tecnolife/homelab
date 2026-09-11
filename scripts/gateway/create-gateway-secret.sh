#!/usr/bin/env bash
# Create the one encrypted, machine-generated credential input for Gateway.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
secret_file="$repo_root/ansible/secrets/gateway.sops.env"

command -v sops >/dev/null || { echo "sops is required" >&2; exit 1; }
command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }
[[ ! -e "$secret_file" ]] || { echo "refusing to overwrite existing encrypted input: $secret_file" >&2; exit 1; }

read -r -s -p "Gateway root password (leave blank to generate one): " root_password
printf '\n'
if [[ -z "$root_password" ]]; then
    root_password="$(openssl rand -base64 48 | tr -d '\n')"
fi
read -r -s -p "Reusable Tailscale auth key: " tailscale_auth_key
printf '\n'
[[ -n "$tailscale_auth_key" ]] || { echo "a Tailscale auth key is required" >&2; exit 1; }

api_key="$(openssl rand -base64 60 | tr -d '\n')"
api_secret="$(openssl rand -base64 60 | tr -d '\n')"
encrypted_tmp="$(mktemp)"
trap 'rm -f "$encrypted_tmp"' EXIT
umask 077
printf 'GATEWAY_ROOT_PASSWORD=%s\nOPNSENSE_URL=https://172.16.10.1\nOPNSENSE_API_KEY=%s\nOPNSENSE_API_SECRET=%s\nTAILSCALE_AUTH_KEY=%s\n' \
    "$root_password" "$api_key" "$api_secret" "$tailscale_auth_key" \
    | sops --config "$repo_root/.sops.yaml" --filename-override "ansible/secrets/gateway.sops.env" --encrypt --input-type dotenv --output-type dotenv /dev/stdin > "$encrypted_tmp"
mv "$encrypted_tmp" "$secret_file"
chmod 600 "$secret_file"
echo "Created encrypted Gateway input at $secret_file. API credentials were generated and never printed."
