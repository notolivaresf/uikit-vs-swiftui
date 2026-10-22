#!/bin/bash
# Stack rule check for a finished build (docs/harness.md, "Stack rule check").
#   Harness/check-stack.sh <uikit|swiftui|objc> <build folder>
#   Harness/check-stack.sh <appkit-swift|appkit-objc|swiftui-mac> <build folder> [<built .app>]   (Round 4)
# Round 4 needs the built app too: every Mach-O file inside it is checked for which system framework its
# symbols are bound to (`nm -m`), so a view from the other framework can't hide behind a type alias or a
# helper framework. A class looked up by name at run time has no such symbol, so the source check also
# refuses run-time class and library lookups (NSClassFromString, objc_getClass, dlopen, dlsym).
# Prints the offending lines and exits 1 on a violation, 0 when the rule holds. Looks at the files
# git tracks or could track (untracked, not ignored) outside CampfireKit/, the package we gave it.
set -euo pipefail
SIDE="${1:-}"; DIR="${2:-}"; APP="${3:-}"
[ -d "$DIR" ] && case "$SIDE" in uikit|swiftui|objc|appkit-swift|appkit-objc|swiftui-mac) ;; *) false ;; esac || { echo "usage: $0 <uikit|swiftui|objc|appkit-swift|appkit-objc|swiftui-mac> <build folder> [<built .app>]" >&2; exit 2; }
case "$SIDE" in appkit-swift|appkit-objc|swiftui-mac)
  [ -n "$APP" ] && [ -d "$APP" ] || { echo "Round 4 stacks need the built .app as the third argument" >&2; exit 2; } ;; esac
[ -z "$APP" ] || APP="$(cd "$APP" && pwd)"
cd "$DIR"
FILES="$(git ls-files -co --exclude-standard | grep -v '^CampfireKit/' || true)"
fail=0
hits() { # pattern, file filter regex
  [ -n "$FILES" ] || return 0
  printf '%s\n' "$FILES" | grep -E "$2" | tr '\n' '\0' | xargs -0 grep -nHE "$1" 2>/dev/null || true
}
case "$SIDE" in
  swiftui)
    out="$(hits 'UIKit|UIViewRepresentable|UIViewControllerRepresentable|UIHostingController' '\.swift$')" ;;
  uikit)
    out="$(hits '(^|[^A-Za-z])import[[:space:]]+SwiftUI|UIHostingController' '\.swift$')" ;;
  objc)
    out="$(hits 'SwiftUI|UIHostingController' '\.(m|mm|h|swift)$')"
    swift="$(printf '%s\n' "$FILES" | grep -E '\.swift$' || true)"
    [ -z "$swift" ] || out="$out"$'\n'"Swift files in the app (not allowed): "$(printf '%s' "$swift" | tr '\n' ' ')
    if git status --porcelain -- CampfireKit | grep -q .; then out="$out"$'\n'"CampfireKit was modified (not allowed)"; fi
    ;;
  appkit-swift)
    out="$(hits '(^|[^A-Za-z])import[[:space:]]+SwiftUI|NSHostingView|NSHostingController|NSHostingMenu|NSHostingSceneRepresentation|"[^"]*SwiftUI' '\.swift$')"
    objc="$(printf '%s\n' "$FILES" | grep -E '\.(m|mm)$' || true)"
    [ -z "$objc" ] || out="$out"$'\n'"Objective-C files in a Swift-only app (not allowed): "$(printf '%s' "$objc" | tr '\n' ' ')
    ;;
  appkit-objc)
    out="$(hits 'SwiftUI|NSHostingView|NSHostingController' '\.(m|mm|h|swift)$')"
    swift="$(printf '%s\n' "$FILES" | grep -E '\.swift$' || true)"
    [ -z "$swift" ] || out="$out"$'\n'"Swift files in the app (not allowed): "$(printf '%s' "$swift" | tr '\n' ' ')
    if git status --porcelain -- CampfireKit | grep -q .; then out="$out"$'\n'"CampfireKit was modified (not allowed)"; fi
    ;;
  swiftui-mac)
    # Like the iPhone rule: no wrapped or hosted AppKit views, no reaching into the AppKit objects underneath.
    # Plain data types that SwiftUI itself hands over (NSImage, NSColor, NSFont, the pasteboard) stay allowed, as
    # UIImage and the pasteboard were on the iPhone, and so does the `import AppKit` that names them, but only
    # when every AppKit name the app sources use is one of those (checked below). Files of the agent's own test
    # targets (a folder ending in Tests) don't count for this rule; the binary check covers the app itself.
    FILES="$(printf '%s\n' "$FILES" | grep -vE '(^|/)[^/]*Tests/' || true)"
    out="$(hits 'NSViewRepresentable|NSViewControllerRepresentable|NSHosting[A-Za-z]*|NSApplicationDelegateAdaptor|NSClassFromString|objc_getClass|objc_lookUpClass|dlopen|dlsym|(^|[^A-Za-z])NSApp([^A-Za-z]|$)|(^|[^A-Za-z])NS(View|ViewController|Window|WindowController|Event|Menu|MenuItem|TextView|TextField|TableView|OutlineView|CollectionView|ScrollView|ClipView|Application|Responder|StackView|Button|Screen|Control|Cell|LayoutManager|TextStorage|TextContainer|Animation|Gesture|TrackingArea)([^A-Za-z]|$)' '\.swift$')"
    imports="$(hits '(^|[^A-Za-z])import[[:space:]]+(AppKit|Cocoa)' '\.swift$')"
    if [ -n "$imports" ]; then
      # Every NS name in the app sources must be Foundation's (looked up in the SDK headers) or an allowed data type.
      sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
      fnd="$(grep -rhoE '\bNS[A-Z][A-Za-z0-9]*' "$sdk/System/Library/Frameworks/Foundation.framework/Versions/Current/Headers" 2>/dev/null | sort -u || true)"
      used="$(printf '%s\n' "$FILES" | grep -E '\.swift$' | tr '\n' '\0' | xargs -0 grep -ohE '(^|[^A-Za-z0-9_])NS[A-Z][A-Za-z0-9]*' 2>/dev/null | grep -oE 'NS[A-Z][A-Za-z0-9]*' | sort -u || true)"
      other="$(printf '%s\n' "$used" | grep -vE '^NS(Image|Color|Font|Pasteboard|PasteboardType[A-Za-z]*)$' | grep -vxF -f <(printf '%s\n' "$fnd") || true)"
      if [ -z "$fnd" ]; then out="$out"$'\n'"import AppKit found but the Foundation headers could not be read to check the names"
      elif [ -n "$other" ]; then out="$out"$'\n'"$imports"$'\n'"AppKit names beyond NSImage/NSColor/NSFont/NSPasteboard: "$(printf '%s' "$other" | tr '\n' ' ')
      else appkit_ok="$(printf '%s\n' "$imports" | cut -d: -f1 | sort -u | tr '\n' ' ')"; fi
    fi ;;
esac
# Round 4: CampfireKit as we gave it (against the build's first commit and the working tree), any stack.
case "$SIDE" in appkit-swift|swiftui-mac)
  root="$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1 || true)"
  if { [ -n "$root" ] && ! git diff --quiet "$root" -- CampfireKit; } || git status --porcelain -- CampfireKit | grep -q .; then
    out="$out"$'\n'"CampfireKit was modified (not allowed)"; fi ;; esac
# The built app: which frameworks the symbols of every Mach-O file in it are bound to.
if [ -n "$APP" ]; then
  syms=""
  while IFS= read -r -d '' f; do
    file -b "$f" | grep -q 'Mach-O' || continue
    s="$(nm -m "$f" 2>&1)" || { out="$out"$'\n'"nm could not read $f"; continue; }
    syms="$syms"$'\n'"$s"
  done < <(find "$APP/Contents" -type f \( -perm -u+x -o -name '*.dylib' \) -print0)
  [ -n "$syms" ] || out="$out"$'\n'"no executable code found in $APP"
  case "$SIDE" in
    appkit-swift|appkit-objc)
      n="$(printf '%s\n' "$syms" | grep -c '(from SwiftUI' || true)"
      [ "$n" = 0 ] || out="$out"$'\n'"the app binary uses $n SwiftUI symbols (nm -m)" ;;
    swiftui-mac)
      bad="$(printf '%s\n' "$syms" | grep '(from AppKit)' | grep -v -E 'NS(Image|Color|Font|Pasteboard)' || true)"
      [ -z "$bad" ] || out="$out"$'\n'"the app binary uses AppKit beyond NSImage/NSColor/NSFont/NSPasteboard (nm -m): $(printf '%s\n' "$bad" | sed 's/.*external //' | head -5 | tr '\n' ' ')" ;;
  esac
fi
out="$(printf '%s' "$out" | sed '/^$/d')"
if [ -n "$out" ]; then echo "Stack rule ($SIDE): FAIL"; echo "$out"; exit 1; fi
if [ -n "${appkit_ok:-}" ]; then echo "Stack rule ($SIDE): ok (AppKit import for allowed data types only: ${appkit_ok% })"; else echo "Stack rule ($SIDE): ok"; fi
