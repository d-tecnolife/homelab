#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment_directory="$repository_root/terraform/environments/labyrinthian-estate"
secret_file="$repository_root/secrets/infrastructure.sops.env"
action="${1:-}"

case "$action" in
  init|validate|plan|apply|output)
    ;;
  fmt)
    exec terraform -chdir="$environment_directory" fmt -check
    ;;
  *)
    echo "usage: $0 {init|fmt|validate|plan|apply|output}" >&2
    exit 2
    ;;
esac

if [[ ! -f "$secret_file" ]]; then
  echo "missing encrypted Terraform secrets: $secret_file" >&2
  exit 1
fi

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
exec sops exec-env "$secret_file" "terraform -chdir=$environment_directory $action"
