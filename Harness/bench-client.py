#!/usr/bin/env python3
"""./bench in a build folder: asks the bench broker (which runs outside the agent's sandbox, where the simulator
and the signing keys are) to build and measure this folder, and prints what the broker writes back.
Needs only this folder: requests and answers are files under .bench-work/requests/.

  bench-client.py <folder> [<number> | --build | --device | --device-full] [--direct]
"""
import json, os, subprocess, sys, time

root = os.path.abspath(sys.argv[1])
args = sys.argv[2:]
NUMBERS = {  # name: what it measures
    "rows-cold": "first 40 rows, cold (fresh install and launch)",
    "rows-repeat": "first 40 rows, repeated launches",
    "stream": "stream CPU (plays the 30 s stream, so about 45 s)",
    "jump": "jump to message 2,500",
    "older": "load older",
    "textsize-bottom": "text size, at the bottom",
    "textsize-mid": "text size, mid-list",
    "memory": "peak memory (plays the 30 s stream too)",
    "size": "app size (build only)",
}
if "--help" in args or "-h" in args:
    print("./bench             all numbers and the 13 checks\n./bench <number>    only that number, much faster (build, launch, record, one row)\n"
          "./bench --build     compile only\n./bench --device | --device-full   the iPhone 12 (ours)\n\nnumbers:")
    for k, v in NUMBERS.items():
        print("  %-16s %s" % (k, v))
    sys.exit(0)
number = next((a for a in args if not a.startswith("-")), None)
if number and number not in NUMBERS:
    sys.exit("unknown number '%s'. Try ./bench --help; the names are: %s" % (number, ", ".join(NUMBERS)))
mode = "sim"
if "--device" in args: mode = "device"
if "--device-full" in args: mode = "device-full"
if "--build" in args: mode = "build"
H = os.path.join(root, ".bench", "Harness")

# 1. locks, checked here too so a changed file is reported at once (the broker checks again against its own copy)
r = subprocess.run([sys.executable, "-I", os.path.join(H, "lockcheck.py"), "verify", "--root", root,
                    "--locks", os.path.join(root, ".bench", "locks.json")], capture_output=True, text=True)
if r.returncode != 0:
    print(r.stdout.strip())
    print("Not scoring. Put these back as they were, then run ./bench again.")
    sys.exit(3)

if "--direct" in args:
    # for us, outside any sandbox: UVS_HARNESS is the repo's Harness folder (the folder's own copy is never run)
    RH = os.environ.get("UVS_HARNESS")
    if not RH:
        sys.exit("--direct needs UVS_HARNESS (the repo's Harness folder)")
    lockdir = open(os.path.join(root, ".bench", "lockdir")).read().strip()
    sys.exit(subprocess.call([sys.executable, "-I", os.path.join(RH, "withlock.py"), os.path.join(lockdir, "measure.lock"),
                              open(os.path.join(root, ".bench", "name")).read().strip() + " " + mode, "--",
                              os.path.join(RH, "bench-inner.sh"), mode, root] + ([number] if number and mode == "sim" else [])))

# 2. ask the broker
rq = os.path.join(root, ".bench-work", "requests")
os.makedirs(rq, exist_ok=True)
rid = "%s-%d" % (time.strftime("%Y%m%d-%H%M%S"), os.getpid())
base = os.path.join(rq, rid)
open(base + ".out", "w").close()
json.dump({"mode": mode, "pid": os.getpid(), "number": number if mode == "sim" else None}, open(base + ".tmp", "w"))
os.rename(base + ".tmp", base + ".req")
print("queued (%s). The measuring runs outside this sandbox, one build at a time; waiting for its turn ..." % mode, flush=True)
pos, started, last_note = 0, time.time(), 0
while True:
    with open(base + ".out") as f:
        f.seek(pos)
        chunk = f.read()
        pos = f.tell()
    if chunk:
        sys.stdout.write(chunk); sys.stdout.flush()
    if os.path.exists(base + ".done"):
        with open(base + ".out") as f:
            f.seek(pos); sys.stdout.write(f.read())
        sys.exit(int(open(base + ".done").read().strip() or 1))
    if time.time() - last_note > 120 and not chunk:
        last_note = time.time()
        print("... still waiting (%d min). If this stays silent, the bench broker is not running." % ((time.time() - started) / 60), flush=True)
    time.sleep(2)
