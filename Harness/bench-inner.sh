#!/bin/bash
# Runs inside the iPhone lock (Harness/withlock.py). Builds the app for Release, measures it with Harness/record.sh,
# prints the scorecard. Called by ./bench; see docs/round3-plan.md.
#   bench-inner.sh <quick|full> <folder>
set -u
mode="$1"; root="$2"; cd "$root"
H="$root/.bench/Harness"
work="$root/.bench-work"
name="$(cat "$root/.bench/name")"; stack="$(cat "$root/.bench/stack")"
ts="$(date +%Y%m%d-%H%M%S)"
out="$work/$mode-$ts"
mkdir -p "$out"
. "$H/local.env"

# Release build, same settings as the Round 2 scoring builds (signing flags on the command line; they touch no code).
auth=(-allowProvisioningUpdates)
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  auth+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
slot=()
command -v buildslot >/dev/null 2>&1 && slot=(buildslot run --label "uvs-r3 $name: bench $mode" --)
echo "building (Release) ..."
${slot[@]+"${slot[@]}"} xcodebuild build -project Campfire.xcodeproj -scheme Campfire -configuration Release \
  -destination "id=$UVS_DEVICE_UDID" -derivedDataPath "$work/dd" DEVELOPMENT_TEAM="$UVS_TEAM" CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES "CODE_SIGN_IDENTITY=Apple Development" "${auth[@]}" >"$out/app-build.log" 2>&1
if [ $? -ne 0 ]; then
  echo "BUILD FAILED. Errors (full log: $out/app-build.log):"
  grep -E "error:|warning: .*(deprecated)" "$out/app-build.log" | sort -u | head -30
  exit 2
fi
app="$work/dd/Build/Products/Release-iphoneos/Campfire.app"
[ -d "$app" ] || { echo "no Campfire.app after the build"; exit 2; }
size_mb="$(du -sk "$app" | awk '{printf "%.2f", $1/1024}')"

# Stack rule
stack_detail="$("$H/check-stack.sh" "$stack" "$root" 2>&1)"; stack_ok=ok
echo "$stack_detail" | grep -q ": FAIL" && stack_ok=FAIL
detail="$(echo "$stack_detail" | sed -n '2,3p' | tr '\n' ' ')"

flags=(--quick); [ "$mode" = full ] && flags=()
echo "measuring on the iPhone 12 ($mode pass) ..."
${slot[@]+"${slot[@]}"} "$H/record.sh" --build "$name" --round "$ts" --out-dir "$out/run" --derived "$work/dd-tests" \
  --app-path "$app" ${flags[@]+"${flags[@]}"} >"$out/record.log" 2>&1
rc=$?
if [ ! -f "$out/run/summary.json" ]; then
  echo "MEASURING FAILED (no summary). Last lines of the log ($out/record.log):"; tail -20 "$out/record.log"
  [ -f "$out/run/logs/failures.txt" ] && cat "$out/run/logs/failures.txt"
  exit 2
fi
[ $rc -ne 0 ] && [ "$mode" = full ] && { echo "NOTE: some measuring steps failed:"; cat "$out/run/logs/failures.txt" 2>/dev/null; }
sflags=(); [ "$mode" = quick ] && sflags=(--quick)
python3 -I "$H/scorecard.py" --summary "$out/run/summary.json" --best "$H/round3-best.json" --stack-rule "$stack_ok" \
  --stack-detail "$detail" --app-size-mb "$size_mb" ${sflags[@]+"${sflags[@]}"} --json "$out/scorecard.json" | tee "$out/scorecard.txt"
echo
echo "(results kept in $out)"
