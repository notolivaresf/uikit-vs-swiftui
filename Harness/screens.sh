#!/bin/bash
# Takes the by-eye comparison screenshots of one build on the iPhone and exports them as PNG files.
#
#   Harness/screens.sh --build <name> --app-path <Release .app>
#
# Output: runs/screens/<build>/<state>-<light|dark>.png (states: room-bottom, room-top, jump-2500, context-menu)
# and runs/screens/<build>/Screenshots.xcresult. Run through the build queue, one build at a time:
#   buildslot run --label "uvs: screenshots <build>" -- Harness/screens.sh --build <name> --app-path <.app>
# Refuses an existing output folder. Does not use record.sh; builds the tests into build/DDH like it does.
set -u
build=""; app_path=""
device_core="73FC3857-7993-59CC-8A8E-34FB2E08AE71"
device_udid="00008101-00062D410CE9003A"
while [ $# -gt 0 ]; do
  case "$1" in
    --build) build="$2"; shift 2;;
    --app-path) app_path="$2"; shift 2;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
if [ -z "$build" ] || [ ! -d "$app_path" ]; then echo "usage: screens.sh --build <name> --app-path <.app>" >&2; exit 2; fi
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
out="$repo/runs/screens/$build"
if [ -e "$out" ]; then echo "refusing: $out already exists" >&2; exit 2; fi
mkdir -p "$out"
derived="$repo/build/DDH"
# App Store Connect key: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, from the untracked Harness/local.env when present.
[ -f "$(dirname "$0")/local.env" ] && . "$(dirname "$0")/local.env"
auth=(-allowProvisioningUpdates)
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  auth+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

xcodebuild build-for-testing -project "$here/CampfireBench.xcodeproj" -scheme CampfireBench \
  -destination "id=$device_udid" -derivedDataPath "$derived" "${auth[@]}" >"$out/build.log" 2>&1 || { echo "build-for-testing failed ($out/build.log)" >&2; exit 1; }
xctestrun="$(ls -t "$derived"/Build/Products/*.xctestrun | head -1)"
xcrun devicectl device install app --device "$device_core" "$app_path" >"$out/install.log" 2>&1 || { echo "install failed ($out/install.log)" >&2; exit 1; }
xcodebuild test-without-building -xctestrun "$xctestrun" -destination "id=$device_udid" \
  -only-testing:CampfireBenchUITests/Screenshots -resultBundlePath "$out/Screenshots.xcresult" >"$out/test.log" 2>&1 || { echo "test failed ($out/test.log)" >&2; exit 1; }
xcrun xcresulttool export attachments --path "$out/Screenshots.xcresult" --output-path "$out/raw" >"$out/export.log" 2>&1 || { echo "export failed ($out/export.log)" >&2; exit 1; }
python3 "$here/screens_export.py" "$out/raw" "$out"
