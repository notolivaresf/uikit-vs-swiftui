#!/usr/bin/env python3
"""./bench in a build folder: asks the bench broker (which runs outside the agent's sandbox, where the simulator
and the signing keys are) to build and measure this folder, and prints what the broker writes back.
Needs only this folder: requests and answers are files under .bench-work/requests/.

  bench-client.py <folder> [--device | --device-full] [--direct]
"""
import json, os, subprocess, sys, time

root = os.path.abspath(sys.argv[1])
args = sys.argv[2:]
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
                              os.path.join(RH, "bench-inner.sh"), mode, root]))

# 2. ask the broker
rq = os.path.join(root, ".bench-work", "requests")
os.makedirs(rq, exist_ok=True)
rid = "%s-%d" % (time.strftime("%Y%m%d-%H%M%S"), os.getpid())
base = os.path.join(rq, rid)
open(base + ".out", "w").close()
json.dump({"mode": mode, "pid": os.getpid()}, open(base + ".tmp", "w"))
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
