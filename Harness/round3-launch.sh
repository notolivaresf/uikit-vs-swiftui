#!/bin/bash
# Starts one Round 3 agent in its folder: sandboxed, with the 3-hour limit. Fernando starts these himself.
#   Harness/round3-launch.sh <build> [--dry-run]
# --dry-run prints the folder, settings and exact command and starts nothing. See docs/round3-plan.md.
# Needs: round3-setup.sh and round3-baseline.sh done for this build, Harness/bench-broker.py running.
set -euo pipefail
B="${1:?usage: round3-launch.sh <build> [--dry-run]}"; B="${B#round2-}"; DRY=0; [ "${2:-}" = "--dry-run" ] && DRY=1
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO="$(cd "$HERE/.." && pwd)"
ROOT="${UVS_BUILDS_ROOT:-$HOME/uvs-builds}"; DEST="$ROOT/round3-$B"; PROMPT_FILE="$ROOT/round3-$B.prompt.md"
CONFIG="$ROOT/round3-$B-config"; RUN="$REPO/runs/round3-$B"
LIMIT=10800
case "$B" in *-opus) MODEL=opus; REQUESTED=claude-opus-5-5 ;; *-sol) MODEL=sol; REQUESTED=gpt-6.1-sol ;; *) echo "unknown build $B" >&2; exit 2 ;; esac
case "$B" in uikit-swift-*) SIDE=uikit ;; uikit-objc-*) SIDE=objc ;; swiftui-*) SIDE=swiftui ;; esac
case "$B" in uikit-swift-*|swiftui-*) SKILLS_ARG=$([ "$SIDE" = uikit ] && echo uikit-specialist,uikit-whats-new-27 || echo swiftui-specialist,swiftui-whats-new-27) ;; *) SKILLS_ARG=uikit-specialist-objc,uikit-whats-new-27-objc ;; esac
[ -d "$DEST/.bench" ] && [ -f "$DEST/.bench/baseline.json" ] || { echo "run round3-setup.sh and round3-baseline.sh for $B first" >&2; exit 1; }
[ -f "$PROMPT_FILE" ] || { echo "no $PROMPT_FILE" >&2; exit 1; }
if [ $DRY -eq 0 ]; then
  [ -e "$RUN" ] && { echo "refusing: $RUN exists" >&2; exit 1; }
  python3 -I "$HERE/lockcheck.py" verify --root "$DEST" --locks "$ROOT/.locks/round3-$B.json" || exit 1
fi
START="$(date +%H:%M)"; END="$(date -v+3H +%H:%M)"
PROMPT="$(cat "$PROMPT_FILE")

Started at $START (local time). Your 3 hours end at $END; check \`date\` now and then. Write NOTES.md before then."
CACHE="$(getconf DARWIN_USER_CACHE_DIR)"; XCODE="$(dirname "$(dirname "$(xcode-select -p)")")"

if [ "$MODEL" = opus ]; then
  SETTINGS="$(python3 -I - "$DEST" "$HOME" "$XCODE" "${CACHE%/}" "$HERE/round3-guard.py" <<'PY'
import json, sys
dest, home, xcode, cache, guard = sys.argv[1:]
print(json.dumps({
  "autoMemoryEnabled": False, "disableBundledSkills": True,
  "skillOverrides": {"design": "off", "doctor": "off", "plugin-authoring": "off"},
  "sandbox": {"enabled": True, "failIfUnavailable": True, "allowUnsandboxedCommands": False,
              "filesystem": {"denyRead": [home + "/"],
                             "allowRead": [dest, home + "/Library/Developer", home + "/Library/Caches", home + "/.gitconfig"],
                             "allowWrite": [dest, home + "/Library/Caches", home + "/Library/Developer", cache]}},
  "permissions": {"blockReadsOutsideWorkingDirectories": True, "additionalDirectories": [xcode]},
  "hooks": {"PreToolUse": [{"matcher": "WebFetch|WebSearch|Bash", "hooks": [{"type": "command", "command": "python3 -I " + guard}]}]},
}))
PY
)"
  MODEL_CMD=(claude -p "$PROMPT" --model "$REQUESTED" --effort high --setting-sources project --strict-mcp-config
             --settings "$SETTINGS" --permission-mode bypassPermissions --output-format stream-json --verbose)
  ENVLINE="(normal Claude login; no CLAUDE_CONFIG_DIR)"
else
  MODEL_CMD=(codex exec -m "$REQUESTED" -c model_reasoning_effort=high --json --ignore-rules --skip-git-repo-check -C "$DEST" "$PROMPT")
  ENVLINE="CODEX_HOME=$CONFIG (config.toml: skills off by path, plus the Round 3 permission profile appended by this script)"
fi
if [ "$MODEL" = opus ]; then CLI_VERSION="$(claude --version 2>/dev/null || echo unknown)"; else CLI_VERSION="$(codex --version 2>/dev/null || echo unknown)"; fi
SUP=(python3 -I "$HERE/run_build.py" --model "$MODEL" --side "$SIDE" --level R3 --build-dir "$DEST" --run-dir "$RUN"
     --requested-model "$REQUESTED" --effort high --cli-version "$CLI_VERSION" --time-limit-s "$LIMIT"
     --skillset-json "$ROOT/round3-$B.skillset.json")
[ "$MODEL" = opus ] && SUP+=(--expect-skills "$SKILLS_ARG")
SUP+=(--)

# Codex: the permission profile (reads only inside the folder, the skills and the toolchain; writes in the folder)
PROFILE="default_permissions = \"r3\"

[features]
network_proxy = true

[permissions.r3]
extends = \":workspace\"

[permissions.r3.filesystem]
\":root\" = \"deny\"
\":minimal\" = \"read\"
\":tmpdir\" = \"write\"
\":slash_tmp\" = \"deny\"
\"$XCODE\" = \"read\"
\"$HOME/.local/bin\" = \"read\"
\"$HOME/.codex/packages\" = \"read\"
\"/Library/Developer\" = \"read\"
\"/usr\" = \"read\"
\"/opt/homebrew\" = \"read\"
\"${CACHE%/}\" = \"write\"
\"$HOME/Library/Developer\" = \"write\"
\"$HOME/Library/Caches\" = \"write\"
\"$HOME/.gitconfig\" = \"read\"
\"$DEST\" = \"write\"

[permissions.r3.network]
enabled = true

[permissions.r3.network.domains]
\"github.com\" = \"deny\"
\"raw.githubusercontent.com\" = \"deny\"
\"api.github.com\" = \"deny\"
"

if [ $DRY -eq 1 ]; then
  echo "DRY RUN: round3-$B ($MODEL, $SIDE): nothing started"
  echo "folder:   $DEST"
  echo "baseline: $(python3 -I -c 'import json,sys; b=json.load(open(sys.argv[1])); print(b["runs"], "runs;", b["checks_passed"], "of 13 checks pass")' "$DEST/.bench/baseline.json")"
  echo "limit:    $LIMIT s (3 h), run_build.py stops the model: SIGTERM, SIGKILL 30 s later; prompt says it ends at $END"
  echo "env:      $ENVLINE"
  [ "$MODEL" = opus ] && { echo "settings: $SETTINGS" | head -c 3000; echo; }
  [ "$MODEL" = sol ] && { echo "--- put at the top of $CONFIG/config.toml ---"; printf '%s\n' "$PROFILE"; }
  printf 'command:  '; printf '%q ' "${SUP[@]}" "${MODEL_CMD[@]}"; echo
  exit 0
fi
mkdir -p "$RUN"
if [ "$MODEL" = sol ]; then
  # top-level key first: appended after a table header it would land inside that table. An older profile (everything
  # before [skills.bundled]) is replaced, so a changed profile reaches folders that were set up earlier.
  python3 -I - "$CONFIG/config.toml" "$PROFILE" <<'PY'
import sys
path, profile = sys.argv[1:]
text = open(path).read()
if text.startswith("default_permissions"):
    text = text[text.index("[skills.bundled]"):]
open(path, "w").write(profile + "\n" + text)
PY
  export CODEX_HOME="$CONFIG"
fi
rc=0
"${SUP[@]}" "${MODEL_CMD[@]}" || rc=$?
[ "$MODEL" = sol ] && "$HERE/codex-auth-sync.sh" "$CONFIG"
exit "$rc"
