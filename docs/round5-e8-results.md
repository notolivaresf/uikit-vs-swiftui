# Round 5, E8: validation round 2 with skill v0.7.0

Run 26 Oct. Same method as E7 (`docs/round5-e7-runbook.md`) but quiet and strictly one thing at a time: the three steps (control re-measure, Opus build, Opus scoring) ran in sequence, nothing else on the two kept simulators (`uvs-r3-a`, `uvs-r3-b`) while scoring ran, and no scoring while the agent built. Skill `uikit-chat-list` v0.7.0 (folder hash `371f83a0...`), installed alone; the Opus init skill list was exactly `uikit-chat-list`. Prompt unchanged from Round 2. Raw data: `runs/opus-uikit-ours-chatlist-v07/` (with `e8-sim/`), quiet controls in `runs/e8-control-quiet/`.

## In plain words

- **The Opus build does not pass.** All 13 checks passed in all three scored passes (E7: one pass of three had 7 of 13, from the shared simulator), so the crash and contamination problems of E7 are gone. But two bar items are missed: the agent took 2,600 s against the allowed 2,454 s (+16.6 % over the control's 2,231 s), and stream CPU is 8.67 s against the quiet control's 6.33 s (+37 %, bar is 10 %). Jump to message 2,500 is also over (64 ms against 44 ms, +45 %).
- **The quiet controls are not the single baseline numbers of Round 3 setup.** The Opus control's stream is 6.33 s in this sitting (single runs earlier: 8.15 s quiet, 5.65 s loaded), so the control itself moves by a third between sittings. The build's 8.67 s is 6 % above the old 8.15 s baseline but 37 % above the control measured today, and the runbook says the same sitting counts. Three passes of each arm read within 2 % of their own median, so this sitting's gap is repeatable; whether it would hold on another day is not known.
- **Sol did not run.** Codex is under the quota threshold (`codex-pace`: weekly 9 %), but the launch stopped after 20 s: Codex refused its login ("your refresh token was already used, please log out and sign in again"). That is a shared login only Fernando can renew, so I did not retry. The failed attempt left `runs/sol-uikit-ours-chatlist-v07/` (exit code 1, zero turns) and a build folder that holds only the inputs (`~/uvs-builds/sol-uikit-ours-chatlist-v07`); nothing was scored. Once Codex is signed in again the same line runs it: `UVS_NAME_SUFFIX=-v07 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist` (the folders must be moved aside or the suffix changed, since the launcher refuses an existing folder).
- **The phone passes are still pending** (nobody at the iPhone 12), as in E7. Everything below is simulator (iPhone 17, iOS 26.4) plus the agent's own facts.
- One build per arm. No arm has been run twice with this skill version.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + skill v0.7.0 | **Does not pass** (simulator part) | 13 of 13 in all passes. Wall time +16.6 % (bar +10 %). Stream CPU +37 % and jump +45 % against the quiet control (bar +10 % each). Phone pending. |
| Sol + skill v0.7.0 | **Not run** | Codex login expired (needs Fernando). |

By the runbook's reading ("only the speed or the numbers miss: report it, do not call it a failure of the skill") this is not "proved wrong": no check the skill covers failed.

## Agent facts (`meta.json`)

| | Opus v0.7.0 | Opus E7 (v0.6.2) | Opus control |
|---|---|---|---|
| Wall time (s) | 2600 | 2280 | 2231 |
| Bar (control + 10 %) | 2454: **missed** | met | |
| Turns | 117 | 83 | 95 |
| Builds (failed) | 10 (1) | 9 (0) | 12 (0) |
| Commits | 0 | 1 | |
| Stack rule | ok; `git grep -l 'import SwiftUI'` finds nothing | ok | |
| Script build phase | none (0) | none | |
| Time cap hit | no | no | |

Skill use: one Skill call; `references/measuring-text.md` read (5 reads), `references/table-view.md` once. The app is a collection view with a custom layout (the skill's default). The agent made 3 test runs of its own (xcodebuild test), against 3 to 14 elsewhere. It also created, used and removed a private simulator of its own (`cf-v07`) for its testing, so it never touched the two scoring simulators: the E7 contamination did not recur, and `simctl list` showed only `uvs-r3-a` and `uvs-r3-b` booted afterwards. The project is `CampfireBench.xcodeproj` (scheme `CampfireBench`, bundle id `campfire.bench`).

## Simulator scorecard, median of three passes, quiet

Each cell: the median, with the three passes in brackets. Controls are the Round 2 UIKit trees (Round 3 folders), same simulators, same method, measured in this sitting before the build started.

### Opus

| Row | Build v0.7.0 | Quiet control | Diff | E7 build (v0.6.2) | Old baseline |
|---|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 7 | 13 |
| First 40 rows, cold (ms) | 158 [150, 167, 158] | 171 [174, 157, 171] | -8 % | 134 | 205 |
| First 40 rows, repeated (ms) | 622 [620, 622, 624] | 601 [592, 604, 601] | +3 % | 583 | 671 |
| Stream CPU (s) | **8.67** [8.67, 8.51, 8.67] | 6.33 [6.30, 6.35, 6.33] | **+37 %** | 8.44 | 8.15 |
| Jump to 2,500 (ms) | **64** [56, 64, 69] | 44 [43, 44, 47] | **+45 %** | 45 | 60 |
| Load older (ms) | 38 [47, 38, 34] | 44 [47, 34, 44] | -14 % | 36 | 55 |
| Text size at bottom (ms) | 47 [47, 41, 47] | 45 [41, 50, 45] | +4 % | 32 | 49 |
| Text size mid-list (ms) | 46 [46, 46, 44] | 48 [45, 50, 48] | -4 % | 37.5 | 67 |
| Peak memory (MB) | 58.5 | 53.5 | +9 % (inside 10 %) | 54.7 | 117.6 |
| App size (MB) | 0.77 | 0.84 | -8 % | 0.74 | 1.34 |

### Sol control (quiet), for reference only (no Sol build this round)

13, 13, 13 of 13. First 40 rows 135 / 579 ms; stream CPU 7.37 s; jump 25 ms; load older 26 ms; text size 15 / 26 ms; peak memory 57.4 MB; app size 0.79 MB. These differ a lot from E7's Sol control re-measure (jump 31, text size at bottom 18, stream 7.61): jump and text size are the rows where E7's Sol build "lost", and the control's own numbers move by 20 % or more between sittings. Another reason to read single-build differences under about 20 % as noise.

## Against the pass bar

| Bar item | Opus v0.7.0 |
|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes**, 3 of 3 passes |
| 1. Same on the phone | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **No** (2,600 s) |
| 3. No simulator row more than 10 % worse than the quiet control | **No** (stream +37 %, jump +45 %) |
| 3. Phone hitch rule | Pending |

## Failures the skill should have prevented, and what each tells us

No check failed, so there is no rule-gap failure of the E7 kind. The misses are all on speed and numbers:

1. **Stream CPU +37 %.** The code (`App/ChatViewController.swift`, `appendLive`) still applies every incoming message as its own `performBatchUpdates` and calls `updateChrome()` after each, and every boost is its own `performBatchUpdates` with a `reconfigureItems` (`rowChanged`). The v0.7 layout fix did land (the layout's `append` now recomputes tops only from the new rows and `update` only from the changed row; trim is a separate step with `reloadData`), and the stream number did not improve (8.44 s in E7, 8.67 s now), which suggests the full rebuild was not what cost most. What remains different from the control is the missing grouping: the control collects events and flushes them every 0.1 s. v0.7 rule 3 says each update should cost only the changed rows; it does not tell the agent to coalesce.
2. **Jump +45 % (64 against 44 ms).** Not diagnosed. In E7 the same build family read 45 ms; here 56 to 69 ms in three passes, so the number is unstable between builds of the same skill. Treat it as a lead.
3. **Wall time +16.6 % with 117 turns** (control 95). Three test runs only; the build had no test-failure spiral (1 failed build). The time went into the agent's own simulator setup and screenshot checks (a private simulator created and removed, several launches and dark mode checks). Not a skill finding unless the skill's "run the checklist" wording prompted the extra screenshot loop; I did not trace that.

## Proposed skill changes (the uikit-skill repo is not edited here)

1. **Live updates: coalesce.** Add a core rule: "collect incoming messages and boosts in a pending list and apply them as one update on a short timer (about 0.1 s); never one `performBatchUpdates` per event." This is the recipe of the control that measures 6.3 s, and the only structural difference left in the code that I can see.
2. **Do the chrome work once per flush**, not per event (`updateChrome()` after every appended message).
3. **Jump path:** ask E6 to look at why a jump measures 45 to 69 ms in builds of the same skill against 25 to 44 ms in the controls; the rule on replacing the window should say to measure only the loaded page, not all loaded rows. (Low confidence; needs a trace before a rule.)
4. **How to work:** keep the line that the agent should test on its own simulator and shut it down; add a limit on screenshot loops (for example "three dark or light checks, once") to hold turns near 95.

## Open items

- Phone passes for the Opus build (iPhone 12), pending.
- Sol build: blocked on Codex login (Fernando). The control's quiet numbers are recorded for when it runs.
- A second Opus build with v0.7.0 would show whether the stream gap is the skill or the day: the control moved from 5.65 s (loaded) and 8.15 s (earlier quiet) to 6.33 s (quiet today).
