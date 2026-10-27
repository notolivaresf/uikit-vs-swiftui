#!/bin/bash
# Builds every arm (Release, simulator) into build/out/<arm>.app.
# usage: build.sh [arm ...]   (default: all targets in project.yml)
set -eu
cd "$(dirname "$0")"
arms=("$@")
if [ ${#arms[@]} -eq 0 ]; then arms=($(awk '/^targets:/{t=1;next} t && /^  [A-Za-z0-9]+:$/{sub(":","");print $1}' project.yml)); fi
mkdir -p build/out
for arm in "${arms[@]}"; do
  xcodebuild -project E13Spike.xcodeproj -scheme "$arm" -configuration Release -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build -quiet
  ditto "build/dd/Build/Products/Release-iphonesimulator/$arm.app" "build/out/$arm.app"
  echo "built $arm"
done
