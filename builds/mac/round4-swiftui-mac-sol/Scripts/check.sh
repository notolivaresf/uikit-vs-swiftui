#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project Campfire.xcodeproj -scheme Campfire -configuration Debug -derivedDataPath build build > /tmp/campfire-check-build.log 2>&1
mkdir -p runs
objects=(build/Build/Intermediates.noindex/CampfireKit.build/Debug/CampfireKit.build/Objects-normal/arm64/*.o)
swiftc -O -parse-as-library -I build/Build/Products/Debug Campfire/Theme.swift Campfire/MessageRow.swift Campfire/RoomChrome.swift Scripts/RenderChecks.swift $objects -o build/render-checks
build/render-checks
swiftc -O -parse-as-library -I build/Build/Products/Debug Campfire/Theme.swift Campfire/MessageRow.swift Campfire/RoomChrome.swift Scripts/ReferenceChecks.swift $objects -o build/reference-checks
build/reference-checks
swiftc -O -parse-as-library -I build/Build/Products/Debug Campfire/RoomStore.swift Campfire/RoomScroll.swift Scripts/BehaviorChecks.swift $objects -o build/behavior-checks
build/behavior-checks
