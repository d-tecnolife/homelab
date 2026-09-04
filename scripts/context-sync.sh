#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
notes_directory="$(cd "$repository_root/../notes" 2>/dev/null && pwd || true)"

if [[ -z "$notes_directory" || ! -d "$notes_directory/.git" ]]; then
  echo "missing sibling Notes checkout: $repository_root/../notes" >&2
  exit 1
fi

if [[ -n "$(git -C "$notes_directory" status --porcelain)" ]]; then
  echo "Notes checkout has local changes; refusing to pull." >&2
  exit 1
fi

git -C "$notes_directory" pull --ff-only
