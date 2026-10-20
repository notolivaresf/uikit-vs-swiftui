#!/bin/bash
# Records one benchmark round on a real iPhone: the XCUITest suites (ChatBenchmarks and StressBenchmarks, 3
# iterations per test, fling and memory 1; numbers from the xcresult and the UVS_RESULT lines in the log) plus one Instruments
# trace per scenario, then writes summary.json.
#
#   Harness/record.sh --build <name> --round <n> [--app-path <Release .app>] [--device <devicectl id>]
#                     [--udid <xcodebuild id>] [--app campfire.bench] [--heap-trace]
#
# --app-path: the build's Release .app; it is installed again before each cold launch sample, so every launch
# is the first after an install (the spec's "freshly installed"). Without it the launches still run cold after
# 30 s idle, but on the copy already installed, and the summary says so.
#
# Output: runs/<build>/<round>/{launch.<n>.trace, bench.xcresult, fling.trace, stream.trace, memory.trace, summary.json, logs/}
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

build=""; round=""; app="campfire.bench"; app_path=""
LAUNCH_SAMPLES=3; heap_trace=0; stream_only=0
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
    --app-path) app_path="$2"; shift 2;;
    --heap-trace) heap_trace=1; shift;;
    # --stream-only: only the stream trace and ChatBenchmarks/testLiveStream (no launches, fling or other
    # tests). Used for the L1 stream reruns of opus-uikit and opus-swiftui, whose round 1 ran the stream test
    # before the relaunch fix (98b2d48); Fernando cut rounds 2 and 3, 18 Oct.
    --stream-only) stream_only=1; shift;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
if [ -z "$build" ] || [ -z "$round" ]; then echo "usage: record.sh --build <name> --round <n>" >&2; exit 2; fi
if [ -n "$app_path" ] && [ ! -d "$app_path" ]; then echo "no app at $app_path" >&2; exit 2; fi

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
# App Store Connect key: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, from the untracked Harness/local.env when present.
[ -f "$(dirname "$0")/local.env" ] && . "$(dirname "$0")/local.env"
auth=(-allowProvisioningUpdates)
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  auth+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

# 0. Build the tests once; every later step runs them without building.
xcodebuild build-for-testing -project "$here/CampfireBench.xcodeproj" -scheme CampfireBench \
  -destination "id=$device_udid" -derivedDataPath "$derived" "${auth[@]}" >"$out/logs/build.log" 2>&1 \
  || { fail "build-for-testing (logs/build.log)"; exit 1; }
xctestrun="$(ls -t "$derived"/Build/Products/*.xctestrun | head -1)"
xct=(xcodebuild test-without-building -xctestrun "$xctestrun" -destination "id=$device_udid")

# xctrace with a hard wall-clock cap: perl sets an alarm and execs xctrace, so SIGALRM ends it after $1 seconds
# even if it never finishes saving. Run in the background, so the kill -INT that stops a recording must reach
# xctrace itself: `exec` makes the background subshell become perl, and perl execs xcrun, which execs xctrace,
# so $! is xctrace's pid (without it $! was the subshell, Ctrl-C never arrived and every trace ran to its time
# limit). Perl also puts SIGINT back to default, which bash sets to ignored for background jobs. Call it only
# with `&`: in the foreground the exec would replace this script.
capped_xctrace() {
  local cap="$1"; shift
  exec /usr/bin/perl -e '$SIG{INT} = "DEFAULT"; $t = shift; alarm $t; exec @ARGV or die "exec: $!"' "$cap" xcrun xctrace "$@"
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

# Wakes the phone: a UI test run turns the screen on. xctrace on a dark phone waits for it to "boot" and
# gives up, so every recording starts right after this (TraceScenarios.testWake, a test that does nothing).
wake() {
  "${xct[@]}" -only-testing:CampfireBenchUITests/TraceScenarios/testWake >>"$out/logs/wake.log" 2>&1 \
    || echo "wake test failed (logs/wake.log)" >&2
}

# Starts a recording in the background and waits until it runs: name $1, time limit $2 seconds, then the
# xctrace options. Right after a UI test the phone sometimes answers "Timed out waiting for device to boot", so
# it tries 3 times; a failed attempt's partial trace is moved aside, never deleted. Sets trace_pid; returns 1
# if no attempt started.
start_recording() {
  local name="$1" limit="$2"; shift 2
  local xlog="$out/logs/$name.xctrace.log" attempt
  for attempt in 1 2 3; do
    wake
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
  local tries=0 pid_before="" pid_after=""
  until [ -n "$pid_before" ] || [ $tries -ge 30 ]; do
    pid_before="$(python3 "$here/summarize.py" pid --device "$device_core" --bundle "$app")"
    tries=$((tries + 1))
  done
  if [ -z "$pid_before" ]; then
    fail "$name trace: the app Instruments launched never showed up"
    kill -INT "$trace_pid" 2>/dev/null; wait "$trace_pid"; return
  fi
  "${xct[@]}" -only-testing:"CampfireBenchUITests/TraceScenarios/$test" \
    -resultBundlePath "$out/logs/$name.xcresult" >"$out/logs/$name.test.log" 2>&1 \
    || fail "$name scenario test $test (logs/$name.test.log)"
  # The scenario must have run in the traced process, start to end: same pid after the test, recording alive.
  pid_after="$(python3 "$here/summarize.py" pid --device "$device_core" --bundle "$app")"
  [ "$pid_after" = "$pid_before" ] || fail "$name trace: the traced app (pid $pid_before) is gone or replaced (now '$pid_after')"
  kill -0 "$trace_pid" 2>/dev/null || fail "$name trace: the recording ended before the scenario did"
  grep -q "Reached specified time limit" "$xlog" && fail "$name trace: time limit hit before the scenario ended"
  kill -INT "$trace_pid" 2>/dev/null
  wait "$trace_pid"
  check_trace "$name" $?
}

# 1. Cold launches, first: for each sample the app is stopped, installed again (--app-path), the phone is left
#    idle 30 s, and Instruments launches it (App Launch template). 10 s in, when the launch is over, a UI test
#    reads the app's own time to the first 40 rows from that same launch (TraceScenarios.testLaunchState).
[ $stream_only -eq 1 ] && LAUNCH_SAMPLES=0
for ((n = 1; n <= LAUNCH_SAMPLES; n++)); do
  pid="$(python3 "$here/summarize.py" pid --device "$device_core" --bundle "$app")"
  [ -n "$pid" ] && xcrun devicectl device process terminate --device "$device_core" --pid "$pid" >/dev/null 2>&1
  if [ -n "$app_path" ]; then
    xcrun devicectl device install app --device "$device_core" "$app_path" >"$out/logs/install.$n.log" 2>&1 \
      || fail "install before launch $n (logs/install.$n.log)"
  fi
  sleep 30
  if start_recording "launch.$n" 25 --template "App Launch"; then
    sleep 10
    "${xct[@]}" -only-testing:CampfireBenchUITests/TraceScenarios/testLaunchState \
      -resultBundlePath "$out/logs/launch.$n.xcresult" >"$out/logs/launch.$n.test.log" 2>&1 \
      || fail "launch $n: time to 40 rows (logs/launch.$n.test.log)"
    wait "$trace_pid"; status=$?
    # The App Launch recording ends at its time limit; that is expected here, not a failure.
    check_trace "launch.$n" $status
  else
    fail "launch $n trace: recording never started"
  fi
done
[ $stream_only -eq 1 ] && [ -n "$app_path" ] && { xcrun devicectl device install app --device "$device_core" "$app_path" >"$out/logs/install.log" 2>&1 || fail "install (logs/install.log)"; }
[ $stream_only -eq 1 ] || [ -n "$app_path" ] || echo "launch samples ran on the installed copy (no --app-path), not freshly installed" | tee "$out/logs/launch-not-fresh.txt"
echo "launch traces done"

# 2. Scenario traces, before the suites (after the suites, in smoke round 6, the fling trace's swipes
#    did not scroll the app: 84 frames instead of about 4,300; run alone they scroll). Light instrument sets:
#    Hitches for the hitches, Frame Lifetimes and Display so every frame is listed (Hitches alone lists only a sample of them). The Allocations heap trace (2 GB) only with
#    --heap-trace; memory numbers come from testMemory.
[ $stream_only -eq 1 ] || trace_scenario testTraceFling fling 240 Hitches "Frame Lifetimes" Display
trace_scenario testTraceStream stream 150 Hitches "Frame Lifetimes" Display
[ $heap_trace -eq 1 ] && trace_scenario testTraceMemory memory 200 Allocations

# 3. The suites: repeated launch, time to 40 rows, fling, jump, load older, stream, memory; text size,
#    rotation, boost burst, text selection and context menu (3 iterations each where measured; fling and memory 1).
suites=(-only-testing:CampfireBenchUITests/ChatBenchmarks -only-testing:CampfireBenchUITests/StressBenchmarks)
[ $stream_only -eq 1 ] && suites=(-only-testing:CampfireBenchUITests/ChatBenchmarks/testLiveStream)
"${xct[@]}" "${suites[@]}" \
  -resultBundlePath "$out/bench.xcresult" >"$out/logs/suite.log" 2>&1 || fail "suite (logs/suite.log)"
echo "suites finished"

# 4. Numbers.
if [ $stream_only -eq 1 ]; then
  # Most numbers are missing by design in a stream-only round; summary.json is still written.
  python3 "$here/summarize.py" summary --dir "$out" --out "$out/summary.json" 2>"$out/logs/summarize.log"
else
  python3 "$here/summarize.py" summary --dir "$out" --out "$out/summary.json" || fail "summarize"
fi
cat "$out/summary.json"
if [ $failed -ne 0 ]; then echo "round finished with failures:" >&2; cat "$out/logs/failures.txt" >&2; exit 1; fi
echo "round finished, no failures"
