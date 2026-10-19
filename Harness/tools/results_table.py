#!/usr/bin/env python3
"""Render the README results table to docs/images/results.png (light) and results-dark.png.

Data is in ROWS below. Cell state: ok (green), bad (red), warn (yellow), none (plain).
best=True marks the best number in a row: bold text and a thin darker border.
Usage: python3 Harness/tools/results_table.py
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

S = 2  # scale
LABEL_W, COL_W, ROW_H, HEAD_H, GROUP_H = 250, 220, 62, 44, 36
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


def render(name):
    th = THEMES[name]
    W = PAD * 2 + LABEL_W + COL_W * 4
    title_h = 64
    H = PAD + title_h + GROUP_H + HEAD_H + ROW_H * len(ROWS) + 56 + PAD
    img = Image.new("RGB", (W * S, H * S), th["bg"])
    d = ImageDraw.Draw(img)
    x0 = PAD
    y = PAD
    d.text((x0 * S, (y + 14) * S), "UIKit vs SwiftUI", font=font(26, True), fill=th["text"], anchor="lm")
    d.text((x0 * S, (y + 46) * S), "Same Campfire chat room, built four times. Level 1 results.",
           font=font(15), fill=th["muted"], anchor="lm")
    y += title_h
    # group header
    for g, (a, b) in (("Opus 5.5", (0, 1)), ("GPT-6.1 Sol", (2, 3))):
        gx = x0 + LABEL_W + COL_W * a
        d.rounded_rectangle([(gx + 4) * S, y * S, (gx + COL_W * 2 - 4) * S, (y + GROUP_H - 6) * S], 8 * S, fill=th["head"])
        centered(d, gx + COL_W, y + (GROUP_H - 6) / 2, g, font(16, True), th["text"])
    y += GROUP_H
    for i, (b, kind) in enumerate(BUILDS):
        cx = x0 + LABEL_W + COL_W * i + COL_W / 2
        centered(d, cx, y + 14, b, font(17, True), th["text"])
        centered(d, cx, y + 33, kind, font(13), th["muted"])
    y += HEAD_H
    d.line([(x0 * S, y * S), ((W - PAD) * S, y * S)], fill=th["line"], width=S)
    for label, cells in ROWS:
        d.text(((x0 + 4) * S, (y + ROW_H / 2) * S), label, font=font(16, True), fill=th["text"], anchor="lm")
        for i, (state, main, sub, best) in enumerate(cells):
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
            n = len(lines) + (1 if sub else 0)
            lh = 21
            ty = y + ROW_H / 2 - (n - 1) * lh / 2
            for ln in lines:
                centered(d, cx, ty, ln, mf, th["text"]); ty += lh
            if sub:
                centered(d, cx, ty - 1, sub, font(13), th["muted"])
        y += ROW_H
        d.line([(x0 * S, y * S), ((W - PAD) * S, y * S)], fill=th["line"], width=S)
    # legend
    y += 18
    lx = x0
    for state, txt in (("ok", "Pass"), ("bad", "Fail"), ("warn", "Not measurable or not measured")):
        bgc, fg = th[state]
        d.rounded_rectangle([lx * S, y * S, (lx + 18) * S, (y + 14) * S], 3 * S, fill=bgc, outline=fg, width=S)
        d.text(((lx + 26) * S, (y + 7) * S), txt, font=font(13), fill=th["muted"], anchor="lm")
        lx += 26 + d.textlength(txt, font=font(13)) / S + 22
    d.rounded_rectangle([lx * S, y * S, (lx + 18) * S, (y + 14) * S], 3 * S, outline=th["text"], width=2 * S)
    d.text(((lx + 26) * S, (y + 7) * S), "Best in row (bold, outlined)", font=font(13), fill=th["muted"], anchor="lm")
    y += 28
    d.text((x0 * S, (y + 6) * S), "iPhone 12 · Level 1 · github.com/notolivaresf/uikit-vs-swiftui",
           font=font(13), fill=th["muted"], anchor="lm")
    out = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "images",
                       "results.png" if name == "light" else "results-dark.png")
    img.save(out)
    print(os.path.normpath(out), img.size)


if __name__ == "__main__":
    for n in THEMES:
        render(n)
