#!/bin/bash
# Heap and VM summary of one arm at the end of the unpolled stream (stream starts 1.5 s after first content, lasts 30 s).
# usage: heapdump.sh <simulator udid> <out dir> <app>...
set -u
udid="$1"; out="$2"; shift 2
mkdir -p "$out"
for app in "$@"; do
  name=$(basename "$app" .app)
  xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
  xcrun simctl install "$udid" "$app"
  xcrun simctl launch --terminate-running-process --stdout="$out/$name.log" --stderr="$out/$name.err" "$udid" campfire.bench -uvsBenchmark YES -uvsAutoStream YES >/dev/null
  sleep 35
  pid=$(xcrun simctl spawn "$udid" launchctl list | awk '/campfire.bench/ {print $1}' | head -1)
  heap -s "$pid" > "$out/$name.heap.txt" 2>&1
  vmmap --summary "$pid" > "$out/$name.vmmap.txt" 2>&1
  footprint "$pid" > "$out/$name.footprint.txt" 2>&1
  echo "$name: $(grep -E 'STREAMCPU|PROBE rowCache' "$out/$name.log" | tr '\n' ' ')"
  xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
done
