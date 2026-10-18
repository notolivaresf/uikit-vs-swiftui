#!/usr/bin/env python3
"""Helpers for Harness/record.sh: find the app's pid on the phone, and turn one round's xcresult and traces
into summary.json. Standard library only."""
import argparse
import json
import statistics
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


# ---------------------------------------------------------------- pid of the app on the phone

def installed_executable(device, bundle):
    """File path of the installed app's executable, from `devicectl device info apps`."""
    out = Path("/tmp") / "uvs-apps.json"
    subprocess.run(["xcrun", "devicectl", "device", "info", "apps", "--device", device, "--bundle-id", bundle,
                    "--json-output", str(out)], capture_output=True)
    try:
        apps = json.loads(out.read_text())["result"]["apps"]
        return apps[0]["url"].rstrip("/")
    except Exception:
        return None


def cmd_pid(args):
    base = installed_executable(args.device, args.bundle)
    procs_path = args.procs
    if not procs_path:
        procs_path = str(Path("/tmp") / "uvs-procs.json")
        subprocess.run(["xcrun", "devicectl", "device", "info", "processes", "--device", args.device,
                        "--json-output", procs_path], capture_output=True)
    try:
        procs = json.loads(Path(procs_path).read_text())["result"]["runningProcesses"]
    except Exception:
        return
    for p in procs:
        exe = p.get("executable", "")
        if base and base in exe:
            print(p["processIdentifier"])
            return


# ---------------------------------------------------------------- trace export

def export(trace, xpath):
    """Runs xctrace export and returns the XML root, with `ref` attributes resolved to the element they point at."""
    text = run(["xcrun", "xctrace", "export", "--input", str(trace), "--xpath", xpath])
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        return None
    by_id = {e.get("id"): e for e in root.iter() if e.get("id")}
    for e in root.iter():
        r = e.get("ref")
        if r and r in by_id:
            src = by_id[r]
            e.text, e.attrib = src.text, {**src.attrib, **{k: v for k, v in e.attrib.items() if k != "ref"}}
            e.extend(list(src))
    return root


def table(trace, schema):
    """Rows of a table as lists of (tag, text, fmt)."""
    root = export(trace, f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]')
    if root is None:
        return []
    return [[(c.tag, c.text, c.get("fmt")) for c in row] for row in root.iter("row")]


def launch_ms(trace):
    """Cold launch: from process creation to the end of the initial frame rendering, which is where the
    "Foreground - Active" period starts (App Launch template, life-cycle-period table)."""
    for row in table(trace, "life-cycle-period"):
        for tag, text, fmt in row:
            if tag == "app-period" and fmt and fmt.startswith("Foreground - Active"):
                start = float(row[0][1])
                return round(start / 1e6, 1)
    return None


def _num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def frame_rows(trace):
    """(start ns, end ns) of every frame in hitches-frame-lifetimes."""
    out = []
    for r in table(trace, "hitches-frame-lifetimes"):
        if len(r) > 1:
            st, du = _num(r[0][1]), _num(r[1][1])
            if st is not None and du is not None:
                out.append((st, st + du))
    return sorted(out)


def hitch_rows(trace):
    """(start ns, duration ms) of every hitch."""
    out = []
    for r in table(trace, "hitches"):
        if len(r) > 1:
            st, du = _num(r[0][1]), _num(r[1][1])
            if st is not None and du is not None:
                out.append((st, du / 1e6))
    return out


def scroll_intervals(trace):
    """UIKit's own scroll intervals (os_signpost "Scroll_Dragging" / "Scroll_Deceleration", the ones
    XCTOSSignpostMetric uses) as merged (start ns, end ns) pairs. Empty when the trace has no os_signpost data."""
    spans = []
    for r in table(trace, "os-signpost-interval"):
        cells = {tag: text for tag, text, _ in r}
        name = " ".join(t or "" for tag, t, _ in r if tag in ("string", "signpost-name", "name"))
        if "Scroll" not in name and "scroll" not in name:
            continue
        st, du = _num(r[0][1]), _num(r[1][1])
        if st is not None and du is not None and du > 0:
            spans.append((st, st + du))
    spans.sort()
    merged = []
    for st, en in spans:
        if merged and st <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], en))
        else:
            merged.append((st, en))
    return merged


def longest_segment(frames, gap_s=1.5):
    """Frames split where nothing was drawn for gap_s or more; the longest stretch, as one interval. The trace
    scenarios idle a few seconds before and after, so this is the scenario itself (the 30 s stream)."""
    if not frames:
        return []
    segs, cur = [], [frames[0][0], frames[0][1]]
    for st, en in frames[1:]:
        if st - cur[1] >= gap_s * 1e9:
            segs.append(tuple(cur)); cur = [st, en]
        else:
            cur[1] = max(cur[1], en)
    segs.append(tuple(cur))
    return [max(segs, key=lambda s: s[1] - s[0])]


def hitches(trace, window="scroll"):
    """Frames, hitches, hitch time ratio and fps, counted only inside the measured intervals.

    window "scroll": while a scroll moves (UIKit's scroll signposts), so the gaps between swipes don't count.
    window "segment": the longest stretch of drawing (the live stream from its first to its last frame).
    Falls back to "segment" when a trace has no scroll signposts, and says which it used."""
    frames = frame_rows(trace)
    if not frames:
        return None
    used = window
    spans = scroll_intervals(trace) if window == "scroll" else []
    if not spans:
        spans = longest_segment(frames)
        used = "segment" if window == "segment" else "segment (no scroll signposts)"
    inside = lambda t: any(a <= t < b for a, b in spans)
    window_s = sum(b - a for a, b in spans) / 1e9
    n = sum(1 for st, _ in frames if inside(st))
    durs = [d for st, d in hitch_rows(trace) if inside(st)]
    total_ms = sum(durs)
    return {
        "window": used,
        "intervals": len(spans),
        "frames": n,
        "window_s": round(window_s, 2),
        "fps": round(n / window_s, 1) if window_s else None,
        "hitches": len(durs),
        "hitch_ms": round(total_ms, 1),
        "hitch_time_ratio_ms_per_s": round(total_ms / window_s, 2) if window_s else None,
        "frames_in_trace": len(frames),
    }


def allocations(trace):
    """Allocations trace: live heap and anonymous VM at the end of the recording, in MB."""
    root = export(trace, '/trace-toc/run[@number="1"]/tracks/track[@name="Allocations"]/details/detail[@name="Statistics"]')
    if root is None:
        return None
    for row in root.iter("row"):
        if row.get("category") == "All Heap & Anonymous VM":
            return {"live_mb_at_end": round(int(row.get("persistent-bytes")) / 1048576, 1),
                    "allocated_mb_total": round(int(row.get("total-bytes")) / 1048576, 1)}
    return None


# ---------------------------------------------------------------- xcresult metrics

def xctest_metrics(xcresult):
    """Median across iterations of every metric of every test, from `xcresulttool get test-results metrics`.
    Returns {test name: {metric name (unit): median}}."""
    text = run(["xcrun", "xcresulttool", "get", "test-results", "metrics", "--path", str(xcresult)])
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return {}
    out = {}
    for test in data if isinstance(data, list) else data.get("tests", []):
        name = (test.get("testIdentifier") or test.get("testName") or "?").split("/")[-1].replace("()", "")
        metrics = {}
        for run_ in test.get("testRuns", []):
            for m in run_.get("metrics", []):
                vals = [float(x) for x in m.get("measurements", [])]
                if vals:
                    metrics[f'{m.get("displayName")} ({m.get("unitOfMeasurement")})'] = {
                        "median": statistics.median(vals), "min": min(vals), "max": max(vals), "n": len(vals)}
        out[name] = metrics
    return out


def pick(metrics, test, *needles, convert=1.0):
    """Median of the first metric of `test` whose name contains all needles."""
    for name, v in metrics.get(test, {}).items():
        if all(n.lower() in name.lower() for n in needles):
            return round(v["median"] * convert, 3)
    return None


def hitch_metrics(metrics, test):
    """Every XCTHitchMetric reading of a test (names and units as Xcode reports them), medians only."""
    return {n: v["median"] for n, v in metrics.get(test, {}).items() if "hitch" in n.lower()}


def to_ms(metrics, test, *needles):
    for name, v in metrics.get(test, {}).items():
        if all(n.lower() in name.lower() for n in needles):
            unit = name.rsplit("(", 1)[-1].rstrip(")").lower()
            factor = {"s": 1000, "sec": 1000, "seconds": 1000, "ms": 1, "milliseconds": 1}.get(unit, 1000)
            return round(v["median"] * factor, 1)
    return None


def results(log):
    """Every `UVS_RESULT {json}` line the tests printed, grouped by test: {test: [values, ...]} (one per iteration)."""
    out = {}
    if not Path(log).exists():
        return out
    seen = set()
    for line in Path(log).read_text(errors="replace").splitlines():
        i = line.find("UVS_RESULT ")
        if i < 0:
            continue
        body = line[i + len("UVS_RESULT "):].strip()
        if body in seen:          # xcodebuild sometimes echoes a line twice
            continue
        try:
            v = json.loads(body)
        except json.JSONDecodeError:
            continue
        seen.add(body)
        out.setdefault(v.pop("test", "?"), []).append(v)
    return out


def med(values):
    vals = [float(v) for v in values if isinstance(v, (int, float)) and not isinstance(v, bool)]
    return round(statistics.median(vals), 1) if vals else None


def stats(values):
    """median, max and count of the numbers in values; None entries (no reading) are counted as missing."""
    vals = [float(v) for v in values if isinstance(v, (int, float)) and not isinstance(v, bool)]
    return {"median": round(statistics.median(vals), 1) if vals else None,
            "max": round(max(vals), 1) if vals else None,
            "n": len(vals), "missing": len(values) - len(vals)}


def all_true(values):
    """"yes" when every reading is true, "no" when every one is false, else "k of n"."""
    b = [bool(v) for v in values if isinstance(v, bool)]
    if not b:
        return None
    if all(b):
        return "yes"
    return "no" if not any(b) else f"{sum(b)} of {len(b)}"


def steps(rs, key):
    return [st.get(key) for r in rs for st in r.get("steps", [])]


def cmd_summary(args):
    d = Path(args.dir)
    m = xctest_metrics(d / "bench.xcresult") if (d / "bench.xcresult").exists() else {}
    r = results(d / "logs" / "suite.log")
    get = lambda test, key: [x.get(key) for x in r.get(test, [])]
    tr = lambda name, window: hitches(d / f"{name}.trace", window) if (d / f"{name}.trace").exists() else None
    mem = lambda needle: pick(m, "testMemory", needle, convert=1/1000)
    s = {
        "device": "iPhone 12, iOS 26.0",
        "iterations_per_test": 5,
        "launch_ms": {
            "instruments_app_launch": launch_ms(d / "launch.trace") if (d / "launch.trace").exists() else None,
            "xctest_launch": to_ms(m, "testLaunch", "duration") or to_ms(m, "testLaunch", "launch"),
        },
        "time_to_40_rows_ms": {"app": stats(get("testTimeTo40Rows", "app_ms")),
                               "xctest_clock_upper_bound": to_ms(m, "testTimeTo40Rows", "clock")},
        "fling": {
            "instruments_while_scrolling": tr("fling", "scroll"),
            "xctest_fps_deceleration": pick(m, "testFling", "frame rate", "deceleration"),
            "xctest_fps_dragging": pick(m, "testFling", "frame rate", "dragging"),
            "xctest_hitch_metrics": hitch_metrics(m, "testFling"),
            "cpu_s": pick(m, "testFling", "cpu time"),
        },
        "jump": {"app_ms": stats(get("testJumpTo2500", "app_ms")),
                 "drift_pt": stats(get("testJumpTo2500", "drift_pt")),
                 "xctest_clock_upper_bound_ms": to_ms(m, "testJumpTo2500", "clock")},
        "load_older": {"app_ms": stats(get("testLoadOlder", "app_ms")),
                       "drift_pt": stats(get("testLoadOlder", "drift_pt")),
                       "xctest_clock_upper_bound_ms": to_ms(m, "testLoadOlder", "clock")},
        "stream": {
            "instruments_stream_window": tr("stream", "segment"),
            "xctest_hitch_metrics": hitch_metrics(m, "testLiveStream"),
            "ends_pinned": all_true(get("testLiveStream", "pinned")),
            "cpu_s": pick(m, "testLiveStream", "cpu time"),
        },
        "text_size": {
            "at_bottom": {"relayout_ms": stats(steps(r.get("testTextSizeAtBottom", []), "app_ms")),
                          "stays_pinned": all_true(steps(r.get("testTextSizeAtBottom", []), "pinned")),
                          "xctest_hitch_metrics": hitch_metrics(m, "testTextSizeAtBottom")},
            "mid_scroll": {"relayout_ms": stats(steps(r.get("testTextSizeMidScroll", []), "app_ms")),
                           "drift_pt": stats(steps(r.get("testTextSizeMidScroll", []), "drift_pt")),
                           "xctest_hitch_metrics": hitch_metrics(m, "testTextSizeMidScroll")},
        },
        "rotation": {
            "at_bottom": {"stays_pinned": all_true(get("testRotationAtBottom", "pinned_landscape") +
                                                   get("testRotationAtBottom", "pinned_portrait")),
                          "xctest_hitch_metrics": hitch_metrics(m, "testRotationAtBottom")},
            "at_2500": {"drift_pt": stats(get("testRotationAt2500", "drift_landscape_pt") +
                                          get("testRotationAt2500", "drift_portrait_pt")),
                        "round_trip_drift_pt": stats(get("testRotationAt2500", "drift_round_trip_pt")),
                        "xctest_hitch_metrics": hitch_metrics(m, "testRotationAt2500")},
        },
        "boost_burst": {"stays_pinned": all_true(get("testBoostBurst", "pinned")),
                        "xctest_hitch_metrics": hitch_metrics(m, "testBoostBurst")},
        "text_selection_and_context_menu": {
            "context_menu": all_true(get("testTextSelectionAndContextMenu", "context_menu")),
            "text_selection": all_true(get("testTextSelectionAndContextMenu", "text_selection")),
        },
        "memory_mb": {
            "peak_footprint": mem("memory peak physical"),
            "growth_over_scenario": next((round(v["median"] / 1000, 3) for n, v in m.get("testMemory", {}).items()
                                          if n.lower().startswith("memory physical (")), None),
            "footprint_at_end": mem("absolute memory physical"),
            "instruments_allocations_from_launch": allocations(d / "memory.trace") if (d / "memory.trace").exists() else None,
        },
        "drift_note": "drift_pt missing = a different row ended up at the top (moved by at least a row)",
        "all_xctest_metrics": m,
        "all_results": r,
    }
    Path(args.out).write_text(json.dumps(s, indent=2) + "\n")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("pid"); p.add_argument("--procs"); p.add_argument("--device"); p.add_argument("--bundle")
    s = sub.add_parser("summary"); s.add_argument("--dir"); s.add_argument("--out")
    a = ap.parse_args()
    {"pid": cmd_pid, "summary": cmd_summary}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
