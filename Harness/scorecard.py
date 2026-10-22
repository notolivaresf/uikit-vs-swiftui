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

# Round 4 (Mac): the same 13 checks, worded for a window (summarize.py --mac stores resize under "resize").
MAC_WORDING = {
    "text_pinned": "The app's own text size (Text size +); changing it keeps the room pinned if it was",
    "text_drift": "The app's own text size (Text size +); changing it keeps the row at the top in place (within 2 pt)",
    "rotate_pinned": "Resizing the window (393 to 852 pt wide and back) keeps the room pinned if it was",
    "rotate_drift": "Resizing the window keeps the row at the top in place (within 2 pt)",
    "context_menu": "Right-click a message: a context menu with Copy and Reply; Copy puts the text on the clipboard",
    "text_selection": "Double-click a word in a message and press Command-C: the word lands on the clipboard",
}


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
    rot = s.get("rotation") or s.get("resize") or {}
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
    if "resize" in s:
        # Round 4 (Codex review, 21 Oct): every reading must hold, not only the median; the window must
        # really have resized; text size must have changed the label each step; the boosts must have landed.
        worst = lambda stat: bool(stat) and stat.get("max") is not None and not stat.get("missing") and stat["max"] <= 2.0
        ts = g(s, "text_size") or {}
        res.update({
            "jump_drift": worst(g(s, "jump", "drift_pt")),
            "older_drift": worst(g(s, "load_older", "drift_pt")),
            "text_pinned": res["text_pinned"] and g(ts, "at_bottom", "label_changed_every_step") == "yes",
            "text_drift": worst(g(ts, "mid_scroll", "drift_pt")) and g(ts, "mid_scroll", "label_changed_every_step") == "yes",
            "rotate_pinned": res["rotate_pinned"] and rot.get("window_really_resized") == "yes",
            "rotate_drift": worst(r2500.get("drift_pt")) and worst(r2500.get("round_trip_drift_pt"))
                            and rot.get("window_really_resized") == "yes",
            "boost_pinned": res["boost_pinned"] and g(s, "boost_burst", "room_moved_so_boosts_landed") == "yes",
        })
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
        ("app_size", "App size", "MB", size_mb if size_mb is not None else s.get("app_size_mb"), "low", False),
    ] + ([("resize_hitch_ms", "Window resize hitch time", "ms", (g(s, "resize", "instruments") or {}).get("hitch_ms"), "low", True)]
         if "resize" in s else [])


SIM_KEYS = ["first40_cold", "first40_repeated", "stream_cpu", "jump", "older", "text_bottom", "text_mid", "memory", "app_size"]


def aggregate(paths, out):
    """Median of each measure over several scorecard.json files (the baseline pass: the same build measured
    a few times). A check counts as failed when it failed in at least half of the runs."""
    import statistics
    runs = [json.load(open(p)) for p in paths]
    base = {"runs": len(runs), "measures": {}, "checks_failed": [], "checks_passed": 0, "checks_total": runs[0]["checks_total"]}
    for i, m in enumerate(runs[0]["measures"]):
        vals = [r["measures"][i]["value"] for r in runs if r["measures"][i]["value"] is not None]
        base["measures"][m["key"]] = {"label": m["label"], "unit": m["unit"], "value": statistics.median(vals) if vals else None,
                                      "values": vals}
    for t in runs[0]["checks_failed"] + [t for r in runs[1:] for t in r["checks_failed"]]:
        if t not in base["checks_failed"] and sum(t in r["checks_failed"] for r in runs) * 2 >= len(runs):
            base["checks_failed"].append(t)
    base["checks_passed"] = base["checks_total"] - len(base["checks_failed"])
    json.dump(base, open(out, "w"), indent=2)


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


# The checks a single number's run can answer (./bench <number>)
RELATED = {"first40_cold": ["first_content"], "first40_repeated": ["first_content"], "jump": ["jump_drift"],
           "older": ["older_drift"], "stream_cpu": ["stream_added", "stream_pinned"], "memory": [],
           "text_bottom": ["text_pinned"], "text_mid": ["text_drift"], "app_size": []}


def only_row(a, s, bl, sim):
    """./bench <number>: one row against the baseline, plus the checks that same run answers."""
    row = [r for r in measures(s, a.app_size_mb) if r[0] == a.only][0]
    key, label, unit, val, direction, _ = row
    b = bl["measures"].get(key, {}).get("value")
    print("%-30s %12s %12s" % ("Measure", "Yours", "Baseline"))
    mark = "" if val is None or b is None else ("better" if val < b else "to beat")
    print("%-30s %12s %12s  %s" % (label, fmt(val, unit) + " " + unit if val is not None else "not measured",
                                   fmt(b, unit) + " " + unit if b is not None else "-", mark))
    checks = evaluate(s, a.stack_rule == "ok")
    if key in ("first40_cold", "first40_repeated"):   # one of the two readings is missing in a single run
        t = g(s, "time_to_40_rows_ms", "cold_app" if key == "first40_cold" else "repeated_app", "median")
        checks["first_content"] = t is not None and t < 1000
    names = dict(CHECKS)
    for c in RELATED[key]:
        print("check: %s: %s" % (names[c], "pass" if checks[c] else "FAIL"))
    if a.stack_rule != "ok":
        print("check: %s: FAIL%s" % (names["stack"], " (" + a.stack_detail + ")" if a.stack_detail else ""))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--summary")
    ap.add_argument("--best")
    ap.add_argument("--sim", action="store_true", help="simulator pass: only the rows a simulator can measure")
    ap.add_argument("--baseline", help="simulator pass: compare with this baseline (from --aggregate) instead of best seen")
    ap.add_argument("--aggregate", nargs="+", help="scorecard.json files -> median baseline, written to --json")
    ap.add_argument("--stack-rule", default="ok")
    ap.add_argument("--stack-detail", default="")
    ap.add_argument("--app-size-mb", type=float)
    ap.add_argument("--locks")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--only", help="simulator pass: print only this measure (a key of SIM_KEYS) and the checks it feeds")
    ap.add_argument("--json")
    ap.add_argument("--markdown", action="store_true")
    a = ap.parse_args()
    if a.aggregate:
        aggregate(a.aggregate, a.json)
        return 0
    s = json.load(open(a.summary))
    sim = a.sim or bool(a.baseline)
    if sim:
        bl = json.load(open(a.baseline)) if a.baseline else {"measures": {k: {"value": None} for k in SIM_KEYS}}
        best = {"measures": {k: {"best": v["value"]} for k, v in bl["measures"].items()}}
    elif a.best:
        best = json.load(open(a.best))
    else:
        # Round 4 (Mac): no earlier Mac numbers, so no best seen yet
        best = {"measures": {}}
    if "resize" in s:
        CHECKS[:] = [(k, MAC_WORDING.get(k, t)) for k, t in CHECKS]
    if a.only:
        return only_row(a, s, bl, sim)
    locks = json.load(open(a.locks)) if a.locks else {"ok": True, "changed": []}
    checks = evaluate(s, a.stack_rule == "ok")
    rows = measures(s, a.app_size_mb)
    failed = [(k, t) for k, t in CHECKS if not checks[k]]

    out = {"quick": a.quick, "locks_ok": locks["ok"], "locks_changed": locks["changed"],
           "checks_passed": sum(1 for v in checks.values() if v), "checks_total": len(CHECKS),
           "checks_failed": [t for _, t in failed], "measures": []}
    lines = []
    if a.markdown:
        lines.append(("| Measure | Yours | Baseline | |\n|---|---|---|---|" if sim else "| Measure | Yours | Best seen | |\n|---|---|---|---|"))
    else:
        lines.append("%-30s %12s %12s" % ("Measure", "Yours", "Baseline" if sim else "Best seen"))
    if sim:
        rows = [r for r in rows if r[0] in SIM_KEYS]
    for key, label, unit, val, direction, full_only in rows:
        b = best["measures"].get(key, {}).get("best")
        skipped = a.quick and full_only and not sim
        hit = None if skipped else met(val, b, direction)
        shown = "full pass only" if skipped else (fmt(val, unit) + " " + unit if val is not None else "not measured")
        bshown = fmt(b, unit) + " " + unit if b is not None else "-"
        if sim:
            mark = "" if val is None or b is None else ("better" if val < b else "to beat")
        else:
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
    if a.quick and not sim:
        lines.append("")
        lines.append("Quick pass: rows marked 'full pass only' (cold launch, fling, stream hitches) need ./bench --full.")
    print("\n".join(lines))
    if a.json:
        json.dump(out, open(a.json, "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
