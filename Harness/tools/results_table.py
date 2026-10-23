#!/usr/bin/env python3
"""Render the README results table to docs/images/results-round1.png (light) and results-round1-dark.png.

Data is in ROWS below. Cell state: ok (green), bad (red), warn (yellow), none (plain).
best=True marks the best number in a row: bold text and a thin darker border.
Usage: python3 Harness/tools/results_table.py
       python3 Harness/tools/results_table.py --round2   (Round 2 only: docs/images/results-round2.png and -dark.png)
       python3 Harness/tools/results_table.py --round2-best3   (best of each stack's two builds, three columns: results-round2-best3.png and -dark.png)
       python3 Harness/tools/results_table.py --round2-gap   (Round 2 distance from optimal: optimal-gap-round2.png and -dark.png)
       python3 Harness/tools/results_table.py --round2-best   (best UIKit vs best SwiftUI of Round 2: results-round2-best.png and -dark.png)
       python3 Harness/tools/results_table.py --swiftui-3way   (best SwiftUI build per row: Round 1, Apple skills, @twannl's skills; 16:9: results-swiftui-3way.png and -dark.png)
       python3 Harness/tools/results_table.py --swiftui-skills   (same, only Apple skills against @twannl's skills: results-swiftui-skills.png and -dark.png, 4:5 portrait)
       python3 Harness/tools/results_table.py --uikit-vs-swiftui-skills   (Best UIKit against the two SwiftUI skill sets, 4:5: results-uikit-vs-swiftui-skills.png and -dark.png)
       python3 Harness/tools/results_table.py --round3-best   (best UIKit vs best SwiftUI of Round 3: results-round3-best.png and -dark.png)
       python3 Harness/tools/results_table.py --round4-appkit-vs-swiftui   (Round 4, Mac: two columns: best of 4 AppKit builds vs best of 2 SwiftUI builds: results-round4-appkit-vs-swiftui.png and -dark.png)
       python3 Harness/tools/results_table.py --round4-all   (Round 4, Mac: all six builds: results-round4-all.png and -dark.png)
"""
import os
from PIL import Image, ImageDraw, ImageFont

HEL = "/System/Library/Fonts/Helvetica.ttc"
BUILDS = [("round1-uikit-swift-opus", "UIKit"), ("round1-swiftui-opus", "SwiftUI"), ("round1-uikit-swift-sol", "UIKit"), ("round1-swiftui-sol", "SwiftUI")]

# (label, [(state, main, sub, best) x4])
ROWS = [
    ("Passes everything", [("bad", "1 fail", "", False), ("bad", "2 fails, 1 not measurable", "", False),
                           ("ok", "Pass", "", True), ("bad", "3 fails", "", False)]),
    ("First 40 rows (cold)", [("ok", "172 ms", "", True), ("ok", "174 ms", "", False),
                              ("ok", "201 ms", "", False), ("ok", "354 ms", "", False)]),
    ("Fling", [("ok", "58.5 fps", "2 hitches", True), ("ok", "57.9 fps", "24 hitches", False),
               ("ok", "58.3 fps", "2 hitches", False), ("ok", "58.3 fps", "2 hitches", False)]),
    ("Live stream, 600 messages", [("ok", "25.7 fps", "1 hitch", False), ("ok", "22.6 fps", "25 hitches", False),
                                   ("ok", "27.8 fps", "2 hitches", True), ("bad", "About 450 of 600 shown", "", False)]),
    ("Jump to message 2,500", [("ok", "52 ms", "", True), ("ok", "85 ms", "", False),
                               ("ok", "73 ms", "", False), ("ok", "210 ms", "", False)]),
    ("Load older", [("ok", "77 ms", "drift 0.3 pt", False), ("warn", "25 ms", "drift unreadable", False),
                    ("ok", "61 ms", "drift 0.0 pt", True), ("ok", "133 ms", "drift 0.0 pt", False)]),
    ("Peak memory", [("none", "43.9 MB", "", False), ("none", "69.7 MB", "", False),
                     ("none", "39.7 MB", "", True), ("warn", "Not measured", "", False)]),
    ("Text selection", [("bad", "Fail", "", False), ("bad", "Fail", "", False),
                        ("ok", "Pass", "", False), ("bad", "Fail", "", False)]),
    ("Stack rule", [("ok", "Pass", "", False), ("bad", "Fail", "uses UIPasteboard", False),
                    ("ok", "Pass", "", False), ("bad", "Fail", "uses UIPasteboard", False)]),
]

THEMES = {
    "light": dict(bg=(255, 255, 255), text=(28, 28, 30), muted=(110, 110, 115), line=(225, 225, 228),
                  ok=((214, 240, 220), (46, 125, 66)), bad=((250, 214, 214), (176, 46, 46)),
                  warn=((253, 240, 196), (160, 118, 10)), none=((255, 255, 255), (150, 150, 155)),
                  second=((255, 243, 176), (176, 132, 0)), last=((255, 218, 184), (200, 90, 10)),
                  head=(243, 243, 246)),
    "dark": dict(bg=(24, 24, 27), text=(240, 240, 243), muted=(160, 160, 168), line=(58, 58, 64),
                 ok=((30, 70, 42), (110, 200, 135)), bad=((84, 34, 34), (240, 130, 130)),
                 warn=((82, 68, 22), (235, 195, 85)), none=((24, 24, 27), (120, 120, 128)),
                 second=((88, 74, 18), (240, 205, 70)), last=((100, 52, 16), (245, 150, 70)),
                 head=(38, 38, 43)),
}

FULL = dict(title="UIKit vs SwiftUI", subtitle="Same Campfire chat room, built four times. Round 1 (no skills).",
            builds=BUILDS, rows=ROWS, col_w=220, file="results-round1",
            groups=[("Opus 5.5", (0, 1)), ("GPT-6.1 Sol", (2, 3))],
            legend=[("ok", "Pass"), ("bad", "Fail"), ("warn", "Not measurable or not measured")], best_legend=True)

# --- Best of each stack, computed from ROWS (nothing retyped) ---
import re

NAMES = [b for b, _ in BUILDS]
STACKS = {"UIKit": [0, 2], "SwiftUI": [1, 3]}


def num(text):
    m = re.search(r"\d+(?:\.\d+)?", text.replace(",", ""))
    return float(m.group()) if m else None


# row label -> (score function of a cell, lower is better). None = not comparable.
def _score(label, cell):
    state, main, sub, _ = cell
    if label == "Passes everything":
        return 0 if state == "ok" else num(main)
    if label in ("Text selection", "Stack rule"):
        return 0 if state == "ok" else 1
    if label == "Fling":
        return -num(main)
    if label == "Live stream, 600 messages":
        return -num(main) if state == "ok" else None
    if label == "Load older":
        return num(main) if state == "ok" else None
    return num(main) if state != "warn" else None  # ms and MB rows


def best_rows():
    out = []
    for label, cells in ROWS:
        picks = []
        for idxs in STACKS.values():
            cand = [(i, _score(label, cells[i])) for i in idxs]
            ok = [c for c in cand if c[1] is not None]
            i, sc = min(ok, key=lambda c: c[1]) if ok else (idxs[0], None)
            picks.append((i, sc))
        (iu, su), (iw, sw) = picks
        tie = su == sw
        passfail = label in ("Passes everything", "Text selection", "Stack rule")
        if su is None or sw is None:
            near = False
        else:
            near = su == sw or (not passfail and abs(su - sw) / max(abs(su), abs(sw)) <= 0.05)
        out_cells = []
        for k, (i, sc) in enumerate(picks):
            state, main, sub, _ = cells[i]
            idxs = list(STACKS.values())[k]
            same = all(cells[j][1] == main and cells[j][0] == state for j in idxs)
            extra = sub if label == "Fling" else ""
            who = "both builds" if same and label in ("Text selection", "Stack rule") else NAMES[i]
            if label == "Passes everything" and state != "ok":
                main, who = "None passes", "closest: %s, %s" % (NAMES[i], re.match(r"\d+ fails?", cells[i][1]).group())
            other = picks[1 - k][1]
            if near:
                rank = "warn"
            elif sc is None:
                rank = "bad"
            elif other is None or sc < other:
                rank = "ok"
            else:
                rank = "bad"
            out_cells.append((rank, main, (extra + " \u00b7 " if extra else "") + who, False))
        unit = {"fps": ("Fling", "Live stream, 600 messages"), "ms": ("First 40 rows (cold)", "Jump to message 2,500", "Load older"),
                "MB": ("Peak memory",)}
        u = next((k for k, v in unit.items() if label in v), None)
        if u and su is not None and sw is not None and su != sw:
            worse = 0 if su > sw else 1
            vals = [num(out_cells[0][1]), num(out_cells[1][1])]
            win, lose = vals[1 - worse], vals[worse]
            diff = abs(lose - win)
            pct = diff / win * 100
            ptxt = ("%.0f" if pct >= 1 else "%.1f") % pct
            red = out_cells[worse][0] == "bad"
            if u == "fps":
                txt = "%.1f fps fewer (\u2212%s%%)" % (diff, ptxt)
            elif u == "ms":
                txt = "+%.0f ms (+%s%%%s)" % (diff, ptxt, " slower" if red else "")
            else:
                txt = "+%.1f MB (+%s%%%s)" % (diff, ptxt, " more" if red else "")
            c = out_cells[worse]
            out_cells[worse] = (c[0], c[1], c[2], (txt, c[0]))
        out.append((label, out_cells))
    return out


BEST = dict(title="Best of UIKit vs best of SwiftUI",
            subtitle="Each stack's best build per row. Colour shows who wins; the last line shows how far behind.",
            builds=[("UIKit", ""), ("SwiftUI", "")], rows=best_rows(), col_w=300, file="results-round1-best", groups=None, row_h=76,
            legend=[("ok", "Wins the row"), ("bad", "Loses the row"), ("warn", "Within 5%")])

# --- Round 2 (docs/results-round2.md): six builds (--round2) and best of each stack's pair (--round2-best3) ---
# One table of facts, one place. Each row: label, then per build (key, main, sub). Lower key is better; key None = not measured.
# Winners are computed (equal keys tie), nothing is marked by hand. All numbers are from docs/results-round2.md.
L2_ORDER = ["opus-uikit", "sol-uikit", "opus-objc", "sol-objc", "opus-swiftui", "sol-swiftui"]
L2_MODEL = {"opus": "Opus", "sol": "Sol"}
NM = (None, "Not measured", "")


def _c(key, main, sub=""):
    return (key, main, sub)


L2_DATA = [
    ("Passes everything", [_c(0, "Pass"), _c(1, "1 fail"), _c(1, "1 fail"), _c(1, "1 fail"), _c(2, "2 fails"), _c(2, "2 fails")]),
    ("Stack rule", [_c(0, "Pass"), _c(0, "Pass"), _c(0, "Pass"), _c(0, "Pass"), _c(1, "Fail", "UIPasteboard"), _c(1, "Fail", "UIPasteboard")]),
    ("First 40 rows (cold)", [_c(252, "252 ms"), _c(196, "196 ms"), _c(158, "158 ms"), _c(198, "198 ms"), _c(326, "326 ms"), _c(314, "314 ms")]),
    ("Cold launch (Instruments)", [_c(843, "843 ms", "1 of 3 traces"), _c(776, "776 ms", "2 of 3 traces"), NM[:2] + ("0 of 3 traces",),
                                   _c(736, "736 ms", "2 of 3 traces"), NM[:2] + ("0 of 3 traces",), NM[:2] + ("0 of 3 traces",)]),
    ("Fling", [_c(2, "2 hitches", "58.0 fps, 51 s"), _c(0, "0 hitches", "58.2 fps, 49 s"), _c(2, "2 hitches", "58.7 fps, 52 s"),
               _c(1, "1 hitch", "58.3 fps, 52 s"), _c(5, "5 hitches", "57.9 fps, 54 s"), _c(0, "0 hitches", "58.0 fps, 41 s")]),
    ("Live stream, 600 messages", [_c(1, "1 hitch", "17 ms, 15.2 fps"), _c(6, "6 hitches", "100 ms, 22.4 fps"), _c(3, "3 hitches", "67 ms, 27.3 fps"),
                                   _c(9, "9 hitches", "167 ms, 37.3 fps"), _c(425, "425 hitches", "13.9 s, 22.0 fps"), _c(242, "242 hitches", "4.9 s, 33.2 fps")]),
    ("Jump to message 2,500", [_c(90, "90 ms"), _c(77, "77 ms"), _c(67, "67 ms"), _c(109, "109 ms"), _c(154, "154 ms"), _c(191, "191 ms")]),
    ("Load older", [_c(93, "93 ms", "drift 0.0 pt"), _c(75, "75 ms", "drift 0.0 pt"), _c(34, "34 ms", "drift 0.1 pt"),
                    _c(106, "106 ms", "drift 0.0 pt"), _c(86, "86 ms", "drift 0.2 pt"), _c(143, "143 ms", "drift 0.1 pt")]),
    ("Text size change", [_c(83, "83 / 103 ms", "bottom / mid-list"), _c(53, "53 / 70 ms", "bottom / mid-list"), _c(77, "77 / 93 ms", "bottom / mid-list"),
                          _c(55, "55 / 75 ms", "bottom / mid-list"), _c(76, "76 / 108 ms", "bottom / mid-list"), _c(123, "123 / 139 ms", "bottom / mid-list")]),
    ("Rotation, boost, menu", [_c(0, "Pass", "all three")] * 6),
    ("Text selection", [_c(0, "Pass"), _c(1, "Fail"), _c(1, "Fail"), _c(1, "Fail"), _c(1, "Fail"), _c(1, "Fail")]),
    ("Peak memory", [_c(107.9, "107.9 MB"), _c(44.5, "44.5 MB"), _c(52.0, "52.0 MB"), _c(35.0, "35.0 MB"), _c(215.4, "215.4 MB"), _c(103.4, "103.4 MB")]),
    ("App size", [_c(0.71, "0.71 MB"), _c(0.64, "0.64 MB"), _c(0.66, "0.66 MB"), _c(2.70, "2.70 MB", "icon assets"), _c(1.50, "1.50 MB"), _c(1.20, "1.20 MB")]),
    ("Agent wall time", [_c(2231, "2231 s", "95 turns, 12 builds"), _c(1233, "1233 s", "90 turns, 14 builds"), _c(2884, "2884 s", "106 turns, 12 builds"),
                         _c(1297, "1297 s", "118 turns, 24 builds"), _c(4301, "4301 s", "197 turns, 24 builds"), _c(1209, "1209 s", "113 turns, 15 builds")]),
]
STACK_COLS = [("UIKit Swift", ("opus-uikit", "sol-uikit")), ("UIKit Objective-C", ("opus-objc", "sol-objc")), ("SwiftUI", ("opus-swiftui", "sol-swiftui"))]


def _cell(cell, winner, tie_all, extra=""):
    key, main, sub = cell
    if key is None:
        return ("warn", main, (sub + extra).strip(" ·"), False)
    if tie_all:
        return ("none", main, ("tie · " + sub + extra).strip(" ·") if sub or extra else "tie", False)
    return ("ok", main, sub + extra, True) if winner else ("none", main, sub + extra, False)


def _winners(keys):
    """Indexes of the best (lowest) key, and whether every measured cell ties."""
    ok = [k for k in keys if k is not None]
    best = min(ok)
    idx = [i for i, k in enumerate(keys) if k == best]
    return idx, len(idx) == len(keys)


def l2_six_rows():
    rows = []
    for label, cells in L2_DATA:
        by = dict(zip(["opus-uikit", "sol-uikit", "opus-objc", "sol-objc", "opus-swiftui", "sol-swiftui"], cells))
        ordered = [by[b] for b in L2_ORDER]
        idx, all_tie = _winners([c[0] for c in ordered])
        out = []
        for i, c in enumerate(ordered):
            tied = len(idx) > 1 and i in idx and not all_tie
            e = _cell(c, i in idx, all_tie)
            if tied:
                e = (e[0], e[1], ("tie · " + e[2]) if e[2] else "tie", e[3])
            out.append(e)
        rows.append((label, out))
    return rows


L2_BEST6 = {}  # label -> list of winning build names (filled by l2_six_rows users)


def l2_best3():
    """Per stack column: the better of its two builds. Returns rows and a record of winners."""
    rows, record = [], []
    for label, cells in L2_DATA:
        by = dict(zip(["opus-uikit", "sol-uikit", "opus-objc", "sol-objc", "opus-swiftui", "sol-swiftui"], cells))
        picks = []
        for _, (a, b) in STACK_COLS:
            ca, cb = by[a], by[b]
            ka, kb = ca[0], cb[0]
            if ka is None and kb is None:
                picks.append((ca, "Opus and Sol"))
            elif kb is None or (ka is not None and ka < kb):
                picks.append((ca, L2_MODEL[a.split("-")[0]]))
            elif ka is None or kb < ka:
                picks.append((cb, L2_MODEL[b.split("-")[0]]))
            else:
                picks.append((ca, "Opus and Sol"))
        keys = [p[0][0] for p in picks]
        idx, all_tie = _winners(keys)
        out = []
        for i, (c, model) in enumerate(picks):
            sub = c[2]
            src = (sub + " · " + model) if sub else model
            e = _cell((c[0], c[1], src), i in idx, all_tie)
            if len(idx) > 1 and i in idx and not all_tie:
                e = (e[0], e[1], "tie · " + e[2], e[3])
            if all_tie:
                e = (e[0], e[1], "tie · " + src, e[3])
            out.append(e)
        rows.append((label, out))
        record.append((label, [STACK_COLS[i][0] for i in idx], all_tie))
    return rows, record


L2_HEAD = [("round2-uikit-swift-opus", "Opus"), ("round2-uikit-swift-sol", "Sol"), ("round2-uikit-objc-opus", "Opus"), ("round2-uikit-objc-sol", "Sol"), ("round2-swiftui-opus", "Opus"), ("round2-swiftui-sol", "Sol")]
_FOOT = "iPhone 12 · Round 2 · github.com/notolivaresf/uikit-vs-swiftui"
_LEG = [("ok", "Best in row (ties share it)"), ("none", "Not the best, or the whole row ties"), ("warn", "Not measured")]
L2 = dict(title="UIKit vs SwiftUI, Round 2",
          subtitle="The six builds, one column each. Rows ordered with hitches first; the best value in each row is outlined in green.",
          builds=L2_HEAD, rows=l2_six_rows(), col_w=210, file="results-round2", row_h=62,
          groups=[("UIKit Swift", (0, 1)), ("UIKit Objective-C", (2, 3)), ("SwiftUI", (4, 5))],
          legend=_LEG, note="fps counts redraws; hitches are late frames you can see", footer=_FOOT)

_B3_ROWS, B3_RECORD = l2_best3()
L2B3 = dict(title="Best of each stack, Round 2",
            subtitle="Each column takes the better of its two builds per row (Opus or Sol). Small text names the model the value came from.",
            builds=[("UIKit Swift", "best of 2 builds"), ("UIKit Objective-C", "best of 2 builds"), ("SwiftUI", "best of 2 builds")],
            rows=_B3_ROWS, col_w=330, file="results-round2-best3", groups=None, row_h=62,
            legend=_LEG, note="fps counts redraws; hitches are late frames you can see", footer=_FOOT)

# --- Round 2 best of each stack (docs/results-round2-best.md), rendered only with --round2-best ---
# Two columns. UIKit = best value per row across the four UIKit builds (Opus and Sol, Swift and Objective-C); SwiftUI = best
# per row of its two builds (mix and match). The small text names the source. All numbers are from docs/results-round2.md.
# Result per cell: W win (ties both win), L lose, T tie, N not measured.
_ST = {"W": "ok", "L": "bad", "T": "none", "N": "warn"}
SW, OC = "Swift \u00b7 ", "Objective-C \u00b7 "


def _r(res, main, sub):
    return (_ST[res], main, sub, res == "W")


def _row(label, u, w):
    return (label, [_r(*u), _r(*w)])


L2B_ROWS = [
    _row("Passes everything", ("W", "Pass", SW + "Opus"), ("L", "2 fails", "Opus and Sol")),
    _row("Stack rule", ("W", "Pass", "all four builds"), ("L", "Fail", "UIPasteboard, Opus and Sol")),
    _row("First 40 rows (cold)", ("W", "158 ms", OC + "Opus"), ("L", "314 ms", "Sol")),
    _row("Cold launch (Instruments)", ("W", "736 ms", "2 of 3 traces saved \u00b7 " + OC + "Sol"), ("N", "Not measured", "0 of 3 traces saved")),
    _row("Fling", ("W", "0 hitches", "58.2 fps, 49 s \u00b7 " + SW + "Sol"), ("W", "0 hitches", "58.0 fps, 41 s \u00b7 Sol")),
    _row("Live stream, 600 messages", ("W", "1 hitch (17 ms)", "15.2 fps, CPU 12.2 s \u00b7 " + SW + "Opus"),
         ("L", "242 hitches (4.9 s)", "33.2 fps, CPU 22.1 s \u00b7 Sol")),
    _row("Jump to message 2,500", ("W", "67 ms", OC + "Opus"), ("L", "154 ms", "Opus")),
    _row("Load older", ("W", "34 ms", "drift 0.1 pt \u00b7 " + OC + "Opus"), ("L", "86 ms", "drift 0.2 pt \u00b7 Opus")),
    _row("Text size change", ("W", "53 / 70 ms", "bottom / mid-list \u00b7 " + SW + "Sol"), ("L", "76 / 108 ms", "bottom / mid-list \u00b7 Opus")),
    _row("Rotation, boost, menu", ("T", "Pass", "all three, all builds"), ("T", "Pass", "all three, both builds")),
    _row("Text selection", ("W", "Pass", SW + "Opus"), ("L", "Fail", "Opus and Sol")),
    _row("Peak memory", ("W", "35.0 MB", OC + "Sol"), ("L", "103.4 MB", "Sol")),
    _row("App size", ("W", "0.64 MB", SW + "Sol"), ("L", "1.20 MB", "Sol")),
    _row("Agent wall time", ("L", "1233 s", "90 turns, 14 builds (7 failed) \u00b7 " + SW + "Sol"),
         ("W", "1209 s", "113 turns, 15 builds (8 failed) \u00b7 Sol")),
]
L2B = dict(title="Best of UIKit vs best of SwiftUI, Round 2",
           subtitle="Best value per row. UIKit: any of its four builds (Swift or Objective-C, Opus or Sol); SwiftUI: its two builds. Small text names the source.",
           builds=[("UIKit", "best of 4 builds: Swift and Objective-C, Opus and Sol"), ("SwiftUI", "best of 2 builds: Opus and Sol")],
           rows=L2B_ROWS, col_w=420, file="results-round2-best",
           groups=None, row_h=58,
           legend=[("ok", "Wins the row (ties both win)"), ("bad", "Loses the row"), ("none", "Tie"), ("warn", "Not measured")],
           note="fps counts redraws; hitches are late frames you can see",
           footer="iPhone 12 \u00b7 Round 2 (with skills) \u00b7 github.com/notolivaresf/uikit-vs-swiftui")

# --- Round 3 best of UIKit vs best of SwiftUI (docs/results-round3.md), rendered only with --round3-best ---
# Values are the "After (measured here)" column of runs/round3-*/verify.md (iPhone 17 simulator):
# (checks of 13, cold first 40 rows ms, stream CPU s, jump ms, load older ms, text size at bottom ms, peak memory MB, app size MB)
R3 = {("Swift", "Opus"): (13, 175, 6.4, 41, 39, 44, 53.9, 0.84), ("Swift", "Sol"): (13, 130, 7.5, 32, 31, 18, 57.9, 0.79),
      ("Obj-C", "Opus"): (13, 135, 4.6, 40, 42, 46, 52.8, 0.71), ("Obj-C", "Sol"): (13, 161, 8.8, 40, 4, 12, 44.4, 2.77),
      ("SwiftUI", "Opus"): (13, 181, 9.9, 19, 27, 8, 127.4, 2.86), ("SwiftUI", "Sol"): (12, 278, 12.5, 76, 71, 55, 77.2, 0.89)}
R3_UI = [("Swift", "Opus"), ("Swift", "Sol"), ("Obj-C", "Opus"), ("Obj-C", "Sol")]
R3_SW = [("SwiftUI", "Opus"), ("SwiftUI", "Sol")]
# Rows where the winning build bent the rules (starred in the chart): see "Bent rules" in docs/results-round3.md.
R3_ROWS = [("Checks passed", 0, lambda v: "%d of 13" % v, set()), ("First 40 rows, cold", 1, lambda v: "%g ms" % v, set()),
           ("Stream CPU", 2, lambda v: "%g s" % v, {("Swift", "Opus"), ("Obj-C", "Opus")}),
           ("Jump to message 2,500", 3, lambda v: "%g ms" % v, {("Obj-C", "Opus")}),
           ("Load older", 4, lambda v: "%g ms" % v, {("Obj-C", "Sol")}), ("Text size, bottom", 5, lambda v: "%g ms" % v, set()),
           ("Peak memory", 6, lambda v: "%g MB" % v, set()), ("App size", 7, lambda v: "%g MB" % v, set())]
R3_EXTRA = {"Checks passed": [("Stack rule", (("Pass", "all four builds"), ("Pass", "both builds")))],
            "Text size, bottom": [("Rotation, boost, menu", (("Pass", "all three, all builds"), ("Pass", "all three, both builds"))),
                                  ("Text selection", (("Pass", "all four builds"), ("Pass", "Opus")))]}


def l2_round3_rows():
    rows = []
    for label, i, fmt, bends in R3_ROWS:
        key = (lambda v: -v) if i == 0 else (lambda v: v)
        picks = []
        for grp in (R3_UI, R3_SW):
            bk = min(key(R3[b][i]) for b in grp)
            picks.append((R3[[b for b in grp if key(R3[b][i]) == bk][0]][i], [b for b in grp if key(R3[b][i]) == bk]))
        best = min(key(p[0]) for p in picks)
        out = []
        for v, ws in picks:
            win = key(v) == best
            lab = "%s \u00b7 %s" % ws[0] if len(ws) == 1 else "all four builds"
            if ws[0][0] == "SwiftUI" and len(ws) == 1:
                lab = ws[0][1]
            star = win and len(ws) == 1 and ws[0] in bends
            out.append(("ok" if win else "bad", fmt(v) + (" *" if star else ""), lab, win))
        rows.append((label, out))
        for lb, (a, b) in R3_EXTRA.get(label, []):
            rows.append((lb, [("ok",) + a + (True,), ("ok",) + b + (True,)]))
    return rows


L2R3 = dict(title="Best of UIKit vs best of SwiftUI, Round 3",
            subtitle="Best value per row. UIKit: any of its four builds; SwiftUI: its two. Small text names the source.",
            builds=[("UIKit", "best of 4 builds"), ("SwiftUI", "best of 2 builds")],
            rows=l2_round3_rows(), col_w=300, label_w=190, file="results-round3-best", groups=None, row_h=62,
            legend=[("ok", "Wins the row (ties: both green)"), ("bad", "Loses the row")],
            note="* Bent rules: Opus Obj-C redraws the stream every 100 ms; Sol Obj-C times part of load older.",
            footer="iPhone 17 simulator \u00b7 Round 3 (3 hours of fixes) \u00b7 github.com/notolivaresf/uikit-vs-swiftui")

# --- Best SwiftUI build per row across three setups (docs/results-round1.md, results-round2.md, results-l2-avdlee.md), rendered only with --swiftui-3way ---
# iPhone 12, one pass per build. Each cell is the better of that setup's Opus and Sol SwiftUI builds for the row; winners are computed, ties share.
# (label, [(key, main, sub) x3]); lower key wins. Stars: Round 1 Sol's stream test failed, so those cells are Opus only.
SW3_ROWS = [
    ("Cold start, 40 rows", [(174, "174 ms", "Opus"), (314, "314 ms", "Sol"), (216, "216 ms", "Sol")]),
    ("Fling", [(2, "2 hitches", "58.3 fps \u00b7 Sol"), (0, "0 hitches", "58.0 fps \u00b7 Sol"), (1, "1 hitch", "57.7 fps \u00b7 Sol")]),
    ("Jump to message 2,500", [(85, "85 ms", "Opus"), (154, "154 ms", "Opus"), (72, "72 ms", "Opus")]),
    ("Load older", [(133, "133 ms", "Sol"), (86, "86 ms", "Opus"), (86, "86 ms", "Sol")]),
    ("Stream hitches", [(25, "25 hitches *", "Opus"), (242, "242 hitches", "Sol"), (73, "73 hitches", "Sol")]),
    ("Stream CPU", [(13.6, "13.6 s *", "Opus"), (22.1, "22.1 s", "Sol"), (12.4, "12.4 s", "Opus")]),
    ("Text size, bottom / mid", [(35, "35 / 54 ms", "Opus"), (76, "76 / 108 ms", "Opus"), (55, "55 / 89 ms", "bottom Opus \u00b7 mid Sol")]),
    ("Peak memory", [(69.7, "69.7 MB *", "Opus"), (103.4, "103.4 MB", "Sol"), (57.2, "57.2 MB", "Opus")]),
    ("App size", [(1.48, "1.48 MB", "Opus"), (1.20, "1.20 MB", "Sol"), (1.54, "1.54 MB", "Opus")]),
]


def sw3_rows(cols=(0, 1, 2)):
    rows, wins = [], [0] * len(cols)
    for label, allcells in SW3_ROWS:
        cells = [allcells[c] for c in cols]
        best = min(c[0] for c in cells)
        idx = [i for i, c in enumerate(cells) if c[0] == best]
        for i in idx:
            wins[i] += 1
        out = []
        for i, (k, main, sub) in enumerate(cells):
            win = i in idx
            out.append(("ok" if win else "none", main, ("tie \u00b7 " + sub) if win and len(idx) > 1 else sub, win))
        rows.append((label, out))
    return rows, wins


_SW3_ROWS, SW3_WINS = sw3_rows()
assert SW3_WINS == [3, 3, 4], SW3_WINS
SW3 = dict(title="Best SwiftUI build per row: @twannl's skills win 4 of 9, no skills 3",
           subtitle="Apple's skills win 3. Each column takes the better of its Opus and Sol builds per row. Small text names the model.",
           builds=[("Round 1", "no skills \u00b7 %d wins" % SW3_WINS[0]), ("Round 2, Apple skills", "%d wins" % SW3_WINS[1]),
                   ("Round 2, @twannl's skills", "%d wins" % SW3_WINS[2])],
           rows=_SW3_ROWS, col_w=370, label_w=230, file="results-swiftui-3way", groups=None, aspect=16 / 9,
           legend=[("ok", "Best in row (ties share it)"), ("none", "Not the best")],
           note="* Round 1 Sol's stream test failed, so these cells are Opus only. iPhone 12, iOS 26, one pass per build. Cold start = app's own time to 40 rows.",
           footer="UIKit vs SwiftUI \u00b7 github.com/notolivaresf/uikit-vs-swiftui")

# Same data, only the two Round 2 columns (Apple skills against @twannl's skills), rendered with --swiftui-skills. Wins recomputed, ties share.
_SK_ROWS, SK_WINS = sw3_rows((1, 2))
_SK_ONLY = sum(1 for _, c in _SK_ROWS if c[0][3] and not c[1][3])
_SK_ONLY_AVD = sum(1 for _, c in _SK_ROWS if c[1][3] and not c[0][3])
_SK_TIES = sum(1 for _, c in _SK_ROWS if c[0][3] and c[1][3])
assert (_SK_ONLY_AVD, _SK_ONLY, _SK_TIES) == (6, 2, 1), (_SK_ONLY_AVD, _SK_ONLY, _SK_TIES)
SWSK = dict(title="@twannl's skills beat Apple's on %d of 9 rows, Apple's on %d, %d tie" % (_SK_ONLY_AVD, _SK_ONLY, _SK_TIES),
            subtitle="Best SwiftUI build of each, per row. Small text names the model the value came from.",
            builds=[("Round 2, Apple skills", "%d wins (with the tie)" % SK_WINS[0]), ("Round 2, @twannl's skills", "%d wins (with the tie)" % SK_WINS[1])],
            rows=[(l, [(st, m.rstrip(" *"), sb, b) for st, m, sb, b in c]) for l, c in _SK_ROWS],
            col_w=240, label_w=220, file="results-swiftui-skills", groups=None, aspect=4 / 5,
            legend=SW3["legend"],
            note="iPhone 12, iOS 26, one pass per build. Each column takes the better of its Opus and Sol builds. Cold start = app's own time to 40 rows.",
            footer=SW3["footer"])

# --- Best UIKit against the two SwiftUI skill sets (docs/results-round2.md, results-l2-avdlee.md), rendered with --uikit-vs-swiftui-skills ---
# Best UIKit = best value per row across the four Round 2 UIKit builds (Swift and Objective-C, Opus and Sol), iPhone 12; none of those
# cells is a bent-rules one. The two SwiftUI columns are SW3_ROWS columns 1 and 2. Winners computed, ties share.
UK_ROWS = [
    ("Cold start, 40 rows", (158, "158 ms", "Opus \u00b7 ObjC")),
    ("Fling", (0, "0 hitches", "58.2 fps \u00b7 Sol \u00b7 Swift")),
    ("Jump to message 2,500", (67, "67 ms", "Opus \u00b7 ObjC")),
    ("Load older", (34, "34 ms", "Opus \u00b7 ObjC")),
    ("Stream hitches", (1, "1 hitch", "Opus \u00b7 Swift")),
    ("Stream CPU", (11.9, "11.9 s", "Opus \u00b7 ObjC")),
    ("Text size, bottom / mid", (53, "53 / 70 ms", "Sol \u00b7 Swift")),
    ("Peak memory", (35.0, "35.0 MB", "Sol \u00b7 ObjC")),
    ("App size", (0.64, "0.64 MB", "Sol \u00b7 Swift")),
]


def uk_rows():
    rows, wins = [], [0, 0, 0]
    for (label, uk), (l2, sw) in zip(UK_ROWS, SW3_ROWS):
        assert label == l2
        cells = [uk, sw[1], sw[2]]
        best = min(c[0] for c in cells)
        idx = [i for i, c in enumerate(cells) if c[0] == best]
        for i in idx:
            wins[i] += 1
        # competition ranking (ties share a rank): 1 green, 2 yellow, 3 orange
        rank = [1 + sum(1 for o in cells if o[0] < c[0]) for c in cells]
        st = {1: "ok", 2: "second", 3: "last"}
        rows.append((label, [(st[rank[i]], m.rstrip(" *"), ("tie \u00b7 " + sb) if i in idx and len(idx) > 1 else sb, i in idx)
                             for i, (k, m, sb) in enumerate(cells)]))
    return rows, wins


_UK_ROWS, UK_WINS = uk_rows()
assert UK_WINS == [9, 1, 0], UK_WINS
UKSW = dict(title="Best UIKit wins all 9 rows; SwiftUI with either skill set wins none outright",
            subtitle="Best UIKit is the best value per row of the four Round 2 UIKit builds (Swift and Objective-C, Opus and Sol). The SwiftUI columns are the better of their Opus and Sol builds. Small text names the model and language.",
            builds=[("Best UIKit", "%d wins" % UK_WINS[0]), ("SwiftUI, Apple's skills", "%d win (a tie)" % UK_WINS[1]),
                    ("SwiftUI, @twannl's skills", "%d wins" % UK_WINS[2])],
            rows=_UK_ROWS, col_w=260, label_w=210, file="results-uikit-vs-swiftui-skills", groups=None, aspect=4 / 5,
            legend=[("ok", "Best in row (ties share it)"), ("second", "Second place"), ("last", "Last place")],
            note="iPhone 12, iOS 26, one pass per build. Fling: Best UIKit and Apple's skills tie at 0 hitches. Cold start = app's own time to 40 rows.",
            footer=SW3["footer"])

# --- Round 2 distance from optimal (docs/optimal-gap-round2.md), rendered only with --round2-gap ---
# Each row: label, kind, optimal value, source of the optimal, unit, and per build (L2_HEAD order) the measured value.
# kind "low": lower is better, score = optimal / value. "high": higher is better, score = value / optimal.
# "frac": the value already is a share (0..1) of the ideal 1.0. None = not measured (left out of the mean).
# All numbers are from docs/results-round2.md and docs/results-round1.md (stream smoothness and fling smoothness from
# the hitch time over the trace window, as published there).
GAP_ROWS = [
    ("First 40 rows (cold)", "low", 158, "round2-uikit-objc-opus", "ms", [252, 196, 158, 198, 326, 314]),
    ("First 40 rows (repeated)", "low", 222, "round1-uikit-swift-opus", "ms", [256, 305, 242, 299, 329, 408]),
    ("Cold launch (Instruments)", "low", 596, "round1-uikit-swift-opus", "ms", [843, 776, None, 736, None, None]),
    ("Fling speed", "high", 60, "60 Hz screen", "fps", [58.0, 58.2, 58.7, 58.3, 57.9, 58.0]),
    ("Fling smoothness", "frac", 1.0, "no hitches", "", [1 - 0.0333 / 51.34, 1.0, 1 - 0.0333 / 52.35, 1 - 0.050 / 52.18, 1 - 0.1501 / 54.15, 1.0]),
    ("Stream smoothness", "frac", 1.0, "no hitches", "", [1 - 0.0167 / 30.76, 1 - 0.1002 / 31.02, 1 - 0.0669 / 31.09, 1 - 0.167 / 31.03, 1 - 13.8525 / 37.56, 1 - 4.8533 / 31.11]),
    ("Stream CPU", "low", 11.719, "round1-uikit-swift-sol", "s", [12.164, 11.982, 11.921, 18.686, 34.804, 22.101]),
    ("Jump to message 2,500", "low", 52, "round1-uikit-swift-opus", "ms", [90, 77, 67, 109, 154, 191]),
    ("Load older", "low", 34, "round2-uikit-objc-opus", "ms", [93, 75, 34, 106, 86, 143]),
    ("Text size (bottom)", "low", 35, "round1-swiftui-opus", "ms", [83, 53, 77, 55, 76, 123]),
    ("Text size (mid-list)", "low", 54, "round1-swiftui-opus", "ms", [103, 70, 93, 75, 108, 139]),
    ("Peak memory", "low", 35.0, "round2-uikit-objc-sol", "MB", [107.9, 44.5, 52.0, 35.0, 215.4, 103.4]),
    ("App size", "low", 0.62, "round1-uikit-swift-sol", "MB", [0.71, 0.64, 0.66, 2.70, 1.50, 1.20]),
    ("Checks passed (of 13)", "high", 13, "all 13", "", [13, 12, 12, 12, 11, 11]),
]
GAP_AGENT = [
    ("Agent wall time", "low", 1200, "round1-uikit-swift-sol", "s", [2231, 1233, 2884, 1297, 4301, 1209]),
    ("Agent turns", "low", 75, "round1-uikit-swift-opus", "", [95, 90, 106, 118, 197, 113]),
    ("Builds that compiled", "frac", 1.0, "no failed builds", "", [1.0, 7 / 14, 1.0, 16 / 24, 1.0, 7 / 15]),
]


def gap_score(kind, opt, v):
    if v is None:
        return None
    if kind == "low":
        return min(1.0, opt / v)
    if kind == "high":
        return min(1.0, v / opt)
    return v


def _fmt(v, unit):
    if unit == "MB":
        return "%.2f MB" % v if v < 10 else "%.1f MB" % v
    if unit == "s":
        return ("%.0f s" if v >= 100 else "%.1f s") % v
    if unit == "fps":
        return "%.1f fps" % v
    if unit == "ms":
        return "%d ms" % v
    return ("%.0f" % v) if v == int(v) else "%.1f%%" % (v * 100)


def _gap_state(p):
    return "ok" if p >= 0.9 else ("warn" if p >= 0.6 else "bad")


def gap_table():
    """Rows of (label, optimal text, [score or None]) plus the two means per build."""
    app, agent = [], []
    for rows, out in ((GAP_ROWS, app), (GAP_AGENT, agent)):
        for label, kind, opt, src, unit, vals in rows:
            out.append((label, kind, opt, src, unit, vals, [gap_score(kind, opt, v) for v in vals]))
    def mean(rows, i):
        xs = [r[6][i] for r in rows if r[6][i] is not None]
        return sum(xs) / len(xs), len(xs)
    return app, agent, [mean(app, i) for i in range(6)], [mean(agent, i) for i in range(6)]


def gap_rows():
    app, agent, am, gm = gap_table()
    rows = []
    rows.append(("App score (mean)", [(_gap_state(m), "%.0f%%" % (m * 100), "mean of %d rows" % n, m == max(x for x, _ in am)) for m, n in am]))
    for label, kind, opt, src, unit, vals, sc in app:
        cells = []
        for v, p in zip(vals, sc):
            if p is None:
                cells.append(("none", "Not measured", "left out of the mean", False))
                continue
            if kind == "frac":
                sub = "%.1f%% of the time smooth" % (v * 100) if "smooth" in label else "%.0f%% of builds" % (v * 100)
            else:
                sub = _fmt(v, unit)
            cells.append((_gap_state(p), "%.0f%%" % (p * 100) if p < 0.995 or p == 1 else ">99%", sub, False))
        rows.append((label, cells))
    rows.append(("Agent score (mean)", [(_gap_state(m), "%.0f%%" % (m * 100), "wall time, turns, builds", False) for m, n in gm]))
    return rows


L2GAP = dict(title="How far from optimal, Round 2",
             subtitle="Each cell is the build's share of the best possible value for that row (100% = optimal). Small text: what it measured.",
             builds=L2_HEAD, rows=gap_rows(), col_w=200, file="optimal-gap-round2", row_h=50,
             groups=[("UIKit Swift", (0, 1)), ("UIKit Objective-C", (2, 3)), ("SwiftUI", (4, 5))],
             legend=[("ok", "90% or more"), ("warn", "60 to 89%"), ("bad", "Under 60%"), ("none", "Not measured")],
             note="Optimal: 60 fps and no hitches where the phone sets a ceiling, otherwise the best value any of the 10 builds reached. See docs/optimal-gap-round2.md.",
             footer=_FOOT)

# --- Round 4, Mac (docs/round4-results.md): --round4-all (six builds) and --round4-appkit-vs-swiftui ---
# Xcode 27.1, macOS 27, MacBook Pro M1 Max, one fast pass per build (differences under about 10 to 15 % are noise).
# Per row: label, then six (key, main, sub) in R4_ORDER; lower key wins, key None = not measured; "*" = that check failed.
# Winners are computed, ties share. All numbers are copied from docs/round4-results.md.
R4_ORDER = ["AppKit Swift Opus", "AppKit Swift Sol", "AppKit ObjC Opus", "AppKit ObjC Sol", "SwiftUI Opus", "SwiftUI Sol"]
R4_SHORT = ["Swift Opus", "Swift Sol", "ObjC Opus", "ObjC Sol"]
R4_NM = (None, "Not measured", "")
CF = "check fails"


def _ms(v):
    return "{:,} ms".format(v)


def _r4(label, vals, fmt, higher=False, subs=None, fails=()):
    cells = []
    for i, v in enumerate(vals):
        if v is None:
            cells.append(R4_NM)
            continue
        main = fmt(v) + (" *" if i in fails else "")
        sub = (subs or {}).get(i, "") or (CF if i in fails else "")
        cells.append((-v if higher else v, main, sub))
    return (label, cells)


R4_DATA = [
    _r4("Checks passed", [9, 9, 9, 9, 9, 5], lambda v: "%d of 13" % v, higher=True),
    _r4("Cold launch, median of 3", [699, 753, 688, 803, 763, 919], _ms, subs={3: "one sample 5,132 ms"}),
    _r4("First 40 rows, cold", [270, 279, 209, 312, 345, 520], _ms),
    _r4("First 40 rows, repeated", [244, 265, 202, 263, 407, 493], _ms),
    _r4("Jump to message 2,500", [32, 33, 15, 22, 66, 407], _ms, fails=(5,)),
    _r4("Load older", [23, 13, 9, 8, 8, 170], _ms, fails=(5,)),
    _r4("Text size, bottom", [25, 16, 9, 10, 24, 112], _ms),
    _r4("Text size, mid-list", [25, 26, 10, 22, 67, 152], _ms),
    _r4("Peak memory", [107.5, 132.9, 102.9, 122.1, 216.9, None], lambda v: "%.1f MB" % v),
    _r4("Stream CPU", [7.2, 8.9, 6.1, 8.7, 9.2, None], lambda v: "%.1f s" % v),
    _r4("App size", [1.26, 0.99, 1.16, 1.01, 1.68, 3.08], lambda v: "%.2f MB" % v),
    _r4("Fling speed (Instruments)", [91.0, 82.9, 97.9, 87.8, 57.3, 68.4], lambda v: "%.1f fps" % v, higher=True),
    _r4("Fling hitch time", [1758, 1150, 1108, 1800, 3142, 1733], _ms),
    _r4("Stream hitch time", [242, 492, 308, 3533, 3800, 9983], _ms, subs={5: "stream run failed"}),
    _r4("Resize hitch time", [8, 8, 8, 8, 8, None], _ms),
]
R4_NOTE = ("One fast pass per build: differences under about 10 to 15 % are noise. * = check failed. Not measured: SwiftUI Sol's stream run "
           "failed (260 of 600 messages arrived), so its stream hitch time is not trustworthy. Hitch times come from Instruments.")
R4_FOOT = "MacBook Pro M1 Max, macOS 27, Xcode 27.1 · Round 4 · github.com/notolivaresf/uikit-vs-swiftui"
R4_LEG = [("ok", "Best in row (ties share it)"), ("none", "Not the best"), ("warn", "Not measured")]


def r4_six_rows():
    rows = []
    for label, cells in R4_DATA:
        idx, _ = _winners([c[0] for c in cells])
        out = []
        for i, c in enumerate(cells):
            e = _cell(c, i in idx, False)
            if len(idx) > 1 and i in idx:
                e = (e[0], e[1], ("tie · " + e[2]) if e[2] else "tie", e[3])
            out.append(e)
        rows.append((label, out))
    return rows


def r4_appkit_rows():
    """Two columns. AppKit = best of its four builds per row (source build named); SwiftUI = best of its two (Opus or Sol named).
    A not-measured SwiftUI value is skipped when the other build has a real one; a starred (failed check) value keeps its star."""
    rows, wins = [], [0, 0]
    ties = 0
    for label, cells in R4_DATA:
        bk = min(c[0] for c in cells[:4] if c[0] is not None)
        who = [k for k in range(4) if cells[k][0] == bk]
        src = "all four builds" if len(who) == 4 else " · ".join(R4_SHORT[k] for k in who)
        if len(who) == 1 and cells[who[0]][2]:
            src = cells[who[0]][2] + " · " + src
        ak = (bk, cells[who[0]][1], src)
        sw = [(k, cells[k]) for k in (4, 5) if cells[k][0] is not None]
        sk = min(c[0] for _, c in sw)
        sw_who = [k for k, c in sw if c[0] == sk]
        model = "Opus and Sol" if len(sw_who) == 2 else ("Opus" if sw_who[0] == 4 else "Sol")
        c0 = cells[sw_who[0]]
        sub = (c0[2] + " · " + model) if c0[2] else model
        pair = [ak, (sk, c0[1], sub)]
        idx, _ = _winners([c[0] for c in pair])
        if len(idx) == 2:
            ties += 1
        else:
            wins[idx[0]] += 1
        out = []
        for i, c in enumerate(pair):
            e = _cell(c, i in idx, False)
            if len(idx) == 2:
                e = (e[0], e[1], "tie · " + e[2], e[3])
            out.append(e)
        rows.append((label, out))
    return rows, wins, ties


R4ALL = dict(title="Round 4: AppKit Swift and Objective-C against SwiftUI on the Mac",
             subtitle="Six builds, one column each, Opus and Sol. The best value in each row is outlined in green; ties share it.",
             builds=[("Opus", ""), ("Sol", ""), ("Opus", ""), ("Sol", ""), ("Opus", ""), ("Sol", "")],
             rows=r4_six_rows(), col_w=170, label_w=230, file="results-round4-all", row_h=58,
             groups=[("AppKit Swift", (0, 1)), ("AppKit Objective-C", (2, 3)), ("SwiftUI", (4, 5))],
             legend=R4_LEG, note=R4_NOTE, footer=R4_FOOT)

_R4A_ROWS, R4A_WINS, R4A_TIES = r4_appkit_rows()
R4AK = dict(title="AppKit beats SwiftUI on %d of %d rows, SwiftUI on %d, %d tie" % (R4A_WINS[0], len(_R4A_ROWS), R4A_WINS[1], R4A_TIES),
            subtitle="Best value per row. AppKit: any of its four builds (Swift and Objective-C, Opus and Sol); SwiftUI: its two builds. Small text names the source build.",
            builds=[("AppKit", "best of 4 builds \u00b7 %d wins" % R4A_WINS[0]), ("SwiftUI", "best of 2 builds \u00b7 %d wins" % R4A_WINS[1])],
            rows=_R4A_ROWS, col_w=330, label_w=240, file="results-round4-appkit-vs-swiftui", row_h=58, groups=None,
            legend=[("ok", "Best in row (ties share it)"), ("none", "Not the best")], note=R4_NOTE, footer=R4_FOOT)

S = 2  # scale
LABEL_W, COL_W, ROW_H, HEAD_H, GROUP_H = 250, 220, 62, 44, 36  # ROW_H is the default; a spec can set row_h
PAD = 28


def font(size, bold=False):
    return ImageFont.truetype(HEL, size * S, index=1 if bold else 0)


def centered(d, cx, cy, text, f, fill):
    d.text((cx * S, cy * S), text, font=f, fill=fill, anchor="mm")


def wrap(d, text, f, maxw):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) <= maxw * S or not cur:
            cur = t
        else:
            lines.append(cur); cur = w
    lines.append(cur)
    return lines


def render(name, spec=None):
    spec = spec or FULL
    th = THEMES[name]
    BUILDS, ROWS, COL_W = spec["builds"], spec["rows"], spec["col_w"]
    ROW_H = spec.get("row_h", 62)
    groups = spec["groups"]
    group_h = GROUP_H if groups else 0
    LABEL_W = spec.get("label_w", globals()["LABEL_W"])
    W = PAD * 2 + LABEL_W + COL_W * len(BUILDS)
    title_h = 64
    _m = Image.new("RGB", (1, 1))
    _md = ImageDraw.Draw(_m)
    tlines = wrap(_md, spec["title"], font(26, True), W - 2 * PAD)  # a narrow chart wraps its headline and note
    title_h += 32 * (len(tlines) - 1)
    slines = wrap(_md, spec["subtitle"], font(15), W - 2 * PAD)
    title_h += 20 * (len(slines) - 1)
    nlines = wrap(_md, spec["note"], font(13), W - 2 * PAD) if spec.get("note") else []
    note_h = 18 * max(len(nlines), 1) + 6 if nlines else 0
    fixed = PAD + title_h + group_h + HEAD_H + 56 + PAD + note_h
    if spec.get("aspect"):  # fit the canvas to the ratio by sizing the rows
        ROW_H = int((W / spec["aspect"] - fixed) // len(ROWS))
    H = fixed + ROW_H * len(ROWS)
    if spec.get("aspect"):
        H = round(W / spec["aspect"])
    img = Image.new("RGB", (W * S, H * S), th["bg"])
    d = ImageDraw.Draw(img)
    x0 = PAD
    y = PAD
    for k, tl in enumerate(tlines):
        d.text((x0 * S, (y + 14 + 32 * k) * S), tl, font=font(26, True), fill=th["text"], anchor="lm")
    for k, sl in enumerate(slines):
        d.text((x0 * S, (y + 46 + 32 * (len(tlines) - 1) + 20 * k) * S), sl, font=font(15), fill=th["muted"], anchor="lm")
    y += title_h
    # group header
    for g, (a, b) in groups or []:
        gx = x0 + LABEL_W + COL_W * a
        span = b - a + 1
        d.rounded_rectangle([(gx + 4) * S, y * S, (gx + COL_W * span - 4) * S, (y + GROUP_H - 6) * S], 8 * S, fill=th["head"])
        centered(d, gx + COL_W * span / 2, y + (GROUP_H - 6) / 2, g, font(16, True), th["text"])
    y += group_h
    for i, (b, kind) in enumerate(BUILDS):
        cx = x0 + LABEL_W + COL_W * i + COL_W / 2
        if kind:
            centered(d, cx, y + 14, b, font(17, True), th["text"])
            centered(d, cx, y + 33, kind, font(13), th["muted"])
        else:
            centered(d, cx, y + HEAD_H / 2, b, font(20, True), th["text"])
    y += HEAD_H
    d.line([(x0 * S, y * S), ((W - PAD) * S, y * S)], fill=th["line"], width=S)
    for label, cells in ROWS:
        d.text(((x0 + 4) * S, (y + ROW_H / 2) * S), label, font=font(16, True), fill=th["text"], anchor="lm")
        for i, (state, main, sub, best) in enumerate(cells):
            delta = best if isinstance(best, tuple) else None
            best = best is True
            bgc, fg = th[state]
            cx0 = x0 + LABEL_W + COL_W * i + 4
            r = [cx0 * S, (y + 4) * S, (cx0 + COL_W - 8) * S, (y + ROW_H - 4) * S]
            if state != "none":
                d.rounded_rectangle(r, 8 * S, fill=bgc)
            if best:
                d.rounded_rectangle(r, 8 * S, outline=fg, width=2 * S)
            elif state == "none":
                d.rounded_rectangle(r, 8 * S, outline=th["line"], width=S)
            elif state in ("second", "last"):
                d.rounded_rectangle(r, 8 * S, outline=fg, width=S)
            cx = cx0 + (COL_W - 8) / 2
            mf = font(17, best)
            lines = wrap(d, main, mf, COL_W - 28)
            n = len(lines) + (1 if sub else 0) + (1 if delta else 0)
            lh = 21
            ty = y + ROW_H / 2 - (n - 1) * lh / 2
            for ln in lines:
                centered(d, cx, ty, ln, mf, th["text"]); ty += lh
            if sub:
                centered(d, cx, ty - 1, sub, font(13), th["muted"])
                ty += lh - 3
            if delta:
                if delta[1] == "bad":
                    centered(d, cx, ty, delta[0], font(14, True), th["bad"][1])
                else:
                    centered(d, cx, ty, delta[0], font(14), th["muted"])
        y += ROW_H
        d.line([(x0 * S, y * S), ((W - PAD) * S, y * S)], fill=th["line"], width=S)
    # legend
    y += 18
    lx = x0
    for state, txt in spec["legend"]:
        bgc, fg = th[state]
        d.rounded_rectangle([lx * S, y * S, (lx + 18) * S, (y + 14) * S], 3 * S, fill=bgc, outline=fg, width=S)
        d.text(((lx + 26) * S, (y + 7) * S), txt, font=font(13), fill=th["muted"], anchor="lm")
        lx += 26 + d.textlength(txt, font=font(13)) / S + 22
    if spec.get("best_legend"):
        d.rounded_rectangle([lx * S, y * S, (lx + 18) * S, (y + 14) * S], 3 * S, outline=th["text"], width=2 * S)
        d.text(((lx + 26) * S, (y + 7) * S), "Best in row (bold, outlined)", font=font(13), fill=th["muted"], anchor="lm")
    y += 28
    for k, nl in enumerate(nlines):
        d.text((x0 * S, (y + 6 + 18 * k) * S), nl, font=font(13), fill=th["muted"], anchor="lm")
    if nlines:
        y += note_h
    d.text((x0 * S, (y + 6) * S), spec.get("footer", "iPhone 12 · Round 1 (no skills) · github.com/notolivaresf/uikit-vs-swiftui"),
           font=font(13), fill=th["muted"], anchor="lm")
    out = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "images",
                       spec["file"] + (".png" if name == "light" else "-dark.png"))
    img.save(out)
    print(os.path.normpath(out), img.size)


if __name__ == "__main__":
    import sys
    for n in THEMES:
        if "--round4-all" in sys.argv:
            render(n, R4ALL)
        elif "--round4-appkit-vs-swiftui" in sys.argv:
            render(n, R4AK)
        elif "--uikit-vs-swiftui-skills" in sys.argv:
            render(n, UKSW)
        elif "--swiftui-skills" in sys.argv:
            render(n, SWSK)
        elif "--swiftui-3way" in sys.argv:
            render(n, SW3)
        elif "--round2-gap" in sys.argv:
            render(n, L2GAP)
        elif "--round3-best" in sys.argv:
            render(n, L2R3)
        elif "--round2-best" in sys.argv:
            render(n, L2B)
        elif "--round2-best3" in sys.argv:
            render(n, L2B3)
        elif "--round2" in sys.argv:
            render(n, L2)
        else:
            render(n)
            render(n, BEST)
