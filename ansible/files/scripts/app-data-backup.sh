#!/usr/bin/env bash
# Nightly offsite backup of the Apps data a rebuild cannot recreate. Each
# service is captured consistently into a staging directory, which restic then
# sends to the encrypted offsite repository. Prometheus reads the outcome
# through the node exporter textfile collector.
set -euo pipefail
umask 0077

readonly env_file=/etc/homelab-backup/restic.env
readonly compose_root=/srv/compose
readonly staging=/var/backups/homelab-app-data
readonly metrics_dir=/var/lib/prometheus/node-exporter

set -a
# shellcheck disable=SC1090
. "${env_file}"
set +a
# Cloudflare R2 accepts any region name but requires one to be sent.
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
export RESTIC_CACHE_DIR=/var/cache/restic

publish_metric() { # name value
  local file="${metrics_dir}/homelab_backup_$1.prom"
  printf 'homelab_backup_%s %s\n' "$1" "$2" >"${file}.tmp"
  chmod 0644 "${file}.tmp"
  mv -- "${file}.tmp" "${file}"
}

succeeded=0
finish() {
  publish_metric last_run_success "${succeeded}"
  publish_metric last_run_timestamp_seconds "$(date +%s)"
  rm -rf -- "${staging}"
}
trap finish EXIT

# Copies a data directory, replacing each live SQLite database with an online
# backup so a write in progress cannot leave a torn copy.
capture_directory() { # source destination
  local source=$1 destination=$2 database
  install -d "${destination}"
  tar --create --directory="${source}" \
    --exclude='*-wal' --exclude='*-shm' --exclude='*-journal' \
    --exclude='./tmp' --exclude='./icon_cache' --file=- . |
    tar --extract --directory="${destination}" --file=-
  while IFS= read -r -d '' database; do
    rm -f -- "${destination}/${database}"
    sqlite3 "${source}/${database}" ".backup '${destination}/${database}'"
  done < <(
    cd "${source}" &&
      find . -type f -size +0 \
        -exec sh -c 'head -c 15 "$1" | grep -q "SQLite format 3"' _ {} \; -print0
  )
}

rm -rf -- "${staging}"
install -d -m 0700 "${staging}"

capture_directory "${compose_root}/vaultwarden/data" "${staging}/vaultwarden"
capture_directory "${compose_root}/job-ops/data" "${staging}/job-ops"

install -d "${staging}/authentik"
docker exec authentik-postgresql \
  pg_dump --username=authentik --dbname=authentik --format=custom \
  >"${staging}/authentik/authentik.pgdump"
for directory in media custom-templates; do
  capture_directory "${compose_root}/authentik/${directory}" "${staging}/authentik/${directory}"
done

# Vault's raft files are unsafe to copy while it runs, and restarting it seals
# it, so it is captured only through a snapshot token once one is configured.
if [[ -n "${VAULT_SNAPSHOT_TOKEN:-}" ]]; then
  install -d "${staging}/vault"
  VAULT_TOKEN="${VAULT_SNAPSHOT_TOKEN}" docker exec \
    --env VAULT_ADDR=http://127.0.0.1:8200 --env VAULT_TOKEN vault \
    sh -c 'vault token renew >/dev/null && vault operator raft snapshot save /tmp/raft.snap'
  docker cp vault:/tmp/raft.snap "${staging}/vault/raft.snap"
  docker exec vault rm -f /tmp/raft.snap
else
  echo "VAULT_SNAPSHOT_TOKEN is unset; skipping the Vault snapshot"
fi

restic cat config >/dev/null 2>&1 || restic init
restic backup --host apps --tag app-data "${staging}"
restic forget --host apps --tag app-data \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
restic check

succeeded=1
publish_metric last_success_timestamp_seconds "$(date +%s)"
echo "Backed up Apps data to ${RESTIC_REPOSITORY%%\?*}"
