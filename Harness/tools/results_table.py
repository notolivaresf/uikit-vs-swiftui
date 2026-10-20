#!/usr/bin/env python3
"""Render the README results table to docs/images/results.png (light) and results-dark.png.

Data is in ROWS below. Cell state: ok (green), bad (red), warn (yellow), none (plain).
best=True marks the best number in a row: bold text and a thin darker border.
Usage: python3 Harness/tools/results_table.py
       python3 Harness/tools/results_table.py --l2   (Level 2 only: docs/images/results-l2.png and -dark.png)
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

# --- Level 2 (docs/results-l2.md): six builds, rendered only with --l2 ---
L2_BUILDS = [("uikit-ours-pair", "UIKit, Swift, our pair"), ("swiftui-apple", "SwiftUI, Apple's skills"),
             ("objc-ours-objc-pair", "UIKit, Objective-C, our pair")] * 2
L2_ROWS = [
    ("Passes everything", [("ok", "Pass", "", True), ("bad", "2 fails", "", False), ("bad", "1 fail", "", False),
                           ("bad", "1 fail", "", False), ("bad", "2 fails", "", False), ("bad", "1 fail", "", False)]),
    ("First 40 rows (cold)", [("ok", "252 ms", "", False), ("ok", "326 ms", "", False), ("ok", "158 ms", "", True),
                              ("ok", "196 ms", "", False), ("ok", "314 ms", "", False), ("ok", "198 ms", "", False)]),
    ("Fling", [("ok", "58.0 fps", "2 hitches", False), ("ok", "57.9 fps", "5 hitches", False),
               ("ok", "58.7 fps", "2 hitches", True), ("ok", "58.2 fps", "0 hitches", False),
               ("ok", "58.0 fps", "0 hitches", False), ("ok", "58.3 fps", "1 hitch", False)]),
    ("Live stream, 600 messages", [("ok", "15.2 fps", "1 hitch", False), ("ok", "22.0 fps", "425 hitches", False),
                                   ("ok", "27.3 fps", "3 hitches", False), ("ok", "22.4 fps", "6 hitches", False),
                                   ("ok", "33.2 fps", "242 hitches", False), ("ok", "37.3 fps", "9 hitches", True)]),
    ("Jump to message 2,500", [("ok", "90 ms", "", False), ("ok", "154 ms", "", False), ("ok", "67 ms", "", True),
                               ("ok", "77 ms", "", False), ("ok", "191 ms", "", False), ("ok", "109 ms", "", False)]),
    ("Load older", [("ok", "93 ms", "drift 0.0 pt", False), ("ok", "86 ms", "drift 0.2 pt", False),
                    ("ok", "34 ms", "drift 0.1 pt", True), ("ok", "75 ms", "drift 0.0 pt", False),
                    ("ok", "143 ms", "drift 0.1 pt", False), ("ok", "106 ms", "drift 0.0 pt", False)]),
    ("Peak memory", [("none", "107.9 MB", "", False), ("none", "215.4 MB", "", False), ("none", "52.0 MB", "", False),
                     ("none", "44.5 MB", "", False), ("none", "103.4 MB", "", False), ("none", "35.0 MB", "", True)]),
    ("Text selection", [("ok", "Pass", "", False), ("bad", "Fail", "", False), ("bad", "Fail", "", False),
                        ("bad", "Fail", "", False), ("bad", "Fail", "", False), ("bad", "Fail", "", False)]),
    ("Stack rule", [("ok", "Pass", "", False), ("bad", "Fail", "uses UIPasteboard", False), ("ok", "Pass", "", False),
                    ("ok", "Pass", "", False), ("bad", "Fail", "uses UIPasteboard", False), ("ok", "Pass", "", False)]),
    ("App size", [("none", "0.71 MB", "", False), ("none", "1.50 MB", "", False), ("none", "0.66 MB", "", False),
                  ("none", "0.64 MB", "", True), ("none", "1.20 MB", "", False), ("none", "2.70 MB", "icon assets", False)]),
]
L2 = dict(title="UIKit vs SwiftUI, Level 2", subtitle="Same Campfire chat room, built six times with skills installed. Level 2 results.",
          builds=L2_BUILDS, rows=L2_ROWS, col_w=210, file="results-l2",
          groups=[("Opus 5.5", (0, 2)), ("GPT-6.1 Sol", (3, 5))],
          legend=[("ok", "Pass"), ("bad", "Fail")], best_legend=True,
          footer="iPhone 12 · Level 2 · github.com/notolivaresf/uikit-vs-swiftui")

# --- Level 2 best of each stack (docs/results-l2-best.md), rendered only with --l2-best ---
# UIKit = opus-uikit-ours-pair (index 0 of L2_ROWS), SwiftUI = sol-swiftui-apple (index 4). Numbers come from L2_ROWS;
# only the rows below that L2_ROWS does not hold are typed here (all from docs/results-l2.md).
_U, _W = 0, 4


def _l2(label):
    return dict(L2_ROWS)[label]


def _pair(label, uw, ww):
    """uw/ww in {"win","lose","tie","close"}: row result for UIKit and SwiftUI. Cells come from L2_ROWS."""
    c = _l2(label)
    st = {"win": "ok", "lose": "bad", "tie": "none", "close": "warn"}
    out = []
    for i, r in ((_U, uw), (_W, ww)):
        _, main, sub, _ = c[i]
        out.append((st[r], main, sub, r == "win"))
    return (label, out)


L2B_ROWS = [
    ("Passes everything", [("ok", "Pass", "", True), ("bad", "2 fails", "", False)]),
    ("Stack rule", [("ok", "Pass", "", True), ("bad", "Fail", "uses UIPasteboard", False)]),
    _pair("First 40 rows (cold)", "win", "lose"),
    ("Cold launch (Instruments)", [("none", "843 ms", "1 of 3 traces saved", False), ("warn", "Not measured", "0 of 3 traces saved", False)]),
    ("Fling", [("bad", "58.0 fps", "2 hitches (33 ms in 51 s)", False), ("ok", "58.0 fps", "0 hitches (41 s)", True)]),
    ("Live stream, 600 messages", [("ok", "15.2 fps", "1 hitch (17 ms), CPU 12.2 s", True), ("bad", "33.2 fps", "242 hitches (4.9 s), CPU 22.1 s", False)]),
    _pair("Jump to message 2,500", "win", "lose"),
    _pair("Load older", "win", "lose"),
    ("Text size change", [("ok", "83 / 103 ms", "bottom / mid-list", True), ("bad", "123 / 139 ms", "bottom / mid-list", False)]),
    ("Rotation, boost, menu", [("none", "Pass", "all three", False), ("none", "Pass", "all three", False)]),
    ("Text selection", [("ok", "Pass", "", True), ("bad", "Fail", "", False)]),
    ("Peak memory", [("bad", "107.9 MB", "", False), ("ok", "103.4 MB", "4% less", True)]),
    _pair("App size", "win", "lose"),
    ("Agent wall time", [("bad", "2231 s", "95 turns, 12 builds (0 failed)", False), ("ok", "1209 s", "113 turns, 15 builds (8 failed)", True)]),
]
L2B = dict(title="Best UIKit vs best SwiftUI, Level 2",
           subtitle="opus-uikit-ours-pair (Swift) against sol-swiftui-apple. Colour shows who wins the row.",
           builds=[("UIKit", "opus-uikit-ours-pair"), ("SwiftUI", "sol-swiftui-apple")], rows=L2B_ROWS, col_w=330, file="results-l2-best",
           groups=None, row_h=58,
           legend=[("ok", "Wins the row"), ("bad", "Loses the row"), ("none", "Tie"), ("warn", "Not measured")],
           footer="iPhone 12 · Level 2 · github.com/notolivaresf/uikit-vs-swiftui")

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
    H = PAD + title_h + group_h + HEAD_H + ROW_H * len(ROWS) + 56 + PAD
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
        elif "--l2" in sys.argv:
            render(n, L2)
        else:
            render(n)
            render(n, BEST)
