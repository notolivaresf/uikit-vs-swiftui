#!/bin/bash
# Usage: codex-auth-sync.sh <CODEX_HOME of a build>
# Codex refreshes its login token during a build and saves it only in that build's CODEX_HOME copy. If the copy's
# "last_refresh" is later than ~/.codex/auth.json's, copy it back so the next build does not start from a used refresh token.
# Reads only last_refresh; never prints token contents.
src="$1/auth.json"; dst="$HOME/.codex/auth.json"
[ -f "$src" ] && [ -f "$dst" ] || exit 0
newer="$(python3 -I - "$src" "$dst" <<'PY'
import json, sys
a, b = (json.load(open(p)).get("last_refresh") or "" for p in sys.argv[1:3])
print("yes" if a > b else "no")
PY
)"
if [ "$newer" = yes ]; then
  cp -p "$src" "$dst" && chmod 600 "$dst" && echo "codex auth: refreshed login copied back to ~/.codex" >&2
fi
