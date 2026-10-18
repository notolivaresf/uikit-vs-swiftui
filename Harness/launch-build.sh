#!/bin/bash
# Set up and launch ONE isolated build. See docs/harness.md, "Launching a build".
#
#   Harness/launch-build.sh <opus|sol> <uikit|swiftui> [--dry-run]
#
# --dry-run only prints what would happen: nothing is created, no model is called.
# Without it, the build folder is made and the model starts working. Fernando starts those.
set -euo pipefail

usage() { echo "usage: $0 <opus|sol> <uikit|swiftui> [--dry-run]" >&2; exit 2; }

MODEL="${1:-}"; SIDE="${2:-}"; shift 2 2>/dev/null || usage
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    *) usage ;;
  esac
  shift
done
case "$MODEL" in opus|sol) ;; *) usage ;; esac
case "$SIDE" in uikit|swiftui) ;; *) usage ;; esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
TAG="v0-inputs"
NAME="$MODEL-$SIDE"
ROOT="${UVS_BUILDS_ROOT:-$HOME/uvs-builds}"
BUILD="$ROOT/$NAME"
CONFIG="$ROOT/$NAME-config"
RUN="$REPO/runs/$NAME"
BRANCH="build/$NAME"
PROMPT_TEXT="Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions."
INPUTS=(.gitignore LICENSE PROMPT.md Fixtures CampfireKit screenshots)

if [ "$SIDE" = uikit ]; then
  STACK="Stack: UIKit only, no SwiftUI"
else
  STACK="Stack: SwiftUI only: no UIKit views, no UIViewRepresentable or UIViewControllerRepresentable, no UIHostingController, no reaching into UIKit views underneath"
fi

if [ "$MODEL" = opus ]; then
  REQUESTED="claude-opus-5-5"; EFFORT=high
  CLI_VERSION="$(claude --version 2>/dev/null || echo unknown)"
  ENVLINE="(none: normal Claude config and login)"
  MODEL_CMD=(claude -p "$PROMPT_TEXT" --model "$REQUESTED" --effort "$EFFORT"
             --setting-sources project --strict-mcp-config --disable-slash-commands
             --settings '{"autoMemoryEnabled":false}'
             --permission-mode bypassPermissions --output-format stream-json --verbose)
else
  REQUESTED="gpt-6.1-sol"; EFFORT=high
  CLI_VERSION="$(codex --version 2>/dev/null || echo unknown)"
  ENVLINE="CODEX_HOME=$CONFIG"
  MODEL_CMD=(codex exec -m "$REQUESTED" -c "model_reasoning_effort=$EFFORT" --json
             --dangerously-bypass-approvals-and-sandbox --ignore-rules
             --skip-git-repo-check -C "$BUILD" "$PROMPT_TEXT")
fi
SUPERVISOR=(python3 -I "$HERE/run_build.py" --model "$MODEL" --side "$SIDE"
            --build-dir "$BUILD" --run-dir "$RUN" --requested-model "$REQUESTED"
            --effort "$EFFORT" --cli-version "$CLI_VERSION" --)

if [ "$DRY" = 1 ]; then
  echo "DRY RUN: $NAME (nothing created, no model called)"
  echo "source:      $REPO @ tag $TAG ($(git -C "$REPO" rev-parse --short "$TAG^{commit}"))"
  echo "build dir:   $BUILD (new git repo, branch $BRANCH, one commit)"
  echo "contents:    ${INPUTS[*]}"
  echo "excluded:    README.md docs/ Harness/ runs/ build/ and all history"
  echo "PROMPT.md:   line 3 becomes: $STACK"
  if [ "$MODEL" = opus ]; then
    echo "isolation:   normal login kept; flags only: project settings only, no MCP, no skills, no auto memory"
  else
    echo "config dir:  $CONFIG (empty; no memory, rules, config)"
    echo "auth:        only auth.json is copied from ~/.codex into the empty CODEX_HOME"
  fi
  echo "run dir:     $RUN (transcript.jsonl, stderr.log, meta.json)"
  echo "time limit:  none (runs until the model is done; Fernando, 18 Oct)"
  echo "env:         $ENVLINE"
  echo "cwd:         $BUILD"
  printf 'command:     '; printf '%q ' "${SUPERVISOR[@]}" "${MODEL_CMD[@]}"; echo
  echo "transcript:  stdout of the command, saved to $RUN/transcript.jsonl"
  echo "meta.json:   start/stop, wall_seconds, idle gaps over 20 min, turns, builds_total, builds_failed, commits, model_version"
  exit 0
fi

# ---- real launch ----
for d in "$BUILD" "$RUN"; do
  [ -e "$d" ] && { echo "refusing: $d already exists (every build starts from nothing)" >&2; exit 1; }
done
case "$BUILD" in "$HOME/olivares-burgos"*) echo "build folder must be outside ~/olivares-burgos" >&2; exit 1 ;; esac

mkdir -p "$BUILD" "$RUN"
git -C "$REPO" archive "$TAG" "${INPUTS[@]}" | tar -x -C "$BUILD"
python3 -I - "$BUILD/PROMPT.md" "$STACK" <<'PY'
import sys
p, stack = sys.argv[1], sys.argv[2]
lines = open(p).read().split("\n")
assert lines[2].startswith("Stack: "), lines[2]
lines[2] = stack
open(p, "w").write("\n".join(lines))
PY
SRC="$(git -C "$REPO" rev-parse "$TAG^{commit}")"
git -C "$BUILD" init -q -b "$BRANCH"
git -C "$BUILD" add -A
git -C "$BUILD" -c user.name=uvs -c user.email=uvs@localhost commit -q -m "Inputs from $TAG ($SRC), stack: $SIDE"

if [ "$MODEL" = sol ]; then
  [ -e "$CONFIG" ] && { echo "refusing: $CONFIG already exists" >&2; exit 1; }
  mkdir -p "$CONFIG"
  cp "$HOME/.codex/auth.json" "$CONFIG/auth.json"; chmod 600 "$CONFIG/auth.json"
  export CODEX_HOME="$CONFIG"
fi
exec "${SUPERVISOR[@]}" "${MODEL_CMD[@]}"
