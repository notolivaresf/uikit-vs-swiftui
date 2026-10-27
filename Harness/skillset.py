#!/usr/bin/env python3
"""Skill sets for Level 2 builds (called by launch-build.sh, not by hand).

  skillset.py --kind none|ours-slim|ours-full|ours-chatlist|ours-pair|ours-objc-pair|apple|avdlee|twostraws [--dest BUILD_DIR] [--install]

Prints one JSON record on stdout: the kind, the skills (name, version, source,
file count, hash of the folder) and the names a model should list. With --install the
folders are copied, identically, to BUILD_DIR/.claude/skills/ and BUILD_DIR/.agents/skills/
and the copied hash is checked against the source hash.

Hash of a skill folder (same formula as uikit-skill/docs/experiment-plan.md, run from the
skill repo root): sha256 of the text made of one line "<sha256 of file>  skills/<folder>/<path>"
per file, files sorted by path. Without --install nothing is written anywhere.

Sources
  ours-slim  git archive of tag UVS_SLIM_TAG (default v0.2-slim) of UVS_SKILL_REPO
             (default ~/olivares-burgos/uikit-skill), folder skills/uikit-specialist-slim
  ours-full  same repo, tag UVS_FULL_TAG (default v0.1), folder skills/uikit-specialist
  ours-chatlist  same repo, tag CHATLIST_TAG (v0.9.0; UVS_CHATLIST_TAG overrides), folder skills/uikit-chat-list only
  ours-pair  the two Swift skills vendored in this repo, skills/uikit/{uikit-specialist,
             uikit-whats-new-27} (copied from uikit-skill tag v0.3-pair, see skills/README.md)
  ours-objc-pair  skills/uikit-objc/{uikit-specialist-objc,uikit-whats-new-27-objc} of this repo
             (vendored later; the kind fails clearly while the folder is missing)
  avdlee     skills/avdlee/swiftui-expert-skill of this repo: Antoine van der Lee's third-party
             SwiftUI skill (MIT), vendored from github.com/AvdLee/SwiftUI-Agent-Skill at 204dba7
  twostraws  skills/twostraws/swiftui-pro of this repo: Paul Hudson's (@twostraws) third-party
             SwiftUI skill (MIT), vendored from github.com/twostraws/SwiftUI-Agent-Skill at 1eac100
             (the plugin packaging inside the folder, a nested skills/ symlink copy and .claude-plugin, is left out)
  apple      a local export of Apple's Xcode skills, UVS_APPLE_SKILLS (default: the newest
             ~/uvs-skills/apple-*), one sub-folder per skill with a SKILL.md; the skills are
             APPLE_SKILLS below. Apple's text is never copied into a repo: only names and
             hashes are recorded.
"""
import argparse, glob, hashlib, io, json, os, re, shutil, subprocess, sys, tarfile

APPLE_SKILLS = ["swiftui-specialist", "swiftui-whats-new-27"]
# The one place to change the pinned tag of the chat-list skill (UVS_CHATLIST_TAG overrides it for a test).
CHATLIST_TAG = "v0.9.0"
OURS = {"ours-slim": ("uikit-specialist-slim", "UVS_SLIM_TAG", "v0.2-slim"),
        "ours-full": ("uikit-specialist", "UVS_FULL_TAG", "v0.1"),
        "ours-chatlist": ("uikit-chat-list", "UVS_CHATLIST_TAG", CHATLIST_TAG)}
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# vendored pairs: kind -> (folder under skills/, the names the two SKILL.md files must carry)
VENDORED = {"ours-pair": ("uikit", ["uikit-specialist", "uikit-whats-new-27"],
                          ("v0.3-pair", "131b2a90a78a2b9359de728f021ba8db146c8f58")),
            "ours-objc-pair": ("uikit-objc", ["uikit-specialist-objc", "uikit-whats-new-27-objc"], (None, None)),
            # third-party SwiftUI skill (MIT), github.com/AvdLee/SwiftUI-Agent-Skill, plugin 5.2.1
            "avdlee": ("avdlee", ["swiftui-expert-skill"], ("5.2.1", "204dba7c67256a8b707ee3fbc5759a824191974f")),
            # third-party SwiftUI skill (MIT), github.com/twostraws/SwiftUI-Agent-Skill, plugin 2.0.0
            "twostraws": ("twostraws", ["swiftui-pro"], ("2.0.0", "1eac100257af9068d5f041c1a1540b1790233716"))}


def fail(msg):
    print("skillset: " + msg, file=sys.stderr)
    sys.exit(1)


def folder_hash(files):
    """files: {relative path from skills/: bytes}"""
    lines = "".join("%s  skills/%s\n" % (hashlib.sha256(files[p]).hexdigest(), p) for p in sorted(files))
    return hashlib.sha256(lines.encode()).hexdigest()


def skill_name(files, folder):
    m = re.search(r"^name:\s*(\S+)\s*$", files[folder + "/SKILL.md"].decode("utf-8", "replace"), re.M)
    if not m:
        fail("%s/SKILL.md has no name: line" % folder)
    return m.group(1)


def tilde(path):
    """Home-relative form (~/...) so records never carry the home path."""
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path.startswith(home + os.sep) else path


def ours(kind):
    folder, tag_env, default_tag = OURS[kind]
    repo = os.environ.get("UVS_SKILL_REPO", os.path.expanduser("~/olivares-burgos/uikit-skill"))
    tag = os.environ.get(tag_env, default_tag)
    try:
        commit = subprocess.run(["git", "-C", repo, "rev-parse", tag + "^{commit}"], capture_output=True,
                                text=True, check=True).stdout.strip()
        raw = subprocess.run(["git", "-C", repo, "archive", tag, "skills/" + folder], capture_output=True,
                             check=True).stdout
        pj = subprocess.run(["git", "-C", repo, "show", tag + ":.claude-plugin/plugin.json"], capture_output=True,
                            text=True).stdout
    except subprocess.CalledProcessError as e:
        fail("cannot read %s of %s: %s" % (tag, repo, (e.stderr or b"").strip() if e.stderr else e))
    files = {}
    with tarfile.open(fileobj=io.BytesIO(raw)) as t:
        for m in t.getmembers():
            if m.isfile():
                files[m.name[len("skills/"):]] = t.extractfile(m).read()
    try:
        plugin_version = json.loads(pj).get("version")
    except ValueError:
        plugin_version = None
    return [dict(folder=folder, name=skill_name(files, folder), files=files,
                 source="git tag %s of %s" % (tag, tilde(repo)), tag=tag, commit=commit,
                 version=plugin_version or tag)]


def vendored(kind):
    sub, names, (tag, commit) = VENDORED[kind]
    base = os.path.join(REPO, "skills", sub)
    if not os.path.isdir(base):
        fail("%s needs %s, which does not exist yet (the skills are vendored there later)" % (kind, base))
    out = []
    for name in names:
        d = os.path.join(base, name)
        if not os.path.isfile(os.path.join(d, "SKILL.md")):
            fail("%s: %s/SKILL.md is missing" % (kind, d))
        files = {}
        for root, _, fns in os.walk(d):
            for n in fns:
                p = os.path.join(root, n)
                files[name + "/" + os.path.relpath(p, d)] = open(p, "rb").read()
        if skill_name(files, name) != name:
            fail("%s: %s/SKILL.md names itself %s, expected %s" % (kind, d, skill_name(files, name), name))
        out.append(dict(folder=name, name=name, files=files, source="vendored in this repo: skills/%s/%s" % (sub, name),
                        tag=tag, commit=commit, version=tag or "see skills/README.md"))
    return out


def apple():
    d = os.environ.get("UVS_APPLE_SKILLS")
    if not d:
        found = sorted(glob.glob(os.path.expanduser("~/uvs-skills/apple-*")))
        d = found[-1] if found else None
    if not d or not os.path.isdir(d):
        fail("no Apple skills export found (set UVS_APPLE_SKILLS or export into ~/uvs-skills/apple-<xcode build>/; "
             "Xcode 27 `xcrun agent skills export`, see docs/harness.md, Level 2)")
    out = []
    for name in APPLE_SKILLS:
        base = os.path.join(d, name)
        if not os.path.isfile(os.path.join(base, "SKILL.md")):
            fail("%s has no %s/SKILL.md" % (d, name))
        files = {}
        for root, _, names in os.walk(base):
            for n in names:
                p = os.path.join(root, n)
                files[name + "/" + os.path.relpath(p, base)] = open(p, "rb").read()
        out.append(dict(folder=name, name=skill_name(files, name), files=files,
                        source="local export " + tilde(d), tag=None, commit=None, version=os.path.basename(d)))
    return out


def install(skills, dest):
    for s in skills:
        for tool in (".claude", ".agents"):
            for p, data in s["files"].items():
                target = os.path.join(dest, tool, "skills", p)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with open(target, "wb") as f:
                    f.write(data)
            copied = {}
            base = os.path.join(dest, tool, "skills", s["folder"])
            for root, _, names in os.walk(base):
                for n in names:
                    full = os.path.join(root, n)
                    copied[s["folder"] + "/" + os.path.relpath(full, base)] = open(full, "rb").read()
            if folder_hash(copied) != s["hash"]:
                fail("installed copy of %s under %s differs from its source" % (s["folder"], tool))


def codex_config(out):
    """config.toml for an empty CODEX_HOME: Codex's bundled system skills off, and every skill it would
    find under the user's ~/.agents/skills or ~/.codex/skills off (checked 19 Oct: without this an
    empty CODEX_HOME still lists the host's skills). The build folder's own .agents/skills stays on."""
    paths = []
    for root in ("~/.agents/skills", "~/.codex/skills"):
        for d, _, names in os.walk(os.path.expanduser(root), followlinks=True):
            if "SKILL.md" in names:
                paths.append(os.path.join(d, "SKILL.md"))
    text = "[skills.bundled]\nenabled = false\n\n"
    for p in sorted(set(paths)):
        text += '[[skills.config]]\npath = "%s"\nenabled = false\n\n' % p
    if out:
        with open(out, "w") as f:
            f.write(text)
    return len(set(paths)), text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--codex-config", metavar="OUT", help="write the Codex config.toml to OUT ('-' = only count)")
    ap.add_argument("--kind", default="none", choices=["none", "ours-slim", "ours-full", "ours-chatlist", "ours-pair", "ours-objc-pair", "apple", "avdlee", "twostraws"])
    ap.add_argument("--dest")
    ap.add_argument("--install", action="store_true")
    a = ap.parse_args()
    if a.codex_config:
        n, text = codex_config(None if a.codex_config == "-" else a.codex_config)
        print(json.dumps(dict(host_skills_disabled=n, config_sha256=hashlib.sha256(text.encode()).hexdigest())))
        return 0
    if a.kind == "none":
        skills = []
    elif a.kind == "apple":
        skills = apple()
    elif a.kind in VENDORED:
        skills = vendored(a.kind)
    else:
        skills = ours(a.kind)
    for s in skills:
        s["hash"] = folder_hash(s["files"])
        s["file_count"] = len(s["files"])
    if a.install:
        if not a.dest:
            fail("--install needs --dest")
        install(skills, a.dest)
    rec = dict(kind=a.kind, installed=bool(a.install),
               install_dirs=[".claude/skills", ".agents/skills"] if skills else [],
               skills=[{k: v for k, v in s.items() if k != "files"} for s in skills],
               expected_names=[s["name"] for s in skills])
    json.dump(rec, sys.stdout, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
