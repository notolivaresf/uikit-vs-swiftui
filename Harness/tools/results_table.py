#!/usr/bin/env python3
"""Render the README results table to docs/images/results.png (light) and results-dark.png.

Data is in ROWS below. Cell state: ok (green), bad (red), warn (yellow), none (plain).
best=True marks the best number in a row: bold text and a thin darker border.
Usage: python3 Harness/tools/results_table.py
       python3 Harness/tools/results_table.py --l2   (Level 2 only: docs/images/results-l2.png and -dark.png)
       python3 Harness/tools/results_table.py --l2-best3   (best of each stack's two builds, three columns: results-l2-best3.png and -dark.png)
       python3 Harness/tools/results_table.py --l2-best   (best UIKit vs best SwiftUI of Level 2: results-l2-best.png and -dark.png)
"""
import os
from PIL import Image, ImageDraw, ImageFont

HEL = "/System/Library/Fonts/Helvetica.ttc"
BUILDS = [("opus-uikit", "UIKit"), ("opus-swiftui", "SwiftUI"), ("sol-uikit", "UIKit"), ("sol-swiftui", "SwiftUI")]

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
                  head=(243, 243, 246)),
    "dark": dict(bg=(24, 24, 27), text=(240, 240, 243), muted=(160, 160, 168), line=(58, 58, 64),
                 ok=((30, 70, 42), (110, 200, 135)), bad=((84, 34, 34), (240, 130, 130)),
                 warn=((82, 68, 22), (235, 195, 85)), none=((24, 24, 27), (120, 120, 128)),
                 head=(38, 38, 43)),
}

FULL = dict(title="UIKit vs SwiftUI", subtitle="Same Campfire chat room, built four times. Level 1 results.",
            builds=BUILDS, rows=ROWS, col_w=220, file="results",
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
            builds=[("UIKit", ""), ("SwiftUI", "")], rows=best_rows(), col_w=300, file="results-best", groups=None, row_h=76,
            legend=[("ok", "Wins the row"), ("bad", "Loses the row"), ("warn", "Within 5%")])

# --- Level 2 (docs/results-l2.md): six builds (--l2) and best of each stack's pair (--l2-best3) ---
# One table of facts, one place. Each row: label, then per build (key, main, sub). Lower key is better; key None = not measured.
# Winners are computed (equal keys tie), nothing is marked by hand. All numbers are from docs/results-l2.md.
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


L2_HEAD = [("opus-uikit", "Opus"), ("sol-uikit", "Sol"), ("opus-objc", "Opus"), ("sol-objc", "Sol"), ("opus-swiftui", "Opus"), ("sol-swiftui", "Sol")]
_FOOT = "iPhone 12 · Level 2 · github.com/notolivaresf/uikit-vs-swiftui"
_LEG = [("ok", "Best in row (ties share it)"), ("none", "Not the best, or the whole row ties"), ("warn", "Not measured")]
L2 = dict(title="UIKit vs SwiftUI, Level 2",
          subtitle="The six builds, one column each. Rows ordered with hitches first; the best value in each row is outlined in green.",
          builds=L2_HEAD, rows=l2_six_rows(), col_w=210, file="results-l2", row_h=62,
          groups=[("UIKit Swift", (0, 1)), ("UIKit Objective-C", (2, 3)), ("SwiftUI", (4, 5))],
          legend=_LEG, note="fps counts redraws; hitches are late frames you can see", footer=_FOOT)

_B3_ROWS, B3_RECORD = l2_best3()
L2B3 = dict(title="Best of each stack, Level 2",
            subtitle="Each column takes the better of its two builds per row (Opus or Sol). Small text names the model the value came from.",
            builds=[("UIKit Swift", "best of 2 builds"), ("UIKit Objective-C", "best of 2 builds"), ("SwiftUI", "best of 2 builds")],
            rows=_B3_ROWS, col_w=330, file="results-l2-best3", groups=None, row_h=62,
            legend=_LEG, note="fps counts redraws; hitches are late frames you can see", footer=_FOOT)

# --- Level 2 best of each stack (docs/results-l2-best.md), rendered only with --l2-best ---
# Two columns. UIKit = best value per row across the four UIKit builds (Opus and Sol, Swift and Objective-C); SwiftUI = best
# per row of its two builds (mix and match). The small text names the source. All numbers are from docs/results-l2.md.
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
L2B = dict(title="Best of UIKit vs best of SwiftUI, Level 2",
           subtitle="Best value per row. UIKit: any of its four builds (Swift or Objective-C, Opus or Sol); SwiftUI: its two builds. Small text names the source.",
           builds=[("UIKit", "best of 4 builds: Swift and Objective-C, Opus and Sol"), ("SwiftUI", "best of 2 builds: Opus and Sol")],
           rows=L2B_ROWS, col_w=420, file="results-l2-best",
           groups=None, row_h=58,
           legend=[("ok", "Wins the row (ties both win)"), ("bad", "Loses the row"), ("none", "Tie"), ("warn", "Not measured")],
           note="fps counts redraws; hitches are late frames you can see",
           footer="iPhone 12 \u00b7 Level 2 \u00b7 github.com/notolivaresf/uikit-vs-swiftui")

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
    W = PAD * 2 + LABEL_W + COL_W * len(BUILDS)
    title_h = 64
    H = PAD + title_h + group_h + HEAD_H + ROW_H * len(ROWS) + 56 + PAD + (24 if spec.get("note") else 0)
    img = Image.new("RGB", (W * S, H * S), th["bg"])
    d = ImageDraw.Draw(img)
    x0 = PAD
    y = PAD
    d.text((x0 * S, (y + 14) * S), spec["title"], font=font(26, True), fill=th["text"], anchor="lm")
    d.text((x0 * S, (y + 46) * S), spec["subtitle"],
           font=font(15), fill=th["muted"], anchor="lm")
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
    if spec.get("note"):
        d.text((x0 * S, (y + 6) * S), spec["note"], font=font(13), fill=th["muted"], anchor="lm")
        y += 24
    d.text((x0 * S, (y + 6) * S), spec.get("footer", "iPhone 12 · Level 1 · github.com/notolivaresf/uikit-vs-swiftui"),
           font=font(13), fill=th["muted"], anchor="lm")
    out = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "images",
                       spec["file"] + (".png" if name == "light" else "-dark.png"))
    img.save(out)
    print(os.path.normpath(out), img.size)


if __name__ == "__main__":
    import sys
    for n in THEMES:
        if "--l2-best" in sys.argv:
            render(n, L2B)
        elif "--l2-best3" in sys.argv:
            render(n, L2B3)
        elif "--l2" in sys.argv:
            render(n, L2)
        else:
            render(n)
            render(n, BEST)
