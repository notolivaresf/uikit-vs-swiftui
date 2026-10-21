# Round 3: plan

> Fernando, 20 Oct: agents work on the simulator only (no iPhone during their run), 3 pairs, 3 hours each, 2 at once. Final scoring on the iPhone 12 is ours, afterwards.

Round 3 gives each Round 2 build back to an agent (the same model, the same skills) with one job: make it faster, measured against its own scorecard. This page is how it is set up, measured, locked, sandboxed, stopped and audited. Nothing here starts an agent; Fernando does.

## The pairs

Two agents run at once, one per simulator, same stack:

| Pair | Builds | Simulators |
|---|---|---|
| 1 | round2-swiftui-sol, round2-uikit-swift-sol | a, b |
| 2 | round2-swiftui-opus, round2-uikit-swift-opus | a, b |
| 3 | round2-uikit-objc-sol, round2-uikit-objc-opus | a, b |

Each folder is `~/uvs-builds/round3-<build>` (for example `round3-uikit-swift-opus`), a copy of the Round 2 working folder with a new git history of one commit, "Round 2 build".

## The simulators

Two simulators are made once and kept: `uvs-r3-a` and `uvs-r3-b`, both **iPhone 17, iOS 26.4** (`Harness/sims.py ensure` creates them, never deletes or erases anything, and boots both through `simcap ensure`). They stay booted for the whole round, so a build is always measured with its partner's simulator up and idle, as in the baseline. The two simulators use both of the Max's iOS simulator slots: no other lane may boot one during a Round 3 pair. Each folder is bound to one (`.bench/sim`).

## The benchmark command

`./bench` in a build folder:

| Command | What | Time |
|---|---|---|
| `./bench` | builds Release for the simulator, measures, prints the scorecard against the baseline | a few minutes (see "Timing" below) |
| `./bench --build` | compile only: build errors and the stack rule | about a minute |
| `./bench --device`, `--device-full` | the same on the iPhone 12 (quick, or the full Instruments pass). Ours, for the final score. Not used while the phone is offline | 10 min / 45 min |

What the simulator pass measures (rows of the scorecard, lower is better in all): first 40 rows, cold and repeated (the app's own ms label); stream CPU; jump to message 2,500; load older; text size at the bottom and mid-list (the ms label); peak memory; app size (the Release simulator .app). It also runs the 13 pass/fail checks (the stack rule plus the 12 numbers of PROMPT.md: first content, jump and load-older drift, the 600 stream messages arriving and staying pinned, text size pinned and drift, rotation pinned and drift, boost burst pinned, context menu, text selection). Not measured on a simulator, so not in the agents' scorecard: cold launch, fling speed and hitches, stream hitches (they need Instruments and a real screen). Those stay in the iPhone 12 pass.

The harness is the Round 2 one: the same XCUITest suites (`Harness/Tests`), `Harness/record.sh --sim`, `Harness/summarize.py`; only the scorecard (`Harness/scorecard.py`) is new. Simulator times are not phone times; they are only comparable with the same build's baseline from the same simulator.

### How a sandboxed agent runs it: the broker

A sandboxed agent cannot build for or talk to the simulator (CoreSimulator, signing keys and device services are blocked by both tools' sandboxes; checked with `codex sandbox`). So `./bench` does not measure itself. It writes a request file under the folder's `.bench-work/requests/` and prints what comes back. **`Harness/bench-broker.py`** runs outside any sandbox (start it before the agents and leave it running; `--once` serves what is queued and stops). It:

- serves requests one at a time, oldest first. That is also the measure lock: two agents never build or measure at the same moment, so one's compile does not disturb the other's timing; a waiting `./bench` says so and keeps waiting;
- runs the repo's own harness, never the copy in the agent's folder, so nothing an agent edits is executed outside the sandbox;
- re-checks the locked files against checksums saved outside the folders (`~/uvs-builds/.locks/`), and refuses an app project that has a script build phase (it would run unsandboxed);
- builds with `buildslot run --label "uvs-r3 <build>: bench sim"`.

`./bench --direct` (with `UVS_HARNESS` set to the repo's Harness folder) skips the broker and runs under the same lock; it is for us.

## Locks

Recorded at setup, in `.bench/locks.json` of the folder and again outside it. `./bench` and the broker refuse to run (exit 3, listing the files) if any of these changed:

| What | Why |
|---|---|
| `CampfireKit/` (the data package, all files, nothing added or removed) | the 50,000 messages, grouping, windowing and the live feed are the fixed input |
| `Fixtures/`, `screenshots/` | the reference numbers and images |
| `PROMPT.md` | the original brief |
| `.bench/` (harness copy: the UI tests that implement the checks, the scorecard, the baseline) and `bench` | the measuring itself |
| the build's own debug-bar timing code: the lines that start the ms clock (at the touch up, at app launch) and read it | the ms label is the number every timing row comes from. Per build, `Harness/round3-pins/<build>.json` lists the exact pieces of code; each must still appear in its file at least as often as at setup. The agent may change everything around them |

Limits, said plainly: the pins fix where the clock starts and how it is read, not where in the code the "laid out on screen" moment is. An agent could in principle move the end of the measurement earlier. The simulator numbers are for the agents; the **final score is ours, on the iPhone 12 with `./bench --device-full`**, where frame times and hitches come from Instruments and cannot be fooled by the label. After a run, diff the build against its "Round 2 build" commit around the pinned lines and the ms label's end point.

## Setup and baseline

```
Harness/round3-setup.sh uikit-swift-opus --sim a     # folder, git, skills, ./bench, locks, prompt (placeholder scorecard)
Harness/round3-setup.sh swiftui-opus     --sim b
Harness/round3-baseline.sh uikit-swift-opus          # 3 runs in its simulator, median -> .bench/baseline.json, prompt filled
Harness/round3-baseline.sh swiftui-opus
```

- `round3-setup.sh <build> --sim a|b` copies the Round 2 working folder (without build output, history or skill folders), starts a new git history ("Round 2 build"), installs the same skills the build had in Round 2 into `.claude/skills` and `.agents/skills` (kept out of git; `skillset.py`, hashes checked), adds `./bench`, records the locks, and writes the prompt next to the folder (`round3-<build>.prompt.md`). Sol builds also get a `CODEX_HOME` with Round 2's `config.toml` (host skills off) and `auth.json`. `--refresh` re-copies the harness and re-records the locks before a launch.
- `round3-baseline.sh <build>` boots both simulators, runs `./bench` 3 times, takes the median of each measure (a check counts as failed when it failed in at least half the runs), stores it in `.bench/baseline.json` and refills the prompt. Run it just before a pair starts, for both builds of the pair, one after the other, so each is measured with its partner's simulator booted and idle.
- The prompt is `prompts/round3.md` with the build's stack line, its baseline scorecard and the exact wording of every check it failed.

## Launch

```
Harness/bench-broker.py                       # leave running
Harness/round3-launch.sh uikit-swift-opus --dry-run
Harness/round3-launch.sh uikit-swift-opus     # then the partner, in a second terminal
```

`round3-launch.sh` checks the locks, then runs the agent through `run_build.py` (transcript, `meta.json`, turn and build counts, as in Rounds 1 and 2) with the sandbox below and the time limit. The run folder is `runs/round3-<build>/`.

### Time limit: 3 hours

- `run_build.py --time-limit-s 10800` stops the model at 3 h of wall-clock time: SIGTERM, then SIGKILL 30 s later, for Claude Code and Codex alike. `meta.json` records `time_limit_s` and `stopped_by_limit`.
- The prompt says "You have 3 hours in total", and the launcher adds the start time and the clock time the 3 hours end, with a reminder to check `date` and write NOTES.md before then (a headless run cannot be told "time's up" mid-run).
- A build in the broker queue when the limit hits is finished by the broker (it does not depend on the agent). The folder is then scored as it stands.

## Sandbox

The aim: each agent can read only its own folder (which holds its skills), the Xcode toolchain and system libraries, and cannot fetch anything of notolivaresf. It is a guard rail and an audit trail, not a wall against a determined agent.

### Claude Code (Opus)

Same flags as Round 2 (`--setting-sources project --strict-mcp-config`, bundled skills off, no auto memory, `bypassPermissions`), plus these `--settings` (printed in full by `round3-launch.sh --dry-run`):

- `sandbox.enabled` with `failIfUnavailable: true` and `allowUnsandboxedCommands: false`: shell commands run in the macOS sandbox and there is no unsandboxed retry. `sandbox.filesystem.denyRead: ["~/"]` with `allowRead` for the build folder, `~/Library/Developer`, `~/Library/Caches` and `~/.gitconfig`; `allowWrite` for the folder, those two library folders and the user cache directory. Outside the home folder (Xcode, `/usr`, Homebrew) reads are open, which is the toolchain.
- The sandbox covers shell commands only. The file tools (Read, Grep, Glob) are fenced with `permissions.blockReadsOutsideWorkingDirectories: true` (applies in every permission mode), with Xcode added through `additionalDirectories`. The working directory is the build folder, so its `.claude/skills` are readable.
- A `PreToolUse` hook (`Harness/round3-guard.py`) on `WebFetch|WebSearch|Bash` refuses (exit 2) any call whose URL, query or command names `notolivaresf`, `uikit-vs-swiftui` or `uikit-skill`, which also covers Wayback and cache copies of those pages. Claude Code's own domain rules work per host, not per path, so a plain `github.com` rule would also block every other repository; the hook blocks only ours. A shell command that reaches the repo without naming it (a redirect, a search) is not caught; the audit is.

Limit: the Claude sandbox settings are taken from Claude Code's documentation (version 2.1.305) and are **not tested end to end**, because testing them means starting an agent. What was tested is the part both tools share: a process confined to its folder can run `./bench` (below). Check the first lines of the first transcript (the `init` event lists the skills as in Round 2; any "sandbox" or permission refusal shows in the tool results) before trusting the pair.

### Codex (Sol)

`CODEX_HOME` as in Round 2, plus a permission profile `r3` put at the top of its `config.toml` (`default_permissions = "r3"`, shown in full by `--dry-run`):

- `extends = ":workspace"` (write in the working directory, which `-C` sets to the build folder), `":root" = "deny"` with read re-allowed for `":minimal"`, Xcode, `/Library/Developer`, `/usr`, `/opt/homebrew`, and write for the temp and cache directories Xcode and Swift need and the folder. Tested with `codex sandbox -P`: `ls ~/olivares-burgos`, reading another build folder and writing to `~` all fail with "Operation not permitted"; the folder is readable and writable.
- Network on, with `features.network_proxy` and domain rules denying `github.com`, `raw.githubusercontent.com` and `api.github.com` for shell commands. Domain rules apply per host (all of GitHub, for commands) and only while the proxy runs, which `codex sandbox` does not start, so **this part is untested**. Codex's hosted web search has its own access settings and cannot be filtered by path or denied by host here: a search can still return a page of ours and the model can read the snippet. That gap is covered only by the audit.

### What a sandboxed process can still do (tested)

With `codex sandbox -P r3` in a Round 3 folder: Python and git work (git needs `~/.gitconfig`, allowed), `lockcheck.py verify` passes, the request files are written, and `./bench` reaches the broker, which does the build and the measuring outside. `xcodebuild` itself does not run inside either sandbox (no CoreSimulator service; the Swift module cache path needs more holes), so **agents compile through `./bench --build`**, not by calling xcodebuild. The prompt does not say how to compile; `./bench` is the only command it names.

## After a run: audit

```
Harness/round3-audit.py runs/round3-<build>/transcript.jsonl ~/uvs-builds/round3-<build>
```

Reads the requests in a Claude (stream-json) or Codex (`--json`) transcript and flags, with the line number: paths outside the folder, the skills, Xcode and the system toolchain (`path`); another build folder or this workspace (`sibling`); any URL naming notolivaresf, uikit-vs-swiftui or uikit-skill (`url`); git commands that read history (`history`). It reads what the agent asked for, so a refused or failed attempt still counts. Exit 1 if anything is flagged. For Codex also read the `web_search` items in the transcript: a search result is not a request and the audit cannot see what it returned. A flagged run is not thrown away; the finding goes next to its numbers.

Also after every run: `Harness/lockcheck.py verify --root <folder> --locks ~/uvs-builds/.locks/round3-<build>.json` (the outside copy), `Harness/check-stack.sh <stack> <folder>`, and a `git diff` against "Round 2 build" around the pinned lines.

## Final scoring (ours)

When the phone is back: `./bench --device-full` in each folder, one at a time, and the same Round 2 scorecard (cold launch, fling, stream hitches included) against Round 2's published numbers. The simulator scorecard is not the result.

## Timing

(filled in from the first real run; see "Timing" in docs/round3-handoff.md if still empty)
