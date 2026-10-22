#!/bin/bash
# Score a finished Level 2 build on the simulator with the Round 3 ./bench (the full pass: 9 measures, app size,
# the 13 checks). Launches nothing and calls no model. See docs/results-l2-avdlee.md.
#
#   Harness/l2-score-setup.sh <run name> --sim a|b      e.g. opus-swiftui-avdlee, sol-swiftui-apple
#
# Makes ~/uvs-builds/score-<run name> (override the root with UVS_BUILDS_ROOT): a copy of the build's working
# folder ~/uvs-builds/<run name> as its model left it (no build output, git history or skill folders), with
# ./bench and .bench/ as round3-setup.sh makes them (no baseline, no pins: nobody edits this copy). Then:
#
#   cd ~/uvs-builds/score-<run name> && UVS_HARNESS=<repo>/Harness ./bench --direct
set -euo pipefail
usage() { echo "usage: $0 <run name> --sim a|b" >&2; exit 2; }
RUNNAME="${1:-}"; [ -n "$RUNNAME" ] || usage; shift
SIM=""
while [ $# -gt 0 ]; do case "$1" in --sim) shift; SIM="${1:-}" ;; *) usage ;; esac; shift; done
case "$SIM" in a|b) ;; *) usage ;; esac
case "$RUNNAME" in
  *-swiftui-*) SIDE=swiftui ;; *-uikit-*) SIDE=uikit ;; *-objc-*) SIDE=objc ;; *) echo "cannot tell the stack of $RUNNAME" >&2; exit 2 ;;
esac
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_FILES=(Tests record.sh summarize.py scorecard.py lockcheck.py withlock.py bench-client.py check-stack.sh)
ROOT="${UVS_BUILDS_ROOT:-$HOME/uvs-builds}"
SRC="$ROOT/$RUNNAME"; DEST="$ROOT/score-$RUNNAME"
[ -d "$SRC/Campfire.xcodeproj" ] || { echo "no finished build folder at $SRC" >&2; exit 1; }
[ -e "$DEST" ] && { echo "refusing: $DEST already exists" >&2; exit 1; }
case "$DEST" in "$HOME/olivares-burgos"*) echo "the folder must be outside ~/olivares-burgos" >&2; exit 1 ;; esac

mkdir -p "$DEST"
rsync -a --exclude='/.git' --exclude='/.claude' --exclude='/.agents' --exclude='/build' --exclude='/.build' \
  --exclude='DerivedData' --exclude='xcuserdata' --exclude='*.xcresult' --exclude='.DS_Store' --exclude='__pycache__' \
  "$SRC/" "$DEST/"
# a git repo of its own, as round3-setup.sh makes: check-stack.sh lists the app's files with git (without one it
# sees no files and passes everything)
git -C "$DEST" init -q -b "score/$RUNNAME"
printf '.claude/skills/\n.agents/skills/\n.bench/\n.bench-work/\nbench\n' >> "$DEST/.git/info/exclude"
git -C "$DEST" add -A
git -C "$DEST" -c user.name=uvs -c user.email=uvs@localhost commit -q -m "Level 2 build as its model left it"
mkdir -p "$DEST/.bench/Harness" "$DEST/.bench-work/requests"
for f in "${HARNESS_FILES[@]}"; do cp -R "$HERE/$f" "$DEST/.bench/Harness/$f"; done
echo "score-$RUNNAME" > "$DEST/.bench/name"; echo "$SIM" > "$DEST/.bench/sim"; echo "$SIDE" > "$DEST/.bench/stack"
echo "$HOME/.uvs-bench" > "$DEST/.bench/lockdir"
cp "$HERE/bench" "$DEST/bench"; chmod +x "$DEST/bench"
echo '{}' > "$DEST/.bench/pins.json"
python3 -I "$HERE/lockcheck.py" create --root "$DEST" --out "$DEST/.bench/locks.json" --pins "$DEST/.bench/pins.json"
echo "ready: cd $DEST && UVS_HARNESS=$HERE ./bench --direct"
