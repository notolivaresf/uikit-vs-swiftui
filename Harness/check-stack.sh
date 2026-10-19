#!/bin/bash
# Stack rule check for a finished build (docs/harness.md, "Stack rule check").
#   Harness/check-stack.sh <uikit|swiftui|objc> <build folder>
# Prints the offending lines and exits 1 on a violation, 0 when the rule holds. Looks at the files
# git tracks or could track (untracked, not ignored) outside CampfireKit/, the package we gave it.
set -euo pipefail
SIDE="${1:-}"; DIR="${2:-}"
[ -d "$DIR" ] && case "$SIDE" in uikit|swiftui|objc) ;; *) false ;; esac || { echo "usage: $0 <uikit|swiftui|objc> <build folder>" >&2; exit 2; }
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
esac
out="$(printf '%s' "$out" | sed '/^$/d')"
if [ -n "$out" ]; then echo "Stack rule ($SIDE): FAIL"; echo "$out"; exit 1; fi
echo "Stack rule ($SIDE): ok"
