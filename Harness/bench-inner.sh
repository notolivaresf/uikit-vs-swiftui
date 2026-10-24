#!/bin/bash
# Builds the app for Release, measures it with Harness/record.sh, prints the scorecard. Run by the bench broker
# (bench-broker.py) or by ./bench --direct, one at a time (the measure lock). Not meant to be run by hand.
#   bench-inner.sh <sim|device|device-full|build> <build folder> [<number>]
# <number> (sim only): measure just that one number: rows-cold rows-repeat stream jump older textsize-bottom
# textsize-mid memory size (./bench <number>); prints its row and the checks that run answers.
# sim          this folder's own simulator (.bench/sim: a or b), baseline from .bench/baseline.json
# device       the iPhone 12, quick pass
# device-full  the iPhone 12, full scoring pass (Instruments traces)
# build        compile only (Release, simulator build), stack rule; no measuring
set -u
mode="$1"; root="$2"; number="${3:-}"; cd "$root"
# number -> the steps record.sh --only runs, and the scorecard row
only=""; row=""
case "$number" in
  "") ;;
  rows-cold) only=launch; row=first40_cold ;;
  rows-repeat) only=testTimeTo40Rows; row=first40_repeated ;;
  stream) only=testLiveStream; row=stream_cpu ;;
  memory) only=testLiveStream; row=memory ;;
  jump) only=testJumpTo2500; row=jump ;;
  older) only=testLoadOlder; row=older ;;
  textsize-bottom) only=testTextSizeAtBottom; row=text_bottom; export UVS_ITER=2 ;;
  textsize-mid) only=testTextSizeMidScroll; row=text_mid; export UVS_ITER=2 ;;   # 2 iterations of 3 steps keep it near 30 s
  size) only=none; row=app_size ;;
  *) echo "unknown number $number"; exit 2 ;;
esac
H="$(cd "$(dirname "$0")" && pwd)"            # always the repo's own harness, never the copy in the build folder
work="$root/.bench-work"
name="$(cat "$root/.bench/name")"; stack="$(cat "$root/.bench/stack")"
ts="$(date +%Y%m%d-%H%M%S)"
out="$work/$mode-$ts"
mkdir -p "$out"
. "$H/local.env"
shared="${UVS_BENCH_HOME:-$HOME/.uvs-bench}"; mkdir -p "$shared"

# The project's name is the model's choice (Level 2 twostraws: CampfireBench.xcodeproj); every earlier build used Campfire.
proj="Campfire"
if [ ! -d Campfire.xcodeproj ]; then
  cands=( *.xcodeproj ); [ "${#cands[@]}" = 1 ] && [ -d "${cands[0]}" ] && proj="${cands[0]%.xcodeproj}"
fi
# A project with a script build phase would run arbitrary commands outside any sandbox; refuse it.
if grep -q "PBXShellScriptBuildPhase" "$proj.xcodeproj/project.pbxproj" 2>/dev/null; then
  echo "Refusing to build: $proj.xcodeproj has a shell script build phase. Remove it."; exit 2
fi

slot=()
command -v buildslot >/dev/null 2>&1 && slot=(buildslot run --label "uvs-r3 $name: bench $mode" --)
if [ "$mode" = sim ] || [ "$mode" = build ]; then
  simname="uvs-r3-$(cat "$root/.bench/sim")"
  sim="$(python3 -I "$H/sims.py" udid "$simname")" || { echo "no simulator $simname (the broker makes it)"; exit 2; }
  xcrun simctl bootstatus "$sim" -b >/dev/null 2>&1
  bdest="platform=iOS Simulator,id=$sim"; prod="Release-iphonesimulator"; sign=(CODE_SIGNING_ALLOWED=NO); auth=()
  dd="$work/dd-sim"; tests_dd="$shared/dd-tests-sim"
else
  bdest="id=$UVS_DEVICE_UDID"; prod="Release-iphoneos"; dd="$work/dd"; tests_dd="$shared/dd-tests-device"
  sign=(DEVELOPMENT_TEAM="$UVS_TEAM" CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES "CODE_SIGN_IDENTITY=Apple Development")
  auth=(-allowProvisioningUpdates)
  if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
    auth+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
  fi
fi

echo "building (Release) ..."
${slot[@]+"${slot[@]}"} xcodebuild build -project "$proj.xcodeproj" -scheme "$proj" -configuration Release \
  -destination "$bdest" -derivedDataPath "$dd" "${sign[@]}" ${auth[@]+"${auth[@]}"} >"$out/app-build.log" 2>&1
if [ $? -ne 0 ]; then
  echo "BUILD FAILED. Errors (full log: $out/app-build.log):"
  grep -E "error:" "$out/app-build.log" | sort -u | head -30
  exit 2
fi
app="$dd/Build/Products/$prod/$proj.app"
[ -d "$app" ] || app="$(ls -d "$dd/Build/Products/$prod/"*.app 2>/dev/null | head -1)"
[ -d "$app" ] || { echo "no .app after the build"; exit 2; }
size_mb="$(du -sk "$app" | awk '{printf "%.2f", $1/1024}')"

stack_detail="$("$H/check-stack.sh" "$stack" "$root" 2>&1)"; stack_ok=ok
echo "$stack_detail" | grep -q ": FAIL" && stack_ok=FAIL
detail="$(echo "$stack_detail" | sed -n '2,3p' | tr '\n' ' ')"

if [ -n "$number" ]; then
  s0=$(date +%s)
  mkdir -p "$out/run"
  if [ "$only" = none ]; then
    echo '{}' > "$out/run/summary.json"
  else
    echo "measuring $number in the simulator $simname ..."
    ${slot[@]+"${slot[@]}"} "$H/record.sh" --build "$name" --round "$ts" --out-dir "$out/rec" --derived "$tests_dd" \
      --app-path "$app" --sim "$sim" --only "$only" >"$out/record.log" 2>&1
    if [ -f "$out/rec/summary.json" ]; then mv "$out/rec/summary.json" "$out/run/summary.json"; fi
  fi
  if [ ! -f "$out/run/summary.json" ]; then
    echo "MEASURING FAILED (no summary). Last lines of the log ($out/record.log):"; tail -20 "$out/record.log"
    [ -f "$out/rec/logs/failures.txt" ] && cat "$out/rec/logs/failures.txt"
    exit 2
  fi
  [ -f "$out/rec/logs/failures.txt" ] && { echo "NOTE: a step failed:"; cat "$out/rec/logs/failures.txt"; }
  sflags=(--sim); [ -f "$root/.bench/baseline.json" ] && sflags+=(--baseline "$root/.bench/baseline.json")
  python3 -I "$H/scorecard.py" --summary "$out/run/summary.json" --best "$H/round3-best.json" --stack-rule "$stack_ok" \
    --stack-detail "$detail" --app-size-mb "$size_mb" "${sflags[@]}" --only "$row"
  echo "($(( $(date +%s) - s0 )) s measuring; results kept in $out)"
  exit 0
fi
if [ "$mode" = build ]; then
  stack_detail="$("$H/check-stack.sh" "$stack" "$root" 2>&1)"; echo "BUILD OK (Release, simulator)"; echo "$stack_detail"; exit 0
fi
flags=(); sflags=()
case "$mode" in
  sim) flags=(--sim "$sim"); sflags=(--sim); [ -f "$root/.bench/baseline.json" ] && sflags+=(--baseline "$root/.bench/baseline.json")
       echo "measuring in the simulator $simname ..." ;;
  device) flags=(--quick); sflags=(--quick); echo "measuring on the iPhone 12 (quick pass) ..." ;;
  device-full) echo "measuring on the iPhone 12 (full pass) ..." ;;
esac
${slot[@]+"${slot[@]}"} "$H/record.sh" --build "$name" --round "$ts" --out-dir "$out/run" --derived "$tests_dd" \
  --app-path "$app" ${flags[@]+"${flags[@]}"} >"$out/record.log" 2>&1
rc=$?
if [ ! -f "$out/run/summary.json" ]; then
  echo "MEASURING FAILED (no summary). Last lines of the log ($out/record.log):"; tail -20 "$out/record.log"
  [ -f "$out/run/logs/failures.txt" ] && cat "$out/run/logs/failures.txt"
  exit 2
fi
[ $rc -ne 0 ] && [ "$mode" = device-full ] && { echo "NOTE: some measuring steps failed:"; cat "$out/run/logs/failures.txt" 2>/dev/null; }
python3 -I "$H/scorecard.py" --summary "$out/run/summary.json" --best "$H/round3-best.json" --stack-rule "$stack_ok" \
  --stack-detail "$detail" --app-size-mb "$size_mb" ${sflags[@]+"${sflags[@]}"} --json "$out/scorecard.json" | tee "$out/scorecard.txt"
echo
echo "(results kept in $out)"
