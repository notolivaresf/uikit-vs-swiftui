"""Side-by-side PNGs: reference, opus-uikit, opus-swiftui, sol-uikit, sol-swiftui, one per state and theme.
Usage: screens_compare.py <reference screens dir> <runs/screens dir>   (needs Pillow)
Output: <runs/screens>/compare/<state>-<light|dark>.png. States without a reference shot get a grey tile."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ref_dir, runs = Path(sys.argv[1]), Path(sys.argv[2])
builds = ["opus-uikit", "opus-swiftui", "sol-uikit", "sol-swiftui"]
ref_name = {"room-bottom": "room-bottom", "room-top": "room-top"}
H, LABEL = 1400, 60
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 40)
(runs / "compare").mkdir(exist_ok=True)

def tile(path, label):
    w = round(1170 * H / 2532)
    img = Image.open(path).convert("RGB") if path else Image.new("RGB", (w, H), (200, 200, 200))
    img = img.resize((round(img.width * H / img.height), H), Image.LANCZOS)
    t = Image.new("RGB", (img.width, H + LABEL), "white")
    t.paste(img, (0, LABEL))
    ImageDraw.Draw(t).text((10, 8), label if path else label + " (no shot)", fill="black", font=font)
    return t

for state in ["room-bottom", "room-top", "jump-2500", "context-menu"]:
    for theme in ["light", "dark"]:
        r = ref_name.get(state)
        rp = ref_dir / (f"{r}.png" if theme == "light" else f"{r}-dark.png") if r else None
        tiles = [tile(rp, "reference")] + [tile(runs / b / f"{state}-{theme}.png", b) for b in builds]
        sheet = Image.new("RGB", (sum(t.width for t in tiles) + 20 * len(tiles), H + LABEL), "white")
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0)); x += t.width + 20
        sheet.save(runs / "compare" / f"{state}-{theme}.png")
