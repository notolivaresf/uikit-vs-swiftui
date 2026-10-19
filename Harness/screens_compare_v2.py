"""Comparison sheets for the screens-v2 round: the Campfire reference seeded with the builds' own data
(uikit-vs-swiftui reference/screens-fixture) next to the four builds, all at the same scale (points), light and dark.

Usage: screens_compare_v2.py <reference screens-fixture dir> <runs/screens-v2 dir>   (needs Pillow)
Output: <runs/screens-v2>/compare/room-bottom-<theme>.png, room-top-<theme>.png, rows-<group>-<theme>.png

Every shot is 3 px per point (Chrome at deviceScaleFactor 3, iPhone 12 at @3x), so tiles are placed point for point.
Phone shots lose the status bar (top 47 pt); the reference is a browser viewport with no status bar. A build that
hides the status bar (its top 30 px are not one colour) keeps its whole shot.
Rows: the reference crop is Campfire's own .message element. A build's row is cropped from its full-screen
row-<kind>-<id> shot by the frame in row-<kind>-<id>.json (the cell holding the row; for builds without cells the
text element, widened to the row: from 34 pt above the text, 70 more for the day separator's date band, to the
reference row's height)."""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ref_dir, runs = Path(sys.argv[1]), Path(sys.argv[2])
builds = ["opus-uikit", "opus-swiftui", "sol-uikit", "sol-swiftui"]
rows = json.loads((runs / "row-ids.json").read_text())["rows"]
GROUPS = {
    "text": ["long-text", "threaded", "mine", "mention", "mention-me", "text-boosts"],
    "media": ["image-boosts", "code", "file", "emoji-only", "long-boosts", "day-separator"],
}
# states a build cannot reach, marked on its grey tile
UNREACHED = {("sol-swiftui", "room-top"): "can't reach the top (stalls at message 2,220)"}
PX, STATUS = 3, 47                  # px per point; iPhone 12 status bar in points
OUT_SCALE = 0.5                      # sheet pixels per screenshot pixel
GAP, LABEL = 24, 70
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 44)
small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 34)
out = runs / "compare"
out.mkdir(exist_ok=True)

def theme_name(base, theme, ref):
    # reference: <name>-light.png / <name>-dark.png; builds: <name>.png / <name>-dark.png
    return f"{base}-{theme}.png" if ref else (f"{base}.png" if theme == "light" else f"{base}-dark.png")

def grey(w, h, text):
    img = Image.new("RGB", (w, h), (205, 205, 205))
    ImageDraw.Draw(img).text((20, 20), text, fill="black", font=small)
    return img

def phone_room(path):
    img = Image.open(path).convert("RGB")
    lo, hi = img.convert("L").crop((0, 0, img.width, 30)).getextrema()
    if hi - lo > 40:                 # app hides the status bar (sol-uikit): its header starts at y 0, keep it
        return img
    return img.crop((0, STATUS * PX, img.width, img.height))

def build_row(build, kind, rid, theme, ref_h):
    stem = f"row-{kind}-{rid}"
    png = runs / build / theme_name(stem, theme, False)
    meta = runs / build / f"{stem}{'' if theme == 'light' else '-dark'}.json"
    if not meta.exists():
        meta = runs / build / f"{stem}.json"
    if not png.exists():
        return None, "no shot"
    img = Image.open(png).convert("RGB")
    info = json.loads(meta.read_text()) if meta.exists() else {}
    f = info.get("frame")
    if not f:
        return None, "no frame"
    x, y, w, h = f
    if info.get("source") != "cell":
        # the day-separator reference row carries the date band (about 70 pt) above the message header
        y, h = y - 34 - (70 if kind == "day-separator" else 0), ref_h / PX
    top = max(round(y * PX), STATUS * PX)
    return img.crop((0, top, img.width, min(img.height, round((y + h) * PX)))), info.get("source", "")

def sheet(columns, path, title):
    """columns: list of (label, [tile images]) — each column stacks its tiles; tile i of every column aligns."""
    n = max(len(c[1]) for c in columns)
    heights = [max((c[1][i].height for c in columns if c[1][i] is not None), default=200) for i in range(n)]
    widths = [max(t.width for t in c[1] if t is not None) for c in columns]
    W = sum(widths) + GAP * (len(columns) + 1)
    H = LABEL * 2 + sum(heights) + GAP * (n + 1)
    s = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(s)
    d.text((GAP, 10), title, fill="black", font=font)
    x = GAP
    for (label, tiles), w in zip(columns, widths):
        d.text((x, LABEL + 10), label, fill="black", font=font)
        y = LABEL * 2
        for t, h in zip(tiles, heights):
            y += GAP
            if t is not None:
                s.paste(t, (x, y))
            y += h
        x += w + GAP
    s = s.resize((round(s.width * OUT_SCALE), round(s.height * OUT_SCALE)), Image.LANCZOS)
    s.save(path)
    print(path)

for theme in ["light", "dark"]:
    for state in ["room-bottom", "room-top"]:
        cols = [("Campfire reference", [Image.open(ref_dir / theme_name(state, theme, True)).convert("RGB")])]
        for b in builds:
            p = runs / b / theme_name(state, theme, False)
            why = UNREACHED.get((b, state), "no shot")
            cols.append((b, [phone_room(p) if p.exists() else grey(390 * PX, 800 * PX, why)]))
        sheet(cols, out / f"{state}-{theme}.png", f"{state}, {theme}: same data (CampfireKit seed), status bar cropped on the phone shots")
    for group, kinds in GROUPS.items():
        ref_tiles, notes = [], []
        for k in kinds:
            p = ref_dir / theme_name(f"row-{k}", theme, True)
            ref_tiles.append(Image.open(p).convert("RGB") if p.exists() else grey(393 * PX, 100 * PX, f"{k}: no shot"))
        cols = [("Campfire reference", ref_tiles)]
        for b in builds:
            tiles = []
            for k, rt in zip(kinds, ref_tiles):
                img, why = build_row(b, k, rows[k], theme, rt.height)
                tiles.append(img if img is not None else grey(390 * PX, rt.height, f"{k} {rows[k]}: {why}"))
            cols.append((b, tiles))
        label = ", ".join(f"{k} ({rows[k]})" for k in kinds)
        sheet(cols, out / f"rows-{group}-{theme}.png", f"rows, {theme}: {label}")
