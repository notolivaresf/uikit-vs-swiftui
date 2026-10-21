#!/usr/bin/env python3
"""After a Round 3 run: lists what a transcript touched outside the build folder.

  round3-audit.py <transcript.jsonl> <build folder> [--json]

Reads a Claude Code stream-json or a Codex --json transcript and looks at what the agent asked for: shell
commands, file paths of its tools, URLs. Flags, with the line number of the event:
  path     an absolute or ~ path outside the folder, the skills, Xcode and the system toolchain
  history  a git command that reads history (log, show, reflog, rev-list, cat-file, blame, diff against a commit)
  url      any URL that names the benchmark's author or repo (notolivaresf, uikit-vs-swiftui) or Wayback copies of them
  sibling  another build folder (round3-*, uvs-builds, olivares-burgos)
It reads the requests, not the results, so a flagged item is something the agent tried, whether it worked or not.
Exit 0 when nothing is flagged, 1 otherwise.
"""
import json, os, re, sys

ALLOWED_PREFIXES = ("/Applications/Xcode", "/Library/Developer", "/Library/Frameworks", "/System/", "/usr/", "/bin/", "/sbin/",
                    "/opt/homebrew/", "/private/var/", "/var/folders/", "/private/tmp", "/tmp", "/dev/", "/etc/", "/private/etc/",
                    "/Library/Apple", "/Library/Preferences", "/Library/Caches")
HOME_OK = ("Library/Developer", "Library/Caches", "Library/Logs", "Library/Preferences", "Library/Keychains",
           ".swiftpm", ".cache", ".uvs-bench")
PATH_RE = re.compile(r"(?<![\w.:/-])((?:~(?=/)|/(?:Users|Volumes|private|opt|Library|Applications|var|tmp|usr|etc))[\w@%+=:,.~/-]*)")
URL_RE = re.compile(r"https?://[^\s\"'`)\]>]+")
HIST_RE = re.compile(r"\bgit\s+(?:-C\s+\S+\s+)?(log|show|reflog|rev-list|cat-file|blame|whatchanged|diff\s+\S*[0-9a-f]{7,}|checkout\s+[0-9a-f]{7,})\b")
BAD_URL = re.compile(r"notolivaresf|uikit-vs-swiftui|uikit-skill", re.I)
SIBLING = re.compile(r"round3-[\w-]+|uvs-builds|olivares-burgos|opus-uikit|sol-uikit|opus-swiftui|sol-swiftui|opus-objc|sol-objc")


def requests(path):
    """Yield (line number, text of what the agent asked for)."""
    for n, line in enumerate(open(path, errors="replace"), 1):
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        t = ev.get("type")
        if t == "assistant":
            for b in ev.get("message", {}).get("content", []) or []:
                if b.get("type") == "tool_use":
                    yield n, json.dumps(b.get("input", {}), ensure_ascii=False)
        elif t in ("item.started", "item.completed"):
            it = ev.get("item", {})
            if it.get("type") == "command_execution":
                yield n, it.get("command", "")
            elif it.get("type") in ("file_change", "mcp_tool_call", "web_search"):
                yield n, json.dumps(it, ensure_ascii=False)[:4000]


def main():
    transcript, folder = sys.argv[1], os.path.abspath(sys.argv[2])
    home = os.path.expanduser("~")
    seen, flags = set(), []
    for n, text in requests(transcript):
        text = text.replace("\\n", " ").replace("\\/", "/")
        for m in PATH_RE.findall(text):
            p = os.path.expanduser(m.rstrip(".,;:'\"")) if m.startswith("~") else m.rstrip(".,;:'\"")
            if p.startswith(folder) or p.startswith(ALLOWED_PREFIXES) or p in ("/", "/Users", "/Library", "/Applications"):
                continue
            if p.startswith(home + "/") and p[len(home) + 1:].startswith(HOME_OK):
                continue
            if m.startswith("/Users") or m.startswith("~") or m.startswith("/Volumes"):
                if ("path", p) not in seen:
                    seen.add(("path", p)); flags.append((n, "path", p))
            if SIBLING.search(p) and ("sibling", p) not in seen:
                seen.add(("sibling", p)); flags.append((n, "sibling", p))
        for u in URL_RE.findall(text):
            if BAD_URL.search(u) and ("url", u) not in seen:
                seen.add(("url", u)); flags.append((n, "url", u))
        h = HIST_RE.search(text)
        if h and ("history", h.group(0)) not in seen:
            seen.add(("history", h.group(0))); flags.append((n, "history", text[:160]))
    if "--json" in sys.argv:
        print(json.dumps([{"line": n, "kind": k, "what": w} for n, k, w in flags], indent=1))
    else:
        for n, k, w in flags:
            print("line %d  %-8s %s" % (n, k, w))
        print("%d flagged" % len(flags) if flags else "nothing flagged")
    return 1 if flags else 0


sys.exit(main())
