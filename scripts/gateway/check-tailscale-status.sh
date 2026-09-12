#!/usr/bin/env bash
# Diagnostic: OPNsense's plugin-specific reconfigureAction() (used
# internally by Unbound/Tailscale's own Settings API) calls a
# configd action literally named "<service> start", which left both
# unbound_enable and tailscaled_enable at "NO" in rc.conf and neither
# daemon running. The GENERIC Core\Api\ServiceController (what the
# GUI's Services page button uses) instead calls a different configd
# action, "service start", parameterized with the service name -- test
# whether that one actually starts things properly.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
secret_file="$repo_root/secrets/infrastructure.sops.env"
gateway_url="https://172.16.10.1"

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

echo "--- generic core service start: unbound ---"
sops exec-env "$secret_file" 'curl -sk -u "$OPNSENSE_API_KEY:$OPNSENSE_API_SECRET" -X POST "'"$gateway_url"'/api/core/service/start/unbound"'
echo
echo "--- generic core service start: tailscaled ---"
sops exec-env "$secret_file" 'curl -sk -u "$OPNSENSE_API_KEY:$OPNSENSE_API_SECRET" -X POST "'"$gateway_url"'/api/core/service/start/tailscaled"'
echo
