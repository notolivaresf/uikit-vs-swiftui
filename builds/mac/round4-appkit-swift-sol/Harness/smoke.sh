#!/bin/zsh
set -eu
cd "${0:A:h:h}"
xcodebuild -project Campfire.xcodeproj -scheme Campfire -configuration Debug -derivedDataPath build build > /tmp/campfire-smoke-build.log 2>&1
args=(-uvsBenchmark YES -selfTest)
for option in "$@"; do
  case "$option" in
    --dark) args+=(-dark) ;;
    --timed-stream) args+=(-timedStream) ;;
    *) print -u2 "Unknown option: $option"; exit 2 ;;
  esac
done
rm -f /tmp/campfire-smoke.txt
build/Build/Products/Debug/Campfire.app/Contents/MacOS/Campfire "${args[@]}" > /tmp/campfire-smoke-run.log 2>&1
cat /tmp/campfire-smoke.txt
if rg -q '^FAIL' /tmp/campfire-smoke.txt; then exit 1; fi
