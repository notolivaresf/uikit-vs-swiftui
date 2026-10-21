#!/bin/bash
# Round 3 setup: one fresh folder per build. Launches nothing and calls no model. See docs/round3-plan.md.
#
#   Harness/round3-setup.sh <build> --sim a|b [--dry-run]
#   Harness/round3-setup.sh <build> --refresh      (before a launch only: re-copy the harness, re-record the locks, refill the prompt)
#
# <build> is a Round 2 build name with or without the "round2-" prefix: uikit-swift-opus, uikit-swift-sol,
# uikit-objc-opus, uikit-objc-sol, swiftui-opus, swiftui-sol.
# Result: ~/uvs-builds/round3-<build> (override the root with UVS_BUILDS_ROOT), a copy of the Round 2 working
# folder (the final tree the agent left, without build output, git history or skill folders), a new git history of
# one commit "Round 2 build", the skills that build had in Round 2 (kept out of git), ./bench, the locked-file
# checksums (also saved outside the folder, in <root>/.locks/), and the filled-in prompt next to the folder
# (<root>/round3-<build>.prompt.md). Sol builds also get <root>/round3-<build>-config (a CODEX_HOME).
# --sim a|b picks which of the two Round 3 simulators (uvs-r3-a, uvs-r3-b: iPhone 17, iOS 26.4) this build measures
# in; the two builds of a pair take a and b. The baseline scorecard is made afterwards, with both simulators
# booted, by Harness/round3-baseline.sh <build> (it also refills the prompt).
set -euo pipefail
usage() { echo "usage: $0 <build> [--dry-run|--refresh]" >&2; exit 2; }
B="${1:-}"; DRY=0; REFRESH=0; SIM=""; [ -n "$B" ] || usage
shift
while [ $# -gt 0 ]; do
  case "$1" in --dry-run) DRY=1 ;; --refresh) REFRESH=1 ;; --sim) shift; SIM="${1:-}" ;; *) usage ;; esac
  shift
done
B="${B#round2-}"
case "$B" in
  uikit-swift-opus)  RUN=opus-uikit-ours-pair;        SIDE=uikit;   SKILLS=ours-pair;      MODEL=opus ;;
  uikit-swift-sol)   RUN=sol-uikit-ours-pair;         SIDE=uikit;   SKILLS=ours-pair;      MODEL=sol ;;
  uikit-objc-opus)   RUN=opus-objc-ours-objc-pair;    SIDE=objc;    SKILLS=ours-objc-pair; MODEL=opus ;;
  uikit-objc-sol)    RUN=sol-objc-ours-objc-pair;     SIDE=objc;    SKILLS=ours-objc-pair; MODEL=sol ;;
  swiftui-opus)      RUN=opus-swiftui-apple;          SIDE=swiftui; SKILLS=apple;          MODEL=opus ;;
  swiftui-sol)       RUN=sol-swiftui-apple;           SIDE=swiftui; SKILLS=apple;          MODEL=sol ;;
  *) usage ;;
esac
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
HARNESS_FILES=(Tests record.sh summarize.py scorecard.py lockcheck.py withlock.py bench-client.py check-stack.sh)
ROOT="${UVS_BUILDS_ROOT:-$HOME/uvs-builds}"
SRC="$ROOT/$RUN"; DEST="$ROOT/round3-$B"; CONFIG="$ROOT/round3-$B-config"
LOCKS="$ROOT/.locks/round3-$B.json"; PROMPT_OUT="$ROOT/round3-$B.prompt.md"
echo "build:   round2-$B  (run $RUN, stack $SIDE, skills $SKILLS, model $MODEL)"
echo "from:    $SRC"
echo "to:      $DEST (new git history, one commit 'Round 2 build')"
echo "locks:   $LOCKS"
echo "prompt:  $PROMPT_OUT"
[ "$MODEL" = sol ] && echo "codex:   $CONFIG"
[ $DRY -eq 1 ] && exit 0
if [ $REFRESH -eq 1 ]; then
  # Before a launch only: copies the current harness files into the existing folder and records the locks again.
  [ -d "$DEST/.bench" ] || { echo "no $DEST to refresh" >&2; exit 1; }
  for f in "${HARNESS_FILES[@]}"; do cp -R "$HERE/$f" "$DEST/.bench/Harness/"; done
  cp "$HERE/bench" "$DEST/bench"
  python3 -I "$HERE/lockcheck.py" create --root "$DEST" --out "$DEST/.bench/locks.json" --pins "$HERE/round3-pins/$B.json"
  cp "$DEST/.bench/locks.json" "$LOCKS"
  python3 -I "$HERE/round3_prompt.py" --build "$B" --folder "$DEST" --out "$PROMPT_OUT"
  echo "refreshed $DEST"; exit 0
fi
case "$SIM" in a|b) ;; *) echo "--sim a|b is required" >&2; exit 2 ;; esac
[ -d "$SRC/Campfire.xcodeproj" ] || { echo "no Round 2 working folder at $SRC" >&2; exit 1; }
for d in "$DEST" "$CONFIG" "$LOCKS" "$PROMPT_OUT"; do [ -e "$d" ] && { echo "refusing: $d already exists" >&2; exit 1; }; done
case "$DEST" in "$HOME/olivares-burgos"*) echo "the folder must be outside ~/olivares-burgos" >&2; exit 1 ;; esac

mkdir -p "$DEST" "$ROOT/.locks"
rsync -a --exclude='/.git' --exclude='/.claude' --exclude='/.agents' --exclude='/build' --exclude='/.build' \
  --exclude='DerivedData' --exclude='xcuserdata' --exclude='*.xcresult' --exclude='.DS_Store' --exclude='__pycache__' \
  "$SRC/" "$DEST/"
git -C "$DEST" init -q -b "round3/$B"
printf '.claude/skills/\n.agents/skills/\n.bench/\n.bench-work/\nbench\n' >> "$DEST/.git/info/exclude"
git -C "$DEST" add -A
git -C "$DEST" -c user.name=uvs -c user.email=uvs@localhost commit -q -m "Round 2 build"

# The skills this build had in Round 2, installed the way launch-build.sh does (hash checked against the source).
python3 -I "$HERE/skillset.py" --kind "$SKILLS" --dest "$DEST" --install > "$ROOT/round3-$B.skillset.json"

# ./bench and the harness copy (locked)
mkdir -p "$DEST/.bench/Harness" "$DEST/.bench-work/requests"
for f in "${HARNESS_FILES[@]}"; do cp -R "$HERE/$f" "$DEST/.bench/Harness/$f"; done
rm -rf "$DEST/.bench/Harness/CampfireBench.xcodeproj/xcuserdata" 2>/dev/null || true
echo "$B" > "$DEST/.bench/name"; echo "$SIM" > "$DEST/.bench/sim"; echo "$SIDE" > "$DEST/.bench/stack"; echo "$HOME/.uvs-bench" > "$DEST/.bench/lockdir"
cp "$HERE/bench" "$DEST/bench"; chmod +x "$DEST/bench" "$DEST/.bench/Harness/"*.sh "$DEST/.bench/Harness/"*.py
python3 -I "$HERE/lockcheck.py" create --root "$DEST" --out "$DEST/.bench/locks.json" --pins "$HERE/round3-pins/$B.json"
cp "$DEST/.bench/locks.json" "$LOCKS"

# the prompt, with this build's stack line and scorecard (docs/round3-baselines.json, from the baseline pass)
python3 -I "$HERE/round3_prompt.py" --build "$B" --folder "$DEST" --out "$PROMPT_OUT" || true

if [ "$MODEL" = sol ]; then
  mkdir -p "$CONFIG"
  cp "$HOME/.codex/auth.json" "$CONFIG/auth.json"; chmod 600 "$CONFIG/auth.json"
  python3 -I "$HERE/skillset.py" --codex-config "$CONFIG/config.toml" > "$ROOT/round3-$B.codex-config.json"
fi
echo "next: Harness/round3-baseline.sh $B (needs the simulators; start Harness/bench-broker.py before the agents)"
echo "done. Check: python3 -I $DEST/.bench/Harness/lockcheck.py verify --root $DEST --locks $LOCKS"
