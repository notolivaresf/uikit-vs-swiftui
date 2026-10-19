"""Joins runs/screens-v2/<build>/notes-<phase>.md into notes.md (latest capture per shot wins).

usage: screens_v2_notes.py <build dir> <phase> [<phase> ...]   (phases in run order, e.g. base toprows rows)
"""
import re, sys
from pathlib import Path

d = Path(sys.argv[1])
phases = sys.argv[2:]
labels, misses, bars, other = {}, {}, [], []
for ph in phases:
    f = d / f"notes-{ph}.md"
    if not f.exists():
        continue
    section = None
    shot_names = set()
    for line in f.read_text().splitlines():
        if line.startswith("## "):
            section = line[3:]
            continue
        if not line.startswith("- "):
            continue
        item = line[2:]
        if section == "State label per capture":
            name = item.split(":", 1)[0]
            labels[name] = (ph, item)
            shot_names.add(name)
        elif section == "Not reached" and item != "nothing":
            name = item.split(":", 1)[0]
            misses.setdefault(name, []).append((ph, item))
        elif section and section.startswith("Debug bar") and item not in bars:
            bars.append(item)
        elif section in ("Other", "Test failures"):
            other.append(f"{ph}: {item}")
    # A shot retaken in this phase drops older misses for it.
    for name in shot_names:
        misses[name] = [m for m in misses.get(name, []) if m[0] == ph]

pngs = sorted(p.name for p in d.glob("*.png"))
md = [f"# {d.name}: screens-v2", "", f"{len(pngs)} PNGs in this folder: " + ", ".join(pngs), "",
      "## State label per capture", ""]
md += [f"- {item}  (run: {ph})" for ph, item in labels.values()]
md += ["", "## Could not be reached", ""]
flat = [f"- {item}  (run: {ph})" for v in misses.values() for ph, item in v]
md += flat or ["- nothing"]
md += ["", "## Debug bar", "",
       "Only with -uvsBenchmark YES (room-bottom is taken without it, so no bar there). The bar sits at the bottom",
       "of the screen, below the composer: two rows of three buttons (Reset, Jump to 2500, Load older / Start stream,",
       "Text size +, Boost burst) and the state label under them. Frames in points (portrait):", ""]
md += [f"- {b}" for b in bars]
if other:
    md += ["", "## Other", ""] + [f"- {o}" for o in other]
(d / "notes.md").write_text("\n".join(md) + "\n")
print(f"notes.md for {d.name}: {len(labels)} labels, {len(flat)} misses")
