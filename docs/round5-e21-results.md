# Round 5, E21: validation round 13, the Sol build with the thin2 skill (`v0.11.2-thin2`)

Run 27 Oct (local). Same method as E19 (`docs/round5-e19-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Sol build with nothing else scoring, three scored passes on `uvs-r3-a`, then the Sol control (Round 2 Sol tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`). Skill `uikit-chat-list` tag `v0.11.2-thin2` (private skill repo, branch `thin2`, commit `0945814`, folder hash `5849b584...`, 4 files), the same skill as the Opus E20 build; what changed from `v0.11.1-thin-timer` and why is in `docs/round5-e20-results.md` (rules 5, 7 and 12, written from E18's crash and E19's cold-rows and memory misses). The committed pin `CHATLIST_TAG` in `Harness/skillset.py` was not changed; the run used `UVS_CHATLIST_TAG=v0.11.2-thin2`. Prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.2-thin2 UVS_NAME_SUFFIX=-thin2 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Raw data: `runs/sol-uikit-ours-chatlist-thin2/e21-sim/` (summaries and scorecards tracked), control in `runs/e21-control-quiet/uikit-swift-sol/baseline.json`.

Rule checks in the code: `main.swift` starts making the data on a background queue before `UIApplicationMain` and the app delegate builds the list controller at once (no placeholder); no cell overrides `draw(_:)`; the flush runs on a 0.1 s timer; changed rows are reconfigured in a batch of their own (`changeRows`), apart from the append-and-trim batch.

## In plain words

- **Both of E19's row misses are gone.** First 40 rows cold 119 against 134 ms (-11 %; E19 +32 %, E17 +29 %), peak memory 55.1 against 57.6 MB (-4 %; E19 +50 %). The two rules written from the code (start the data before `UIApplicationMain` with no placeholder; no `draw(_:)` in cells) were both followed and both rows moved the predicted way.
- **13 of 13 in all three passes, and every speed row is better than the control**: repeated -20 %, stream CPU -15 % (6.46 against 7.60 s), jump -46 %, load older -77 %, text size at the bottom -33 %, mid-list -60 %. Stack rule ok, no `import SwiftUI`, no script build phase.
- **Wall time still misses the bar**: 1,595 s against at most 1,356 s (+29 % on the control's 1,233). Faster than E19 (1,749) but slower than E17 (1,445) and E12 (1,380); every Sol build with a skill has missed this bar. 77 turns, 17 builds, 7 failed; 6.5 M input tokens including cached, 53 k output.
- **App size**: the whole `.app` is 3.27 MB against 0.79, because the agent fetched the icon set from the public Campfire repository (MIT, license file added) with `curl` and two web searches, and put it in its asset catalog (2.5 MB). The executable alone is 0.68 MB. No earlier Sol build searched the web. The prompt does not forbid it; noted, not scored.
- One build is one sample. Phone passes are not run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Sol + thin2 (E21) | **Does not pass** (misses bar 2 only) | 13 of 13 in 3 of 3 passes and no simulator row worse than the same-sitting control, but wall 1,595 s against 1,356 s. Phone pending. |
| Against thin + timer (E19) | **Better** | Cold 119 against 175 ms, memory 55.1 against 86.5 MB, stream 6.46 against 7.00 s; wall 1,595 against 1,749 s, turns 77 against 93, tokens 6.5 against 7.0 M. Failed builds 7 against 5. |
| Against thin (E17) | **Better rows, slower build** | Cold 119 against 172 ms, stream 6.46 against 7.87 s; wall 1,595 against 1,445 s. |
| Against v0.9.0 (E12) | **Better rows, slower build** | Cold 119 against 122, memory 55.1 against 71.2 MB, every other row better except repeated (468 against 178); wall 1,595 against 1,380 s, tokens 6.5 against 3.6 M. |

## Against the pass bar (Sol)

| Bar item | E21 thin2 | E19 thin + timer | E17 thin | E12 v0.9.0 |
|---|---|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) | Yes | Yes | Yes |
| 1. Same on the phone | Pending | Pending | Pending | Pending |
| 2. Wall time within 10 % (at most 1,356 s) | **No** (1,595 s, +29 %) | No (1,749 s, +42 %) | No (1,445 s, +17 %) | No (1,380 s, +12 %) |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes** (none worse; app size see text) | No (cold +32 %, memory +50 %) | No (cold +29 %) | No (5 rows) |
| 3. Phone hitch rule | Pending | Pending | Pending | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The control is the Round 2 Sol UIKit tree (Round 3 folder), measured after the build was scored, same simulator and method.

| Row | E21 Sol build (thin2) | E21 Sol control (same sitting) | Diff | E19 build (thin + timer) | E17 build (thin) | E12 build (v0.9.0) |
|---|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 | 13, 13, 13 |
| First 40 rows, cold (ms) | 119 [119, 118, 120] | 134 [134, 136, 132] | -11 % | 175 | 172 | 122 |
| First 40 rows, repeated (ms) | 468 [471, 468, 468] | 582 [598, 580, 582] | -20 % | 580 | 585 | 178 |
| Stream CPU (s) | 6.46 [6.29, 6.46, 6.52] | 7.60 [7.65, 7.60, 7.50] | -15 % | 7.00 | 7.87 | 7.14 |
| Jump to 2,500 (ms) | 14 [14, 15, 14] | 26 [26, 24, 26] | -46 % | 21 | 12 | 49 |
| Load older (ms) | 6 [6, 6, 6] | 26 [26, 27, 26] | -77 % | 6 | 5 | 40 |
| Text size at bottom (ms) | 10 [10, 10, 10] | 15 [15, 14, 15] | -33 % | 14 | 9 | 40 |
| Text size mid-list (ms) | 10 [10, 10, 10] | 25 [25, 25, 26] | -60 % | 15 | 9 | 42 |
| Peak memory (MB) | 55.1 [54.5, 55.1, 56.6] | 57.6 [58.0, 57.6, 57.6] | -4 % | 86.5 | 58.5 | 71.2 |
| App size (MB) | 3.27 (whole `.app`; executable 0.68) | 0.79 | see text | 1.98 (executable 0.73) | 0.84 | 0.73 |

## Agent facts (`meta.json`, transcript)

| | Thin2 (E21) | Thin + timer (E19) | Thin (E17) | v0.9.0 (E12) | v0.10.0 (E14) | Control (Round 2) |
|---|---|---|---|---|---|---|
| Wall (s) | 1,595 | 1,749 | 1,445 | 1,380 | 2,013 | 1,233 |
| Turns | 77 | 93 | 77 | 74 | 96 | 90 |
| Builds (failed) | 17 (7) | 17 (5) | 15 (3) | 11 (4) | 22 (8) | 14 (7) |
| Input tokens incl. cached (M) | 6.5 | 7.0 | 4.6 | 3.6 | 9.0 | n/a |
| Output tokens (k) | 53 | 61 | 51 | 49 | 72 | n/a |

- 0 commits, exit 0, `stopped_by_limit` false.
- Skill files read: `SKILL.md`, `references/more-surfaces.md`, and also `references/measuring-text.md` and `references/table-view.md` (E19 read only the first two). The transcript counts include pointers inside the files.
- Two web searches and a `curl` of the public Campfire repository's file list, for the icons (see above).
- Stack rule ok, `PBXShellScriptBuildPhase` count 0.
- Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted; nothing extra to shut down.

## What this changes

1. **The diagnosis held for Sol.** The cold-rows miss that repeated across E14, E17 and E19 was the launch order (data started after UIKit's start-up, behind a placeholder), and the memory swing was cells drawing themselves; with one sentence each in the skill, both rows are under the control. Sol now misses only on agent wall time.
2. With E20 (Opus passes the whole sim bar) this makes thin2 the best thin arm on both models at 829 words of `SKILL.md`.
3. Open: Sol's wall time (all Sol skill builds miss it; spread between builds of the same skill is about 300 s); the web-fetched assets (decide whether the prompt or harness should say anything); phone passes for both thin2 builds.
