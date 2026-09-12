#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secret_file="$repository_root/secrets/infrastructure.sops.env"
component="proxmox"
action="${1:-}"

case "$action" in
  proxmox|tailscale|opnsense)
    component="$action"
    action="${2:-}"
    ;;
esac

case "$component" in
  proxmox)
    environment_directory="$repository_root/terraform/environments/labyrinthian-estate"
    ;;
  tailscale)
    environment_directory="$repository_root/terraform/environments/labyrinthian-estate/tailscale"
    ;;
  opnsense)
    environment_directory="$repository_root/terraform/environments/labyrinthian-estate/opnsense"
    ;;
esac

case "$action" in
  init|validate|plan|apply|output)
    ;;
  fmt)
    exec terraform -chdir="$environment_directory" fmt -check
    ;;
  *)
    echo "usage: $0 [proxmox|tailscale|opnsense] {init|fmt|validate|plan|apply|output}" >&2
    exit 2
    ;;
esac

if [[ ! -f "$secret_file" ]]; then
  echo "missing encrypted Terraform secrets: $secret_file" >&2
  exit 1
fi

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
exec sops exec-env "$secret_file" "terraform -chdir=$environment_directory $action"
