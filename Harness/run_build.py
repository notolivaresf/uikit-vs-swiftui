#!/usr/bin/env python3
"""Supervisor for one UvS build (called by launch-build.sh, not by hand).

Runs the model command in the build folder with a hard time limit, keeps the
transcript, and writes runs/<model>-<side>/meta.json from the transcript
(never from the model's own summary).

usage: run_build.py --model opus|sol --side uikit|swiftui
                    --build-dir DIR --run-dir DIR --requested-model NAME
                    --effort high -- <command...>
Environment is inherited (launch-build.sh sets CLAUDE_CONFIG_DIR / CODEX_HOME).
"""
import argparse, json, os, re, signal, subprocess, sys, threading, time
from datetime import datetime, timezone

BUILD_RE = re.compile(r"\b(xcodebuild|swift\s+build)\b")


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def parse_claude(path):
    turns, seen, model_version, init = 0, set(), None, {}
    cmds, results = {}, {}
    for line in open(path, errors="replace"):
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        t = ev.get("type")
        if t == "system" and ev.get("subtype") == "init":
            model_version = ev.get("model") or model_version
            init = {k: ev.get(k) for k in ("mcp_servers", "skills", "slash_commands", "agents", "plugins")}
        elif t == "assistant":
            msg = ev.get("message", {})
            mid = msg.get("id") or id(ev)
            if mid not in seen:
                seen.add(mid)
                turns += 1
            if msg.get("model"):
                model_version = msg["model"]
            for b in msg.get("content", []) or []:
                if b.get("type") == "tool_use" and b.get("name") == "Bash":
                    cmds[b["id"]] = (b.get("input") or {}).get("command", "")
        elif t == "user":
            for b in (ev.get("message", {}).get("content") or []):
                if isinstance(b, dict) and b.get("type") == "tool_result":
                    results[b.get("tool_use_id")] = bool(b.get("is_error"))
    total = failed = 0
    for tid, cmd in cmds.items():
        if BUILD_RE.search(cmd):
            total += 1
            failed += 1 if results.get(tid) else 0
    return dict(turns=turns, builds_total=total, builds_failed=failed, model_version=model_version, isolation_check=init)


def parse_codex(path):
    # turns = model actions: agent messages, commands, file changes, tool calls
    turns = total = failed = 0
    model_version = None
    for line in open(path, errors="replace"):
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        for k in ("model", "model_slug"):
            if isinstance(ev.get(k), str):
                model_version = ev[k]
        if ev.get("type") != "item.completed":
            continue
        it = ev.get("item", {})
        ty = it.get("type")
        if ty in ("agent_message", "command_execution", "file_change", "mcp_tool_call"):
            turns += 1
        if ty == "command_execution" and BUILD_RE.search(it.get("command", "")):
            total += 1
            ec = it.get("exit_code")
            if ec not in (0, None) or it.get("status") == "failed":
                failed += 1
    return dict(turns=turns, builds_total=total, builds_failed=failed, model_version=model_version)


def idle_gaps(path, limit=1200):
    try:
        ts = [float(x) for x in open(path)]
    except OSError:
        return None
    gaps = [round(b - a) for a, b in zip(ts, ts[1:]) if b - a > limit]
    return dict(count=len(gaps), seconds=sum(gaps), gaps_seconds=gaps)


def commits(build_dir):
    try:
        out = subprocess.run(["git", "-C", build_dir, "rev-list", "--count", "HEAD"],
                             capture_output=True, text=True).stdout.strip()
        return max(int(out) - 1, 0)  # minus the inputs commit
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--side", required=True)
    ap.add_argument("--level", default="L1")
    ap.add_argument("--build-dir", required=True)
    ap.add_argument("--run-dir", required=True)
    ap.add_argument("--requested-model", required=True)
    ap.add_argument("--effort", required=True)
    ap.add_argument("--cli-version", default="")
    ap.add_argument("--skillset-json", help="Level 2: skillset.py record, stored in meta.json")
    ap.add_argument("--expect-skills", help="Level 2, Claude: comma-separated skill names the init event must list "
                    "exactly (empty string = none); on a mismatch the build is stopped before it starts")
    ap.add_argument("--extra-json", help="Level 2: extra fields for meta.json (stack, inputs tag, config hashes)")
    ap.add_argument("--time-limit-s", type=int, default=0, help="Round 3: stop the model after this many seconds "
                    "(SIGTERM, then SIGKILL 30 s later); meta.json records stopped_by_limit")
    ap.add_argument("--parse-only", help="skip running; parse this transcript (self-test)")
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.cmd[1:] if a.cmd[:1] == ["--"] else a.cmd

    os.makedirs(a.run_dir, exist_ok=True)
    transcript = a.parse_only or os.path.join(a.run_dir, "transcript.jsonl")
    start, t0 = now(), time.time()
    exit_code = None
    isolation_error = None
    stopped_by_limit = False
    if not a.parse_only:
        with open(transcript, "wb") as out, open(os.path.join(a.run_dir, "transcript.times"), "w") as tm, \
                open(os.path.join(a.run_dir, "stderr.log"), "wb") as err:
            p = subprocess.Popen(cmd, cwd=a.build_dir, stdout=subprocess.PIPE, stderr=err)
            if a.time_limit_s:
                def stop_at_limit():
                    nonlocal stopped_by_limit
                    if p.poll() is None:
                        stopped_by_limit = True
                        p.terminate()
                        threading.Timer(30, lambda: p.poll() is None and p.kill()).start()
                threading.Timer(a.time_limit_s, stop_at_limit).start()
            for line in p.stdout:
                out.write(line); out.flush()
                tm.write("%.3f\n" % time.time()); tm.flush()
                if a.expect_skills is not None and a.model == "opus" and isolation_error is None and b'"init"' in line:
                    try:
                        ev = json.loads(line)
                    except ValueError:
                        continue
                    if ev.get("type") == "system" and ev.get("subtype") == "init":
                        want = sorted(x for x in a.expect_skills.split(",") if x)
                        got = sorted(ev.get("skills") or [])
                        isolation_error = "" if want == got else "init lists skills %s, expected %s" % (got, want)
                        if isolation_error:
                            print("STOPPING: " + isolation_error, file=sys.stderr)
                            p.terminate()
            exit_code = p.wait()
    stop, t1 = now(), time.time()
    idle = idle_gaps(os.path.join(os.path.dirname(transcript), "transcript.times"))
    parsed = (parse_claude if a.model == "opus" else parse_codex)(transcript)
    meta = dict(model=a.model, side=a.side, requested_model=a.requested_model,
                model_version=parsed.pop("model_version") or a.requested_model,
                effort=a.effort, cli_version=a.cli_version, level=a.level,
                start=start, stop=stop, wall_seconds=round(t1 - t0), idle_gaps_over_20min=idle,
                exit_code=exit_code, time_limit_s=a.time_limit_s or None, stopped_by_limit=stopped_by_limit, commits=commits(a.build_dir), transcript=os.path.basename(transcript),
                **parsed)
    if a.expect_skills is not None:
        meta["skill_isolation"] = dict(expected=sorted(x for x in a.expect_skills.split(",") if x),
                                       error=(isolation_error or None) if isolation_error is not None else ("no init event seen" if a.model == "opus" else None),
                                       checked=("claude init event" if a.model == "opus" else
                                                "none in the transcript: Codex prints no skill list; isolation is the generated config.toml (see skillset)"))
    if a.skillset_json:
        meta["skillset"] = json.load(open(a.skillset_json))
    if a.extra_json:
        meta.update(json.load(open(a.extra_json)))
    dest = os.path.join(a.run_dir, "meta.json")
    if a.parse_only:
        print(json.dumps(meta, indent=2))
        return 0
    with open(dest, "w") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    print("meta:", dest)
    return 0 if exit_code == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
