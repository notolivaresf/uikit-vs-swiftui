#!/bin/bash
# Copy of screens-v2-rows.sh with phases rows2 and all2 (testRowsSweep2: one older page first, smaller drags, multi-term row words). Earlier: copy of screens-v2.sh that also writes <shot>.json row frames (screens_v2_frames.py). Second round of screenshots of one build on the iPhone (ScreensV2.swift), named like screenshots/.
#
#   Harness/screens-v2-rows.sh --build <name> --app-path <Release .app> --phase base|top|rows|all [--rows <row-ids.json>]
#
# base: room-bottom (no debug bar) and room-top. rows: one row-<kind>-<id> pair per entry of row-ids.json.
# Output: runs/screens-v2/<build>/<name>.png and <name>-dark.png, <phase>.xcresult, <phase>-test.log, and
# notes-<phase>.md (labels, misses, debug bar). Run through the build queue, one phone job at a time:
#   buildslot run --label "uvs: screens <what>" -- Harness/screens-v2-rows.sh --build <name> --app-path <.app> --phase base
# Refuses an existing <phase>.xcresult. Builds the tests into build/DDH like screens.sh.
set -u
build=""; app_path=""; phase=""; rows_json=""
[ -f "$(dirname "$0")/local.env" ] && . "$(dirname "$0")/local.env"
device_core="${UVS_DEVICE_CORE:?set it in Harness/local.env}"
device_udid="${UVS_DEVICE_UDID:?set it in Harness/local.env}"
while [ $# -gt 0 ]; do
  case "$1" in
    --build) build="$2"; shift 2;;
    --app-path) app_path="$2"; shift 2;;
    --phase) phase="$2"; shift 2;;
    --rows) rows_json="$2"; shift 2;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
if [ -z "$build" ] || [ ! -d "$app_path" ]; then echo "usage: screens-v2.sh --build <name> --app-path <.app> --phase base|rows" >&2; exit 2; fi
case "$phase" in
  base) only=(-only-testing:CampfireBenchUITests/ScreensV2/testBottom -only-testing:CampfireBenchUITests/ScreensV2/testTop);;
  top) only=(-only-testing:CampfireBenchUITests/ScreensV2/testTop);;
  rows) only=(-only-testing:CampfireBenchUITests/ScreensV2/testRowsSweep2);;
  rows2) only=(-only-testing:CampfireBenchUITests/ScreensV2/testRowsSweep2);;
  all2) only=(-only-testing:CampfireBenchUITests/ScreensV2/testBottom -only-testing:CampfireBenchUITests/ScreensV2/testTop -only-testing:CampfireBenchUITests/ScreensV2/testRowsSweep2);;
  toprows) only=(-only-testing:CampfireBenchUITests/ScreensV2/testTop -only-testing:CampfireBenchUITests/ScreensV2/testRowsSweep);;
  all) only=(-only-testing:CampfireBenchUITests/ScreensV2/testBottom -only-testing:CampfireBenchUITests/ScreensV2/testTop -only-testing:CampfireBenchUITests/ScreensV2/testRowsSweep);;
  *) echo "--phase base|top|rows|all" >&2; exit 2;;
esac
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
out="$repo/runs/screens-v2/$build"
if [ -e "$out/$phase.xcresult" ]; then echo "refusing: $out/$phase.xcresult already exists" >&2; exit 2; fi
mkdir -p "$out"
rows_spec=""
if [ "$phase" = rows ] || [ "$phase" = all ] || [ "$phase" = toprows ] || [ "$phase" = rows2 ] || [ "$phase" = all2 ]; then
  if [ ! -f "$rows_json" ]; then echo "--rows <row-ids.json> missing" >&2; exit 2; fi
  rows_spec="$(python3 "$here/screens_v2_rows.py" "$rows_json")" || { echo "could not read $rows_json" >&2; exit 2; }
  echo "rows: $rows_spec"
fi
derived="$repo/build/DDH"
# App Store Connect key: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, from the untracked Harness/local.env when present.
[ -f "$(dirname "$0")/local.env" ] && . "$(dirname "$0")/local.env"
auth=(-allowProvisioningUpdates)
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  auth+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

xcodebuild build-for-testing -project "$here/CampfireBench.xcodeproj" -scheme CampfireBench \
  -destination "id=$device_udid" -derivedDataPath "$derived" "${auth[@]}" >"$out/$phase-build.log" 2>&1 || { echo "build-for-testing failed ($out/$phase-build.log)" >&2; exit 1; }
xctestrun="$(ls -t "$derived"/Build/Products/*.xctestrun | head -1)"
xcrun devicectl device install app --device "$device_core" "$app_path" >"$out/$phase-install.log" 2>&1 || { echo "install failed ($out/$phase-install.log)" >&2; exit 1; }
status=0
TEST_RUNNER_UVS_ROWS="$rows_spec" xcodebuild test-without-building -xctestrun "$xctestrun" -destination "id=$device_udid" \
  "${only[@]}" -resultBundlePath "$out/$phase.xcresult" >"$out/$phase-test.log" 2>&1 || { echo "test failed ($out/$phase-test.log), exporting what there is" >&2; status=1; }
xcrun xcresulttool export attachments --path "$out/$phase.xcresult" --output-path "$out/raw-$phase" >"$out/$phase-export.log" 2>&1 || { echo "export failed ($out/$phase-export.log)" >&2; exit 1; }
python3 "$here/screens_v2_export.py" "$out/raw-$phase" "$out" "$out/$phase-test.log" "$out/notes-$phase.md" "$build" "$phase"
python3 "$here/screens_v2_frames.py" "$out/$phase-test.log" "$out"
exit $status
