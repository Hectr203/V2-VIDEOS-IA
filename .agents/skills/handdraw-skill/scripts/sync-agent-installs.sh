#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS=("$HOME/.openclaw/workspace/skills/handdraw-skill" "$HOME/.hermes/skills/video/handdraw-skill")
for target in "${TARGETS[@]}"; do
  if [ ! -d "$target" ]; then
    echo "Not installed, skipping: $target" >&2
    continue
  fi
  rsync -a --exclude node_modules --exclude out --exclude '.git' "$ROOT/" "$target/"
  echo "Synced: $target"
done
