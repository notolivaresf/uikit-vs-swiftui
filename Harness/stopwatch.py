#!/usr/bin/env python3
"""The common stopwatch's reader (Round 5, 27 Oct). Standard library plus ffmpeg/ffprobe.

  stopwatch.py analyze --dir <stopwatch.sh output> --out stopwatch.json
  stopwatch.py median <stopwatch.json>... --out median.json
  stopwatch.py noise --dir <stopwatch.sh output>      how far apart the marker and a frame step are (resolution)

For every tap on Jump to 2500, Load older and Text size +, the time from the touch to the first frame that shows
its result, read only from the simulator's screen recording:

- touch: the first frame where the harness's touch marker (stopwatch/UVSStopwatch.m, a strip of 8 black or white
  cells at the top of the window) shows this touch's code. The marker is committed before the app sees the touch,
  so its frame is the first frame after the touch, whatever the app then does.
- result: the first frame from which the screen no longer changes until the next touch (or for 3 s), with the
  debug bar's buttons, the status bar and the marker left out. Read for two parts on their own: the room (the
  list and everything else outside the state label) and the state label. The row value is the room's when the
  tap changed the room (jump, text size), else the label's (load older: a build that keeps the top row in place
  changes nothing else on screen). screen_ms (the later of the two) is kept as well.
- ms = (result frame time - touch frame time). Time base 1/600 s; the simulator draws at about 60 frames a second.

The app's own `ms` (app_ms in the tests' UVS_RESULT lines) for the same taps is kept next to it.
"""
import argparse
import json
import operator
import os
import re
import statistics
import subprocess
import sys

TESTS = {
    "testJumpTo2500": ("jump", "Jump to 2500"),
    "testLoadOlder": ("older", "Load older"),
    "testTextSizeAtBottom": ("text_bottom", "Text size +"),
    "testTextSizeMidScroll": ("text_mid", "Text size +"),
}
# Marker geometry (points), as UVSStopwatch.m draws it.
CELLS, CELL_W, CELL_H, TOP = 8, 12, 8, 2
STRIP_W = 2 + CELLS * CELL_W
STATUS_BAR_PT = 54          # left out: the clock and the marker live up here
SCALE_PT = 2                # the compared picture: one pixel per 2 points
SETTLE_WINDOW_S = 3.0
DIFF_LEVEL = 16             # a pixel counts as changed when its grey level moves more than this
CHANGED_PIXELS = 3          # ...and a picture as changed when more than this many pixels did


def probe(video):
    out = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                                   "stream=width,height", "-of", "json", video])
    s = json.loads(out)["streams"][0]
    times = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                                     "frame=pts_time", "-of", "csv=p=0", video]).decode().split()
    return s["width"], s["height"], [float(t.strip(",")) for t in times if t.strip(",")]


def frames(video, vf, w, h):
    """Yields each decoded frame (grey, w x h bytes), every frame the file holds (no frame dropped or doubled)."""
    p = subprocess.Popen(["ffmpeg", "-v", "error", "-i", video, "-vf", vf, "-fps_mode", "passthrough",
                          "-pix_fmt", "gray", "-f", "rawvideo", "-"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    size = w * h
    while True:
        b = p.stdout.read(size)
        if len(b) < size:
            break
        yield b
    p.wait()


def parse_log(path):
    """The tests' log: UVS_RESULT and UVS_LAYOUT lines (each printed once or echoed; kept once by rid / text)."""
    results, layouts, seen = [], [], set()
    for line in open(path, errors="replace"):
        m = re.search(r"UVS_(RESULT|LAYOUT) (\{.*\})\s*$", line)
        if not m:
            continue
        try:
            v = json.loads(m.group(2))
        except ValueError:
            continue
        key = v.get("rid") or m.group(2)
        if key in seen:
            continue
        seen.add(key)
        (results if m.group(1) == "RESULT" else layouts).append(v)
    return results, layouts


def parse_touches(path):
    """[(seq, event_ts, dispatch_ts, label)], per process launch (a list of lists)."""
    runs = []
    for line in open(path, errors="replace"):
        if line.startswith("#"):
            runs.append([])
            continue
        parts = line.rstrip("\n").split(" ", 3)
        if len(parts) < 4:
            continue
        if not runs:
            runs.append([])
        runs[-1].append((int(parts[0]), float(parts[1]), float(parts[2]), parts[3]))
    return runs


def app_ms_values(results, test):
    vals = []
    for r in results:
        if r.get("test") != test:
            continue
        if "steps" in r:
            vals += [s.get("app_ms") for s in r["steps"]]
        else:
            vals.append(r.get("app_ms"))
    return vals


def decode_codes(video, w, h, scale, win_w_pt):
    """Per frame: the marker's code (0-255), or None where no marker is on screen."""
    x0 = int((win_w_pt - STRIP_W) // 2)
    cw, ch = int(STRIP_W * scale), int((CELL_H + 4) * scale)
    cx, cy = int(x0 * scale), int(TOP * scale)
    codes = []
    for b in frames(video, "crop=%d:%d:%d:%d" % (cw, ch, cx, cy), cw, ch):
        def px(xp, yp):
            xs, ys = int(xp * scale), int(yp * scale)
            vals = [b[(ys + dy) * cw + xs + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)]
            return sum(vals) / len(vals)
        # The red frame (grey about 50 to 90) around the cells says the marker is there.
        border = px(1, (CELL_H + 4) / 2)
        if not 30 <= border <= 120:
            codes.append(None)
            continue
        code, ok = 0, True
        for i in range(CELLS):
            v = px(2 + i * CELL_W + (CELL_W - 2) / 2, 2 + CELL_H / 2)
            if 60 < v < 190:
                ok = False
            code = (code << 1) | (1 if v >= 128 else 0)
        codes.append(code if ok else None)
    return codes


def region_masks(layout, w_s, h_s, win):
    """Two lists of byte offsets in the scaled picture: the list part and the label part."""
    def to_s(r):
        x, y, ww, hh = r
        return (int((x - win[0]) / SCALE_PT) - 1, int((y - win[1]) / SCALE_PT) - 1,
                int((x - win[0] + ww) / SCALE_PT) + 2, int((y - win[1] + hh) / SCALE_PT) + 2)
    buttons = [to_s(r) for r in layout.get("buttons") or []]
    label = to_s(layout["label"]) if layout.get("label") else None
    top = int(STATUS_BAR_PT / SCALE_PT)
    content, lab = [], []
    for y in range(h_s):
        for x in range(w_s):
            if label and label[0] <= x < label[2] and label[1] <= y < label[3]:
                lab.append(y * w_s + x)
                continue
            if y < top or any(b[0] <= x < b[2] and b[1] <= y < b[3] for b in buttons):
                continue
            content.append(y * w_s + x)
    return content, lab


def changed(a, b, idx):
    """How many pixels of the region moved more than DIFF_LEVEL grey levels between two pictures."""
    if a is b:
        return 0
    ga = operator.itemgetter(*idx)
    n = 0
    for d in map(operator.sub, ga(a), ga(b)):
        if d > DIFF_LEVEL or d < -DIFF_LEVEL:
            n += 1
    return n


def settle_frame(pics, start, end, idx):
    """Index of the first frame in (start, end] from which the region equals the end frame; None if it never
    differs from it (the tap changed nothing there)."""
    final = pics[end]
    last_diff = None
    for i in range(start, end + 1):
        if changed(pics[i], final, idx) > CHANGED_PIXELS:
            last_diff = i
    if last_diff is None:
        return None
    return last_diff + 1


def analyze_test(d, test):
    video = os.path.join(d, test + ".mp4")
    log = os.path.join(d, test + ".test.log")
    touches = os.path.join(d, test + ".touches.log")
    if not (os.path.exists(video) and os.path.exists(log) and os.path.exists(touches)):
        return {"error": "missing video, test log or touch log"}
    results, layouts = parse_log(log)
    layout = next((l for l in reversed(layouts) if l.get("test", "").endswith(test + "]")), layouts[-1] if layouts else None)
    if not layout or not layout.get("window"):
        return {"error": "no layout line in the test log"}
    win = layout["window"]
    w, h, times = probe(video)
    scale = w / win[2]
    codes = decode_codes(video, w, h, scale, win[2])
    n = min(len(codes), len(times))
    codes, times = codes[:n], times[:n]
    w_s, h_s = int(win[2] / SCALE_PT), int(win[3] / SCALE_PT)
    pics = list(frames(video, "scale=%d:%d:flags=area" % (w_s, h_s), w_s, h_s))[:n]
    content_idx, label_idx = region_masks(layout, w_s, h_s, win)

    # Touches in video order: a frame whose code differs from the frame before.
    marks = []
    for i in range(1, n):
        if codes[i] is not None and codes[i] != codes[i - 1]:
            marks.append(i)
    if codes and codes[0] is not None:
        marks.insert(0, 0)
    # Line them up with the touch log by code (seq mod 256), in order.
    logged = [t for run in parse_touches(touches) for t in run]
    want_label = TESTS[test][1]
    taps, li = [], 0
    for mi, f in enumerate(marks):
        while li < len(logged) and logged[li][0] % 256 != codes[f]:
            li += 1
        if li >= len(logged):
            break
        seq, ev, disp, label = logged[li]
        li += 1
        # The window ends at the next touch's frame, at 3 s, or where the marker goes away (the app quit).
        end = marks[mi + 1] - 1 if mi + 1 < len(marks) else n - 1
        while end > f and times[end] - times[f] > SETTLE_WINDOW_S:
            end -= 1
        while end > f and codes[end] is None:
            end -= 1
        taps.append({"seq": seq, "label": label, "frame": f, "end": end, "dispatch_lag_ms": (disp - ev) * 1000})
    timed = [t for t in taps if t["label"] == want_label]
    app_ms = app_ms_values(results, test)
    out = []
    for k, t in enumerate(timed):
        f, end = t["frame"], t["end"]
        c = settle_frame(pics, f, end, content_idx)
        l = settle_frame(pics, f, end, label_idx)
        both = [x for x in (c, l) if x is not None]
        r = c if c is not None else l
        screen = max(both) if both else None
        ms = lambda x: round((times[x] - times[f]) * 1000, 1) if x is not None and x < n else None
        out.append({"seq": t["seq"], "ms": ms(r), "list_ms": ms(c), "label_ms": ms(l), "screen_ms": ms(screen),
                    "touch_s": round(times[f], 4), "settle_window_s": round(times[end] - times[f], 3),
                    "dispatch_lag_ms": round(t["dispatch_lag_ms"], 2),
                    "app_ms": app_ms[k] if k < len(app_ms) else None})
    steps = [round((times[i] - times[i - 1]) * 1000, 2) for i in range(1, n)]
    return {"taps": out, "touches_seen": len(taps), "app_ms_readings": len(app_ms), "frames": n,
            "frame_step_ms_median": statistics.median(steps) if steps else None,
            "video_px": [w, h], "window_pt": win}


def med(vals):
    v = [x for x in vals if x is not None]
    return statistics.median(v) if v else None


def analyze(d, out_path):
    res = {"dir": os.path.basename(os.path.normpath(d)), "rows": {}}
    for test, (key, _) in TESTS.items():
        if not os.path.exists(os.path.join(d, test + ".mp4")):
            continue
        r = analyze_test(d, test)
        taps = r.get("taps", [])
        r["median_ms"] = med([t["ms"] for t in taps])
        r["median_app_ms"] = med([t["app_ms"] for t in taps])
        r["median_list_ms"] = med([t["list_ms"] for t in taps])
        r["median_label_ms"] = med([t["label_ms"] for t in taps])
        r["median_screen_ms"] = med([t["screen_ms"] for t in taps])
        r["median_dispatch_lag_ms"] = med([t["dispatch_lag_ms"] for t in taps])
        res["rows"][key] = r
    json.dump(res, open(out_path, "w"), indent=2)
    for key, r in res["rows"].items():
        print("%-12s stopwatch %s ms  (list %s, label %s)  app-reported %s ms  taps %d" % (
            key, r.get("median_ms"), r.get("median_list_ms"), r.get("median_label_ms"), r.get("median_app_ms"),
            len(r.get("taps", []))))
    return 0


def median_of(paths, out_path):
    runs = [json.load(open(p)) for p in paths]
    res = {"passes": len(runs), "rows": {}}
    for key in ["jump", "older", "text_bottom", "text_mid"]:
        vals = [r["rows"].get(key, {}).get("median_ms") for r in runs]
        app = [r["rows"].get(key, {}).get("median_app_ms") for r in runs]
        res["rows"][key] = {"stopwatch_ms": med(vals), "stopwatch_passes": vals,
                            "app_ms": med(app), "app_passes": app}
    json.dump(res, open(out_path, "w"), indent=2)
    print(json.dumps(res, indent=2))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["analyze", "median"])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--dir")
    ap.add_argument("--out")
    a = ap.parse_args()
    if a.cmd == "analyze":
        return analyze(a.dir, a.out)
    return median_of(a.files, a.out)


if __name__ == "__main__":
    sys.exit(main())
