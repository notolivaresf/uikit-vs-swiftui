#!/usr/bin/env python3
"""PreToolUse hook for a Round 3 Claude Code run: blocks web fetches, searches and shell commands that name the
benchmark's author or repo (notolivaresf, uikit-vs-swiftui, uikit-skill), including Wayback and cache copies of
them. A block is exit code 2 with the reason on stderr. Everything else passes. It reads only the tool call."""
import json, re, sys

BAD = re.compile(r"notolivaresf|uikit-vs-swiftui|uikit-skill", re.I)
try:
    call = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
inp = call.get("tool_input", {}) or {}
text = " ".join(str(inp.get(k, "")) for k in ("url", "query", "command", "prompt"))
if BAD.search(text):
    print("Blocked: this task works from this folder only; sources about this benchmark are off limits.", file=sys.stderr)
    sys.exit(2)
sys.exit(0)
