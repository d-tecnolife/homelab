#!/usr/bin/env bash
# Rotate only the console root password in the encrypted Gateway input.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
secret_file="$repo_root/ansible/secrets/gateway.sops.env"

command -v sops >/dev/null || { echo "sops is required" >&2; exit 1; }
[[ -f "$secret_file" ]] || { echo "missing encrypted Gateway input: $secret_file" >&2; exit 1; }

read -r -s -p "New Gateway root password (stored encrypted; use a memorable unique password): " root_password
printf '\n'
[[ -n "$root_password" ]] || { echo "a Gateway root password is required" >&2; exit 1; }
[[ "$root_password" != *$'\n'* && "$root_password" != *$'\r'* && "$root_password" != *=* && "$root_password" != *\\* ]] \
    || { echo "Gateway root password cannot contain a newline, '=' or '\\'" >&2; exit 1; }

umask 077
plaintext_tmp="$(mktemp)"
encrypted_tmp="$(mktemp)"
trap 'rm -f "$plaintext_tmp" "$encrypted_tmp"' EXIT

sops --decrypt --output-type dotenv "$secret_file" > "$plaintext_tmp"
grep -q '^GATEWAY_ROOT_PASSWORD=' "$plaintext_tmp" \
    || { echo "Gateway input has no root-password entry" >&2; exit 1; }

awk -v password="$root_password" '
  /^GATEWAY_ROOT_PASSWORD=/ { print "GATEWAY_ROOT_PASSWORD=" password; next }
  { print }
' "$plaintext_tmp" \
    | sops --config "$repo_root/.sops.yaml" --filename-override "ansible/secrets/gateway.sops.env" \
        --encrypt --input-type dotenv --output-type dotenv /dev/stdin > "$encrypted_tmp"

mv "$encrypted_tmp" "$secret_file"
chmod 600 "$secret_file"
echo "Rotated the encrypted Gateway root password. Rebuild the bootstrap ISO before installing Gateway."
