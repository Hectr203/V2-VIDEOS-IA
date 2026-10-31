#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v openclaw >/dev/null 2>&1 || { echo "OpenClaw CLI is required." >&2; exit 1; }
openclaw skills install "$ROOT" --as handdraw-skill
echo "Installed HandDraw Skill for OpenClaw. Start a new agent session before use."
