# Round 5, E10: validation round 4 with skill v0.9.0

Run 27 Oct (UTC; local evening of 26 Oct). Same method as E9 (`docs/round5-e9-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), three scored passes, the Opus control re-measured in the same sitting, then one Sol attempt. Nothing else ran on the two kept simulators (`uvs-r3-a`, `uvs-r3-b`) while scoring ran. Skill `uikit-chat-list` v0.9.0, installed alone; the Opus init skill list was exactly `uikit-chat-list`. Prompt unchanged. Raw data: scored passes in `runs/opus-uikit-ours-chatlist-v09/e10-sim/`, control re-measure in `runs/e10-control-quiet/`; meta, transcript and the Sol stub stay local under `runs/` (their meta files hold home paths).

## In plain words

- **The Opus build passes the simulator part of the bar.** 13 of 13 checks in all three passes (E9 failed text size, 12 of 13). Text size mid-list, the E9 failure, is fixed: it passes every pass.
- **The three E9 misses are gone.** Stream CPU 5.94 s against the control's 6.44 s the same sitting (-8 %; E9 was +14 %). Peak memory 54.1 MB against 53.8 MB (+0.6 %; E9 was +18 %). The pixel-snapped rows, TextKit 1 text views and prefetching off, the three v0.9 rules, are all in the code the agent wrote.
- **One row is a hair over the strict line:** load older 43 ms against 39 ms (+10.3 %, 4 ms, less than one frame). The control's own three passes in this sitting ran 35, 44, 39 ms, and its earlier sittings 38 and 44, so this is noise. By the letter of the bar it is a marginal miss; I read it as a pass and say so.
- **The agent was faster again.** 2,115 s (control 2,231 s, bar 2,454 s), 62 turns (control 95), 11 builds, none failed. Stack rule ok, no `import SwiftUI`, no script build phase, no time cap hit.
- **Sol did not run, third time.** `codex login status` still says "Logged in using ChatGPT" and `codex-pace` was 9 % (reading 4.8 days old), but the login file has not changed since 14 Oct. The one try died after 20 s with "your refresh token was already used" (exit 1, zero turns). Not retried. Fernando needs to log Codex out and in again. No Sol control re-measure was taken (tied to the Sol build running). Stub left: `runs/sol-uikit-ours-chatlist-v09/`, and an inputs-only folder `~/uvs-builds/sol-uikit-ours-chatlist-v09`.
- **Phone passes are still pending** (nobody at the iPhone 12). Everything below is simulator (iPhone 17, iOS 26.4) plus the agent's own facts. One build per arm.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + skill v0.9.0 | **Passes** the simulator part (marginal on one row) | 13 of 13 in 3 of 3 passes, text selection and text size pass. Wall time met (-5 %). No row worse than +10 % except load older at +10.3 % (4 ms, inside the control's own spread). Phone pending. |
| Sol + skill v0.9.0 | **Not run** | Codex refresh token already used (third failure; needs Fernando to sign in again). |

## Against the pass bar (Opus)

| Bar item | Opus v0.9.0 |
|---|---|
| 1. 13 of 13 on the sim median, text selection passing | **Yes** (13, 13, 13) |
| 1. Same on the phone | Pending |
| 2. Wall time within 10 % (at most 2,454 s) | **Yes** (2,115 s, -5 %) |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes, with one caveat**: load older +10.3 % (4 ms). All other rows within +5 % or better. |
| 3. Phone hitch rule | Pending |

## Simulator scorecard, median of three passes, quiet

Each cell is the median with the three passes in brackets. The same-day control is the Round 2 Opus UIKit tree (Round 3 folder), measured after the build was scored, same simulators, same method (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`).

| Row | E10 build (v0.9.0) | E10 control (same day) | Diff |
|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | |
| First 40 rows, cold (ms) | 139 [139, 142, 133] | 163 [172, 162, 163] | -15 % |
| First 40 rows, repeated (ms) | 574 [581, 574, 572] | 595 [595, 591, 605] | -4 % |
| Stream CPU (s) | 5.94 [5.94, 5.97, 5.94] | 6.44 [6.44, 6.39, 6.54] | -8 % |
| Jump to 2,500 (ms) | 44 [45, 42, 44] | 42 [42, 46, 40] | +5 % |
| Load older (ms) | 43 [41, 43, 44] | 39 [35, 44, 39] | +10 % |
| Text size at bottom (ms) | 41 [42, 41, 41] | 45 [44, 45, 48] | -9 % |
| Text size mid-list (ms) | 42 [43, 39, 42] | 46 [43, 46, 49] | -9 % |
| Peak memory (MB) | 54.1 [54.1, 54.2, 53.8] | 53.8 [53.8, 53.8, 52.8] | +1 % |
| App size (MB) | 0.77 | 0.84 | -8 % |

## E7 / E8 / E9 / E10 side by side (Opus; the control column is that sitting's re-measure)

| Row | E7 build (v0.6.2) | E8 build (v0.7.0) | E9 build (v0.8.0) | **E10 build (v0.9.0)** | Control, E10 sitting | Control, E9 sitting |
|---|---|---|---|---|---|---|
| Checks passed (sim) | 13, 13, 7 | 13, 13, 13 | 12, 12, 12 | **13, 13, 13** | 13 | 13 |
| Stream CPU (s) | 8.44 | 8.67 | 7.33 | **5.94** | 6.44 | 6.44 |
| Stream vs control | | +37 % | +14 % | **-8 %** | | |
| Jump to 2,500 (ms) | 45 | 64 | 48 | **44** | 42 | 52 |
| Text size bottom / mid (ms) | 32 / 37.5 | 47 / 46 | 50 / 47 | **41 / 42** | 45 / 46 | 46 / 48 |
| First 40 rows cold / repeated (ms) | 134 / 583 | 158 / 622 | 163 / 629 | **139 / 574** | 163 / 595 | 168 / 605 |
| Peak memory (MB) | 54.7 | 58.5 | 63.2 | **54.1** | 53.8 | 53.3 |
| Wall time (s) | 2280 | 2600 | 2094 | **2115** | (2231 build) | |
| Turns | 83 | 117 | 71 | **62** | (95 build) | |
| Builds (failed) | 9 (0) | 10 (1) | 7 (0) | **11 (0)** | (12 (0)) | |
| Wall bar (at most 2,454 s) | met | missed | met | **met** | | |
| Sol | ran in E7 (13 of 13, 1,669 s: missed the time bar) | not run | not run | **not run** | | |

E7 to E10 are different builds by the same model with a different skill version each, one build per version; across sittings the control itself moves by up to about 15 % on the small rows (jump 42 to 52 ms, load older 38 to 44 ms), so compare each build with its own sitting's control.

## Agent facts (`meta.json`, transcript)

- Wall 2,115 s, 62 turns, 11 builds (0 failed), 0 commits, exit 0, no idle gaps over 20 minutes.
- Skill use: one Skill call, then it read `references/measuring-text.md` (three times) and `references/table-view.md` once.
- What v0.9 asked for is in the code: `ChatLayout.swift` rounds the running row position to the pixel grid (`((bottom + spacing) * scale).rounded() / scale`); `MessageCell.swift` builds text views with `usingTextLayoutManager: false`; `RoomViewController.swift` sets `isPrefetchingEnabled = false`.
- Stack rule ok; `grep -rl "import SwiftUI"` over `Campfire/` and `CampfireKit/` finds nothing; `PBXShellScriptBuildPhase` count 0.
- Simulators: the agent made its own iPhone 17 Pro simulator and left it booted when it stopped (a third booted device, over the cap). I shut it down with `xcrun simctl shutdown` after the build ended and before any scoring. It never touched `uvs-r3-a` or `uvs-r3-b`. v0.8's "close any simulator you made when you stop" was proposed in E9 and is not in v0.9, so the habit is still the agent's own.

## What v0.9 fixed, and what is left

Fixed (against E9, each predicted by `docs/round5-v09-spikes.md`):

1. **Text size anchoring.** Pixel-snapped rows removed the 0.12 pt sliver; 12 of 13 became 13 of 13 in every pass.
2. **Stream CPU.** +14 % to -8 % over the control. TextKit 1 text views were the cause the spike found (-25 % alone), and the full harness gives -19 % against the E9 build (7.33 to 5.94 s). The spike's patched copy gave 5.8 s; the new build lands on the same number.
3. **Peak memory.** +18 % to +1 %. The spike's patched copy was +7 %; this build did better than the patch.

Left:

1. **Phone passes** for the Opus build (iPhone 12), pending.
2. **Sol** is blocked on the Codex login; the Sol half of v0.9 (and of v0.8, v0.7) has no data. Sol is where the skill most needs a second look: E7's Sol run was the one that missed the time bar by 35 %.
3. **Load older** sits at +10 % in this sitting and -13 % to +13 % in others: noise, not a fault. Nothing to fix.
4. **One build is one sample.** Three identical passes prove the build, not the skill. A second Opus v0.9 build would show whether the 13 of 13 and the 5.9 s repeat.

## Proposed next skill changes (the uikit-skill repo is not edited here)

1. **None for the list rules.** v0.9's three rules did what the spikes said; do not tune them on one build.
2. **Add one line to how-to-work: "close any simulator you made when you stop"** (proposed in E9, still missing; the agent left a third booted device again).
3. **Do not add the cell-skip lead** (measured, no gain).
4. **Before v0.9.1 or v1.0, spend the effort on replication, not on rules:** a second Opus build, the Sol build once the login is renewed, and the phone passes. Tag v1.0 only if those hold.

## My call on further iterations

More skill iterations on the simulator numbers are unlikely to gain anything beyond noise for Opus. The build is now better than the control on six rows and within 1 to 10 % worse on three (jump +5 %, peak memory +1 %, load older +10 % or 4 ms), and the control itself moves 10 to 15 % between sittings. The gains from v0.7 to v0.9 (stream +37 % to -8 %, text size fail to pass, memory +18 % to +1 %) were large and caused by named rules, so they are real; what is left is below the size the method can see. Two things could still move: a different failure showing up in a second build (replication), and Sol, which has never run on a recent skill. Those are worth a build each; a v0.10 is not.

## Open items

- Phone passes for the Opus build (iPhone 12).
- Sol: needs Fernando to log Codex out and in again; then `UVS_NAME_SUFFIX=-v09b UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist` (the launcher refuses the existing `-v09` stub folder).
- Raw material kept: `runs/opus-uikit-ours-chatlist-v09/`, `runs/sol-uikit-ours-chatlist-v09/` (failed stub with its stderr). The Opus control now has a new `baseline.json` in the Round 3 folder (the E9 one is saved at `~/uvs-builds/e10/opus-baseline-e9.json`).
