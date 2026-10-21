# Round 3 preparation: hand-off (20 Oct)

State of the work, for whoever picks it up. The plan itself is [round3-plan.md](round3-plan.md).

## Done

- `./bench` (simulator pass, `--build`, `--device`, `--device-full`), the broker, the simulators, locks with timing-code pins, setup, baseline, launch (dry run), audit. All in `Harness/` (`bench*`, `sims.py`, `lockcheck.py`, `scorecard.py`, `round3-*`).
- `prompts/round3.md`, filled per build by `round3_prompt.py` from `.bench/baseline.json`.
- `run_build.py --time-limit-s` (3 h stop for both tools).

## Status (20 Oct, evening)

- Measured: uikit-swift-opus baseline (1 run) and a second `./bench --direct` pass. All nine scorecard rows and all 13 checks read on the simulator, memory included; nothing was missing in summarize.py or scorecard.py. Baseline: first 40 cold 206 ms, repeated 657 ms, stream CPU 7.7 s, jump 60 ms, load older 62 ms, text size bottom 50 ms, mid 70 ms, peak memory 118.8 MB, app size 1.34 MB, 13 of 13 checks. The second pass (same code) gave 209 / 660 / 7.9 / 56 / 66 / 49 / 64 / 119.7 MB: about 1 to 10 percent noise per row, so a gain smaller than that is not proof.
- Time: a full `./bench` pass took 9 min 6 s with the test bundle already built (the first one, with its first-time build, about 9.5 min for the baseline command). Broker `./bench --build` takes about 12 s. Two agents at once queue behind each other in the broker, so an agent waits up to one extra pass per request.
- Broker from inside a sandbox: tested and works. `bench-broker.py --once` exits at once if nothing is queued, so start the sandboxed `./bench --build` first, then the broker. Under `codex sandbox -P r3` (profile from the launch output) in round3-uikit-swift-sol the request was queued, served and returned "BUILD OK (Release, simulator)", "Stack rule (uikit): ok", exit 0, in 12 s. `ls` of `~/olivares-burgos` from inside it: "Operation not permitted". The Claude sandbox settings could not be tested without starting an agent session.
- Pair 1 is set up and has a 1-run baseline (not 3, for speed): swiftui-sol on simulator a (11 of 13 checks; fails the stack rule on `import class UIKit.UIPasteboard` in MessageRow.swift, and text selection) and uikit-swift-sol on simulator b (12 of 13; fails text selection). `round3-launch.sh <build> --dry-run` was run for both; the prompts read right (stack line, failed-check wording, no framework hints, no best-seen numbers). Other four builds (uikit-swift-opus is set up with a baseline; swiftui-opus, uikit-objc-sol, uikit-objc-opus are not): see below.

## Start pair 1 (Fernando)

Baselines are 1 run each, taken 20 Oct about 20:30 to 20:50. If the pair starts much later, or you want more stable numbers, redo them (3 runs is the default, about 55 min for both; `--runs 1` is about 20 min):

```
cd ~/olivares-burgos/uikit-vs-swiftui-repo
Harness/round3-baseline.sh swiftui-sol --runs 1
Harness/round3-baseline.sh uikit-swift-sol --runs 1
```

Then, with nothing else booting simulators (both slots are used):

```
Harness/bench-broker.py                          # terminal 1, leave running
Harness/round3-launch.sh swiftui-sol             # terminal 2
Harness/round3-launch.sh uikit-swift-sol         # terminal 3
```

Each agent runs 3 hours. After each: `Harness/round3-audit.py runs/round3-<build>/transcript.jsonl ~/uvs-builds/round3-<build>`, lockcheck against `~/uvs-builds/.locks/`, `Harness/check-stack.sh`. Check the first lines of each transcript for sandbox refusals (Claude settings are untested; the Sol profile is).

## Not done / not verified

- Pair 2 (swiftui-opus + uikit-swift-opus): uikit-swift-opus is set up and measured; swiftui-opus is not (`Harness/round3-setup.sh swiftui-opus --sim b`, then baselines just before the pair starts). Pair 3 (uikit-objc-sol, uikit-objc-opus): not set up (`--sim a` and `--sim b`).
- A quicker default pass is proposed in the plan (see "Timing"); not built.
- Domain rules (github deny) and the Claude sandbox settings are untested (need an agent). The iPhone 12 was offline: `--device`, `--device-full` untested.
- Earlier folders in `~/uvs-builds/round3-old/` can be swept.

## Commits

edbf421, 9901bf2, and this lane's commits (see git log).
