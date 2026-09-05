#!/usr/bin/env bash
set -euo pipefail
umask 0007

readonly data_dir=/srv/compose/minecraft/data
readonly backup_dir=/srv/backups/minecraft
readonly stamp="$(date --utc +%Y%m%dT%H%M%SZ)"
readonly archive="${backup_dir}/minecraft-${stamp}.tar.zst"

test -d "${data_dir}/Backshots Central"
install -d -m 2770 -g minecraft-data "${backup_dir}"

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
  zstd --quiet --threads=0 --long=27 -o "${archive}.partial"
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
