#!/bin/bash
# Unpolled text size trace: launches each app with -uvsAutoTextSize (jump to 2,500, three text size steps)
# and prints its TRACE and LABEL lines.
# usage: textsize.sh <simulator udid> <out dir> <passes> <app>...
set -u
udid="$1"; out="$2"; passes="$3"; shift 3
mkdir -p "$out"
for p in $(seq 1 "$passes"); do
  for app in "$@"; do
    name=$(basename "$app" .app)
    xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
    xcrun simctl install "$udid" "$app"
    log="$out/$name.textsize.$p.log"
    xcrun simctl launch --terminate-running-process --stdout="$log" --stderr="$log.err" "$udid" campfire.bench -uvsBenchmark YES -uvsAutoTextSize YES >/dev/null
    sleep 7
    echo "== $name pass $p"
    grep -E 'LABEL|TRACE' "$log"
    xcrun simctl terminate "$udid" campfire.bench >/dev/null 2>&1
  done
done
