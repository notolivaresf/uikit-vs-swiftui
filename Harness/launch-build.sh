#!/bin/bash
# Set up and launch ONE isolated build. See docs/harness.md, "Launching a build".
#
#   Harness/launch-build.sh <opus|sol> <uikit|swiftui|objc> [--skills none|ours-slim|ours-full|ours-pair|ours-objc-pair|apple|avdlee|twostraws] [--dry-run]
#   Harness/launch-build.sh <opus|sol> <appkit-swift|appkit-objc|swiftui-mac> [--dry-run]      (Round 4, Mac)
#
# Round 4 (the three Mac stacks): the build is named round4-<stack>-<model>, the inputs come from tag
# v4-inputs with PROMPT-mac.md as the build's PROMPT.md, and no skills are loaded (the Level 2 "none" arm's
# isolation: bundled skills off for Claude, host skills off for Codex). See docs/round4-plan.md.
#
# Level 1 (no --skills, stack uikit or swiftui): exactly as before. Level 2 is chosen by giving
# --skills (even "none") or the stack objc: the build is named <model>-<stack>-<skills>, the skill
# folders are copied to .claude/skills and .agents/skills, and both models see only those skills.
# See docs/harness.md, "Level 2".
#
# --dry-run only prints what would happen: nothing is created, no model is called.
# Without it, the build folder is made and the model starts working. Fernando starts those.
set -euo pipefail

usage() { echo "usage: $0 <opus|sol> <uikit|swiftui|objc|appkit-swift|appkit-objc|swiftui-mac> [--skills none|ours-slim|ours-full|ours-pair|ours-objc-pair|apple|avdlee|twostraws] [--dry-run]" >&2; exit 2; }

MODEL="${1:-}"; SIDE="${2:-}"; shift 2 2>/dev/null || usage
DRY=0; SKILLS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --skills) shift; SKILLS="${1:-}"; [ -n "$SKILLS" ] || usage ;;
    *) usage ;;
  esac
  shift
done
case "$MODEL" in opus|sol) ;; *) usage ;; esac
case "$SIDE" in uikit|swiftui|objc|appkit-swift|appkit-objc|swiftui-mac) ;; *) usage ;; esac
R4=0
case "$SIDE" in appkit-swift|appkit-objc|swiftui-mac)
  R4=1
  [ -z "$SKILLS" ] || [ "$SKILLS" = none ] || { echo "Round 4 runs without skills (Fernando, 21 Oct)" >&2; exit 2; }
  SKILLS=none ;;
esac
if [ -n "$SKILLS" ]; then
  case "$SKILLS" in none|ours-slim|ours-full|ours-pair|ours-objc-pair|apple|avdlee|twostraws) ;; *) usage ;; esac
fi
L2=0
if [ -n "$SKILLS" ] || [ "$SIDE" = objc ] || [ "$R4" = 1 ]; then L2=1; [ -n "$SKILLS" ] || SKILLS=none; fi
case "$SKILLS" in
  ours-slim|ours-full|ours-pair) [ "$SIDE" = uikit ] || { echo "our UIKit skill goes with the stack uikit only" >&2; exit 2; } ;;
  ours-objc-pair) [ "$SIDE" = objc ] || { echo "our Objective-C skills go with the stack objc only" >&2; exit 2; } ;;
  apple) [ "$SIDE" = swiftui ] || { echo "Apple's skills (swiftui-specialist, swiftui-whats-new-27) go with the stack swiftui only" >&2; exit 2; } ;;
  twostraws) [ "$SIDE" = swiftui ] || { echo "the third-party twostraws skill (swiftui-pro) goes with the stack swiftui only" >&2; exit 2; } ;;
  avdlee) [ "$SIDE" = swiftui ] || { echo "the third-party AvdLee skill (swiftui-expert-skill) goes with the stack swiftui only" >&2; exit 2; } ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
TAG="${UVS_INPUTS_TAG:-v0-inputs}"
NAME="$MODEL-$SIDE"
LEVEL=L1
if [ "$L2" = 1 ]; then
  LEVEL=L2; NAME="$MODEL-$SIDE-$SKILLS"
  # Level 2 inputs: a tag that holds CampfireKitObjC (set UVS_INPUTS_TAG); v2-inputs when it exists
  if [ -z "${UVS_INPUTS_TAG:-}" ] && git -C "$REPO" rev-parse -q --verify "v2-inputs^{commit}" >/dev/null; then TAG="v2-inputs"; fi
fi
ROOT="${UVS_BUILDS_ROOT:-$HOME/uvs-builds}"
BUILD="$ROOT/$NAME"
CONFIG="$ROOT/$NAME-config"
RUN="$REPO/runs/$NAME"
BRANCH="build/$NAME"
PROMPT_TEXT="Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions."
INPUTS=(.gitignore LICENSE PROMPT.md Fixtures CampfireKit screenshots)
if [ "$R4" = 1 ]; then
  LEVEL=R4; NAME="round4-$SIDE-$MODEL"
  TAG="${UVS_INPUTS_TAG:-v4-inputs}"
  BUILD="$ROOT/$NAME"; CONFIG="$ROOT/$NAME-config"; RUN="$REPO/runs/$NAME"; BRANCH="build/$NAME"
  INPUTS=(.gitignore LICENSE PROMPT-mac.md Fixtures CampfireKit screenshots)
fi

SKILL_SENTENCE=""
if [ "$L2" = 1 ] && [ "$SKILLS" != none ]; then
  SKILL_SENTENCE="Agent skills are installed in this project; use any that help."
fi
if [ "$SIDE" = appkit-swift ]; then
  STACK="Stack: AppKit in Swift only, no SwiftUI"
elif [ "$SIDE" = appkit-objc ]; then
  STACK="Stack: AppKit in Objective-C only: every source file of the app target is Objective-C (no .swift files in the app target), no SwiftUI. Get the data with \`@import CampfireKitObjC;\` (the Objective-C wrapper in the CampfireKit package; link its CampfireKitObjC product) and do not modify CampfireKit or CampfireKitObjC."
elif [ "$SIDE" = swiftui-mac ]; then
  STACK="Stack: SwiftUI only: no AppKit views, no NSViewRepresentable or NSViewControllerRepresentable, no NSHostingView or NSHostingController, no reaching into AppKit views underneath"
elif [ "$SIDE" = uikit ]; then
  STACK="Stack: UIKit only, no SwiftUI"
elif [ "$SIDE" = objc ]; then
  STACK="Stack: UIKit in Objective-C only: every source file of the app target is Objective-C (no .swift files in the app target), no SwiftUI. Get the data with \`@import CampfireKitObjC;\` (the Objective-C wrapper in the CampfireKit package; link its CampfireKitObjC product) and do not modify CampfireKit or CampfireKitObjC."
else
  STACK="Stack: SwiftUI only: no UIKit views, no UIViewRepresentable or UIViewControllerRepresentable, no UIHostingController, no reaching into UIKit views underneath"
fi

if [ "$MODEL" = opus ]; then
  REQUESTED="claude-opus-5-5"; EFFORT=high
  CLI_VERSION="$(claude --version 2>/dev/null || echo unknown)"
  ENVLINE="(none: normal Claude config and login)"
  if [ "$L2" = 1 ]; then
    # --disable-slash-commands would hide our skill too. Instead: bundled skills off (setting
    # disableBundledSkills) and the three that survive that switch off by name (skillOverrides).
    # Probed 19 Oct on Claude Code 2.1.299; the run stops itself if the init event lists anything else.
    ENVLINE="(none: normal Claude config and login)"
    SETTINGS='{"autoMemoryEnabled":false,"disableBundledSkills":true,"skillOverrides":{"design":"off","doctor":"off","plugin-authoring":"off"}}'
    MODEL_CMD=(claude -p "$PROMPT_TEXT" --model "$REQUESTED" --effort "$EFFORT"
               --setting-sources project --strict-mcp-config
               --settings "$SETTINGS"
               --permission-mode bypassPermissions --output-format stream-json --verbose)
  else
    MODEL_CMD=(claude -p "$PROMPT_TEXT" --model "$REQUESTED" --effort "$EFFORT"
               --setting-sources project --strict-mcp-config --disable-slash-commands
               --settings '{"autoMemoryEnabled":false}'
               --permission-mode bypassPermissions --output-format stream-json --verbose)
  fi
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
            --effort "$EFFORT" --cli-version "$CLI_VERSION")
if [ "$L2" = 1 ]; then
  if ! SKILLSET_JSON="$(python3 -I "$HERE/skillset.py" --kind "$SKILLS")"; then
    [ "$DRY" = 1 ] || exit 1
    SKILLSET_JSON='{"expected_names":[],"skills":[]}'; echo "NOTE: skill set $SKILLS is not available yet (dry run goes on; a real launch would refuse)" >&2
  fi
  EXPECT="$(printf '%s' "$SKILLSET_JSON" | python3 -I -c 'import json,sys; print(",".join(json.load(sys.stdin)["expected_names"]))')"
  SUPERVISOR+=(--level "$LEVEL" --skillset-json "$RUN/skillset.json" --extra-json "$RUN/extra.json")
  [ "$MODEL" = opus ] && SUPERVISOR+=(--expect-skills "$EXPECT")
fi
SUPERVISOR+=(--)

if [ "$DRY" = 1 ]; then
  echo "DRY RUN: $NAME (nothing created, no model called)"
  echo "source:      $REPO @ tag $TAG ($(git -C "$REPO" rev-parse --short "$TAG^{commit}"))"
  echo "build dir:   $BUILD (new git repo, branch $BRANCH, one commit)"
  echo "contents:    ${INPUTS[*]}"
  echo "excluded:    README.md docs/ Harness/ runs/ build/ and all history"
  [ "$R4" = 1 ] && echo "PROMPT.md:   PROMPT-mac.md from the tag, saved as PROMPT.md"
  echo "PROMPT.md:   line 3 becomes: $STACK"
  if [ "$MODEL" = opus ]; then
    [ "$L2" = 1 ] || echo "isolation:   normal login kept; flags only: project settings only, no MCP, no skills, no auto memory"
  else
    [ "$L2" = 1 ] && echo "config dir:  $CONFIG (empty, then a generated config.toml: skills only)" || echo "config dir:  $CONFIG (empty; no memory, rules, config)"
    echo "auth:        only auth.json is copied from ~/.codex into the empty CODEX_HOME"
  fi
  if [ "$L2" = 1 ]; then
    echo "level:       $LEVEL, stack $SIDE, skills $SKILLS, inputs tag $TAG"
    [ -n "$SKILL_SENTENCE" ] && echo "PROMPT.md:   plus line 5: $SKILL_SENTENCE"
    echo "skill set:   $(printf '%s' "$SKILLSET_JSON" | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print("; ".join("%s %s (%s, %d files, sha256 %s)" % (s["name"], s["version"], s["source"], s["file_count"], s["hash"]) for s in r["skills"]) or "none")')"
    [ "$SKILLS" = none ] || echo "installed:   into .claude/skills and .agents/skills of the build folder, identically; kept out of git (.git/info/exclude) so Apple's text can never be committed from a build"
    if [ "$MODEL" = opus ]; then
      echo "isolation:   bundled skills off (disableBundledSkills) + design/doctor/plugin-authoring off (skillOverrides); init event must list exactly: ${EXPECT:-(no skills)}; otherwise the run stops before the first turn"
    else
      echo "codex home:  $CONFIG gets config.toml: bundled system skills off, $(python3 -I "$HERE/skillset.py" --codex-config - | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["host_skills_disabled"])') host skills under ~/.agents/skills and ~/.codex/skills off by path"
    fi
    case "$SIDE" in objc|appkit-objc) false ;; *) true ;; esac || git -C "$REPO" ls-tree -r --name-only "$TAG" | grep -c '^CampfireKit/Sources/CampfireKitObjC/' >/dev/null || echo "WARNING:     tag $TAG has no CampfireKitObjC (Objective-C builds need a newer inputs tag: set UVS_INPUTS_TAG)"
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
[ "$R4" = 1 ] && mv "$BUILD/PROMPT-mac.md" "$BUILD/PROMPT.md"
python3 -I - "$BUILD/PROMPT.md" "$STACK" "$SKILL_SENTENCE" <<'PY'
import sys
p, stack, sentence = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(p).read().split("\n")
assert lines[2].startswith("Stack: "), lines[2]
lines[2] = stack + ("\n\n" + sentence if sentence else "")
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
if [ "$L2" = 1 ]; then
  if [ "$SIDE" = objc ] || [ "$SIDE" = appkit-objc ]; then
    [ -d "$BUILD/CampfireKit/Sources/CampfireKitObjC" ] || { echo "refusing: tag $TAG has no CampfireKitObjC (set UVS_INPUTS_TAG)" >&2; exit 1; }
  fi
  # the skills stay out of git, so a build's commits never carry them
  printf '.claude/skills/\n.agents/skills/\n' >> "$BUILD/.git/info/exclude"
  python3 -I "$HERE/skillset.py" --kind "$SKILLS" --dest "$BUILD" --install > "$RUN/skillset.json"
  if [ "$MODEL" = sol ]; then
    python3 -I "$HERE/skillset.py" --codex-config "$CONFIG/config.toml" > "$RUN/codex-config.json"
  fi
  python3 -I - "$RUN/extra.json" "$SIDE" "$SKILLS" "$TAG" "$SRC" "$STACK" "$SKILL_SENTENCE" "$RUN/codex-config.json" <<'PY'
import json, os, sys
out, stack, skills, tag, src, line, sentence, cfg = sys.argv[1:]
d = dict(stack=stack, skills_arm=skills, inputs_tag=tag, inputs_commit=src, stack_line=line, skill_sentence=sentence or None)
if os.path.exists(cfg):
    d["codex_config"] = json.load(open(cfg))
json.dump(d, open(out, "w"), indent=2)
PY
fi
exec "${SUPERVISOR[@]}" "${MODEL_CMD[@]}"
