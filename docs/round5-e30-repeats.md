# Round 5, E30 repeats: Sol + thin6 (`v0.11.6-thin6`) three times

Linked from `docs/round5-e30-results.md`. Same launch, scoring and stopwatch method as E30, suffixes `-e30b` and `-e30c`, run one at a time. Launch: `UVS_CHATLIST_TAG=v0.11.6-thin6 UVS_NAME_SUFFIX=-e30b UVS_TIME_LIMIT_S=7200 Harness/launch-build.sh sol uikit --skills ours-chatlist`. Scoring: stack check, Release simulator build, three `record.sh --sim` passes on `uvs-r3-a`, `scorecard.py --sim`, then the stopwatch (three passes, build and Sol control alternating). Raw data: `runs/sol-uikit-ours-chatlist-e30b/` (and `-e30c`), stopwatch in `runs/stopwatch-r5/e30b-thin6/`, `e30b-control-sol/` (and e30c).

## E30b (28 Oct, 02:29 to 03:07 UTC)

- Checks 13, 13, 13. Stack rule ok.
- Wall 2,282 s (meta), 101 turns, 21 builds (9 failed), 0 commits, exit 0, not stopped by the limit. 77.6 k output tokens.
- Model speed 38.0 tokens per second (E30 45.8; controls median 54.0); waiting on commands 236 s. Corrected to 54.0: about 1,674 s.
- Stopwatch medians (ms) build [passes] against control [passes]: jump 26.7 [26.7, 28.3, 26.7] / 33.3; load older 6.7 [10.0, 6.7, 5.0] / 31.7; text bottom 23.3 [23.3, 23.3, 21.7] / 18.3; text mid 23.3 [25.0, 23.3, 23.3] / 30.0.
