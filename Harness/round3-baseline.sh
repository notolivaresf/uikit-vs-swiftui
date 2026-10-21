#!/bin/bash
# The baseline scorecard of one Round 3 build: ./bench in its simulator, N times (default 3), median per measure,
# with both Round 3 simulators booted (the partner's idle) so conditions match what the agent will see.
# Writes <folder>/.bench/baseline.json, records the locks again and refills the prompt.
#
#   Harness/round3-baseline.sh <build> [--runs N]
# Run it just before the pair starts. Not through the broker: it measures directly, under the same lock.
set -euo pipefail
export UVS_HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="${1:?usage: round3-baseline.sh <build> [--runs N]}"; B="${B#round2-}"; RUNS=3
[ "${2:-}" = "--runs" ] && RUNS="${3:-3}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${UVS_BUILDS_ROOT:-$HOME/uvs-builds}"; DEST="$ROOT/round3-$B"
[ -d "$DEST/.bench" ] || { echo "no $DEST: run round3-setup.sh first" >&2; exit 1; }
python3 -I "$HERE/sims.py" ensure
runs=()
for ((i = 1; i <= RUNS; i++)); do
  echo "baseline run $i of $RUNS ..."
  log="$(mktemp "${TMPDIR:-/tmp}/uvs-baseline.XXXXXX")"
  python3 -I "$DEST/.bench/Harness/bench-client.py" "$DEST" --direct | tee "$log"
  dir="$(sed -n 's/^(results kept in \(.*\))$/\1/p' "$log" | tail -1)"
  [ -f "$dir/scorecard.json" ] || { echo "run $i gave no scorecard" >&2; exit 1; }
  runs+=("$dir/scorecard.json")
done
python3 -I "$HERE/scorecard.py" --aggregate "${runs[@]}" --json "$DEST/.bench/baseline.json"
"$HERE/round3-setup.sh" "$B" --refresh
echo "baseline written: $DEST/.bench/baseline.json"
