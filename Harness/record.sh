#!/bin/bash
# Records one benchmark round on a real iPhone: the XCUITest suites (ChatBenchmarks and StressBenchmarks, 5
# iterations per test, numbers from the xcresult and the UVS_RESULT lines in the log) plus one Instruments
# trace per scenario, then writes summary.json.
#
#   Harness/record.sh --build <name> --round <n> [--device <devicectl id>] [--udid <xcodebuild id>] [--app campfire.bench]
#
# Output: runs/<build>/<round>/{bench.xcresult, launch.trace, fling.trace, stream.trace, memory.trace, summary.json, logs/}
# Refuses a round folder that already exists (every run is kept). Exits non-zero when any step fails: a test
# failure, a trace that did not record, or a trace that had to be killed. logs/failures.txt says which.
#
# How the traces are driven: Instruments starts the app itself (`xctrace record --launch`), so the trace covers
# the whole process. Once the recording runs, a UI test (TraceScenarios) takes over the running app with
# activate(), plays one scenario and ends; the script then stops the trace. Each recording has a time limit that
# fits its scenario, and a hard cap (time limit + FINALISE_S) after which xctrace is killed, so it can't hang.
# Needs the app already installed (Release) and the phone unlocked, with Settings > Developer > Enable UI Automation on.
# Run it through the build queue: buildslot run --label "uvs: record" -- Harness/record.sh ...
set -u

build=""; round=""; app="campfire.bench"
device_core="73FC3857-7993-59CC-8A8E-34FB2E08AE71"   # devicectl id (iPhone 12, iOS 26.0)
device_udid="00008101-00062D410CE9003A"              # xctrace / xcodebuild id of the same phone
FINALISE_S=300                                       # longest we wait for xctrace to save after it stops
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
if [ -e "$out" ]; then echo "refusing: $out already exists; every round gets a new number" >&2; exit 2; fi
mkdir -p "$out/logs"
derived="$repo/build/DDH"
failed=0
fail() { echo "FAILED: $1" | tee -a "$out/logs/failures.txt" >&2; failed=1; }

# Signing: team H8HSTBN8ZP (Amazing Humans), automatic. The App Store Connect key lets xcodebuild make the
# profile; it lives outside the repo.
auth=(-allowProvisioningUpdates
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_MYT9KLPSWK.p8"
  -authenticationKeyID MYT9KLPSWK
  -authenticationKeyIssuerID 69a6de85-b768-47e3-e053-5b8c7c11a4d1)

# 0. Build the tests once; every later step runs them without building.
xcodebuild build-for-testing -project "$here/CampfireBench.xcodeproj" -scheme CampfireBench \
  -destination "id=$device_udid" -derivedDataPath "$derived" "${auth[@]}" >"$out/logs/build.log" 2>&1 \
  || { fail "build-for-testing (logs/build.log)"; exit 1; }
xctestrun="$(ls -t "$derived"/Build/Products/*.xctestrun | head -1)"
xct=(xcodebuild test-without-building -xctestrun "$xctestrun" -destination "id=$device_udid")

# xctrace with a hard wall-clock cap: perl sets an alarm and execs xctrace, so SIGALRM ends it after $1 seconds
# even if it never finishes saving.
capped_xctrace() {
  local cap="$1"; shift
  /usr/bin/perl -e '$t = shift; alarm $t; exec @ARGV or die "exec: $!"' "$cap" xcrun xctrace "$@"
}

# Waits for the recording to start (xctrace prints "Ctrl-C to stop"), at most 120 s. Returns 1 if it never did.
wait_recording() {
  local log="$1" pid="$2" n=0
  until grep -q "Ctrl-C to stop" "$log" 2>/dev/null; do
    if ! kill -0 "$pid" 2>/dev/null || [ $n -ge 120 ]; then return 1; fi
    sleep 1; n=$((n + 1))
  done
}

# Checks a finished recording: exit status, the trace on disk, and xctrace's own log.
check_trace() {
  local name="$1" status="$2"
  if [ "$status" -ne 0 ]; then fail "$name trace: xctrace exit $status (142 = killed after the cap; logs/$name.xctrace.log)"; fi
  if [ ! -d "$out/$name.trace" ]; then fail "$name trace: no trace file"; fi
}

# Starts a recording in the background and waits until it runs: name $1, time limit $2 seconds, then the
# xctrace options. Right after a UI test the phone sometimes answers "Timed out waiting for device to boot", so
# it tries 3 times; a failed attempt's partial trace is moved aside, never deleted. Sets trace_pid; returns 1
# if no attempt started.
start_recording() {
  local name="$1" limit="$2"; shift 2
  local xlog="$out/logs/$name.xctrace.log" attempt
  for attempt in 1 2 3; do
    capped_xctrace $((limit + FINALISE_S)) record --device "$device_udid" "$@" \
      --time-limit "${limit}s" --no-prompt --output "$out/$name.trace" \
      --launch -- "$app" -uvsBenchmark YES >"$xlog" 2>&1 &
    trace_pid=$!
    if wait_recording "$xlog" "$trace_pid"; then return 0; fi
    kill -INT "$trace_pid" 2>/dev/null; wait "$trace_pid"
    cp "$xlog" "$out/logs/$name.attempt$attempt.xctrace.log"
    if [ -e "$out/$name.trace" ]; then mv "$out/$name.trace" "$out/logs/$name.attempt$attempt.trace"; fi
    echo "$name: recording did not start (attempt $attempt): $(tail -1 "$xlog")" >&2
    sleep 15
  done
  return 1
}

# One traced scenario: test $1 of TraceScenarios, trace name $2, time limit $3 seconds, then the instruments.
trace_scenario() {
  local test="$1" name="$2" limit="$3"; shift 3
  local xlog="$out/logs/$name.xctrace.log"
  local instruments=()
  for i in "$@"; do instruments+=(--instrument "$i"); done
  if ! start_recording "$name" "$limit" "${instruments[@]}"; then
    fail "$name trace: recording never started (logs/$name.attempt*.xctrace.log)"; return
  fi
  # The test must take over the app Instruments launched, not start its own: wait until it is running
  # (each devicectl call takes a couple of seconds, so 30 tries is about a minute).
  local tries=0
  until [ -n "$(python3 "$here/summarize.py" pid --device "$device_core" --bundle "$app")" ] || [ $tries -ge 30 ]; do
    tries=$((tries + 1))
  done
  "${xct[@]}" -only-testing:"CampfireBenchUITests/TraceScenarios/$test" \
    -resultBundlePath "$out/logs/$name.xcresult" >"$out/logs/$name.test.log" 2>&1 \
    || fail "$name scenario test $test (logs/$name.test.log)"
  grep -q "Reached specified time limit" "$xlog" && fail "$name trace: time limit hit before the scenario ended"
  kill -INT "$trace_pid" 2>/dev/null
  wait "$trace_pid"
  check_trace "$name" $?
}

# 1. The suites: launch, time to 40 rows, fling, jump, load older, stream, memory; text size, rotation,
#    boost burst, text selection and context menu (5 iterations each where measured).
"${xct[@]}" -only-testing:CampfireBenchUITests/ChatBenchmarks -only-testing:CampfireBenchUITests/StressBenchmarks \
  -resultBundlePath "$out/bench.xcresult" >"$out/logs/suite.log" 2>&1 || fail "suite (logs/suite.log)"
echo "suites finished"

# 2. Cold launch trace, after the phone has been idle 30 s (spec): Instruments starts the app itself.
xcrun devicectl device process terminate --device "$device_core" --pid "$(python3 "$here/summarize.py" pid --device "$device_core" --bundle "$app")" >/dev/null 2>&1
sleep 30
if start_recording launch 15 --template "App Launch"; then
  wait "$trace_pid"
else
  fail "launch trace: recording never started"; false
fi
check_trace launch $?
echo "launch trace done"

# 3. Scenario traces, light instrument sets. Hitches gives frames and hitches; os_signpost gives UIKit's scroll
#    intervals (fps counts only while a scroll moves); Allocations runs from process start for the heap.
trace_scenario testTraceFling fling 240 Hitches os_signpost
trace_scenario testTraceStream stream 150 Hitches os_signpost
trace_scenario testTraceMemory memory 200 Allocations

# 4. Numbers.
python3 "$here/summarize.py" summary --dir "$out" --out "$out/summary.json" || fail "summarize"
cat "$out/summary.json"
if [ $failed -ne 0 ]; then echo "round finished with failures:" >&2; cat "$out/logs/failures.txt" >&2; exit 1; fi
echo "round finished, no failures"
