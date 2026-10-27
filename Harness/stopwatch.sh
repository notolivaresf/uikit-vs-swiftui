#!/bin/bash
# The common stopwatch (Round 5, 27 Oct): times jump, load older and both text size rows the same way for every
# build, from the touch to the first frame that shows the result, by nothing the app's code can change.
#
#   Harness/stopwatch.sh --sim <udid> --app-path <Release simulator .app> --out <new folder> [--tests a,b,c]
#
# For each timed test (testJumpTo2500, testLoadOlder, testTextSizeAtBottom, testTextSizeMidScroll) it records the
# simulator's screen (simctl io recordVideo) while the unchanged XCUITest plays the test, with the harness's touch
# marker (stopwatch/UVSStopwatch.m) injected into the app. Harness/stopwatch.py then reads the video frame by frame:
# the touch is the frame where the marker's code changes, the result the first frame where the rest of the screen
# (debug bar buttons and status bar left out) already shows the picture it settles on. The app's own `ms` from the
# same taps is kept next to it as the app-reported value.
#
# Output: <out>/<test>.mp4 (kept local, ignored by git), <test>.touches.log, <test>.test.log, stopwatch.json.
# Run it through the build queue: buildslot run --label "uvs: stopwatch" -- Harness/stopwatch.sh ...
set -u
sim=""; app_path=""; out=""; app="campfire.bench"
tests="testJumpTo2500,testLoadOlder,testTextSizeAtBottom,testTextSizeMidScroll"
while [ $# -gt 0 ]; do
  case "$1" in
    --sim) sim="$2"; shift 2;;
    --app-path) app_path="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --tests) tests="$2"; shift 2;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
if [ -z "$sim" ] || [ -z "$app_path" ] || [ -z "$out" ]; then
  echo "usage: stopwatch.sh --sim <udid> --app-path <.app> --out <folder>" >&2; exit 2
fi
[ -d "$app_path" ] || { echo "no app at $app_path" >&2; exit 2; }
[ -e "$out" ] && { echo "refusing: $out already exists" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
failed=0
fail() { echo "FAILED: $1" | tee -a "$out/failures.txt" >&2; failed=1; }

dylib="$("$here/stopwatch/build.sh" 2>"$out/dylib.log")" || { fail "dylib build (dylib.log)"; exit 1; }

# The test bundle: the same one record.sh builds and reuses (same stamp).
derived="$repo/build/DDH"
dest="platform=iOS Simulator,id=$sim"
stamp="$(find "$here/Tests" "$here/CampfireBench.xcodeproj" -type f -not -path '*/xcuserdata/*' | sort | xargs shasum | shasum | cut -d' ' -f1)-$dest"
if [ "$(cat "$derived/.tests-stamp" 2>/dev/null)" = "$stamp" ] && ls "$derived"/Build/Products/*.xctestrun >/dev/null 2>&1; then
  echo "test bundle unchanged, reused" >"$out/build.log"
else
  xcodebuild build-for-testing -project "$here/CampfireBench.xcodeproj" -scheme CampfireBench \
    -destination "$dest" -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO >"$out/build.log" 2>&1 \
    || { fail "build-for-testing (build.log)"; exit 1; }
  echo "$stamp" >"$derived/.tests-stamp"
fi
xctestrun="$(ls -t "$derived"/Build/Products/*.xctestrun | head -1)"

xcrun simctl terminate "$sim" "$app" >/dev/null 2>&1
xcrun simctl install "$sim" "$app_path" >"$out/install.log" 2>&1 || { fail "install (install.log)"; exit 1; }
cp "$app_path/Info.plist" "$out/app-Info.plist" 2>/dev/null

export TEST_RUNNER_UVS_FAST=1
export TEST_RUNNER_UVS_STOPWATCH_DYLIB="$dylib"
for t in ${tests//,/ }; do
  case "$t" in testTextSize*) suite=StressBenchmarks;; *) suite=ChatBenchmarks;; esac
  export TEST_RUNNER_UVS_STOPWATCH_LOG="$out/$t.touches.log"
  xcrun simctl terminate "$sim" "$app" >/dev/null 2>&1
  xcrun simctl io "$sim" recordVideo --codec=h264 --force "$out/$t.mp4" >"$out/$t.video.log" 2>&1 &
  vpid=$!
  n=0
  until grep -q "Recording started" "$out/$t.video.log" 2>/dev/null; do
    if ! kill -0 "$vpid" 2>/dev/null || [ $n -ge 60 ]; then break; fi
    sleep 0.5; n=$((n + 1))
  done
  grep -q "Recording started" "$out/$t.video.log" || fail "$t: video never started ($t.video.log)"
  xcodebuild test-without-building -xctestrun "$xctestrun" -destination "$dest" \
    -only-testing:"CampfireBenchUITests/$suite/$t" >"$out/$t.test.log" 2>&1 || fail "$t test ($t.test.log)"
  kill -INT "$vpid" 2>/dev/null
  wait "$vpid"
  [ -s "$out/$t.mp4" ] || fail "$t: no video"
done
xcrun simctl terminate "$sim" "$app" >/dev/null 2>&1

python3 -I "$here/stopwatch.py" analyze --dir "$out" --out "$out/stopwatch.json" >"$out/analyze.log" 2>&1 \
  || fail "analysis (analyze.log)"
cat "$out/stopwatch.json" 2>/dev/null
[ $failed -eq 0 ] || { echo "stopwatch finished with failures" >&2; exit 1; }
echo "stopwatch finished, no failures"
