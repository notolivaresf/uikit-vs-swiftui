# Recording time per run

Besides how the apps perform, we record how long each model takes to build the same screen in UIKit and in SwiftUI. Each build is one run in an empty folder with no memory and the same prompt (`PROMPT.md`), at high reasoning effort for both models.

## Three levels

Each level is a fresh session that starts from the committed result of the one before.

- L1: the app builds and shows the messages.
- L2: it passes the behaviour tests, including layout within 2 pt of every screenshot.
- L3: performance work, with the same optimisation budget for both stacks.

## What we record per run

All of it is read from the run's session transcript, never from the run's own summary.

| Field | How |
|---|---|
| model, stack, level | for example Opus 5.5, UIKit, L2 |
| build time per level | wall time from the first to the last timestamp of the level's session; gaps over 20 minutes count as idle and are reported separately |
| turns | number of assistant messages |
| failed builds | build commands (xcodebuild, swift build) whose result was an error, next to the total number of builds |
| commits | commits in the run |
| benchmark results | harness results after L3 (see `harness.md`) |

"Done" is decided by a separate checker running the tests and the harness. Results go in `runs/`, one folder per build.
