"""Copies the attachments that xcresulttool exported (raw/manifest.json) to <state>-<theme>.png files."""
import json, shutil, sys
from pathlib import Path

raw, out = Path(sys.argv[1]), Path(sys.argv[2])
manifest = json.loads((raw / "manifest.json").read_text())
n = 0
for test in manifest:
    for att in test.get("attachments", []):
        name = att["suggestedHumanReadableName"].split("_")[0]
        shutil.copyfile(raw / att["exportedFileName"], out / f"{name}.png")
        n += 1
print(f"{n} screenshots in {out}")
