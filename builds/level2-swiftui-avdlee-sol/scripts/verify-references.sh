#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
probe_tmp=$(mktemp -d /tmp/campfire-reference.XXXXXX)
probe_sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
mkdir -p "$probe_tmp/ReferenceProbe.app"
python3 - "$probe_tmp" <<'PY'
import pathlib, plistlib, sys
root=pathlib.Path(sys.argv[1])
s=pathlib.Path('Campfire/RoomStore.swift').read_text().split('@MainActor @Observable')[0]
(root/'RowModels.swift').write_text(s)
v=pathlib.Path('Campfire/RoomViewport.swift').read_text().split('@MainActor @Observable')[0]
(root/'ViewportModels.swift').write_text(v)
plist={'CFBundleIdentifier':'campfire.bench.reference', 'CFBundleExecutable':'ReferenceProbe', 'CFBundleName':'ReferenceProbe', 'CFBundlePackageType':'APPL', 'CFBundleVersion':'1', 'CFBundleShortVersionString':'1.0', 'MinimumOSVersion':'18.0', 'UIDeviceFamily':[1], 'UILaunchScreen':{}}
(root/'ReferenceProbe.app/Info.plist').write_bytes(plistlib.dumps(plist))
PY
xcrun --sdk iphonesimulator swiftc -O -target arm64-apple-ios18.0-simulator -sdk "$probe_sdk" \
    -module-name CampfireKit -parse-as-library \
    CampfireKit/Sources/CampfireKit/*.swift "$probe_tmp/RowModels.swift" \
    Campfire/Style.swift Campfire/MessageRow.swift Campfire/RangeSelectionOverlay.swift Campfire/RoomChrome.swift "$probe_tmp/ViewportModels.swift" \
    scripts/ReferenceProbe.swift -o "$probe_tmp/ReferenceProbe.app/ReferenceProbe"
if [ -f build/Build/Products/Release-iphonesimulator/Campfire.app/Assets.car ]; then
    cp build/Build/Products/Release-iphonesimulator/Campfire.app/Assets.car "$probe_tmp/ReferenceProbe.app/"
fi
codesign --force --sign - "$probe_tmp/ReferenceProbe.app"
xcrun simctl install booted "$probe_tmp/ReferenceProbe.app"
probe_container=$(xcrun simctl get_app_container booted campfire.bench.reference data)
rm -f "$probe_container/Documents/ReferenceRenders/heights.json"
xcrun simctl launch --terminate-running-process booted campfire.bench.reference
for probe_attempt in {1..30}; do
    if [ -f "$probe_container/Documents/ReferenceRenders/heights.json" ]; then break; fi
    sleep 1
done
mkdir -p build/reference-renders
cp "$probe_container/Documents/ReferenceRenders/"* build/reference-renders/
python3 - <<'PY'
import json, pathlib
constants=json.loads(pathlib.Path('Fixtures/constants.json').read_text())
heights=json.loads(pathlib.Path('build/reference-renders/heights.json').read_text())
for row in constants['rows']:
    actual=heights['row-'+row['name']+'.png']
    print(f"{row['name']:16} expected {row['rowHeight']:7.2f} actual {actual:7.2f} delta {actual-row['rowHeight']:+7.2f}")
PY
