# Round 3 preparation: hand-off (20 Oct)

State of the work, for whoever picks it up. The plan itself is [round3-plan.md](round3-plan.md).

## Done

- `./bench` (simulator pass, `--build`, `--device`, `--device-full`), the broker, the simulators, locks with timing-code pins, setup, baseline, launch (dry run), audit. All in `Harness/` (`bench*`, `sims.py`, `lockcheck.py`, `scorecard.py`, `round3-*`).
- `prompts/round3.md`, filled per build by `round3_prompt.py` from `.bench/baseline.json`.
- `run_build.py --time-limit-s` (3 h stop for both tools).

## Not done / not verified

- Only `uikit-swift-opus` has been set up and measured (one baseline run) in `~/uvs-builds/round3-uikit-swift-opus`. The other five: `Harness/round3-setup.sh <build> --sim a|b`, then `Harness/round3-baseline.sh <build>` for each build of a pair just before it starts. Earlier folders from a first design (iPhone-only) were moved to `~/uvs-builds/round3-old/`; they can be swept.
- The broker has not served a request from inside a sandbox yet. Test: `Harness/bench-broker.py --once` in one terminal, `./bench --build` from `codex sandbox -P r3 -- ./bench --build` in the other (profile in `round3-launch.sh --dry-run` output).
- The Claude sandbox settings and the Codex domain rules are untested (they need an agent); see the plan.
- `round3-launch.sh --dry-run` has not been run for every build; the real launch path was never run.
- The iPhone 12 was offline in xctrace the whole time. `--device`, `--device-full` and the `record.sh --quick` device path are untested, and so is the Round 2 re-measure (dropped by Fernando).
- **The one baseline run (uikit-swift-opus, 20 Oct 19:57) produced no scorecard.** It was aborted by my own edit: I changed `Harness/bench-inner.sh` (added the `build` mode) while bash was still reading it, which broke the running script ("syntax error near unexpected token `('"). Before that point the Release simulator build and the harness test build had run (about 9.5 min in all, mostly the first-time build of the test bundle); the suites were mid-way (the log showed testJumpTo2500 passing in 18 s and testLiveStream running). The script parses fine now. So there is **no measured timing, no baseline, and no proof yet that the suites finish and `summarize.py`/`scorecard.py --sim` read a simulator run**. `.bench/baseline.json` does not exist, so that folder's prompt still has the placeholder scorecard.

## Next steps, in order

1. `Harness/round3-baseline.sh uikit-swift-opus --runs 1` (do not edit anything in `Harness/` while it runs). Read `~/uvs-builds/round3-uikit-swift-opus/.bench-work/sim-*/scorecard.txt`; fix whatever `summarize.py` misses on a simulator (memory and CPU metrics are the likely gaps; the scorecard prints "-" for a missing value). Fill in "Timing" in the plan.
2. In one terminal `Harness/bench-broker.py`; in another, from the folder: `codex sandbox -P r3 -- ./bench --build` (profile from `round3-launch.sh --dry-run`, sol build) to prove the broker path from inside a sandbox.
3. Set up the other five builds (`round3-setup.sh <build> --sim a|b`; pairs in the plan), run `round3-baseline.sh` for both builds of a pair just before it starts, then `round3-launch.sh <build> --dry-run` for each.
4. Fernando starts the pairs. After each run: `round3-audit.py`, lockcheck against the outside copy, `check-stack.sh`.

## Commits

edbf421 (bench, scorecard, locks, setup, prompt template), 9901bf2 (simulator design: client, broker, sims, baseline, launch, audit, plan), and this hand-off. Old repo scripts (`screens*.sh`) no longer carry the phone's ids; they still appear in git history before 9901bf2.
