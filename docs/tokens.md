# Recording tokens

The second half of the experiment is how many tokens, turns and minutes each model needs to build the same screen in UIKit and in SwiftUI. Each build is one run in an empty folder with no memory and the same prompt (`PROMPT.md`).

## Three levels

Each level is a fresh session that starts from the committed result of the one before, so context sizes stay comparable.

- L1: the app builds and shows the messages.
- L2: it passes the behaviour tests, including layout within 2 pt of every screenshot.
- L3: performance work, with the same optimisation budget for both stacks.

## What we record per run

| Field | Meaning |
|---|---|
| model, stack, level | for example Opus 5.5, UIKit, L2 |
| input, cached input, cache writes, output tokens | summed from the session's usage records, each API message counted once |
| turns | assistant messages |
| active and idle time | gaps over 20 minutes count as idle |
| builds, failed builds | build commands run, and how many failed |
| commits | commits in the run |
| lines of code | of the stack's source at the last commit |
| benchmark medians | harness results after L3 |

Dollar cost is worked out afterwards from published per-model prices. "Done" is decided by a separate checker running the tests and the harness, never by the run's own summary. Results go in `runs/`, one folder per build.
