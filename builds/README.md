# Builds

The four builds measured in [`docs/results-l1.md`](../docs/results-l1.md). Each is committed exactly as the model left it: no code was changed here. Each build's own `.git` folder is not included; its final commit is listed instead. Build output (`DerivedData`, `build/`, `.build/`, `*.xcresult`, `xcuserdata`) is left out.

| Folder | Model | Stack | Source commit |
|---|---|---|---|
| [`opus-uikit`](opus-uikit) | Opus | UIKit | `c0e6bb088f3e111cae11913a9042b5740d8e08c1` |
| [`opus-swiftui`](opus-swiftui) | Opus | SwiftUI | `daf271b6fc36dcc7a92eea242d36d3b032d2dbba` |
| [`sol-uikit`](sol-uikit) | Sol | UIKit | `9131ccaf114d8df79f9d9bbc136eff39ee815d04` |
| [`sol-swiftui`](sol-swiftui) | Sol | SwiftUI | `795a82f550d8a3f7fd821d0574ac0451d2c4698a` |

Three of the source commits (opus-uikit, sol-uikit, sol-swiftui) were made by the harness operator to save the model's uncommitted work at exit.

Transcripts are not kept in this repo.
