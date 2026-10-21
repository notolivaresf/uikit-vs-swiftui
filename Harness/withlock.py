#!/usr/bin/env python3
"""Runs a command while holding the iPhone lock, so two ./bench runs (two agents) never use the phone at once.
Waits its turn (first come, first served is not guaranteed, but nobody starves in practice) and says who holds it.

  withlock.py LOCKFILE LABEL -- command args...

LOCKFILE's folder is made when missing. The holder's label, pid and start time are written into the lock file.
"""
import fcntl, json, os, subprocess, sys, time

lock, label = sys.argv[1], sys.argv[2]
cmd = sys.argv[sys.argv.index("--") + 1:]
os.makedirs(os.path.dirname(lock), exist_ok=True)
f = open(lock, "a+")
waited = 0
while True:
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        break
    except OSError:
        if waited % 60 == 0:
            f.seek(0)
            try:
                h = json.loads(f.read() or "{}")
            except ValueError:
                h = {}
            print("waiting for the iPhone (in use by %s since %s); waited %d s so far"
                  % (h.get("label", "another bench"), h.get("since", "?"), waited), flush=True)
        time.sleep(5)
        waited += 5
f.seek(0); f.truncate()
f.write(json.dumps({"label": label, "pid": os.getpid(), "since": time.strftime("%H:%M:%S")}))
f.flush()
if waited:
    print("got the iPhone after %d s" % waited, flush=True)
sys.exit(subprocess.call(cmd))
