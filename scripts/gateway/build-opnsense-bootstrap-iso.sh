#!/usr/bin/env bash
# Render Gateway config.xml and add it to a bootable copy of the OPNsense ISO.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
proxmox_host="${1:?usage: $0 <proxmox-host> <source-iso-file-id> <output-iso-file-name> <ssh-public-key>}"
source_id="${2:?missing source ISO file ID}"
output_name="${3:?missing output ISO filename}"
ssh_public_key="${4:?missing SSH public key path}"
secret_file="$repo_root/ansible/secrets/gateway.sops.env"

[[ "$source_id" == local:iso/* ]] || { echo "source ISO must use local:iso/<name>" >&2; exit 2; }
[[ "$output_name" =~ ^[A-Za-z0-9._-]+\.iso$ ]] || { echo "output must be a simple .iso filename" >&2; exit 2; }
[[ -f "$secret_file" ]] || { echo "missing encrypted Gateway bootstrap input: $secret_file" >&2; exit 1; }
[[ -r "$ssh_public_key" ]] || { echo "cannot read SSH public key: $ssh_public_key" >&2; exit 1; }
command -v sops >/dev/null || { echo "sops is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
command -v xmllint >/dev/null || { echo "xmllint is required" >&2; exit 1; }
if ! command -v htpasswd >/dev/null; then
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install --yes apache2-utils
fi
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install --yes python3-yaml
fi

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
config_xml="$build_dir/config.xml"
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
sops exec-env "$secret_file" "python3 '$repo_root/scripts/gateway/render-opnsense-config.py' --catalog '$repo_root/gateway/baseline.yaml' --ssh-public-key '$ssh_public_key' --output '$config_xml'"
xmllint --noout "$config_xml"

source_name="${source_id#local:iso/}"
remote_tmp="/tmp/homelab-gateway-config.xml"
remote_source="/var/lib/vz/template/iso/$source_name"
remote_output="/var/lib/vz/template/iso/$output_name"
if [[ "$proxmox_host" == "localhost" || "$proxmox_host" == "127.0.0.1" ]]; then
    if ! command -v xorriso >/dev/null; then
        sudo apt-get update
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install --yes xorriso
    fi
    test -r "$remote_source"
    install -m 0600 "$config_xml" "$remote_tmp"
    rm -f "$remote_output"
    # OPNsense 26.7 stores hidden El Torito images. Replay discards those
    # images because they are not regular ISO files; keep preserves them.
    xorriso -indev "$remote_source" -outdev "$remote_output" -boot_image any keep -map "$remote_tmp" /conf/config.xml -commit -end
    xorriso -indev "$remote_output" -find /conf/config.xml -exec lsdl
    xorriso -indev "$remote_output" -report_el_torito plain 2>&1 | grep -q "El Torito boot img"
    rm -f "$remote_tmp"
else
    scp "$config_xml" "root@$proxmox_host:$remote_tmp"
    ssh "root@$proxmox_host" "command -v xorriso >/dev/null && test -r '$remote_source' && rm -f '$remote_output' && xorriso -indev '$remote_source' -outdev '$remote_output' -boot_image any keep -map '$remote_tmp' /conf/config.xml -commit -end && xorriso -indev '$remote_output' -find /conf/config.xml -exec lsdl && xorriso -indev '$remote_output' -report_el_torito plain 2>&1 | grep -q 'El Torito boot img' && rm -f '$remote_tmp'"
fi
printf 'gateway_bootstrap_iso_file_id = "local:iso/%s"\n' "$output_name"
