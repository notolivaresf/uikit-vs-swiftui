# Round 5, E7: runbook for the two validation builds

Prepared 26 Oct. **Nothing here has been run.** No build, agent, simulator or phone was started to write this page. Fernando gives the go for E7 (`docs/round5-plan.md`, E7); E7 follows E6.

Question (from the plan): do builds with the new skill pass more checks, at least as fast, than the Round 2 control?

## What runs

Two builds of the Campfire room, UIKit in Swift, iPhone, started one at a time:

| Build | Model | Launcher name | Folder |
|---|---|---|---|
| Opus with the skill | `claude-opus-5-5`, effort high | `opus-uikit-ours-chatlist` | `~/uvs-builds/opus-uikit-ours-chatlist` |
| Sol with the skill | `gpt-6.1-sol` via Codex, effort high | `sol-uikit-ours-chatlist` | `~/uvs-builds/sol-uikit-ours-chatlist` |

Control (not rebuilt): `round2-uikit-swift-opus` and `round2-uikit-swift-sol`, run names `opus-uikit-ours-pair` and `sol-uikit-ours-pair`, with our UIKit pair v0.3 (`uikit-specialist`, `uikit-whats-new-27`).

## Blockers before the launch lines work

1. **The skill tag.** The launcher now has the kind `ours-chatlist` (only `skills/uikit-chat-list` of `uikit-skill`, installed per build folder) and an optional `UVS_TIME_LIMIT_S` cap. The pinned tag is one constant, `CHATLIST_TAG = "v0.6.2"` in `Harness/skillset.py` (the env var `UVS_CHATLIST_TAG` overrides it for a test). **`v0.6.2` did not exist yet on 26 Oct** (latest tag `v0.6.1`): until it is cut, the real launch refuses and the dry run says the skill set is not available. Check with `git -C ~/olivares-burgos/uikit-skill tag`; the run record keeps the tag, the commit and the folder hash. The v0.6.1 folder (3 files: `SKILL.md`, `references/measuring-text.md`, `references/table-view.md`) hashes to `a26565be3b5b32f67f65fd22056f9ac933eae66294aab7c29e9a2c76927c8339`; v0.6.2 will differ.
2. **Time cap.** Launch with `UVS_TIME_LIMIT_S=7200`: the launcher appends `--time-limit-s 7200` to the supervisor line (unset: no limit, as before), and `meta.json` then carries `time_limit_s` and `stopped_by_limit`.
3. **Open points in the skill itself** (E6's business, noted because they bear on what E7 can prove):
   - The skill says the table-view stream tie "is being rechecked" (30.7 s in the later E2/E3 runs against 7.73 s in E1). An agent reading that may pick either view.
   - `SKILL.md` is about 2,080 words, a little over the plan's 2,000.
   - The plan says the skill names nothing about the benchmark. It currently carries evidence tags and text such as "S3 lost 14 minutes", "Round 5 spike" and measured stream seconds, and `SOURCES.md` points at the benchmark repo. The build folder has no repo, so nothing can be read from it, but the skill still tells the agent that a benchmark exists. Decide in E6 whether to strip these for the build copy; if the copy differs from the repo's, record it.
4. **The Harness fix has landed** (`3da9ff2`): `Harness/record.sh --only <tests>` now always installs the target app, so single-row re-runs (for example `stream`) measure the right build. The full-pass commands below never depended on it.
5. **Fernando's go**, and for the phone passes someone at the iPhone 12 (unlocked, awake, Settings > Developer > Enable UI Automation on, several GB free).
6. **Quota.** `~/olivares-burgos/pacer/tools/codex-pace` on 26 Oct: `codex open · weekly 9% · resets Tue 27 Oct 19:37 · reading 6584 min old`. Under 50 % weekly, so Sol builds are free to run. The reading is 4.5 days old, so re-run `codex-pace` right before the Sol launch. A Sol build is one Codex session of about 20 to 40 minutes (control: 1233 s). Claude side (`pace`): push, maxAgents 8, hey.com 5 % of the week used, so Opus is fine too.

## The prompt

The prompt is the **Round 2 Swift prompt, unchanged**: `prompts/round2-uikit-swift.md` is the filled-in copy of `PROMPT.md` from tag `v2-inputs` (`9bbe868`), which the launcher selects by itself when no `UVS_INPUTS_TAG` is set. It states outcomes and numbers only (within 2 pt, 40 of 50,000 messages, first content within 1 s, 20 messages a second for 30 s, the 13 behaviours, the debug bar and its state label); it names no API. The one start sentence is the Round 2 one: "Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions." Line 3 is "Stack: UIKit only, no SwiftUI" and line 5 is "Agent skills are installed in this project; use any that help." Both are in the Round 2 control's prompt too.

**What differs from Round 2: nothing in the prompt.** The only difference between an E7 build and its control is the installed skill: `uikit-chat-list` alone, in place of the pair `uikit-specialist` plus `uikit-whats-new-27`. That is a change of two things at once (the skill, and the pair's absence); the plan accepts it because the pair is what the control had. If E7 passes and the question "is it the new skill or just fewer skills" matters, a third arm with the pair plus `uikit-chat-list` is the follow-up.

Check after launch that nothing slipped in: `diff builds/round2-uikit-swift-opus/PROMPT.md ~/uvs-builds/opus-uikit-ours-chatlist/PROMPT.md` prints nothing (run from the repo), and the same for the Sol folder. No `./bench` is given to these builds (it is a Round 3 tool); they get what the Round 2 builds got: the folder with the prompt, `Fixtures/`, `CampfireKit/`, `screenshots/`.

## Launch lines (one at a time, Fernando starts them)

From `~/olivares-burgos/uikit-vs-swiftui-repo`, (the launcher change is in). First a dry run for each; it creates nothing and calls no model:

```
UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist --dry-run
UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist --dry-run
```

The dry run must show: skill set `uikit-chat-list` with the tag's folder hash, `time limit: 7200 s`, `installed: into .claude/skills and .agents/skills`, and the right inputs tag (`v2-inputs`). Then the real launches, each in the background (`run_in_background`) and the second only after the first has stopped and been scored far enough that you know it ran:

```
UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist
UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist
```

Both launch lines are prefixed with `UVS_TIME_LIMIT_S=7200` (the 2-hour cap):

What the launcher runs (from `launch-build.sh`, the same lines as the Round 2 pair builds):

- Opus, in the build folder: `python3 -I Harness/run_build.py --model opus --side uikit --build-dir <folder> --run-dir runs/opus-uikit-ours-chatlist --requested-model claude-opus-5-5 --effort high --cli-version <claude --version> --level L2 --skillset-json runs/.../skillset.json --extra-json runs/.../extra.json --expect-skills uikit-chat-list -- claude -p "Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions." --model claude-opus-5-5 --effort high --setting-sources project --strict-mcp-config --settings '{"autoMemoryEnabled":false,"disableBundledSkills":true,"skillOverrides":{"design":"off","doctor":"off","plugin-authoring":"off"}}' --permission-mode bypassPermissions --output-format stream-json --verbose`
- Sol: the same supervisor with `--model sol --requested-model gpt-6.1-sol` and `codex exec -m gpt-6.1-sol -c model_reasoning_effort=high --json --dangerously-bypass-approvals-and-sandbox --ignore-rules --skip-git-repo-check -C ~/uvs-builds/sol-uikit-ours-chatlist "<same sentence>"`, with `CODEX_HOME=~/uvs-builds/sol-uikit-ours-chatlist-config`.

## How the skill is installed without leaking into other builds

- **Per build folder only.** `skillset.py --install` copies the skill folder, identically, into `<build>/.claude/skills/uikit-chat-list` (Claude Code) and `<build>/.agents/skills/uikit-chat-list` (Codex) and checks the copy's hash against the source. Both paths are written to `<build>/.git/info/exclude`, so nothing the build commits carries them. Nothing is installed in `~/.claude/skills`, `~/.agents/skills`, `~/.codex/skills` or any plugin: do **not** install the `uikit-skill` plugin (it also holds the pair, the Objective-C skills and the `uikit-list-reviewer` agent).
- **Opus.** `--setting-sources project` (the folder has no settings), `--strict-mcp-config`, `autoMemoryEnabled:false`, `disableBundledSkills:true`, and `design`, `doctor`, `plugin-authoring` switched off by name. The supervisor reads the stream's init event and **stops the run before the first turn** if the skill list is anything but exactly `uikit-chat-list` (`skill_isolation.error` in `meta.json`).
- **Sol.** An empty `CODEX_HOME` holding only `auth.json` and a generated `config.toml` that turns Codex's bundled system skills off and every skill under the host's `~/.agents/skills` and `~/.codex/skills` off by path (`skillset.py --codex-config`, enumerated on the launch day). Codex prints no skill list; the isolation evidence is the config hash in `meta.json` plus, after the run, a search of the transcript for any `SKILL.md` read that is not `uikit-chat-list`.
- **The reviewer agent is not installed.** `uikit-list-reviewer` is a Claude Code subagent; Codex cannot call it, and installing it for Opus alone would make the arms differ and add an agent to the init list the isolation check does not know. E7 tests the skill. The agent can be a later arm.
- **Before the first real launch**, one tiny probe per model, as for the Round 2 pair (docs/harness.md, "Isolation"): install into a scratch folder with `skillset.py --kind ours-chatlist --dest <scratch> --install`, ask Haiku with the Opus flags to "reply ok" and read the init `skills` (exactly `uikit-chat-list`); ask Codex with the generated config "list the names of your skills, nothing else" (exactly `uikit-chat-list`). Add the result to `docs/harness.md`.

## After each build stops

Record the facts from the run, not from the agent: `runs/<name>/meta.json` (wall seconds, turns, builds total and failed, commits, `skill_isolation`), and which skill files the agent read (search `transcript.jsonl` for `SKILL.md` and `references/`; the control reads are in `runs/*-uikit-ours-pair`). Then `Harness/check-stack.sh uikit ~/uvs-builds/<name>` (no `import SwiftUI`). A build that fails the stack rule is reported as such and still scored.

## Scoring

Two stages, both by us, never by the agent. The agent never saw a benchmark; the numbers below come only from the Harness.

### Stage 1: simulator, all 13 checks, three passes

Simulator: the kept iPhone 17 simulators `uvs-r3-a` (Opus build) and `uvs-r3-b` (Sol build), iOS 26.4, the same ones that produced the control's simulator baseline. Make sure they exist and are within the cap (`simcap ensure`, `python3 -I Harness/sims.py ensure`); never delete or erase one.

For each build, `<P>` is the Xcode project name the agent chose (`ls *.xcodeproj`), `<name>` the launcher name:

```
buildslot run --label "uvs-e7 <name>: sim build" -- xcodebuild build -project ~/uvs-builds/<name>/<P>.xcodeproj -scheme <P> -configuration Release -destination "platform=iOS Simulator,id=$(python3 -I Harness/sims.py udid uvs-r3-a)" -derivedDataPath ~/uvs-builds/dd/<name>-sim CODE_SIGNING_ALLOWED=NO
```

Refuse a project with a script build phase (`grep -c PBXShellScriptBuildPhase <P>.xcodeproj/project.pbxproj` must be 0), as `./bench` does. Then three passes, full (no `--only`), `<n>` = 1, 2, 3:

```
buildslot run --label "uvs-e7 <name>: sim pass <n>" -- Harness/record.sh --build <name> --round e7-sim<n> --out-dir ~/uvs-builds/e7/<name>/sim<n> --derived ~/.uvs-bench/dd-tests-sim --app-path ~/uvs-builds/dd/<name>-sim/Build/Products/Release-iphonesimulator/<P>.app --sim "$(python3 -I Harness/sims.py udid uvs-r3-a)"
python3 -I Harness/scorecard.py --summary ~/uvs-builds/e7/<name>/sim<n>/summary.json --best Harness/round3-best.json --stack-rule ok --app-size-mb <MB of the .app> --sim --json ~/uvs-builds/e7/<name>/sim<n>.json
```

(`--stack-rule` takes the result of `check-stack.sh`; `--app-size-mb` is `du -sk <app>` in MB.) A pass takes about 3.6 minutes. Then the median of the three, the way `round3-baseline.sh` makes a baseline:

```
python3 -I Harness/scorecard.py --aggregate ~/uvs-builds/e7/<name>/sim1.json ~/uvs-builds/e7/<name>/sim2.json ~/uvs-builds/e7/<name>/sim3.json --json ~/uvs-builds/e7/<name>/sim-median.json
```

**Numbers read** (the 9 simulator rows plus the 13 checks), against the **control's simulator baselines**, which exist from Round 3 setup (one scorecard run each, on the same simulators): `~/uvs-builds/round3-uikit-swift-opus/.bench/baseline.json` and `~/uvs-builds/round3-uikit-swift-sol/.bench/baseline.json`. They are the Round 2 trees, unchanged.

| Row | Control Opus | Control Sol |
|---|---|---|
| Checks passed | 13 of 13 | 12 of 13 (text selection fails) |
| First 40 rows, cold / repeated (ms) | 205 / 671 | 195 / 639 |
| Stream CPU (s) | 8.15 | 9.84 |
| Jump to 2,500 (ms) | 60 | 38 |
| Load older (ms) | 55 | 33 |
| Text size at bottom / mid-list (ms) | 49 / 67 | 20 / 31 |
| Peak memory (MB) | 117.6 | 59.6 |
| App size (MB) | 1.34 | 1.20 |

Those baselines are one scorecard run each; a single run varies 1 to 10 % (`docs/round3-handoff.md`). For a fair comparison, measure the control again alongside the new builds in the same sitting: `Harness/round3-baseline.sh uikit-swift-opus --runs 3` and `... uikit-swift-sol --runs 3` (they use the Round 3 folders and rewrite their own `baseline.json`; copy the old one first). Report the old baseline too.

### Stage 2: the iPhone 12, one full pass each

The simulator's frame times mean nothing; the phone gives the hitch, fling, cold launch and memory numbers. Build for the device with the signing values from `Harness/local.env` (not in git; `. Harness/local.env` gives `UVS_DEVICE_UDID`, `UVS_TEAM`):

```
buildslot run --label "uvs-e7 <name>: device build" -- xcodebuild build -project ~/uvs-builds/<name>/<P>.xcodeproj -scheme <P> -configuration Release -destination "id=$UVS_DEVICE_UDID" -derivedDataPath ~/uvs-builds/dd/<name>-device DEVELOPMENT_TEAM="$UVS_TEAM" CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES "CODE_SIGN_IDENTITY=Apple Development" -allowProvisioningUpdates
buildslot run --label "uvs-e7 <name>: record" -- Harness/record.sh --build <name> --round 1 --app-path ~/uvs-builds/dd/<name>-device/Build/Products/Release-iphoneos/<P>.app
python3 -I Harness/scorecard.py --summary runs/<name>/1/summary.json --best Harness/round3-best.json --stack-rule ok --app-size-mb <MB> --json runs/<name>/1/scorecard.json
```

(The Round 2 passes were `record.sh --build <name> --round 1 --app-path <Release .app>`; the `light` cold-launch mode is now the default, so **cold launch is not comparable with Round 2's** and is reported with its mode.) The control's phone numbers are in `docs/results-round2.md` (columns `round2-uikit-swift-opus` and `round2-uikit-swift-sol`; raw in `runs/opus-uikit-ours-pair/1/summary.json` and `runs/sol-uikit-ours-pair/1/summary.json`).

Phone control numbers to beat or match: Opus: fling 58.0 fps, 2 hitches (33 ms); stream 1 hitch (17 ms), CPU 12.2 s; first 40 rows 252 ms; jump 90 ms; load older 93 ms; text size 83 / 103 ms; peak memory 107.9 MB. Sol: fling 58.2 fps, 0 hitches; stream 6 hitches (100 ms), CPU 12.0 s; first 40 rows 196 ms; jump 77 ms; load older 75 ms; text size 53 / 70 ms; peak memory 44.5 MB.

### Also reported (not pass/fail)

Agent wall time, turns and builds (failed) from `meta.json`, against the control: Opus 2231 s / 95 / 12 (0); Sol 1233 s / 90 / 14 (7). Which skill files each agent read and when; how many of its own test runs it made (the Round 5 plan's notes table method). Any "Bent rules" shortcut from `docs/results-round3.md` (a stream redrawn on a timer, a load older timer) counts as a fail of the row it bends.

## The pass bar

Decided before any build runs, so the result cannot move it.

A build **passes E7** when all of these hold:

1. **13 of 13 checks** on the simulator median of three passes (the check list is `Harness/scorecard.py`; the stack rule included), **text selection passing**, and the same 13 of 13 on the phone pass.
2. **At least as fast to build:** agent wall time within 10 % of its control's (Opus 2231 s, so at most 2454 s; Sol 1233 s, so at most 1356 s), measured from `meta.json`.
3. **No worse than the control on the numbers:** none of the 9 simulator rows is more than 10 % worse than the control median measured in the same sitting (1 to 10 % is the noise between runs), and the phone's fling and stream hitch times are no worse than the control's by more than 50 ms or 1 hitch.

The plan's wider hope (numbers at or better than the Round 3 UIKit builds: 130 to 175 ms for 40 rows, 4.6 to 8.8 s stream CPU, 32 to 42 ms jump, 44 to 58 MB) is reported beside the result but is not the bar: those builds had three hours and a scorecard to iterate on, and E7 builds get one run.

**Proved wrong (plan wording):** either build fails a check the skill covers. Read it this way: a failed check among edit menu / text selection (rule 1), jump, load older, text size, rotation, pin (rules 2 to 4, 7) or boosts. A fail of a check the skill does not cover (stack rule, first content) is reported and does not by itself disprove the skill.

**Reading the result:**

- Both pass: the skill is not worse and Sol's text selection failure is fixed (the control's Sol failed it). Next, per the plan, a repeat pair to see whether it was luck.
- One or both fail a check the skill covers: the failure goes back to E6 as a fixed rule, with the transcript line that shows what the agent read and chose.
- Only the speed or the numbers miss: report it, do not call it a failure of the skill; say which row and by how much.
- One pair is a sample of two per arm (the control has the same weakness: no arm has run twice). Say so in the result.

## Hygiene

Build folders are outside the repo (`~/uvs-builds`); the launcher refuses a folder that already exists. Results go to `runs/<name>/` and `docs/round5-results-e7.md` (to write). No key ids, issuer ids, key paths or device ids in tracked files: they live in the untracked `Harness/local.env` and are read from the environment. Shut down any simulator started for scoring that is not one of the two kept ones; never delete or erase one.
