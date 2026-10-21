#!/usr/bin/env python3
"""The bench broker. Runs outside any agent sandbox (we start it before Round 3 and leave it running); the
./bench of every Round 3 folder talks to it through files. It runs one request at a time, oldest first, which is
also the measure lock: two agents never build or measure at the same moment. It uses the repo's own harness
and the lock checksums saved outside the folders (<builds root>/.locks/), so nothing an agent edits is run.

  bench-broker.py [--root ~/uvs-builds] [--once]
"""
import glob, json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
root = os.path.expanduser("~/uvs-builds")
once = "--once" in sys.argv
if "--root" in sys.argv:
    root = os.path.expanduser(sys.argv[sys.argv.index("--root") + 1])


def log(m):
    print(time.strftime("%H:%M:%S ") + m, flush=True)


def pending():
    reqs = []
    for p in glob.glob(os.path.join(root, "round3-*", ".bench-work", "requests", "*.req")):
        if not os.path.exists(p[:-4] + ".done") and not os.path.exists(p[:-4] + ".taken"):
            reqs.append(p)
    return sorted(reqs, key=lambda p: os.path.basename(p))


def serve(req):
    base = req[:-4]
    folder = os.path.dirname(os.path.dirname(os.path.dirname(req)))
    name = os.path.basename(folder)
    open(base + ".taken", "w").close()
    rq = json.load(open(req))
    out = open(base + ".out", "a", buffering=1)
    log("%s: %s" % (name, rq["mode"]))
    locks = os.path.join(root, ".locks", name + ".json")
    r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "lockcheck.py"), "verify", "--root", folder, "--locks", locks],
                       capture_output=True, text=True)
    if r.returncode != 0:
        out.write(r.stdout + "Not scoring. Put these back as they were, then run ./bench again.\n")
        rc = 3
    else:
        rc = subprocess.call([os.path.join(HERE, "bench-inner.sh"), rq["mode"], folder], stdout=out, stderr=subprocess.STDOUT)
    out.close()
    open(base + ".done", "w").write(str(rc))
    log("%s: done, exit %d" % (name, rc))


subprocess.call([sys.executable, "-I", os.path.join(HERE, "sims.py"), "ensure"])
log("broker ready, watching %s" % root)
while True:
    reqs = pending()
    if reqs:
        serve(reqs[0])
    elif once:
        break
    else:
        time.sleep(2)
