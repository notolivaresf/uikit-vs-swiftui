<h1 align="center">UIKit vs SwiftUI</h1>

<p align="center">One Campfire chat room, built twice, in UIKit and in SwiftUI, by AI models.<br>
Started after 37signals moved <a href="https://once.com">ONCE</a> off Rails.</p>

## Results

**Four builds of the same chat screen, one phone, real numbers: only one passes everything.**

- Only **sol-uikit** passes every behaviour. The other three each fail at least one.
- Text selection fails in 3 of 4 builds; the two SwiftUI builds also fail the stack rule (both use UIKit's UIPasteboard).
- sol-swiftui could not keep up with the live stream: about 450 of 600 messages shown after 60 s. The other three finished it, at 22.6 to 27.8 fps.

Level 1, iPhone 12, one round per build. Green = pass, red = fail, yellow = not measurable or not measured; the best number in a row is bold with a dark outline.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/results-dark.png">
  <img src="docs/images/results.png" alt="Results table: four builds (opus-uikit, opus-swiftui, sol-uikit, sol-swiftui) across behaviour and performance checks. Only sol-uikit passes everything.">
</picture>

<details><summary>Table as text</summary>

| | opus-uikit | opus-swiftui | sol-uikit | sol-swiftui |
|---|---|---|---|---|
| **Passes everything** | Fail (1 fail) | Fail (2 fails, 1 not measurable) | Pass | Fail (3 fails) |
| **First 40 rows (cold)** | Pass, 172 ms (best) | Pass, 174 ms | Pass, 201 ms | Pass, 354 ms |
| **Fling** | Pass, 58.5 fps, 2 hitches (best) | Pass, 57.9 fps, 24 hitches | Pass, 58.3 fps, 2 hitches | Pass, 58.3 fps, 2 hitches |
| **Live stream, 600 messages** | Pass, 25.7 fps, 1 hitch | Pass, 22.6 fps, 25 hitches | Pass, 27.8 fps, 2 hitches (best) | Fail, about 450 of 600 shown |
| **Jump to message 2,500** | Pass, 52 ms (best) | Pass, 85 ms | Pass, 73 ms | Pass, 210 ms |
| **Load older** | Pass, 77 ms, drift 0.3 pt | Not measurable, 25 ms, drift unreadable | Pass, 61 ms, drift 0.0 pt (best) | Pass, 133 ms, drift 0.0 pt |
| **Peak memory** | 43.9 MB | 69.7 MB | 39.7 MB (best) | Not measured |
| **Text selection** | Fail | Fail | Pass | Fail |
| **Stack rule** | Pass | Fail (UIPasteboard) | Pass | Fail (UIPasteboard) |

</details>

### Best of UIKit vs best of SwiftUI

Each stack's best build per row (the build it came from is the grey line), so no single app does all of it. The winner of a row is bold and outlined; a tie marks neither.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/results-best-dark.png">
  <img src="docs/images/results-best.png" alt="Best UIKit build against best SwiftUI build per row. UIKit wins every row; SwiftUI never passes everything.">
</picture>

<details><summary>Table as text</summary>

| | UIKit (best build) | SwiftUI (best build) |
|---|---|---|
| **Passes everything** | Pass (sol-uikit) (winner) | None passes (closest: opus-swiftui, 2 fails) |
| **First 40 rows (cold)** | 172 ms (opus-uikit) (winner) | 174 ms (opus-swiftui) |
| **Fling** | 58.5 fps, 2 hitches (opus-uikit) (winner) | 58.3 fps, 2 hitches (sol-swiftui) |
| **Live stream, 600 messages** | 27.8 fps (sol-uikit) (winner) | 22.6 fps (opus-swiftui) |
| **Jump to message 2,500** | 52 ms (opus-uikit) (winner) | 85 ms (opus-swiftui) |
| **Load older** | 61 ms (sol-uikit) (winner) | 133 ms (sol-swiftui) |
| **Peak memory** | 39.7 MB (sol-uikit) (winner) | 69.7 MB (opus-swiftui) |
| **Text selection** | Pass (sol-uikit) (winner) | Fail (both builds) |
| **Stack rule** | Pass (both builds) (winner) | Fail (both builds) |

</details>

Full numbers and notes: [`docs/results-l1.md`](docs/results-l1.md). The builds are in [`builds/`](builds). These results describe this app and these models, not UIKit vs SwiftUI in general. One round per build, so there is no spread between rounds.

<p align="center"><img src="docs/images/room-top-light.png" alt="The top of the room in each build, light"></p>

*Every column shows the same Campfire data; sol-swiftui can't reach the top, because it keeps 300 messages loaded and Load older stops at message 2,220.*

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

## Credit

Campfire's design is (c) 37signals, MIT: [basecamp/once-campfire](https://github.com/basecamp/once-campfire). No Campfire code is copied here.

MIT licensed, see [LICENSE](LICENSE).
