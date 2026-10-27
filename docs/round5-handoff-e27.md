# Round 5 hand-off: E27, the Sol build with thin4

Written 27 Oct after E26. Nothing for E27 has been started.

## State

- Skill: `uikit-chat-list` tag `v0.11.4-thin4` (private skill repo, branch `thin4`, commit `5fd6ca8`). It adds two sentences to thin3: Copy needs no pasteboard check from a UI test, and `xcodebuild test` runs per test with `-test-timeouts-enabled YES -default-test-execution-time-allowance 60`. Why: `docs/thinning-plan.md`, section "Agent time", in the skill repo.
- E26 (Opus, thin4): passes all three bars, wall 1,546 s (bar 2,454 s), 13 of 13, every row level or better than the control. `docs/round5-e26-results.md`.
- The pin `CHATLIST_TAG` in `Harness/skillset.py` is still `v0.11.2-thin2`; runs pass the tag with `UVS_CHATLIST_TAG`.

## E27: what to run

Same method as E23 (`docs/round5-e23-results.md`), one thing at a time:

1. Check Codex quota with `codex-pace` before the launch.
2. Dry run, then the launch in the background (wait with `caffeinate -w <pid>` via `run_in_background`, never a sleep loop):
   `UVS_CHATLIST_TAG=v0.11.4-thin4 UVS_NAME_SUFFIX=-thin4 UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`
3. Stack check, Release simulator build, three scored passes on `uvs-r3-b`, median, and the Sol control re-measured in the same sitting (`Harness/round3-baseline.sh uikit-swift-sol --runs 3`), as in E23.
4. Write `docs/round5-e27-results.md` like E23's, including the phase table (Sol bar: 1,356 s; E23 thin3 2,366 s, E21 thin2 1,593 s, E25 no skill 1,954 s).

## What to watch

- Sol's extra time in E23 was visual matching (a rendering test against the given screenshots, pixel study, fetching icons from the web), not the hung-test detour; thin4 does not address it. If E27 still misses wall time, the phase table will say whether it is the same visual work again.
- Sol runs commands side by side: a test run that never ends costs it less idle time than it costs Opus (E25 had two, both overlapped other work).
- The E25 Sol agent deleted and created its own simulator (`simctl delete` inside the build). Check `simcap status` before the launch and shut down any leftover (never delete or erase one).
