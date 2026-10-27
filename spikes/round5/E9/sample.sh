#!/bin/bash
# Samples one arm's threads for 15 s in the middle of the unpolled stream (no UI test attached).
# usage: sample.sh <simulator udid> <out dir> <app>...
set -u
udid="$1"; out="$2"; shift 2
mkdir -p "$out"
for app in "$@"; do
  name=$(basename "$app" .app)
  xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
  xcrun simctl install "$udid" "$app"
  xcrun simctl launch --terminate-running-process --stdout="$out/$name.log" --stderr="$out/$name.err" "$udid" campfire.bench -uvsBenchmark YES -uvsAutoStream YES >/dev/null
  sleep 8
  pid=$(xcrun simctl spawn "$udid" launchctl list | awk '/campfire.bench/ {print $1}' | head -1)
  sample "$pid" 15 -file "$out/$name.sample.txt" >/dev/null 2>&1
  sleep 16
  echo "$name: $(grep -E 'STREAMCPU' "$out/$name.log")"
  xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
done
