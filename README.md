<h1 align="center">UIKit vs SwiftUI</h1>

<p align="center">One Campfire chat room, built twice, in UIKit and in SwiftUI, by AI models.<br>
Started after 37signals moved <a href="https://once.com">ONCE</a> off Rails.</p>

<table align="center"><tr>
<td><img src="screenshots/room-bottom.png" width="300" alt="Room, light"></td>
<td><img src="screenshots/room-bottom-dark.png" width="300" alt="Room, dark"></td>
</tr></table>

## How it works

- **One prompt.** [`PROMPT.md`](PROMPT.md) asks for a single iPhone chat room copied 1:1 from the screenshots in [`screenshots/`](screenshots), light and dark, within 2 pt of [`Fixtures/constants.json`](Fixtures/constants.json).
- **One shared package.** [`CampfireKit`](CampfireKit) makes 50 people and 50,000 messages from a fixed seed, pages of 40, the threading rule and a live stream of 20 messages a second. Foundation only, so it is neutral.
- **Frozen inputs.** Prompt, package, fixtures and screenshots do not change once runs start.
- **Clean runs.** Each build starts in an empty folder with no memory of the others.

## The plan

- **Benchmarks** ([`Harness/`](Harness), [`docs/harness.md`](docs/harness.md)): cold launch, fling scroll, jump to message 2,500, load older, live stream. Frames per second (fps) and hitches for scrolling and the stream, plus CPU and memory; wall time for launch, jump and load older. Three alternating rounds, headline = median.
- **Build time** ([`docs/timing.md`](docs/timing.md)), recorded at three levels: L1 messages show, L2 passes the behaviour tests including layout within 2 pt, L3 performance work. Also turns and failed builds.
- **Fairness:** same prompt, same budget, both models at high reasoning effort, results only for builds that pass.

Models: Opus 5.5 and GPT-6.1 Sol, each in UIKit and SwiftUI. Branches: `build/opus-uikit`, `build/opus-swiftui`, `build/sol-uikit`, `build/sol-swiftui`. Per-build results land in [`runs/`](runs).

## Results

Level 1, iPhone 12, one round per build. Full numbers and notes: [`docs/results-l1.md`](docs/results-l1.md). The builds are in [`builds/`](builds).

| Behaviour | opus-uikit | opus-swiftui | sol-uikit | sol-swiftui |
|---|---|---|---|---|
| Builds and installs | pass | pass | pass | pass |
| Stack rule (no other UI framework) | pass | fail (UIPasteboard) | pass | fail (UIPasteboard) |
| First content under 1 s | pass | pass | pass | pass |
| Fling | pass | pass (24 hitches) | pass | pass |
| Jump to message 2,500 | pass | pass | pass | pass |
| Load older keeps place | pass | not measurable | pass | pass |
| Live stream, 600 messages, pinned | pass | pass | pass | fail (about 450 shown) |
| Text size change | pass | pass | pass | pass |
| Rotation | pass | pass | pass | pass |
| Boost burst | pass | pass | pass | pass |
| Context menu | pass | pass | pass | pass |
| Text selection | fail | fail | pass | fail |

<p align="center"><img src="docs/images/room-top-light.png" alt="The top of the room in each build, light"></p>

*Every column shows the same Campfire data; sol-swiftui can't reach the top, because it keeps 300 messages loaded and Load older stops at message 2,220.*

## Credit

Campfire's design is (c) 37signals, MIT: [basecamp/once-campfire](https://github.com/basecamp/once-campfire). No Campfire code is copied here.

MIT licensed, see [LICENSE](LICENSE).
