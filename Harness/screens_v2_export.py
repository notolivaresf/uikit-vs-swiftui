"""Copies ScreensV2 attachments to <name>.png and writes notes-<phase>.md from the test log.

usage: screens_v2_export.py <raw dir> <out dir> <test.log> <notes.md> <build> <phase>
"""
import json, shutil, sys
from pathlib import Path

raw, out, log, notes, build, phase = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4]), sys.argv[5], sys.argv[6]
names = []
for test in json.loads((raw / "manifest.json").read_text()):
    for att in test.get("attachments", []):
        name = att["suggestedHumanReadableName"].rsplit("_", 2)[0]
        if not name.startswith(("room-", "row-")):
            continue
        shutil.copyfile(raw / att["exportedFileName"], out / f"{name}.png")
        names.append(name)

shots, misses, bars, infos, seen = [], [], [], [], set()
for line in log.read_text(errors="replace").splitlines():
    for tag, bucket in (("UVS_SHOT ", shots), ("UVS_MISS ", misses), ("UVS_BAR ", bars), ("UVS_INFO ", infos)):
        i = line.find(tag)
        # xcodebuild echoes some lines; keep each once, and skip the source-code echo.
        if i >= 0 and '\\(' not in line:
            text = line[i + len(tag):].strip()
            if (tag, text) not in seen:
                seen.add((tag, text)); bucket.append(text)
fails = [l.strip() for l in log.read_text(errors="replace").splitlines() if "error:" in l and "XCTAssert" in l or ": error: -[" in l]

md = [f"# {build}: screens-v2 {phase}", "", f"{len(names)} PNGs: " + ", ".join(sorted(f"{n}.png" for n in names)), "", "## State label per capture", ""]
md += [f"- {s.replace(' | ', ': `', 1)}`" for s in shots] or ["- none"]
md += ["", "## Not reached", ""] + ([f"- {m}" for m in misses] or ["- nothing"])
if fails:
    md += ["", "## Test failures", ""] + [f"- {f}" for f in fails[:10]]
if bars:
    md += ["", "## Debug bar (frames in points, portrait)", ""] + [f"- {b}" for b in bars]
if infos:
    md += ["", "## Other", ""] + [f"- {i}" for i in infos]
notes.write_text("\n".join(md) + "\n")
print(f"{len(names)} screenshots in {out}; notes in {notes}")
