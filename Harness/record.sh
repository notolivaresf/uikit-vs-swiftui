#!/bin/bash
# Records one benchmark round on a real iPhone: the XCUITest suite (5 iterations per test, numbers from the
# xcresult) plus one Instruments trace per scenario, then writes summary.json.
#
#   Harness/record.sh --build <name> --round <n> [--device <devicectl id>] [--app campfire.bench]
#
# Output: runs/<build>/<round>/{bench.xcresult, launch.trace, fling.trace, stream.trace, memory.trace, summary.json, logs/}
#
# How the traces are driven: a UI test (TraceScenarios) launches the app, waits 25 s, then plays one scenario.
# The script finds the app's process id with devicectl during that wait, attaches `xctrace` to it, and stops the
# trace when the test ends. Cold launch needs no UI: `xctrace --launch` starts the app itself.
# Needs the app already installed (Release) and the phone unlocked, with Settings > Developer > Enable UI Automation on.
# Run every step through the build queue: buildslot run --label "uvs: record" -- Harness/record.sh ...
set -u

build=""; round=""; app="campfire.bench"
device_core="73FC3857-7993-59CC-8A8E-34FB2E08AE71"   # devicectl id (iPhone 12, iOS 26.0)
device_udid="00008101-00062D410CE9003A"              # xctrace / xcodebuild id of the same phone
while [ $# -gt 0 ]; do
  case "$1" in
    --build) build="$2"; shift 2;;
    --round) round="$2"; shift 2;;
    --device) device_core="$2"; shift 2;;
    --udid) device_udid="$2"; shift 2;;
    --app) app="$2"; shift 2;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
if [ -z "$build" ] || [ -z "$round" ]; then echo "usage: record.sh --build <name> --round <n>" >&2; exit 2; fi

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
out="$repo/runs/$build/$round"
mkdir -p "$out/logs"
derived="$repo/build/DDH"

# Signing: team H8HSTBN8ZP (Amazing Humans), automatic. The App Store Connect key lets xcodebuild make the
# profile; it lives outside the repo.
auth=(-allowProvisioningUpdates
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_MYT9KLPSWK.p8"
  -authenticationKeyID MYT9KLPSWK
  -authenticationKeyIssuerID 69a6de85-b768-47e3-e053-5b8c7c11a4d1)
xcb=(xcodebuild test -project "$here/CampfireBench.xcodeproj" -scheme CampfireBench
  -destination "id=$device_udid" -derivedDataPath "$derived" "${auth[@]}")

# Process id of the app on the phone (matches the installed bundle's executable path), empty if not running.
app_pid() {
  local json="$out/logs/procs.json"
  xcrun devicectl device info processes --device "$device_core" --json-output "$json" >/dev/null 2>&1
  python3 "$here/summarize.py" pid --procs "$json" --device "$device_core" --bundle "$app"
}

# One traced scenario: test $1 of TraceScenarios, Instruments template $2, trace file $3.
trace_scenario() {
  local test="$1" template="$2" name="$3"
  local log="$out/logs/$name.test.log"
  "${xcb[@]}" -only-testing:"CampfireBenchUITests/TraceScenarios/$test" \
    -resultBundlePath "$out/logs/$name.xcresult" >"$log" 2>&1 &
  local test_pid=$!
  # Wait for the app to appear (the test launches it, then idles for the attach window). Each devicectl call
  # takes a couple of seconds, so a bounded number of tries covers the wait without sleeping.
  local pid="" tries=0
  while [ -z "$pid" ] && [ $tries -lt 60 ] && kill -0 "$test_pid" 2>/dev/null; do
    pid="$(app_pid)"; tries=$((tries + 1))
  done
  if [ -z "$pid" ]; then echo "$name: app never appeared" >&2; wait "$test_pid"; return 1; fi
  xcrun xctrace record --device "$device_udid" --template "$template" --attach "$pid" \
    --time-limit 600s --no-prompt --output "$out/$name.trace" >"$out/logs/$name.xctrace.log" 2>&1 &
  local trace_pid=$!
  wait "$test_pid"            # the test ends when its scenario ends
  kill -INT "$trace_pid" 2>/dev/null
  wait "$trace_pid"
}

# 1. The whole suite: launch, time to 40 rows, fling, jump, load older, stream (5 iterations each).
"${xcb[@]}" -only-testing:CampfireBenchUITests/ChatBenchmarks -resultBundlePath "$out/bench.xcresult" \
  >"$out/logs/suite.log" 2>&1
echo "suite finished (exit $?)"

# 2. Cold launch trace: Instruments starts the app itself.
xcrun xctrace record --device "$device_udid" --template "App Launch" --time-limit 12s --no-prompt \
  --output "$out/launch.trace" --launch -- "$app" -uvsBenchmark YES >"$out/logs/launch.xctrace.log" 2>&1
echo "launch trace done"

# 3. Scenario traces.
trace_scenario testTraceFling "Animation Hitches" fling
trace_scenario testTraceStream "Animation Hitches" stream
trace_scenario testTraceMemory "Allocations" memory

# 4. Numbers.
python3 "$here/summarize.py" summary --dir "$out" --out "$out/summary.json"
cat "$out/summary.json"
