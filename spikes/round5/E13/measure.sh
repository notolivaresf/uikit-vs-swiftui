#!/bin/bash
# Unpolled measurement of the E13 spike arms: no UI test attached; the app runs its own probe.
# usage: measure.sh <jump|older|textb|textm|stream|stream1|fling|callback> <simulator udid> <out dir> <passes> <app>...
# Each pass installs and launches every app in turn (A B C, A B C, ...) and prints the probe lines.
set -u
mode="$1"; udid="$2"; out="$3"; passes="$4"; shift 4
mkdir -p "$out"; out=$(cd "$out" && pwd)
extra=()
case "$mode" in
  jump) flag=-uvsAutoJump; wait_s=22 ;;
  older) flag=-uvsAutoOlder; wait_s=18 ;;
  textb) flag=-uvsAutoTextBottom; wait_s=20 ;;
  textm) flag=-uvsAutoTextMid; wait_s=22 ;;
  stream) flag=-uvsAutoStream; wait_s=36 ;;
  stream1) flag=-uvsAutoStream; wait_s=36; extra=(-uvsFeedRate 1) ;;
  fling) flag=-uvsAutoFling; wait_s=14 ;;
  callback) flag=-uvsAutoCallback; wait_s=8 ;;
  *) echo "unknown mode $mode"; exit 2 ;;
esac
for p in $(seq 1 "$passes"); do
  for app in "$@"; do
    name=$(basename "$app" .app)
    xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
    xcrun simctl install "$udid" "$app"
    log="$out/$name.$mode.$p.log"
    for try in 1 2 3; do
      xcrun simctl launch --terminate-running-process --stdout="$log" --stderr="$log.err" "$udid" campfire.bench -uvsBenchmark YES "$flag" YES ${extra[@]+"${extra[@]}"} >/dev/null 2>"$out/launch.err" && break
      sleep 3
    done
    sleep "$wait_s"
    echo "$name pass $p: $(grep -E 'STREAMCPU|MS |PHASES|FLING|CALLBACK|MEM first' "$log" | tr '\n' ' ')"
    xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
  done
done
