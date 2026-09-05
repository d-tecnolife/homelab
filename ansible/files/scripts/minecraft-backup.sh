#!/usr/bin/env bash
set -euo pipefail

readonly data_dir=/srv/compose/minecraft/data
readonly backup_root=/mnt/game-backups
readonly backup_dir="${backup_root}/minecraft"
readonly stamp="$(date --utc +%Y%m%dT%H%M%SZ)"
readonly archive="${backup_dir}/minecraft-${stamp}.tar.zst"

mountpoint -q "${backup_root}" || {
  echo "Refusing backup: ${backup_root} is not a separate mounted filesystem" >&2
  exit 1
}
test -d "${data_dir}/FeedTheBeast"
install -d -m 0750 "${backup_dir}"

save_enabled=false
cleanup() {
  if ${save_enabled}; then
    docker exec minecraft rcon-cli save-on >/dev/null 2>&1 || true
  fi
  test ! -e "${archive}.partial" || rm -f -- "${archive}.partial"
}
trap cleanup EXIT

docker exec minecraft rcon-cli save-off >/dev/null
save_enabled=true
docker exec minecraft rcon-cli save-all flush >/dev/null

tar --create --directory="${data_dir}" --exclude='*.lock' --file=- . |
  zstd --quiet --threads=0 --long=27 --output="${archive}.partial"
mv -- "${archive}.partial" "${archive}"
docker exec minecraft rcon-cli save-on >/dev/null
save_enabled=false

mapfile -t old_backups < <(
  find "${backup_dir}" -maxdepth 1 -type f -name 'minecraft-*.tar.zst' -printf '%T@ %p\n' |
    sort -nr |
    tail -n +6 |
    cut -d' ' -f2-
)
((${#old_backups[@]} == 0)) || rm -f -- "${old_backups[@]}"

echo "Created ${archive}; retained the five newest backups"
