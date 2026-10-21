#!/usr/bin/env python3
"""Fills prompts/round3.md for one build: its Round 2 stack line, its baseline scorecard and the exact wording of
each check it failed. Baselines come from docs/round3-baselines.json (written by the baseline pass); without it
the scorecard stays a placeholder and a warning is printed.

  round3_prompt.py --build uikit-swift-opus --folder DIR --out FILE
"""
import argparse, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import scorecard  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--build", required=True); ap.add_argument("--folder"); ap.add_argument("--out", required=True)
a = ap.parse_args()
stack = {"uikit-swift": "uikit-swift", "uikit-objc": "uikit-objc", "swiftui": "swiftui"}["-".join(a.build.split("-")[:-1])]
src = open(os.path.join(REPO, "prompts", "round2-%s.md" % stack)).read().split("\n")
stack_line = src[2]
assert stack_line.startswith("Stack: "), stack_line
text = open(os.path.join(REPO, "prompts", "round3.md")).read()
best = json.load(open(os.path.join(HERE, "round3-best.json")))["measures"]
path = os.path.join(REPO, "docs", "round3-baselines.json")
base = json.load(open(path)).get(a.build) if os.path.exists(path) else None
if base is None:
    print("WARNING: no baseline scorecard for %s in docs/round3-baselines.json; the prompt keeps a placeholder" % a.build, file=sys.stderr)
    table, checks, failed_n = "[scorecard: filled in when the baseline pass has run]", "[checks failed: same]", 1
else:
    rows = ["| Measure | Yours | Best seen |", "|---|---|---|"]
    for m in base["measures"]:
        unit = m["unit"]
        v = "full pass only" if m["skipped_in_quick"] else ("not measured" if m["value"] is None else "%s %s" % (scorecard.fmt(m["value"], unit), unit))
        rows.append("| %s | %s | %s %s |" % (m["label"], v, scorecard.fmt(m["best"], unit), unit))
    table = "\n".join(rows)
    failed = base["checks_failed"]
    failed_n = len(failed)
    if failed:
        checks = "Checks failed (%d of 13 pass):\n\n%s" % (base["checks_passed"], "\n".join("- " + c for c in failed))
    else:
        checks = "Checks failed: none. All 13 pass."
text = text.replace("{{STACK_LINE}}", stack_line).replace("{{SCORECARD}}", table).replace("{{CHECKS}}", checks)
text = text.replace("{{FIX_FIRST}}", "- Fix the failed checks first.\n" if failed_n else "")
open(a.out, "w").write(text)
