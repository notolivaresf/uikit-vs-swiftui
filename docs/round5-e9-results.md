# Round 5, E9: validation round 3 with skill v0.8.0

Run 26 to 27 Oct (local evening). Same method as E8 (`docs/round5-e8-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing else scoring), then three scored passes, then the Opus control re-measured in the same sitting, then the Sol attempt. Nothing else ran on the two kept simulators (`uvs-r3-a`, `uvs-r3-b`) while scoring ran. Skill `uikit-chat-list` v0.8.0 (folder hash `a97884b5...`), installed alone; the Opus init skill list was exactly `uikit-chat-list`. Prompt unchanged. Raw data: `runs/opus-uikit-ours-chatlist-v08/` (with `e9-sim/`), same-day control in `runs/e9-control-quiet/`, E8 control in `runs/e8-control-quiet/`.

## In plain words

- **The Opus build does not pass, and this time one check the skill covers failed.** The text size check fails in all three passes (12 of 13): after the first text size step in the mid-list test, the row at the top is message 2,499 instead of 2,500. The later steps hold. It happens in every one of the nine steps-of-first-position readings, so it is repeatable. Text size is a rule the skill covers, so by the runbook's reading this goes back to the skill as a fixed rule (E8's build passed all 13, so v0.8 or the luck of the build moved it).
- **Speed and the agent's time are the best so far.** The agent finished in 2,094 s (control 2,231 s, bar 2,454 s) with 71 turns (control 95) and 7 builds, none failed. That is the first Opus build that is faster than its control.
- **Stream CPU is much closer but still over the bar.** 7.33 s against the control's 6.44 s measured today: +14 % (bar 10 %). E8 was +37 %. The build now coalesces live updates on a 0.1 s flush, which is the v0.8 rule. Jump is now level with the control (48 ms against 52 ms; E8 was +45 %).
- **Peak memory is the new miss:** 63.2 MB against 53.3 MB (+18 %). E8 was +9 % (58.5 against 53.5). Not diagnosed.
- **Sol did not run, again.** `codex login status` says logged in and `codex-pace` was 9 % (its reading was about 4.8 days old), but the launch stopped after 20 s with the same error, "your refresh token was already used", then 401 on every reconnect. Per the brief I did not retry. The login needs to be renewed by Fernando (log out and sign in again). Left behind: `runs/sol-uikit-ours-chatlist-v08/` (exit code 1, zero turns) and an inputs-only folder `~/uvs-builds/sol-uikit-ours-chatlist-v08`. No Sol control re-measure was taken (the brief ties it to the Sol build running); E8's quiet Sol control numbers still stand.
- **Phone passes are still pending** (nobody at the iPhone 12). Everything below is simulator (iPhone 17, iOS 26.4) plus the agent's own facts. One build per arm.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + skill v0.8.0 | **Does not pass** (simulator part) | Text size check fails in 3 of 3 passes (12 of 13): a skill-covered check. Wall time met (-6 %). Stream CPU +14 % (bar +10 %), peak memory +18 % (bar +10 %). Phone pending. |
| Sol + skill v0.8.0 | **Not run** | Codex sign-in refresh token already used (needs Fernando). Second failure. |

## Against the pass bar (Opus)

| Bar item | Opus v0.8.0 |
|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **No**: 12 of 13 (text size mid-list drift). Text selection passes. |
| 1. Same on the phone | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (2,094 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **No**: stream CPU +14 %, peak memory +18 % (load older +13 % is 5 ms, inside the one-frame noise; text size at bottom +9 %) |
| 3. Phone hitch rule | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The same-day control is the Round 2 Opus UIKit tree (Round 3 folder), measured after the build was scored, same simulators, same method (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`).

| Row | E9 build (v0.8.0) | E9 control (same day) | Diff | E8 build (v0.7.0) | E8 control | E7 build (v0.6.2) | Old baseline |
|---|---|---|---|---|---|---|---|
| Checks passed | **12**, 12, 12 | 13, 13, 13 | | 13, 13, 13 | 13, 13, 13 | 13, 13, 7 | 13 |
| First 40 rows, cold (ms) | 163 [154, 168, 163] | 168 [168, 168, 167] | -3 % | 158 | 171 | 134 | 205 |
| First 40 rows, repeated (ms) | 629 [628, 629, 637] | 605 [608, 592, 605] | +4 % | 622 | 601 | 583 | 671 |
| Stream CPU (s) | **7.33** [7.34, 7.33, 7.24] | 6.44 [6.44, 6.46, 6.43] | **+14 %** | 8.67 | 6.33 | 8.44 | 8.15 |
| Jump to 2,500 (ms) | 48 [48, 51, 47] | 52 [54, 49, 52] | -8 % | 64 | 44 | 45 | 60 |
| Load older (ms) | 43 [43, 38, 50] | 38 [37, 39, 38] | +13 % | 38 | 44 | 36 | 55 |
| Text size at bottom (ms) | 50 [52, 45, 50] | 46 [46, 51, 46] | +9 % | 47 | 45 | 32 | 49 |
| Text size mid-list (ms) | 47 [47, 44, 49] | 48 [48, 49, 45] | -2 % | 46 | 48 | 37.5 | 67 |
| Peak memory (MB) | **63.2** [63.2, 61.8, 63.7] | 53.3 [54.1, 53.3, 52.8] | **+18 %** | 58.5 | 53.5 | 54.7 | 117.6 |
| App size (MB) | 0.77 | 0.84 | -8 % | 0.77 | 0.84 | 0.74 | 1.34 |

How the control moves: its stream reading was 6.33 s (E8 sitting), 6.44 s (today), against 8.15 s on the old baseline day and 5.65 s loaded. Control rows move by up to 15 % between sittings (jump 44 to 52 ms, load older 38 to 44 ms), so differences under about 15 % on the small rows are inside the noise. The stream and memory gaps are the two that are bigger than that or have held up in three sittings in a row (memory has been above the control in E8 and E9).

## Agent facts (`meta.json`, transcript)

| | E9 Opus v0.8.0 | E8 Opus v0.7.0 | E7 Opus v0.6.2 | Opus control |
|---|---|---|---|---|
| Wall time (s) | **2094** | 2600 | 2280 | 2231 |
| Bar (control + 10 %) | 2454: met | missed | met | |
| Turns | **71** | 117 | 83 | 95 |
| Builds (failed) | 7 (0) | 10 (1) | 9 (0) | 12 (0) |
| Own test runs (xcodebuild test) | 2 | 3 | | 6 in the E8 analysis |
| Commits | 0 | 0 | 1 | |
| Screenshots taken | 22 | | | |
| Stack rule / `git grep -l 'import SwiftUI'` | ok / nothing found | ok | ok | |
| Script build phase | none (0) | none | none | |
| Time cap hit | no | no | no | |
| Sol (any version) | not run (sign-in) | not run (sign-in) | ran, in E7 | |

Skill use: one Skill call, then it read `references/measuring-text.md`. The app is a collection view with a custom layout (`ChatLayout.swift`, `RowLayout.swift`); live updates are queued and flushed on a 0.1 s `asyncAfter`, with one `performBatchUpdates` for the flush (v0.8 rule 8 landed). Jump and window replacement call `reloadData` then set the offset (v0.8's jump rule). The agent made a private simulator of its own (`cf-v08`) for testing and left it booted; I shut it down after the build ended (it was a third booted simulator, over the cap, while the build was running and before scoring started). It did not touch the two scoring simulators. The v0.8 "how to work" lines show in the numbers: 71 turns and a quarter fewer than the control, no suite-rerun spiral.

## What v0.8 fixed, and what is left

Fixed (against E8):

1. **Live-update grouping.** Stream CPU went from +37 % to +14 % over the same-quiet control. The spike predicted -24 % from the grouping alone (6.49 to 4.92 s unpolled); the polled number dropped 15 % (8.67 to 7.33 s).
2. **Jump double layout.** +45 % to -8 % (the rule that sets the target offset right after `reloadData` landed).
3. **Agent time and turns.** 2,600 s / 117 turns to 2,094 s / 71 turns; the polish tail after the checks passed is gone.

Left:

1. **Text size anchoring (new failure).** In `testTextSizeMidScroll` the first text size step moves the top row from 2,500 to 2,499; steps two and three keep it. Same in all three passes and all three iterations each. The code (`textSizeDidChange`, `relayoutAll(keeping: captureAnchor())`) already captures an anchor and restores it, so the fault is in what the anchor holds for the first step: not traced. Lead: the first step happens right after the jump to 2,500, so the captured anchor may be one pixel-rounded row off, or the first relayout happens before the jump has settled. Needs a spike before a rule.
2. **Stream CPU +14 %.** What the spike showed is still the story: with grouping, the cells (setting each text view's frame and text on every provision; the control skips the text assignment when it is unchanged) cost more than the control. The skill does not say to skip unchanged assignments.
3. **Peak memory +18 %** (63 against 53 MB, two sittings above the control). Not diagnosed. The cache of measured rows (`pruneCache`) and row layout data are the first places to look.
4. **Phone passes and Sol** are still not done.

## Proposed next skill changes (the uikit-skill repo is not edited here)

1. **Text size rule: keep the same message under the header, checked on the first step.** Add to the text size rule: "after the first change of text size the message that was at the top is still at the top (same id, same offset within 2 pt); test the first step, not only later ones". Before writing the rule, run a spike that reproduces the 2,500 to 2,499 move on this build (E9 spike: capture the anchor right after the jump and after the first step, print both). Confidence the rule is right: medium; the cause is unknown.
2. **Cell configuration.** Add "in the cell, set text and frames only when the value changed" (the spike's lead; not yet measured as an arm). Measure it first as an arm in `spikes/round5/E8Stream/`.
3. **Memory.** A spike on the E9 build (heap growth during the stream, size of the measured-row cache against the control's) before any rule. If it is the row cache, the rule is "keep measured heights for the loaded window only".
4. **Keep v0.8's how-to-work lines.** The agent's 71 turns and 7 builds say they work. Add "close any simulator you made when you stop" so a third simulator is not left booted (it was shut down here by hand).
5. **Re-run before shipping v0.9:** one more Opus build with the same quiet method to see whether the text size fail repeats (3 identical passes of one build prove the build, not the skill).

## Open items

- Phone passes for the Opus build (iPhone 12), pending.
- Sol: blocked on the Codex login (second time). After Fernando signs in again: `UVS_NAME_SUFFIX=-v09 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist` (or keep `-v08` only after moving the existing stub aside; the launcher refuses an existing folder).
- Raw material kept: `runs/opus-uikit-ours-chatlist-v08/` (meta, transcript, `e9-sim/` summaries and scorecards), `runs/e9-control-quiet/uikit-swift-opus/`, `runs/sol-uikit-ours-chatlist-v08/` (failed stub, with its stderr).
