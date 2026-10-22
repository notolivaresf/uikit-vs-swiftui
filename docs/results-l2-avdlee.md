# Level 2, SwiftUI: Apple skills against third-party skills (AvdLee)

Fernando, 21 Oct: run the two Level 2 SwiftUI builds again, Opus and Sol, with only the skill of [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill): "comparable to the experiment that we did with Apple's skills but these are third party skills". Everything is as in the Level 2 Apple-skill builds (same prompt, stack line, skill sentence, inputs, CampfireKit, fixtures, model, effort, flags, Codex config) except the skill set. The UIKit and Objective-C builds are not part of this.

| Arm | Skills installed | Builds |
|---|---|---|
| Apple skills | `swiftui-specialist`, `swiftui-whats-new-27` (Xcode 27.0 RC, not vendored) | `opus-swiftui-apple`, `sol-swiftui-apple` (Round 2, 19 Oct) |
| third-party skills (AvdLee) | `swiftui-expert-skill` 5.2.1, commit `204dba7`, MIT (vendored in `skills/avdlee/`) | `opus-swiftui-avdlee`, `sol-swiftui-avdlee` (21 Oct) |

Setup, hashes and the isolation probe: `docs/harness.md` ("Level 2, third-party skills: AvdLee") and `skills/README.md`. In short: the Opus init event listed `swiftui-expert-skill` and nothing else (no MCP servers), Sol's Codex config is the same file as Level 2's (24 host skills off) and Sol named only `swiftui-expert-skill`. Inputs are tag `v2-inputs`, as for the Apple arm; tag `v2-avdlee-inputs` marks the harness commit.

## Simulator scorecard

The full `./bench` pass of Round 3 (Release build, iPhone 17 simulator, iOS 26.4, nothing else booted): nine measures, app size and the 13 checks. All four builds were scored the same evening, one at a time, twice (the second pass in reverse order), from a copy of each build's working folder as its model left it (`Harness/l2-score-setup.sh`). Cells read "pass 1 / pass 2". Lower is better in every row. Simulator times are not phone times: compare builds with each other here, not with the iPhone 12 numbers below.

| | opus-swiftui-apple | opus-swiftui-avdlee | sol-swiftui-apple | sol-swiftui-avdlee |
|---|---|---|---|---|
| Model, skills | Opus, Apple skills | Opus, third-party skills (AvdLee) | Sol, Apple skills | Sol, third-party skills (AvdLee) |
| First 40 rows, cold | 284 / 273 ms | 270 / 253 ms | 556 / 371 ms | 240 / 255 ms |
| First 40 rows, repeated | 788 / 789 ms | 778 / 766 ms | 872 / 861 ms | 712 / 695 ms |
| Stream CPU | 31.2 / 30.3 s | **10.0 / 10.3 s** | 19.8 / 20.0 s | 13.7 / 13.7 s |
| Jump to message 2,500 | 132 / 132 ms | **48 / 48 ms** | 174 / 174 ms | 112 / 113 ms |
| Load older | 59 / 62 ms | 76 / 76 ms | 108 / 107 ms | 59 / 60 ms |
| Text size, at the bottom | 55 / 58 ms | 40 / 39 ms | 89 / 90 ms | 38 / 38 ms |
| Text size, mid-list | 79 / 80 ms | 82 / 91 ms | 110 / 111 ms | 55 / 56 ms |
| Peak memory (during the stream) | 201.3 / 201.3 MB | **65.3 / 65.1 MB** | 95.8 / 95.7 MB | 75.5 / 75.3 MB |
| App size (Release simulator .app) | 2.88 MB | 2.95 MB | 2.28 MB | 3.99 MB |
| Checks passed | 11 of 13 | 11 of 13 | 11 of 13 | 11 of 13 |
| Failed: stack rule | `RowParts.swift` imports UIKit for UIPasteboard | `MessageRow.swift` uses `UIPasteboard` (under `#if canImport(UIKit)`) | `MessageRow.swift` imports `UIKit.UIPasteboard` | `MessageRow.swift` and `RangeSelectionOverlay.swift` import UIKit for UIPasteboard |
| Failed: text selection | yes | yes (adds a "Select Text" sheet; the system selection menu does not appear on the row) | yes | yes (a TextEditor selection overlay; same) |

All other checks pass in all four: first content, jump and load-older drift, the 600 stream messages arriving and staying pinned, text size pinned and drift, rotation pinned and drift, boost burst pinned, context menu.

The first pass ran with the stack rule wrongly passing (the scoring copies had no git repo, so `check-stack.sh` saw no files; fixed in `l2-score-setup.sh` before pass 2). Its measures are unaffected; the stack rule was re-checked by hand on all four and fails in all four, as in pass 2. The Apple builds' numbers agree with their Round 3 simulator baselines of 20 Oct (opus: 785 ms repeated, 30.7 s stream CPU, 133 ms jump, 200.5 MB; sol: within a few percent), apart from the noisy cold launch.

## The Apple-skill builds on the iPhone 12 (Round 2)

From `docs/results-round2.md` (iPhone 12, iOS 26.0, full Instruments pass). The third-party builds have not been on the phone yet; that pass is Fernando's, afterwards.

| | round2-swiftui-opus (opus-swiftui-apple) | round2-swiftui-sol (sol-swiftui-apple) |
|---|---|---|
| First content | 326 ms cold, 329 ms repeated | 314 ms cold, 408 ms repeated |
| Fling | 57.9 fps, 5 hitches | 58.0 fps, 0 hitches |
| Jump to 2500 | 154 ms, drift 0.0 pt | 191 ms, drift 0.1 pt |
| Load older | 86 ms, drift 0.2 pt | 143 ms, drift 0.1 pt |
| Stream | 600, pinned; 425 hitches (13.9 s); CPU 34.8 s | 600, pinned; 242 hitches (4.9 s); CPU 22.1 s |
| Text size | 76 / 108 ms | 123 / 139 ms |
| Peak memory (heavy session) | 215.4 MB | 103.4 MB |
| App size (Release device .app) | 1.50 MB | 1.20 MB |
| Fails | stack rule, text selection | stack rule, text selection |

## Agent cost

Read from each run's transcript and `meta.json`, the same way for both arms. Opus tokens and cost are the transcript's final result line; Sol tokens are the sum of Codex's per-turn usage (Codex reports no cost).

| | opus-swiftui-apple | opus-swiftui-avdlee | sol-swiftui-apple | sol-swiftui-avdlee |
|---|---|---|---|---|
| Wall time | 4301 s (1 h 12 min) | **18447 s (5 h 7 min)** | 1209 s (20 min) | 5785 s (1 h 36 min) |
| Turns | 197 | 274 | 113 | 146 |
| Builds (failed) | 24 (0) | 56 (4) | 15 (8) | 31 (13) |
| Commits | 2 | 7 | 0 | 0 |
| Idle gaps over 20 min | 0 | 0 | 0 | 0 |
| Output tokens | 222,327 | 311,170 | 57,387 (27,624 reasoning) | 223,959 (171,267 reasoning) |
| Input tokens | 394 new, 425,121 cache write, 55.4 M cache read | 548 new, 579,670 cache write, 95.7 M cache read | 12.05 M (11.86 M cached) | 26.07 M (25.65 M cached) |
| Cost (Claude's own figure) | $18.93 | $29.99 | n/a | n/a |
| CLI | Claude Code 2.1.299 | Claude Code 2.1.306 | codex-cli 0.162.1 | codex-cli 0.162.1 |

## What it shows (simulator only)

- The third-party skill fixed none of the two failures: all four builds use UIKit's UIPasteboard for Copy and none gives the system text-selection menu. Both third-party builds tried harder at selection (a Select Text sheet, a TextEditor overlay), and both still fail the check.
- On the numbers it is the better skill for both models. Opus with it: stream CPU 31 → 10 s, peak memory 201 → 65 MB, jump 132 → 48 ms, text size at the bottom 57 → 40 ms; load older is slower (61 → 76 ms) and mid-list text size about the same. Sol with it: every timing row is better (cold 464 → 248 ms on average, stream CPU 20 → 14 s, jump 174 → 113 ms, load older 108 → 60 ms, text size 90/111 → 38/56 ms) and memory 96 → 75 MB; its app is bigger (2.28 → 3.99 MB).
- It costs more agent time: Opus ran 4.3 times as long (5 h 7 min, $30 against $19, 1.4 times the output tokens) and Sol 4.8 times as long (3.9 times the output tokens, most of it reasoning); both ran about twice as many builds.
- Whether the stream stutter of the Apple builds (425 and 242 hitches on the phone) is gone can only be seen on the iPhone 12: the simulator does not measure hitches or frame rate.

## Audit

`Harness/round3-audit.py` on both transcripts: Opus ran `git log` on its own one-commit input repo (the only flag); Sol ran one `rg --files -g AGENTS.md` over the parent builds folder, which found nothing, and read no file of another build. Both read only their own copy of `swiftui-expert-skill`. Neither run had a read fence, as in Level 2 (see `docs/harness.md`).
