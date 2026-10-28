# The Experiment

## Round 5: a thinned chat-list skill

A UIKit chat-list skill cut from 2,962 to 826 words and frozen at v1.0.0, scored against same-sitting controls with Sol and Opus. Write-up: [Round 5 summary](docs/round5-summary.md).

## Round 3: three hours to optimise

Each of the six Round 2 builds went back to its agent for three hours to get faster and smaller. Write-up: [Round 3](docs/results-round3.md).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/results-round3-best-dark.png">
  <img src="docs/images/results-round3-best.png" alt="Round 3: best of UIKit (Swift or Objective-C, Opus or Sol) against best of SwiftUI, row by row, each cell naming its source build. UIKit wins 5 rows (cold first rows, stream CPU, load older, peak memory, app size), SwiftUI 2 (jump to message 2,500, text size at the bottom), and 4 rows are ties.">
</picture>

## Level 2 again with third-party skills

The two Level 2 SwiftUI builds were rerun with the skill set by Antoine van der Lee (@twannl on X) instead of Apple's. It beats Apple's skills on 6 of 9 rows, but the best UIKit build still wins all 9. Write-up and the other two charts: [Charts (iPhone 12)](docs/results-l2-avdlee.md#charts-iphone-12).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/results-uikit-vs-swiftui-skills-dark.png">
  <img src="docs/images/results-uikit-vs-swiftui-skills.png" alt="Best UIKit build against SwiftUI with Apple's skills and SwiftUI with @twannl's skills, per row. Best UIKit wins all 9 rows; SwiftUI with either skill set wins none outright.">
</picture>

## Round 2: one prompt with skills

The same chat room built six times with a skill installed, by Opus and by Sol. Write-up: [Round 2](docs/results-round2.md).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/results-round2-best-dark.png">
  <img src="docs/images/results-round2-best.png" alt="Round 2: best of UIKit (Swift or Objective-C, Opus or Sol) against best of SwiftUI, row by row, each cell naming its source build. Colour shows the winner of each row; UIKit wins 11 rows, SwiftUI 1, fling and one more row are ties.">
</picture>

## Round 1: no skills

The same chat room built four times with no skills, by Opus and by Sol. Write-up: [Round 1](docs/results-round1.md).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/results-round1-best-dark.png">
  <img src="docs/images/results-round1-best.png" alt="Round 1: best UIKit build against best SwiftUI build per row. Colour shows the winner of each row; two rows are near ties.">
</picture>

## What this is

We are experimenting with coding agents (Opus and Sol). Each one builds the same [Campfire](https://github.com/basecamp/once-campfire) chat room in UIKit and in SwiftUI, and we measure what they produce. The builds are in [`builds/`](builds) and the benchmark harness is described in [`docs/harness.md`](docs/harness.md).
