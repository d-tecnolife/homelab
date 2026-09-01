#!/usr/bin/env bash

set -euo pipefail

TERRAFORM_USER="${TERRAFORM_USER:-terraform@pve}"
TOKEN_ID="${TOKEN_ID:-provider}"
ROLE_ID="${ROLE_ID:-TerraformVM}"
PRIVILEGES="Datastore.AllocateSpace Datastore.Audit SDN.Use Sys.Audit VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.PowerMgmt"

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root on a Proxmox VE node." >&2
    exit 1
fi

command -v pveum >/dev/null || {
    echo "pveum was not found; run this script on a Proxmox VE node." >&2
    exit 1
}

if ! pveum user permissions "$TERRAFORM_USER" >/dev/null 2>&1; then
    pveum user add "$TERRAFORM_USER" --comment "Terraform automation"
fi

if ! pveum role modify "$ROLE_ID" --privs "$PRIVILEGES" 2>/dev/null; then
    pveum role add "$ROLE_ID" --privs "$PRIVILEGES"
fi

# Token permissions are the intersection of token and backing-user ACLs.
pveum acl modify / --user "$TERRAFORM_USER" --role "$ROLE_ID"

if pveum user token modify "$TERRAFORM_USER" "$TOKEN_ID" --privsep 1 2>/dev/null; then
    echo "Token $TERRAFORM_USER!$TOKEN_ID already exists; its secret was not changed."
else
    echo "Creating $TERRAFORM_USER!$TOKEN_ID. Save the displayed secret now; Proxmox shows it only once."
    pveum user token add "$TERRAFORM_USER" "$TOKEN_ID" --privsep 1
fi

pveum acl modify / --token "$TERRAFORM_USER!$TOKEN_ID" --role "$ROLE_ID"

echo
echo "Effective token permissions:"
pveum user token permissions "$TERRAFORM_USER" "$TOKEN_ID"
