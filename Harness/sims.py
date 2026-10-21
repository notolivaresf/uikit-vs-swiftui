#!/usr/bin/env python3
"""The two Round 3 simulators: fixed device type and iOS version, one per agent of a pair.
  sims.py ensure     create uvs-r3-a and uvs-r3-b when missing (never deletes or erases anything), boot both
  sims.py udid NAME  print a simulator's UDID
"""
import json, subprocess, sys

TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17"
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-26-4"
NAMES = ["uvs-r3-a", "uvs-r3-b"]


def devices():
    out = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))["devices"]
    return [d for rt, ds in out.items() for d in ds if rt == RUNTIME]


def state(name):
    for d in devices():
        if d["name"] == name:
            return d["state"]


def udid(name):
    for d in devices():
        if d["name"] == name:
            return d["udid"]


def main():
    if sys.argv[1] == "udid":
        u = udid(sys.argv[2])
        if not u:
            return 1
        print(u)
        return 0
    for n in NAMES:
        if not udid(n):
            subprocess.check_call(["xcrun", "simctl", "create", n, TYPE, RUNTIME])
        if state(n) == "Booted":
            continue
        if subprocess.call(["simcap", "ensure"]) != 0:
            print("simcap: no room for another simulator (2 already booted)", file=sys.stderr)
            return 1
        subprocess.call(["xcrun", "simctl", "boot", udid(n)])
        subprocess.call(["xcrun", "simctl", "bootstatus", udid(n), "-b"], stdout=subprocess.DEVNULL)
    return 0


sys.exit(main())
