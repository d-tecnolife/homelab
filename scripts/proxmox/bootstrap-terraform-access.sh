#!/usr/bin/env bash

set -euo pipefail

TERRAFORM_USER="${TERRAFORM_USER:-terraform@pve}"
TOKEN_ID="${TOKEN_ID:-provider}"
ROLE_ID="${ROLE_ID:-TerraformVM}"
PRIVILEGES="Datastore.Allocate Datastore.AllocateSpace Datastore.Audit SDN.Use Sys.Audit Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.PowerMgmt"
TERRAFORM_TOKEN_VALUE=""

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root on a Proxmox VE node." >&2
    exit 1
fi

command -v pveum >/dev/null || {
    echo "pveum was not found; run this script on a Proxmox VE node." >&2
    exit 1
}

if pveum user add "$TERRAFORM_USER" --comment "Terraform automation" 2>/dev/null; then
    echo "Created user $TERRAFORM_USER."
else
    # An existing user makes `user add` fail; modify also verifies it exists.
    pveum user modify "$TERRAFORM_USER" --comment "Terraform automation"
    echo "User $TERRAFORM_USER already exists."
fi

if ! pveum role modify "$ROLE_ID" --privs "$PRIVILEGES" 2>/dev/null; then
    pveum role add "$ROLE_ID" --privs "$PRIVILEGES"
fi

# Token permissions are the intersection of token and backing-user ACLs.
pveum acl modify / --user "$TERRAFORM_USER" --role "$ROLE_ID"

if pveum user token modify "$TERRAFORM_USER" "$TOKEN_ID" --privsep 1 2>/dev/null; then
    echo "Token $TERRAFORM_USER!$TOKEN_ID already exists; its secret was not changed."
else
    echo "Creating $TERRAFORM_USER!$TOKEN_ID."
    TOKEN_JSON="$(pveum user token add "$TERRAFORM_USER" "$TOKEN_ID" --privsep 1 --output-format json)"
    TOKEN_SECRET="$(printf '%s\n' "$TOKEN_JSON" | sed -n 's/.*"value"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

    if [[ -z "$TOKEN_SECRET" ]]; then
        echo "The token was created, but its secret could not be parsed. Save this output now:" >&2
        printf '%s\n' "$TOKEN_JSON" >&2
        exit 1
    fi

    TERRAFORM_TOKEN_VALUE="$TERRAFORM_USER!$TOKEN_ID=$TOKEN_SECRET"
fi

pveum acl modify / --token "$TERRAFORM_USER!$TOKEN_ID" --role "$ROLE_ID"

echo
echo "Effective token permissions:"
pveum user token permissions "$TERRAFORM_USER" "$TOKEN_ID"

echo
if [[ -n "$TERRAFORM_TOKEN_VALUE" ]]; then
    printf 'proxmox_api_token = "%s"\n' "$TERRAFORM_TOKEN_VALUE"
else
    echo "Existing token: $TERRAFORM_USER!$TOKEN_ID"
fi
