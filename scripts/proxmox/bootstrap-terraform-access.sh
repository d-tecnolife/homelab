#!/usr/bin/env bash

set -euo pipefail

TERRAFORM_USER="${TERRAFORM_USER:-terraform@pve}"
TERRAFORM_SSH_USER="${TERRAFORM_SSH_USER:-terraform}"
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

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <terraform-runner-public-key> [additional-public-key ...]" >&2
    exit 1
fi

apt-get install -y sudo

if id "$TERRAFORM_SSH_USER" >/dev/null 2>&1; then
    echo "Linux user $TERRAFORM_SSH_USER already exists."
else
    useradd --create-home --shell /bin/bash "$TERRAFORM_SSH_USER"
    echo "Created Linux user $TERRAFORM_SSH_USER."
fi
passwd --lock "$TERRAFORM_SSH_USER" >/dev/null

SSH_HOME="$(getent passwd "$TERRAFORM_SSH_USER" | cut -d: -f6)"
install -d -m 0700 -o "$TERRAFORM_SSH_USER" -g "$TERRAFORM_SSH_USER" "$SSH_HOME/.ssh"
touch "$SSH_HOME/.ssh/authorized_keys"
chown "$TERRAFORM_SSH_USER:$TERRAFORM_SSH_USER" "$SSH_HOME/.ssh/authorized_keys"
chmod 0600 "$SSH_HOME/.ssh/authorized_keys"

for public_key_file in "$@"; do
    if [[ ! -f "$public_key_file" ]]; then
        echo "Public key file not found: $public_key_file" >&2
        exit 1
    fi
    ssh-keygen -l -f "$public_key_file" >/dev/null
    public_key="$(tr -d '\r\n' < "$public_key_file")"
    if ! grep -qxF "$public_key" "$SSH_HOME/.ssh/authorized_keys"; then
        printf '%s\n' "$public_key" >> "$SSH_HOME/.ssh/authorized_keys"
        echo "Authorized $(ssh-keygen -lf "$public_key_file") for $TERRAFORM_SSH_USER."
    fi
done

SUDOERS_FILE="/etc/sudoers.d/$TERRAFORM_SSH_USER"
SUDOERS_TEMP="$(mktemp)"
trap 'rm -f "$SUDOERS_TEMP"' EXIT
cat > "$SUDOERS_TEMP" << EOF
$TERRAFORM_SSH_USER ALL=(root) NOPASSWD: /usr/sbin/pvesm
$TERRAFORM_SSH_USER ALL=(root) NOPASSWD: /usr/sbin/qm
$TERRAFORM_SSH_USER ALL=(root) NOPASSWD: /usr/bin/tee /var/lib/vz/snippets/[a-zA-Z0-9_][a-zA-Z0-9_.-]*
EOF
visudo -cf "$SUDOERS_TEMP"
install -m 0440 -o root -g root "$SUDOERS_TEMP" "$SUDOERS_FILE"

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
if [[ -n "$TERRAFORM_TOKEN_VALUE" ]]; then
    echo "Bootstrap complete. Copy this value now; Proxmox will not show the secret again:"
    echo
    printf 'proxmox_api_token = "%s"\n' "$TERRAFORM_TOKEN_VALUE"
else
    echo "Bootstrap complete. Existing token: $TERRAFORM_USER!$TOKEN_ID"
    echo "Its secret cannot be displayed again. Use the saved value or create a replacement token."
fi
