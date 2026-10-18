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
    try:
        procs = json.loads(Path(args.procs).read_text())["result"]["runningProcesses"]
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


def hitches(trace):
    """Animation Hitches trace: frames drawn, hitch count, total hitch time, hitch time ratio, fps.

    Frames come from hitches-frame-lifetimes (one row per frame), hitches from the hitches table (one row per
    hitch; the duration is the time over budget). The window is first frame start to last frame end, so idle
    time before and after the scenario does not dilute the ratio."""
    frames = table(trace, "hitches-frame-lifetimes")
    hs = table(trace, "hitches")
    if not frames:
        return None
    starts = [float(r[0][1]) for r in frames if r and r[0][1] not in (None, "")]
    ends = [float(r[0][1]) + float(r[1][1]) for r in frames if len(r) > 1 and r[1][1] not in (None, "")]
    window_s = (max(ends) - min(starts)) / 1e9 if starts and ends else 0
    durs = [float(r[1][1]) / 1e6 for r in hs if len(r) > 1 and r[1][1] not in (None, "")]
    total_ms = sum(durs)
    return {
        "frames": len(frames),
        "window_s": round(window_s, 2),
        "fps": round(len(frames) / window_s, 1) if window_s else None,
        "hitches": len(durs),
        "hitch_ms": round(total_ms, 1),
        "hitch_time_ratio_ms_per_s": round(total_ms / window_s, 2) if window_s else None,
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


def to_ms(metrics, test, *needles):
    for name, v in metrics.get(test, {}).items():
        if all(n.lower() in name.lower() for n in needles):
            unit = name.rsplit("(", 1)[-1].rstrip(")").lower()
            factor = {"s": 1000, "sec": 1000, "seconds": 1000, "ms": 1, "milliseconds": 1}.get(unit, 1000)
            return round(v["median"] * factor, 1)
    return None


def cmd_summary(args):
    d = Path(args.dir)
    m = xctest_metrics(d / "bench.xcresult") if (d / "bench.xcresult").exists() else {}
    s = {
        "device": "iPhone 12, iOS 26.0",
        "iterations_per_test": 5,
        "launch_ms": {
            "instruments_app_launch": launch_ms(d / "launch.trace") if (d / "launch.trace").exists() else None,
            "xctest_launch": to_ms(m, "testLaunch", "duration") or to_ms(m, "testLaunch", "launch"),
        },
        "time_to_40_rows_ms": to_ms(m, "testTimeTo40Rows", "clock"),
        "fling": {
            "xctest_fps": pick(m, "testFling", "frame rate"),
            "xctest_hitch_time_ratio": pick(m, "testFling", "hitch time ratio"),
            "xctest_hitches_ms": pick(m, "testFling", "hitch", "duration"),
            "instruments": hitches(d / "fling.trace") if (d / "fling.trace").exists() else None,
        },
        "jump_ms": to_ms(m, "testJumpTo2500", "clock"),
        "load_older_ms": to_ms(m, "testLoadOlder", "clock"),
        "stream": {
            "xctest_fps": pick(m, "testLiveStream", "frame rate"),
            "xctest_hitch_time_ratio": pick(m, "testLiveStream", "hitch time ratio"),
            "instruments": hitches(d / "stream.trace") if (d / "stream.trace").exists() else None,
        },
        "peak_memory_mb": {
            "xctest_peak_physical": {t: pick(m, t, "memory", "peak") for t in
                                     ("testLaunch", "testFling", "testJumpTo2500", "testLoadOlder", "testLiveStream")},
            "instruments_allocations": allocations(d / "memory.trace") if (d / "memory.trace").exists() else None,
        },
        "all_xctest_metrics": m,
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
