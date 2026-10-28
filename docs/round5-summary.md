# Round 5 summary: a chat-list skill, thinned to 826 words and frozen at v1.0.0

Round 5 asked how small a skill for one job (a UIKit chat list) can get before the builds get worse. The skill was cut step by step, and each version was built by agents and scored the same way: 13 checks, the app's own timings, and a stopwatch on four rows, always against a control built in the same sitting. On 28 Oct the last version tested, thin7, was frozen as `v1.0.0` (private skill repo, tag `v1.0.0`; the harness pins it in `Harness/skillset.py`). A further trim, thin8, was started and dropped unscored. The skill's text is not in this repo.

## The journey in words

Words in the whole skill folder (SKILL.md plus references), counted with `wc -w` at each git tag. Source: `docs/thinning-plan.md` in the skill repo.

| Version | Words in the skill folder |
|---|---|
| v0.6.2 (starting skill) | 2,962 |
| v0.9.0 | 3,023 |
| v0.10.0 | 2,765 |
| thin (v0.11.0) | 1,523 |
| thin-timer, thin2 | 1,531, 1,533 |
| thin3 (extra files cut) | 621 |
| thin4 | 677 |
| thin5 | 721 |
| thin6 | 730 |
| **thin7 (v1.0.0)** | **826** |

The big drop came from cutting what the builds never used (a reviewer agent that never ran, reference files opened in none or one of the builds). After thin3, the small additions each fixed a measured problem, so the count crept back up from 621 to 826.

## Sol: thin7 against the same-morning control

Sol is the OpenAI agent. thin7 was built three times (e31a, b, c); the control (the same task with the earlier general skill, `ctl28b`) was built right after, at the same service speed. Details: `docs/round5-e31-thin7.md`.

| | thin7, median of three | Control ctl28b |
|---|---|---|
| Checks (13 possible) | 13 | 12 (the long-press menu fails) |
| Wall, raw | 1,597 s | 2,524 s (thin7 is 37 % faster) |
| Wall, corrected to a common model speed | 1,200 s | 1,712 s (30 % faster) |
| Output tokens | 55.9k | 77.0k |
| Turns | 68 | 84 |

Stopwatch medians in the same sitting (ms, lower is faster), thin7 against the Sol control build measured alongside it:

| Row | thin7 | Control |
|---|---|---|
| Jump to message 2,500 | 18.3 | 35.0 |
| Load older | 16.7 | 33.3 |
| Text size at the bottom | 20.0 | 20.0 |
| Text size mid-list | 21.7 | 28.3 |

The ctl28b build itself read 65.0, 46.7, 25.0 and 40.0 ms on those rows. One bar was missed: raw wall against the old 1,491 s target (1,597 s), which the corrected wall passes. A control run at the same speed took 2,524 s, so a slow morning does not explain the gap.

## Opus: e32 against earlier Opus builds and the Opus control

One Opus build with thin7 (`docs/round5-e32-opus-thin7.md`).

| Run | Checks | Wall | Turns | Output tokens | Corrected wall |
|---|---|---|---|---|---|
| v09 (27 Oct) | 13 | 2,115 s | 62 | 147.2k | 1,936 s |
| v09b | 13 | 2,221 s | 62 | 130.4k | 1,715 s |
| thin4 (E26) | 13 | 1,546 s | 46 | 121.0k | 1,591 s |
| thin4b (E28) | 13 | 1,807 s | 72 | 136.8k | 1,806 s |
| Opus control (19 Oct) | 13 | 2,231 s | 95 | 169.4k | 2,236 s |
| **e32 (thin7)** | **13, 13, 13** | **2,108 s** | **55** | **108.3k** | **1,427 s** |

e32 used the fewest tokens of any Opus build, had no failed build, and was fastest once corrected. Its raw wall was not the fastest because the model ran at 51.6 tokens per second, the slowest Opus speed in the table. Stopwatch (ms) against the Opus control in the same sitting: jump 23.3 against 33.3, load older 5.0 against 18.3, text bottom 21.7 against 18.3, text mid-list 25.0 against 23.3. No row is slower than the allowance (the larger of 10 % or 17 ms). One Opus build is one sample.

## Lessons

- **Three sentences made Sol run the same tests again and again.** Rules written as "the screen must do X" read to Sol like a test list: one test per rule, then the whole suite rerun after each change. That cost 600 to 1,250 s of model time per build. The fix (thin6, thin7) was a line saying the rules are not a test list, plus "rerun only the failed tests". In the thin7 builds, test commands fell to 6 to 8 per build and the repeated live-stream test rerun disappeared.
- **Downloads.** Sol sometimes searched the web and downloaded image assets and icons. One sentence about using system symbols ended it: none of the three thin7 builds downloaded anything. The control still did.
- **Model speed varies, so always run a same-sitting control.** Output ran from 32.9 to 54 tokens per second across the same week for the same model. Raw wall time alone ranged by half. Only a control built in the same sitting, or a time corrected to one speed, tells you whether a change helped.
- **Never run two jobs on one simulator.** Two jobs at once left it in a stuck recording state and cost two stopwatch attempts.
- **Stop at a good version.** thin8 would have trimmed a few more words; thin7 already had every stopwatch row at or ahead of the control, so the trim was dropped.
