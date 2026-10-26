#!/bin/bash
# Samples one arm's main thread during the unpolled stream (seconds 4 to 24 of 30).
# usage: profile.sh <simulator udid> <out dir> <app>...
set -u
udid="$1"; out="$2"; shift 2
mkdir -p "$out"
for app in "$@"; do
  name=$(basename "$app" .app)
  xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
  xcrun simctl install "$udid" "$app"
  xcrun simctl launch --terminate-running-process --stdout="$out/$name.log" --stderr="$out/$name.err" "$udid" campfire.bench -uvsBenchmark YES -uvsAutoStream YES >/dev/null
  sleep 4
  pid=$(xcrun simctl spawn "$udid" launchctl list | awk '/campfire.bench/ {print $1}' | head -1)
  sample "$pid" 20 -mayDie -file "$out/$name.sample.txt" >/dev/null 2>&1
  sleep 12
  echo "$name sampled: $(grep STREAMCPU "$out/$name.log" | tail -1)"
  xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
done
