# Round 5, E7: results of the two validation builds

Run 26 Oct. Skill `uikit-chat-list` v0.6.2 (commit `db872cd`, folder hash `26a0f5ac...`), installed alone in each build folder (init skill list was exactly `uikit-chat-list` for Opus; Sol's config isolation as in the runbook). Prompt identical to Round 2 (diff empty for both). Runbook: `docs/round5-e7-runbook.md`. Raw data: `runs/opus-uikit-ours-chatlist/`, `runs/sol-uikit-ours-chatlist/` (including `e7-sim/`), control re-measure in `runs/e7-control-remeasure/`.

**Phone passes: pending** (nobody at the iPhone 12). Pass-bar item 1 (13 of 13 on the phone) and the phone hitch rule therefore cannot be decided yet. Everything below is simulator (iPhone 17 simulators `uvs-r3-a` Opus, `uvs-r3-b` Sol, iOS 26.4) and the build facts.

## Verdicts (simulator part only)

| Build | Verdict | Why |
|---|---|---|
| Opus + skill | **Does not pass** | Stream CPU 8.44 s against the control's 5.65 s (+49 %, bar is 10 %). The app also crashed during the run in 2 of 3 passes. |
| Sol + skill | **Does not pass** | Wall time 1669 s against 1356 s allowed (+35 % over control). Jump +81 % and text size at bottom +72 % against the control re-measure. 13 of 13 in all three passes, text selection passes. |

One build per arm; no arm has been run twice. The control is also noisy (see below), so single rows move.

## Agent facts (from `meta.json`)

| | Opus build | Opus control | Sol build | Sol control |
|---|---|---|---|---|
| Wall time (s) | 2280 | 2231 | 1669 | 1233 |
| Bar (control + 10 %) | 2454: met | | 1356: **missed** | |
| Turns | 83 | 95 | 85 | 90 |
| Builds (failed) | 9 (0) | 12 (0) | 20 (8) | 14 (7) |
| Commits | 1 | | 0 | |
| Stack rule, `git grep -l 'import SwiftUI'` | none | | none | |
| Time cap hit | no | | no | |

The Opus agent called the skill (one Skill call) and the transcript shows it read `references/measuring-text.md`; it built the collection view with a custom layout (the skill's default). The Sol agent read `SKILL.md` and `references/measuring-text.md`. Neither build has a script build phase.

## Simulator scorecard, median of three passes, against the control measured in the same sitting

Control = the Round 2 UIKit trees (Round 3 folders), re-measured with the same three-pass method on the same simulator the same day. The old single-run baseline from Round 3 setup is in the last column group for reference.

### Opus

| Row | Build | Control (re-measured) | Diff | Old baseline |
|---|---|---|---|---|
| Checks passed (median) | 13 of 13 | 13 of 13 | | 13 of 13 |
| Checks per pass | 13, 13, 7 | 12, 11, 13 | | |
| First 40 rows, cold (ms) | 134 | 167 | -20 % | 205 |
| First 40 rows, repeated (ms) | 583 | 603 | -3 % | 671 |
| Stream CPU (s) | 8.44 | 5.65 | **+49 %** | 8.15 |
| Jump to 2,500 (ms) | 45 | 45 | 0 % | 60 |
| Load older (ms) | 36 | 37 | -3 % | 55 |
| Text size at bottom (ms) | 32 | 46 | -30 % | 49 |
| Text size mid-list (ms) | 37.5 | 39 | -4 % | 67 |
| Peak memory (MB) | 54.7 | 52.8 | +4 % | 117.6 |
| App size (MB) | 0.74 | 0.84 | -12 % | 1.34 |

Against the old single-run baseline the stream row is level (8.44 against 8.15); the re-measured control happened to run 5.65 s, so the verdict on that row depends on which control you trust. Under the pre-set rule (control measured in the same sitting) it fails.

### Sol

| Row | Build | Control (re-measured) | Diff | Old baseline |
|---|---|---|---|---|
| Checks passed (median) | 13 of 13 | 13 of 13 | | 12 of 13 |
| Checks per pass | 13, 13, 13 | 13, 13, 13 | | |
| First 40 rows, cold (ms) | 144 | 148 | -3 % | 195 |
| First 40 rows, repeated (ms) | 618 | 594 | +4 % | 639 |
| Stream CPU (s) | 8.37 | 7.61 | +9.9 % (inside 10 %) | 9.84 |
| Jump to 2,500 (ms) | 56 | 31 | **+81 %** | 38 |
| Load older (ms) | 24 | 31 | -23 % | 33 |
| Text size at bottom (ms) | 31 | 18 | **+72 %** | 20 |
| Text size mid-list (ms) | 32 | 31 | +3 % | 31 |
| Peak memory (MB) | 59.8 | 58.0 | +3 % | 59.6 |
| App size (MB) | 0.70 | 0.79 | -11 % | 1.20 |

Note: the Round 2 Sol control failed text selection in Round 3 setup (12 of 13); in this re-measure it passed 13 of 13 in all three passes, so the "text selection fixed" reading in the runbook has no baseline to be fixed from. The new Sol build passes it.

The plan's wider hope (130 to 175 ms for 40 rows, 4.6 to 8.8 s stream CPU, 32 to 42 ms jump, 44 to 58 MB) is met by Opus on 40 rows, stream, memory (54.7) and, on jump, nearly (45 ms); Sol meets 40 rows (144) and stream (8.37) and misses jump (56 ms) and memory (59.8 MB, just over). Not the bar.

## Failed checks and the skill rule that covers them

Only Opus failed checks, and only in the third pass (6 checks, listed below) plus crashed test iterations in pass 2 that did not change that pass's result. The control's Opus also had failing passes (12 and 11 of 13: "Rotating keeps the room pinned" failed once with "state label missing"; "all 600 arrive" and "stay pinned after the stream" failed once with "stream never finished"; one test iteration lost the app), so this harness plus the Round 2 Opus tree is flaky too. The scorecard's median reports 13 of 13 for both, because most iterations passed.

Opus pass 3 failures:

| Failed check | Cause seen | Skill rule |
|---|---|---|
| New messages come only from the live stream: all 600 arrive | App crashed during the stream (`testLiveStream`: "Application is not running") | No rule covers it (see below) |
| Stay pinned after the stream | Same crash | Same |
| Text size keeps the room pinned; keeps the top row in place | App not running / connection lost during the text size tests | Same crash; the skill's text-size rules (core rule 11, the clamp trap) were not the failure |
| Rotating keeps the room pinned; keeps the top row in place | App not running | Same |

**Correction (see round5-v07-diagnosis.md):** both crash reports came from the agent's own Debug runs before it fixed the bug; the scored passes failed because another agent installed and tested its app on the same simulator. The original reading follows.

The crash itself: two crash reports of the app in this sitting, both an `NSAssertionHandler` failure inside `UICollectionView performBatchUpdates` (selector `_validateSortedDeleteItems:moveItems:...insertItems:`), called from the build's `update(keeping:_:)` ← `appendRows` ← `appendLive` ← the stream task, at the point where the window trims the oldest rows (a batch that deletes at the top and inserts at the bottom together). I have not established why the counts or indices disagree. **No skill rule covers this.** The nearest text is the trap paragraph (trimming clamps the offset; use `reloadData` for a large removal) and the insert line (`insertItems` inside `performBatchUpdates`, data changed in the same closure); neither says that a trim and an append should not share one batch, or what to do instead. This is a rule gap for E6, a candidate: "when the window trims, `reloadData` plus the computed offset; never delete and insert in one batch while streaming."

Sol: no failed check in any pass, so no rule gap to report from the checks. Its rows that lost to the control (jump 56 ms, text size at bottom 31 ms) are rows the skill covers (rules for jump and text size) but the numbers are small; with one build per arm and a control whose own passes ranged this widely, treat them as a lead, not a finding.

## Against the pass bar

| Bar item | Opus | Sol |
|---|---|---|
| 1. 13 of 13 on the sim median, text selection passing | Median yes; one pass of three 7 of 13, two of three passes had crashes | Yes, 3 of 3 passes |
| 1. Same on the phone | Pending | Pending |
| 2. Wall time within 10 % | Yes (2280 s, +2 %) | **No** (1669 s, +35 %) |
| 3. No simulator row more than 10 % worse | **No** (stream CPU +49 %) | **No** (jump +81 %, text size bottom +72 %) |
| 3. Phone hitch rule | Pending | Pending |

Reading by the runbook: both builds miss on speed or numbers; the Opus crash is a fail of a check the skill does not cover, so by the runbook's wording it does not by itself disprove the skill but it goes to E6 as a missing rule. Not "proved wrong" for either build.

## Open items

- Phone passes for both builds (iPhone 12): pending, someone at the phone.
- The machine had a third booted simulator (not ours) during scoring, so the cap showed 3 of 2; ours stayed the two kept ones. The Sol agent's build and later its passes shared the Mac with the control passes (builds queue through `buildslot`, but the Sol agent's own builds overlapped the Opus passes), which adds noise to the Opus numbers.
- The Sol build's `meta.json` has no isolation_check block (its isolation evidence is the config hash); the transcript shows reads of only the `uikit-chat-list` files.
