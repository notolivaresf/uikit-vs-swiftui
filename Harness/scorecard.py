#!/usr/bin/env python3
"""Round 3 scorecard: turns one summary.json (Harness/summarize.py) into the measures, the best value seen on
this phone, and the 13 pass/fail checks. Standard library only.

  scorecard.py --summary summary.json --best round3-best.json --stack-rule ok|FAIL [--stack-detail TEXT]
               [--app-size-mb N] [--locks locks-result.json] [--quick] [--json out.json] [--markdown]

Best seen is the best value any of the ten Round 1 and Round 2 builds reached on the iPhone 12
(docs/optimal-gap-round2.md). Only the numbers are printed, never which build set them.
"""
import argparse
import json
import sys

# The 13 checks, worded as PROMPT.md words the behaviour (the stack rule is the stack line of the prompt).
CHECKS = [
    ("stack", "Stack rule: the build stays inside its stack line"),
    ("first_content", "Open on the newest 40 of the 50,000 messages, at the bottom; first content within 1 s"),
    ("jump_drift", "\"Jump to 2500\" puts message 2,500's top just under the header, within 2 pt"),
    ("older_drift", "Reaching the top loads 40 older messages; the message you were looking at stays put (within 2 pt)"),
    ("stream_added", "New messages come only from the live stream: all 600 arrive"),
    ("stream_pinned", "If the last row is within 100 pt of the bottom, stay pinned (after the stream)"),
    ("text_pinned", "Text size follows Dynamic Type; changing it keeps the room pinned if it was"),
    ("text_drift", "Text size follows Dynamic Type; changing it keeps the row at the top in place (within 2 pt)"),
    ("rotate_pinned", "Rotating keeps the room pinned if it was"),
    ("rotate_drift", "Rotating keeps the row at the top in place (within 2 pt)"),
    ("boost_pinned", "A row can change after it shows: new boosts make it grow, and the room stays pinned or in place"),
    ("context_menu", "Long-press a message: show a context menu with Copy and Reply"),
    ("text_selection", "Long-press a message: select any range of its text and copy it. The harness recognises selection by the system's text-selection menu (Look Up, Translate, Select All...) appearing after a long press or a double tap on the text"),
]


def g(d, *path):
    for p in path:
        if not isinstance(d, dict) or p not in d:
            return None
        d = d[p]
    return d


def ok_drift(stat):
    """A drift reading passes when it exists and its median is within 2 pt; a missing reading (another row
    ended up on top) fails."""
    if not stat or stat.get("median") is None or stat.get("missing"):
        return False
    return stat["median"] <= 2.0


def evaluate(s, stack_ok):
    first = g(s, "time_to_40_rows_ms", "cold_app", "median")
    first_rep = g(s, "time_to_40_rows_ms", "repeated_app", "median")
    rot = s.get("rotation", {})
    r2500 = rot.get("at_2500", {})
    sel = s.get("text_selection_and_context_menu", {})
    res = {
        "stack": stack_ok,
        "first_content": first is not None and first < 1000 and (first_rep is None or first_rep < 1000),
        "jump_drift": ok_drift(g(s, "jump", "drift_pt")),
        "older_drift": ok_drift(g(s, "load_older", "drift_pt")),
        "stream_added": (g(s, "stream", "messages_added", "median") or 0) >= 600,
        "stream_pinned": g(s, "stream", "ends_pinned") == "yes",
        "text_pinned": g(s, "text_size", "at_bottom", "stays_pinned") == "yes",
        "text_drift": ok_drift(g(s, "text_size", "mid_scroll", "drift_pt")),
        "rotate_pinned": g(rot, "at_bottom", "stays_pinned") == "yes",
        "rotate_drift": ok_drift(r2500.get("drift_pt")) and ok_drift(r2500.get("round_trip_drift_pt")),
        "boost_pinned": g(s, "boost_burst", "stays_pinned") == "yes",
        "context_menu": sel.get("context_menu") == "yes",
        "text_selection": sel.get("text_selection") == "yes",
    }
    return res


def measures(s, size_mb):
    """(key, label, unit, value, direction, full_only)"""
    st = g(s, "stream", "instruments_tap_to_stream_done") or {}
    fl = g(s, "fling", "instruments") or {}
    return [
        ("first40_cold", "First 40 rows, cold", "ms", g(s, "time_to_40_rows_ms", "cold_app", "median"), "low", False),
        ("first40_repeated", "First 40 rows, repeated", "ms", g(s, "time_to_40_rows_ms", "repeated_app", "median"), "low", False),
        ("cold_launch", "Cold launch (Instruments)", "ms", g(s, "launch_ms", "cold_instruments_app_launch", "median"), "low", True),
        ("fling_fps", "Fling speed", "fps", fl.get("fps"), "high", True),
        ("fling_hitch_ms", "Fling hitch time", "ms", fl.get("hitch_ms"), "low", True),
        ("stream_hitch_ms", "Stream hitch time", "ms", st.get("hitch_ms"), "low", True),
        ("stream_cpu", "Stream CPU", "s", g(s, "stream", "cpu_s"), "low", False),
        ("jump", "Jump to message 2,500", "ms", g(s, "jump", "app_ms", "median"), "low", False),
        ("older", "Load older", "ms", g(s, "load_older", "app_ms", "median"), "low", False),
        ("text_bottom", "Text size, at the bottom", "ms", g(s, "text_size", "at_bottom", "relayout_ms", "median"), "low", False),
        ("text_mid", "Text size, mid-list", "ms", g(s, "text_size", "mid_scroll", "relayout_ms", "median"), "low", False),
        ("memory", "Peak memory", "MB", g(s, "memory_mb", "peak_footprint"), "low", False),
        ("app_size", "App size", "MB", size_mb, "low", False),
    ]


def met(value, best, direction):
    if value is None or best is None:
        return None
    return value >= best if direction == "high" else value <= best


def fmt(v, unit):
    if v is None:
        return "-"
    if unit == "MB" or unit == "s":
        return "%.2f" % v if unit == "MB" and v < 10 else "%.1f" % v
    if unit == "fps":
        return "%.1f" % v
    return "%d" % round(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--summary", required=True)
    ap.add_argument("--best", required=True)
    ap.add_argument("--stack-rule", default="ok")
    ap.add_argument("--stack-detail", default="")
    ap.add_argument("--app-size-mb", type=float)
    ap.add_argument("--locks")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--json")
    ap.add_argument("--markdown", action="store_true")
    a = ap.parse_args()
    s = json.load(open(a.summary))
    best = json.load(open(a.best))
    locks = json.load(open(a.locks)) if a.locks else {"ok": True, "changed": []}
    checks = evaluate(s, a.stack_rule == "ok")
    rows = measures(s, a.app_size_mb)
    failed = [(k, t) for k, t in CHECKS if not checks[k]]

    out = {"quick": a.quick, "locks_ok": locks["ok"], "locks_changed": locks["changed"],
           "checks_passed": sum(1 for v in checks.values() if v), "checks_total": len(CHECKS),
           "checks_failed": [t for _, t in failed], "measures": []}
    lines = []
    if a.markdown:
        lines.append("| Measure | Yours | Best seen | |\n|---|---|---|---|")
    else:
        lines.append("%-30s %12s %12s" % ("Measure", "Yours", "Best seen"))
    for key, label, unit, val, direction, full_only in rows:
        b = best["measures"][key]["best"]
        skipped = a.quick and full_only
        hit = None if skipped else met(val, b, direction)
        shown = "full pass only" if skipped else (fmt(val, unit) + " " + unit if val is not None else "not measured")
        bshown = fmt(b, unit) + " " + unit
        mark = "" if hit is None else ("at or better" if hit else "to beat")
        out["measures"].append({"key": key, "label": label, "unit": unit, "value": None if skipped else val,
                                "best": b, "met": hit, "skipped_in_quick": skipped})
        if a.markdown:
            lines.append("| %s | %s | %s | %s |" % (label, shown, bshown, mark))
        else:
            lines.append("%-30s %12s %12s  %s" % (label, shown, bshown, mark))
    lines.append("")
    lines.append("Checks passed: %d of %d" % (out["checks_passed"], out["checks_total"]))
    if failed:
        lines.append("Checks failed:")
        for k, t in failed:
            detail = (" (" + a.stack_detail + ")") if k == "stack" and a.stack_detail else ""
            lines.append("  - " + t + detail)
    if not locks["ok"]:
        lines.insert(0, "NOT A VALID SCORE: locked files changed: " + ", ".join(locks["changed"]) +
                     "\n(Restore them; the numbers below do not count.)\n")
    if a.quick:
        lines.append("")
        lines.append("Quick pass: rows marked 'full pass only' (cold launch, fling, stream hitches) need ./bench --full.")
    print("\n".join(lines))
    if a.json:
        json.dump(out, open(a.json, "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
