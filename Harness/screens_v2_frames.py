"""Writes <out>/<shot>.json from the `UVS_FRAME <shot> {json}` lines of a ScreensV2 test log.

usage: screens_v2_frames.py <test.log> <out dir>
"""
import json, sys
from pathlib import Path

log, out = Path(sys.argv[1]), Path(sys.argv[2])
n = 0
for line in log.read_text(errors="replace").splitlines():
    i = line.find("UVS_FRAME ")
    if i < 0 or "\\(" in line:
        continue
    name, _, js = line[i + len("UVS_FRAME "):].strip().partition(" ")
    try:
        info = json.loads(js)
    except ValueError:
        continue
    (out / f"{name}.json").write_text(json.dumps(info, ensure_ascii=False, sort_keys=True) + "\n")
    n += 1
print(f"{n} frame files in {out}")
