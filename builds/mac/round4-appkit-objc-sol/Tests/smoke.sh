#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project Campfire.xcodeproj -scheme Campfire -configuration Debug -derivedDataPath build build > /tmp/campfire-build.log 2>&1
rm -f /tmp/campfire-self-tests.json
build/Build/Products/Debug/Campfire.app/Contents/MacOS/Campfire -uvsBenchmark YES -uvsSelfTest YES > /tmp/campfire-smoke.log 2>&1
python3 - <<'PY'
import json
with open('/tmp/campfire-self-tests.json') as f:
    results = json.load(f)
for result in results:
    print(('PASS' if result['passed'] else 'FAIL') + ': ' + result['test'])
assert all(result['passed'] for result in results), 'See /tmp/campfire-smoke.log'
print(f"{len(results)} checks passed")
PY
