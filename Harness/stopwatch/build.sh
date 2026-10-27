#!/bin/bash
# Builds the stopwatch's touch marker (UVSStopwatch.m) for the iOS simulator into build/stopwatch/libUVSStopwatch.dylib.
#   Harness/stopwatch/build.sh   prints the dylib's path
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$repo/build/stopwatch"
mkdir -p "$out"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator clang -dynamiclib -fobjc-arc -O2 \
  -target arm64-apple-ios17.0-simulator -isysroot "$sdk" \
  -framework UIKit -framework QuartzCore -framework Foundation \
  -install_name @rpath/libUVSStopwatch.dylib \
  -o "$out/libUVSStopwatch.dylib" "$here/UVSStopwatch.m"
echo "$out/libUVSStopwatch.dylib"
