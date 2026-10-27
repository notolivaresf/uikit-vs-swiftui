#!/bin/bash
# Unpolled measurement of the E9 spike arms: no UI test attached, the app starts its own stream or jumps.
# usage: measure.sh <stream|jump> <simulator udid> <out dir> <passes> <app>...
# Each pass installs and launches every app in turn (A B C, A B C, ...) and keeps the app's own probe line.
set -u
mode="$1"; udid="$2"; out="$3"; passes="$4"; shift 4
mkdir -p "$out"
if [ "$mode" = stream ]; then flag=-uvsAutoStream; wait_s=36; else flag=-uvsAutoJump; wait_s=20; fi
for p in $(seq 1 "$passes"); do
  for app in "$@"; do
    name=$(basename "$app" .app)
    xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
    xcrun simctl install "$udid" "$app"
    log="$out/$name.$mode.$p.log"
    xcrun simctl launch --terminate-running-process --stdout="$log" --stderr="$log.err" "$udid" campfire.bench -uvsBenchmark YES "$flag" YES >/dev/null
    sleep "$wait_s"
    pid=$(xcrun simctl spawn "$udid" launchctl list | awk '/campfire.bench/ {print $1}' | head -1)
    cpu=$(ps -o cputime= -p "$pid" 2>/dev/null | tr -d ' ')
    echo "$name pass $p: $(grep -E 'STREAMCPU|JUMPMS|PROBE rowCache|MEM first' "$log" | tr '\n' ' ') | ps cputime incl. launch $cpu"
    xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
  done
done
