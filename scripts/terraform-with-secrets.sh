#!/usr/bin/env bash
set -euo pipefail

# `pwd -W` gives a native Windows path (C:/...) instead of git-bash's POSIX
# path (/c/...); terraform.exe's -chdir does not understand the latter. Real
# Unix shells don't support -W at all, so fall back to plain pwd there.
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && { pwd -W 2>/dev/null || pwd; })"
secret_file="$repository_root/secrets/infrastructure.sops.env"
component="proxmox"

case "${1:-}" in
  proxmox|tailscale)
    component="$1"
    shift
    ;;
esac

action="${1:-}"
[[ $# -eq 0 ]] || shift

case "$component" in
  proxmox)
    environment_directory="$repository_root/terraform/environments/labyrinthian-estate"
    ;;
  tailscale)
    environment_directory="$repository_root/terraform/environments/labyrinthian-estate/tailscale"
    ;;
esac

case "$action" in
  init|validate|plan|apply|output)
    ;;
  # import only writes state; it reads the remote object and never changes it.
  import)
    ;;
  fmt)
    exec terraform -chdir="$environment_directory" fmt -check
    ;;
  *)
    echo "usage: $0 [proxmox|tailscale] {init|fmt|validate|plan|apply|output|import} [args...]" >&2
    exit 2
    ;;
esac

if [[ ! -f "$secret_file" ]]; then
  echo "missing encrypted Terraform secrets: $secret_file" >&2
  exit 1
fi

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
arguments=""
for argument in "$@"; do
  arguments+=" $(printf '%q' "$argument")"
done

exec sops exec-env "$secret_file" "terraform -chdir=$environment_directory $action$arguments"
