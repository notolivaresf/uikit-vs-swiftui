# Round 5, E22: validation round 14, the Opus build with the thin3 skill (`v0.11.3-thin3`)

Run 27 Oct (local). Same method as E20 (`docs/round5-e20-results.md`, runbook `docs/round5-e7-runbook.md`), strictly one thing at a time: Opus build (nothing scoring), three scored passes on `uvs-r3-a`, then the Opus control (Round 2 Opus tree, Round 3 folder) re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-opus --runs 3`). Skill `uikit-chat-list` tag `v0.11.3-thin3` (private skill repo, branch `thin3` from `thin2`, commit `bd32a40`; a single `SKILL.md` of 621 words, no references, no agent). Installed alone; the init skill list was exactly `uikit-chat-list` (`skill_isolation.error` null). The pin `CHATLIST_TAG` in `Harness/skillset.py` is `v0.11.2-thin2`; the run used `UVS_CHATLIST_TAG=v0.11.3-thin3`. Prompt unchanged. Launch: `UVS_CHATLIST_TAG=v0.11.3-thin3 UVS_NAME_SUFFIX=-thin3 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh opus uikit --skills ours-chatlist`. Raw data: `runs/opus-uikit-ours-chatlist-thin3/` (meta, skillset, transcript times), scorecards in `~/uvs-builds/e22/`, control in `runs/e22-control-quiet/uikit-swift-opus/baseline.json`.

What thin3 cut from thin2 and why is in the uikit-skill repo, `docs/thinning-plan.md`, section "thin2 rule use" (SKILL.md 829 to 621 words; the three reference files and the reviewer agent removed).

## In plain words

- **Opus with thin3 passes every check**: 13 of 13 in all three passes. Stack rule ok, no `import SwiftUI`, no script build phase. No crash.
- **Every speed row is level or better than the same-sitting control**: cold -21 %, repeated +1 %, jump -72 %, load older -64 %, text size at the bottom -84 %, mid-list -81 %. Stream CPU +4 % (6.55 against 6.30 s, same as E20), peak memory +7 % (58.7 against 54.6 MB, E20 +6 %), both inside the 10 % line. App size 0.80 against 0.84 MB.
- **Agent wall time misses the bar**: 2,737 s against at most 2,454 s (+23 % on the control's 2,231). E20 (thin2) took 2,389 s. 85 turns (E20 71), 21 builds with none failed (E20 14), 15.1 M input tokens including cache (E20 10.9), $7.83 (E20 $6.89). The skill had no references to open, so the extra time is not reading.
- One build is one sample; the spread between Opus builds of one skill is several hundred seconds (v0.9.0 2,115 and 2,221 s, thin2 2,389 s). Phone passes are not run.

## Verdict

| Build | Verdict | Why |
|---|---|---|
| Opus + thin3 (E22) | **Does not pass** (misses bar 2 only) | 13 of 13 in 3 of 3 passes and no simulator row more than 10 % worse than the control, but wall 2,737 s against 2,454 s. |
| Against thin2 (E20) | **Rows level, slower agent** | Same checks; cold 129 against 136, jump 13 against 28, older 16 against 18, text 7 / 9 against 23 / 24 ms; stream 6.55 against 6.53 s; memory 58.7 against 56.5 MB; wall +348 s, builds 21 against 14, tokens +4.2 M. |

## Which cut the failure maps to

None of the cuts touches a screen row: every row held or improved. The miss is time only. The agent's own account of its work (transcript) shows it added an XCUITest target to drive the debug bar, rotate and take screenshots, and built 21 times; that is test-writing, not a rule. If a rule is to blame, the candidates are the ones whose cut removes guidance the agent then rediscovered by trial: the removed text size and rotation bullets (the agent tested rotation and text size by hand) and the removed "keep a few hundred rows" and offset-by-hand sentences. The evidence for this is weak (one sample, no per-rule timing); a second thin3 Opus build would show whether 2,737 s is the build or the noise before putting any group back. If it repeats, restore in this order: the text size and rotation bullets, then rule 8's offset sentence.

## Against the pass bar (Opus)

| Bar item | E22 thin3 | E20 thin2 |
|---|---|---|
| 1. 13 of 13 on the sim median | **Yes** (13, 13, 13) | Yes |
| 1. Same on the phone | Not run | Not run |
| 2. Wall time within 10 % (at most 2,454 s) | **No** (2,737 s, +23 %) | Yes (2,389 s) |
| 3. No simulator row more than 10 % worse than the same-day control | **Yes** (worst memory +7 %) | Yes |

## Simulator scorecard, median of three passes, quiet

| Row | E22 build (thin3) | E22 control (same sitting) | Diff | E20 build (thin2) |
|---|---|---|---|---|
| Checks passed | 13, 13, 13 | 13, 13, 13 | | 13, 13, 13 |
| First 40 rows, cold (ms) | 129 [130, 129, 129] | 163 [163, 173, 160] | -21 % | 136 |
| First 40 rows, repeated (ms) | 599 [599, 601, 598] | 592 [592, 603, 591] | +1 % | 604 |
| Stream CPU (s) | 6.55 [6.54, 6.63, 6.55] | 6.30 [6.22, 6.30, 6.33] | +4 % | 6.53 |
| Jump to 2,500 (ms) | 13 [13, 13, 13] | 47 [42, 47, 48] | -72 % | 28 |
| Load older (ms) | 16 [16, 16, 15] | 44 [44, 38, 44] | -64 % | 18 |
| Text size at bottom (ms) | 7 [7, 7, 7] | 43 [43, 43, 42] | -84 % | 23 |
| Text size mid-list (ms) | 9 [9, 10, 9] | 47 [45, 47, 50] | -81 % | 24 |
| Peak memory (MB) | 58.7 [58.7, 60.4, 58.4] | 54.6 [54.7, 53.9, 54.6] | +7 % | 56.5 |
| App size (MB, binary) | 0.80 | 0.84 | -5 % | 0.80 |

## Agent facts

Wall 2,737 s, 85 turns, 21 builds (0 failed), 0 commits, exit 0, not stopped by the limit; 15.1 M input tokens including cache, 138 k output, $7.83. Skill files read: `SKILL.md` through the Skill call only (there are no other files). Simulators: only `uvs-r3-a` and `uvs-r3-b` were booted.

## What this changes

1. thin3 keeps all of thin2's row results at 621 words, so the cut group did no harm to the screen.
2. The one open question is agent time. Next: a second Opus thin3 build only if Fernando wants the noise measured; the Sol build (E23) tests thin3 on the model whose miss is also wall time.
