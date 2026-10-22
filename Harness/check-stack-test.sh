#!/bin/bash
# Fixture tests for the swiftui-mac source rule of Harness/check-stack.sh.  Run: bash Harness/check-stack-test.sh
# Builds tiny git folders in a fresh temp dir (left for the system to clear) and a fake .app holding a copy of /bin/ls.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
mkdir -p "$T/app/Contents/MacOS" && cp /bin/ls "$T/app/Contents/MacOS/x"
fails=0
case_() { # name, expected exit, expected text, then file contents via files in $T/w
  local name="$1" want="$2" text="$3" out rc
  ( cd "$W" && git init -q . 2>/dev/null; git add -A >/dev/null 2>&1 )
  out="$(bash "$HERE/check-stack.sh" swiftui-mac "$W" "$T/app" 2>&1)"; rc=$?
  if [ "$rc" = "$want" ] && printf '%s' "$out" | grep -qF "$text"; then echo "pass: $name"; else echo "FAIL: $name (exit $rc)"; echo "$out"; fails=$((fails+1)); fi
}
n=0
fresh() { n=$((n+1)); W="$T/w$n"; mkdir -p "$W/Campfire" "$W/CampfireUITests"; }
fresh; printf 'import SwiftUI\nstruct A {}\n' > "$W/Campfire/A.swift"
case_ "plain SwiftUI" 0 "ok"
fresh; printf 'import AppKit\nimport Foundation\nlet p = NSPasteboard.general; let t = NSPasteboard.PasteboardType.string; let r: NSRange? = nil; let i = NSImage()\n' > "$W/Campfire/A.swift"
case_ "AppKit import for data types only" 0 "AppKit import for allowed data types only: Campfire/A.swift"
fresh; printf 'import AppKit\nlet v = NSVisualEffectView()\n' > "$W/Campfire/A.swift"
case_ "AppKit import with another AppKit type" 1 "NSVisualEffectView"
fresh; printf 'import AppKit\nlet w: NSWindow? = nil\n' > "$W/Campfire/A.swift"
case_ "NSWindow" 1 "NSWindow"
fresh; printf 'import SwiftUI\nstruct R: NSViewRepresentable {}\n' > "$W/Campfire/A.swift"
case_ "NSViewRepresentable" 1 "NSViewRepresentable"
fresh; printf 'import SwiftUI\n' > "$W/Campfire/A.swift"; printf 'import AppKit\nlet a = NSApplication.shared\n' > "$W/CampfireUITests/T.swift"
case_ "UI test target ignored" 0 "ok"
echo "failures: $fails"; exit $fails
