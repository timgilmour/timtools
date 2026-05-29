#!/usr/bin/env bash
# Install (or refresh) the runtime copy of the skill at ~/.claude/skills/win2lin/.
# Run from anywhere; resolves the source dir from the script's own path.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills/win2lin"
mkdir -p "$(dirname "$DEST")"
rsync -a --delete \
  --exclude tests/ \
  --exclude install-to-home.sh \
  "$SRC/" "$DEST/"
echo "Installed $SRC -> $DEST"
