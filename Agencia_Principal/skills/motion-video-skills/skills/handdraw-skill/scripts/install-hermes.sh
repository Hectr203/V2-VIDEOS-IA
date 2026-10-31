#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$HOME/.hermes/skills/video/handdraw-skill}"
if [ -e "$DEST" ]; then
  echo "Destination already exists: $DEST" >&2
  echo "Remove it or pass a different destination." >&2
  exit 1
fi
mkdir -p "$(dirname "$DEST")"
rsync -a --exclude node_modules --exclude out --exclude '.git' "$ROOT/" "$DEST/"
cd "$DEST"
npm install
npm run build
if ! python3 -m edge_tts --version >/dev/null 2>&1; then
  python3 -m venv .venv
  .venv/bin/pip install -r packages/audio/requirements.txt
fi
node scripts/check-environment.mjs
echo "Installed HandDraw Skill for Hermes at $DEST. Start a new Hermes session before use."
