#!/usr/bin/env python3
"""Round 3 locks. Files the agent must not change are recorded at setup (sha256 of every file under the locked
folders and of the locked single files, plus "pins": short pieces of the build's own debug-bar timing code that
must stay in their file). `verify` lists what changed. Standard library only.

  lockcheck.py create --root DIR --out locks.json --pins pins.json
  lockcheck.py verify --root DIR --locks locks.json [--json]

Locked folders: CampfireKit/, Fixtures/, screenshots/, .bench/ (the harness: tests, scripts, best-seen numbers).
Locked files: PROMPT.md, bench. Pins: pins.json is {"file": ["text that must still appear", ...]}; the count of
each text in its file may not drop.
"""
import argparse, hashlib, json, os, sys

DIRS = ["CampfireKit", "Fixtures", "screenshots", ".bench"]
FILES = ["PROMPT.md", "bench"]
SKIP = {".DS_Store", ".build", "__pycache__", "locks.json"}


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def walk(root):
    out = {}
    for d in DIRS:
        base = os.path.join(root, d)
        for dp, dn, fn in os.walk(base):
            dn[:] = [x for x in dn if x not in SKIP]
            for f in fn:
                if f in SKIP:
                    continue
                p = os.path.join(dp, f)
                if os.path.isfile(p):
                    out[os.path.relpath(p, root)] = sha(p)
    for f in FILES:
        p = os.path.join(root, f)
        if os.path.isfile(p):
            out[f] = sha(p)
    return out


def count(root, rel, text):
    try:
        return open(os.path.join(root, rel), errors="replace").read().count(text)
    except OSError:
        return 0


def create(a):
    pins_in = json.load(open(a.pins))
    pins = []
    for rel, texts in pins_in.items():
        for t in texts:
            n = count(a.root, rel, t)
            if n == 0:
                sys.exit("pin not found in %s: %s" % (rel, t))
            pins.append({"file": rel, "text": t, "count": n})
    json.dump({"files": walk(a.root), "pins": pins}, open(a.out, "w"), indent=1)


def verify(a):
    locks = json.load(open(a.locks))
    now = walk(a.root)
    changed = []
    for p, h in locks["files"].items():
        if p not in now:
            changed.append(p + " (removed)")
        elif now[p] != h:
            changed.append(p)
    for p in now:
        if p not in locks["files"]:
            changed.append(p + " (added)")
    for pin in locks["pins"]:
        if count(a.root, pin["file"], pin["text"]) < pin["count"]:
            changed.append("%s (timing code changed: %s)" % (pin["file"], pin["text"][:60]))
    res = {"ok": not changed, "changed": sorted(set(changed))}
    if a.json:
        print(json.dumps(res))
    else:
        print("locks ok" if res["ok"] else "LOCKED FILES CHANGED:\n  " + "\n  ".join(res["changed"]))
    return 0 if res["ok"] else 3


ap = argparse.ArgumentParser()
sub = ap.add_subparsers(dest="cmd", required=True)
c = sub.add_parser("create"); c.add_argument("--root", required=True); c.add_argument("--out", required=True); c.add_argument("--pins", required=True)
v = sub.add_parser("verify"); v.add_argument("--root", required=True); v.add_argument("--locks", required=True); v.add_argument("--json", action="store_true")
a = ap.parse_args()
sys.exit(create(a) or 0 if a.cmd == "create" else verify(a))
