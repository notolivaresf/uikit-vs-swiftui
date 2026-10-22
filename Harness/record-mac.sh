#!/bin/bash
# Records one Round 4 benchmark round of a Mac build on this Mac: cold launches and scenario traces in
# Instruments, then the Mac XCUITest suites (MacChatBenchmarks, MacStressBenchmarks), then summary.json.
# The Mac twin of record.sh; called as `record.sh --mac ...` or directly.
#
#   Harness/record-mac.sh --build <name> --round <n> --app-path <Release .app> [--fast] [--no-traces]
#                         [--out-dir DIR] [--derived DIR] [--xctestrun FILE]
#
# --app-path: the build's Release .app. Each cold launch runs a fresh copy of it (copied into the round folder,
# never run before), after 30 s of idle. The disk cache is not purged (that needs root), so "cold" means first
# launch of a freshly copied app, not a cold disk.
# --fast: smoke mode (the stand-in app, or a guest): one iteration per test, one launch sample.
# --no-traces: skip Instruments (a smoke check of the suites only).
# --xctestrun: use Mac tests already built (build-for-testing elsewhere) instead of building them here.
#
# Needs: a logged-in, unlocked session with the display awake, Automation Mode on (once, by an admin:
# `automationmodetool enable-automationmode-without-authentication`), nobody using mouse or keyboard, and
# the window free to appear. Run it through the build queue:
#   buildslot run --label "UvS R4: record <build>" -- Harness/record-mac.sh --build <name> --round 1 --app-path <app>
#
# Output: runs/<build>/<round>/{launch.<n>.trace, fling.trace, stream.trace, resize.trace, bench.xcresult,
# summary.json, logs/, apps/}. Refuses a round folder that already exists. Exits non-zero on any failure;
# logs/failures.txt says which.
set -u

build=""; round=""; app_path=""; fast=0; traces=1; out_dir=""; derived_dir=""; prebuilt=""
LAUNCH_SAMPLES=3
FINALISE_S=300
LAUNCH_FINALISE_S=120
while [ $# -gt 0 ]; do
  case "$1" in
    --mac) shift;;
    --build) build="$2"; shift 2;;
    --round) round="$2"; shift 2;;
    --app-path) app_path="$2"; shift 2;;
    --fast) fast=1; shift;;
    --no-traces) traces=0; shift;;
    --out-dir) out_dir="$2"; shift 2;;
    --derived) derived_dir="$2"; shift 2;;
    --xctestrun) prebuilt="$2"; shift 2;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
if [ -z "$build" ] || [ -z "$round" ] || [ -z "$app_path" ]; then
  echo "usage: record-mac.sh --build <name> --round <n> --app-path <Release .app>" >&2; exit 2
fi
if [ ! -d "$app_path" ]; then echo "no app at $app_path" >&2; exit 2; fi
app_path="$(cd "$app_path" && pwd)"

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
out="${out_dir:-$repo/runs/$build/$round}"
if [ -e "$out" ]; then echo "refusing: $out already exists; every round gets a new number" >&2; exit 2; fi
mkdir -p "$out/logs" "$out/apps"
derived="${derived_dir:-$repo/build/MacBenchDD}"
failed=0
fail() { echo "FAILED: $1" | tee -a "$out/logs/failures.txt" >&2; failed=1; }
[ $fast -eq 1 ] && LAUNCH_SAMPLES=1 && export TEST_RUNNER_UVS_FAST=1

# The measured copy: the suites and scenario traces run this one; each cold launch gets its own copy.
cp -R "$app_path" "$out/apps/bench.app" || { fail "copy the app"; exit 1; }
bench_app="$out/apps/bench.app"
exe_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bench_app/Contents/Info.plist")"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bench_app/Contents/Info.plist")"
echo "$app_path" >"$out/logs/app-source.txt"
[ "$bundle_id" = "campfire.bench" ] || fail "app id is $bundle_id, not campfire.bench"

# Stops any other running app with the benchmark's bundle id (a build or stand-in left running, or one that
# Instruments launched and left suspended). XCUITest finds the app under test by bundle id: with a stray
# instance alive, every test fails with "Application 'campfire.bench' does not have a process ID".
stop_strays() {
  local line pid cmd app id
  while read -r line; do
    pid="${line%% *}"; cmd="${line#* }"
    case "$cmd" in *.app/Contents/MacOS/*) ;; *) continue;; esac
    app="${cmd%%.app/Contents/MacOS/*}.app"
    id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)"
    if [ "$id" = "campfire.bench" ]; then echo "stopping stray campfire.bench (pid $pid): $app" | tee -a "$out/logs/strays.txt"; kill -9 "$pid" 2>/dev/null; fi
  done < <(ps -axo pid=,command=)
}
stop_strays

# 0. Build the Mac tests once (ad-hoc signed, no team).
if [ -n "$prebuilt" ]; then
  xctestrun="$prebuilt"
else
  xcodebuild build-for-testing -project "$here/MacBench/CampfireBenchMac.xcodeproj" -scheme CampfireBenchMac \
    -configuration Release -destination platform=macOS -derivedDataPath "$derived" >"$out/logs/build.log" 2>&1 \
    || { fail "build-for-testing (logs/build.log)"; exit 1; }
  xctestrun="$(ls -t "$derived"/Build/Products/*.xctestrun | head -1)"
fi
export TEST_RUNNER_UVS_APP_PATH="$bench_app"
xct=(xcodebuild test-without-building -xctestrun "$xctestrun" -destination platform=macOS)
T=CampfireBenchMacUITests

# Stops every running copy of the app under test (by its executable path inside this round's folder).
stop_app() { pkill -9 -f "$out/apps/.*/Contents/MacOS/$exe_name" 2>/dev/null; stop_strays >/dev/null; true; }
app_pid() { pgrep -f "$1/Contents/MacOS/$exe_name" | head -1; }

# Instruments is given the executable inside the .app, not the .app: handed the bundle, xctrace on macOS 27
# (Xcode 26.4) starts two copies, traces a suspended one that never runs and leaves the real one untraced
# (the launch period never closes, exit 54, and UI tests see "no process ID").
# xctrace with a hard wall-clock cap (same as record.sh): call only with `&`.
capped_xctrace() {
  local cap="$1"; shift
  exec /usr/bin/perl -e '$SIG{INT} = "DEFAULT"; $t = shift; alarm $t; exec @ARGV or die "exec: $!"' "$cap" xcrun xctrace "$@"
}

wait_recording() {
  local log="$1" pid="$2" n=0
  until grep -q "Ctrl-C to stop" "$log" 2>/dev/null; do
    if ! kill -0 "$pid" 2>/dev/null || [ $n -ge 120 ]; then return 1; fi
    sleep 1; n=$((n + 1))
  done
}

check_trace() {
  local name="$1" status="$2"
  # Exit 54 is how this xctrace reports that it ended the process it launched (SIGKILL at the end of the
  # recording); with the trace saved and "Recording completed" in the log it is a normal end.
  if [ "$status" -eq 54 ] && [ -d "$out/$name.trace" ] && grep -q "Recording completed" "$out/logs/$name.xctrace.log"; then status=0; fi
  if [ "$status" -ne 0 ]; then fail "$name trace: xctrace exit $status (142 = killed after the cap; logs/$name.xctrace.log)"; fi
  if [ ! -d "$out/$name.trace" ]; then fail "$name trace: no trace file"; fi
}

# Starts a recording of app $3 in the background: name $1, time limit $2, then the xctrace options.
start_recording() {
  local name="$1" limit="$2" target="$3"; shift 3
  local xlog="$out/logs/$name.xctrace.log"
  local finalise="${FINALISE_OVERRIDE:-$FINALISE_S}"
  capped_xctrace $((limit + finalise)) record "$@" --time-limit "${limit}s" --no-prompt \
    --output "$out/$name.trace" --launch -- "$target/Contents/MacOS/$exe_name" -uvsBenchmark YES -ApplePersistenceIgnoreState YES >"$xlog" 2>&1 &
  trace_pid=$!
  wait_recording "$xlog" "$trace_pid" && return 0
  kill -INT "$trace_pid" 2>/dev/null; wait "$trace_pid"
  return 1
}

# One traced scenario: test $1 of MacTraceScenarios, trace name $2, time limit $3, then the instruments.
trace_scenario() {
  local test="$1" name="$2" limit="$3"; shift 3
  local xlog="$out/logs/$name.xctrace.log" instruments=() tries=0 pid_before="" pid_after=""
  for i in "$@"; do instruments+=(--instrument "$i"); done
  stop_app
  if ! start_recording "$name" "$limit" "$bench_app" "${instruments[@]}"; then
    fail "$name trace: recording never started (logs/$name.xctrace.log)"; return
  fi
  until [ -n "$pid_before" ] || [ $tries -ge 30 ]; do
    sleep 1; pid_before="$(app_pid "$bench_app")"; tries=$((tries + 1))
  done
  if [ -z "$pid_before" ]; then
    fail "$name trace: the app Instruments launched never showed up"
    kill -INT "$trace_pid" 2>/dev/null; wait "$trace_pid"; return
  fi
  "${xct[@]}" -only-testing:"$T/MacTraceScenarios/$test" \
    -resultBundlePath "$out/logs/$name.xcresult" >"$out/logs/$name.test.log" 2>&1 \
    || fail "$name scenario test $test (logs/$name.test.log)"
  pid_after="$(app_pid "$bench_app")"
  [ "$pid_after" = "$pid_before" ] || fail "$name trace: the traced app (pid $pid_before) is gone or replaced (now '$pid_after')"
  kill -0 "$trace_pid" 2>/dev/null || fail "$name trace: the recording ended before the scenario did"
  grep -q "Reached specified time limit" "$xlog" && fail "$name trace: time limit hit before the scenario ended"
  kill -INT "$trace_pid" 2>/dev/null
  wait "$trace_pid"
  check_trace "$name" $?
  stop_app
}

# 1. Cold launches: a fresh copy of the app, 30 s idle, the App Launch template launches it; 10 s in, a UI test
#    reads the app's own time to the first 40 rows from that same launch and quits the app.
if [ $traces -eq 1 ]; then
  for ((n = 1; n <= LAUNCH_SAMPLES; n++)); do
    stop_app
    mkdir -p "$out/apps/launch.$n"
    cp -R "$app_path" "$out/apps/launch.$n/Campfire.app" || fail "copy the app for launch $n"
    sleep 30
    if FINALISE_OVERRIDE=$LAUNCH_FINALISE_S start_recording "launch.$n" 20 "$out/apps/launch.$n/Campfire.app" --template "App Launch"; then
      sleep 10
      TEST_RUNNER_UVS_APP_PATH="$out/apps/launch.$n/Campfire.app" "${xct[@]}" -only-testing:$T/MacTraceScenarios/testLaunchState \
        -resultBundlePath "$out/logs/launch.$n.xcresult" >"$out/logs/launch.$n.test.log" 2>&1 \
        || fail "launch $n: time to 40 rows (logs/launch.$n.test.log)"
      wait "$trace_pid"; status=$?
      check_trace "launch.$n" $status
      if [ -d "$out/launch.$n.trace" ] && ! python3 "$here/summarize.py" launchms --mac --trace "$out/launch.$n.trace" >"$out/logs/launch.$n.launchms.txt" 2>&1; then
        fail "launch.$n trace saved but its launch period never ended (did the window draw?)"
      fi
    else
      fail "launch $n trace: recording never started (logs/launch.$n.xctrace.log)"
    fi
    stop_app
  done
  echo "template" >"$out/logs/launch-mode.txt"
  echo "launch traces done"

  # 2. Scenario traces: Hitches, Frame Lifetimes and Display, as on the iPhone.
  trace_scenario testTraceFling fling 240 Hitches "Frame Lifetimes" Display
  trace_scenario testTraceStream stream 150 Hitches "Frame Lifetimes" Display
  trace_scenario testTraceResize resize 120 Hitches "Frame Lifetimes" Display
fi

# 3. The suites.
stop_app
"${xct[@]}" -only-testing:$T/MacChatBenchmarks -only-testing:$T/MacStressBenchmarks \
  -resultBundlePath "$out/bench.xcresult" >"$out/logs/suite.log" 2>&1 || fail "suite (logs/suite.log)"
stop_app
echo "suites finished"

# 4. Numbers.
python3 "$here/summarize.py" summary --mac --app "$app_path" --dir "$out" --out "$out/summary.json" 2>"$out/logs/summarize.log" \
  || { [ $traces -eq 1 ] && fail "summarize (logs/summarize.log)"; }
cat "$out/summary.json"
if [ $failed -ne 0 ]; then echo "round finished with failures:" >&2; cat "$out/logs/failures.txt" >&2; exit 1; fi
echo "round finished, no failures"
