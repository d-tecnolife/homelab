#!/usr/bin/env bash
# Diagnostic mode: dump the live login page so we can see its real form
# field names and CSRF token mechanism, since GitHub source search hasn't
# turned up a clean answer. TEMPORARY -- see git history for the real
# mint-automation-api-key.sh once the login flow is confirmed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gateway_url="https://172.16.10.1"

curl -sk -c /tmp/opnsense_cookies.txt "$gateway_url/" | grep -i -E "csrf|usernamefld|passwordfld|<form|name=\"login" -A2 -B2
echo "--- cookies received ---"
cat /tmp/opnsense_cookies.txt
