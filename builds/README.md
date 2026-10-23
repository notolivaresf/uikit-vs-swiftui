# Builds

The ten builds measured in [`docs/results-round1.md`](../docs/results-round1.md) (Round 1, no skills) and [`docs/results-round2.md`](../docs/results-round2.md) (Round 2, with skills). Each is the app source as the model left it: no code was changed here. Each build's own `.git` folder is not included; its last commit is listed instead. Build output (`DerivedData`, `build/`, `.build/`, `*.xcresult`, `xcuserdata`) is left out, and so are agent skill folders (`.claude/`, `.agents/`).

Folder names read `round<N>-<stack>-<model>`: round 1 is without skills, round 2 with skills.

| Folder | Round | Model | Stack | What it is | Source commit | Run name (in `runs/` and the harness) |
|---|---|---|---|---|---|---|
| [`round1-uikit-swift-opus`](round1-uikit-swift-opus) | 1 | Opus | UIKit (Swift) | No skills | `c0e6bb088f3e111cae11913a9042b5740d8e08c1` | `opus-uikit` |
| [`round1-uikit-swift-sol`](round1-uikit-swift-sol) | 1 | Sol | UIKit (Swift) | No skills | `9131ccaf114d8df79f9d9bbc136eff39ee815d04` | `sol-uikit` |
| [`round1-swiftui-opus`](round1-swiftui-opus) | 1 | Opus | SwiftUI | No skills | `daf271b6fc36dcc7a92eea242d36d3b032d2dbba` | `opus-swiftui` |
| [`round1-swiftui-sol`](round1-swiftui-sol) | 1 | Sol | SwiftUI | No skills | `795a82f550d8a3f7fd821d0574ac0451d2c4698a` | `sol-swiftui` |
| [`round2-uikit-swift-opus`](round2-uikit-swift-opus) | 2 | Opus | UIKit (Swift) | With our UIKit skill pair | `4f635a6d3a8f5a998713a5c0a1cb1b75c08aa47f` | `opus-uikit-ours-pair` |
| [`round2-uikit-swift-sol`](round2-uikit-swift-sol) | 2 | Sol | UIKit (Swift) | With our UIKit skill pair | `e77677a939d22791520259b93df2ecf66c4e837d` | `sol-uikit-ours-pair` |
| [`round2-uikit-objc-opus`](round2-uikit-objc-opus) | 2 | Opus | UIKit (Objective-C) | With our Objective-C UIKit skill pair | `e8c96a5a3e696623942a7d49ff432f0018ce86ed` | `opus-objc-ours-objc-pair` |
| [`round2-uikit-objc-sol`](round2-uikit-objc-sol) | 2 | Sol | UIKit (Objective-C) | With our Objective-C UIKit skill pair | `560c09bf728b6567be6102d64b09eb83d617952d` | `sol-objc-ours-objc-pair` |
| [`round2-swiftui-opus`](round2-swiftui-opus) | 2 | Opus | SwiftUI | With Apple's SwiftUI skills | `09f40f30f752fdc1d363c02f7bfa2e6f06376afa` | `opus-swiftui-apple` |
| [`round2-swiftui-sol`](round2-swiftui-sol) | 2 | Sol | SwiftUI | With Apple's SwiftUI skills | `86dce034f4ea7da66adba0ce0a7992658ade81e8` | `sol-swiftui-apple` |

Several source commits (Round 1: round1-uikit-swift-opus, round1-uikit-swift-sol, round1-swiftui-sol; Round 2: the Sol builds and round2-uikit-swift-opus) are only the harness operator's starting commit or a save of the model's uncommitted work. In those, the app source here is the final working tree, which is newer than the listed commit.

## Skills

The Round 2 UIKit builds used our own skills, which are public in [`skills/`](../skills) and in [notolivaresf/uikit-skill](https://github.com/notolivaresf/uikit-skill). The skills folders the agents had installed are not copied into the builds.

Apple's skills used by the two Round 2 SwiftUI builds are not included in this repo. They come from the [artemnovichkov/xcode-skills](https://github.com/artemnovichkov/xcode-skills) mirror at commit `876d18c` (Apple's Xcode 27.0 release candidate skills).

## Other omissions

- `round2-uikit-objc-sol/Campfire/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1.3 MB) is left out to keep files under 1 MB; the icon is a plain image and does not affect the measurements.
- Transcripts are not kept in this repo.

## Later rounds and Level 2

Added after the first ten. Same rule: the app source as the model left it, no code changed; each build's `.git`, `build/`, `.bench-work/`, agent skill folders, logs and `runs/` are left out. The locked copy of the harness (`.bench/`) is not copied either (the repo's `Harness/` is the source; the `bench` script in each Round 3 build points at it).

Layout: iPhone builds sit directly in `builds/`, named `round<N>-<stack>-<model>`. Mac builds sit in [`mac/`](mac), because they are AppKit or SwiftUI-for-Mac and not UIKit. Level 2 builds (SwiftUI rerun with the AvdLee skill set) are named `level2-<stack>-<skills>-<model>`.

| Folder | Round | Model | Stack | What it is | Run name |
|---|---|---|---|---|---|
| [`round3-uikit-swift-opus`](round3-uikit-swift-opus) | 3 | Opus | UIKit (Swift) | Round 2 build after a three-hour speed and size pass | `round3-uikit-swift-opus` |
| [`round3-uikit-swift-sol`](round3-uikit-swift-sol) | 3 | Sol | UIKit (Swift) | same | `round3-uikit-swift-sol` |
| [`round3-uikit-objc-opus`](round3-uikit-objc-opus) | 3 | Opus | UIKit (Objective-C) | same | `round3-uikit-objc-opus` |
| [`round3-uikit-objc-sol`](round3-uikit-objc-sol) | 3 | Sol | UIKit (Objective-C) | same | `round3-uikit-objc-sol` |
| [`round3-swiftui-opus`](round3-swiftui-opus) | 3 | Opus | SwiftUI | same | `round3-swiftui-opus` |
| [`round3-swiftui-sol`](round3-swiftui-sol) | 3 | Sol | SwiftUI | same | `round3-swiftui-sol` |
| [`level2-swiftui-avdlee-opus`](level2-swiftui-avdlee-opus) | Level 2 | Opus | SwiftUI | With the AvdLee skill set | `opus-swiftui-avdlee` |
| [`level2-swiftui-avdlee-sol`](level2-swiftui-avdlee-sol) | Level 2 | Sol | SwiftUI | With the AvdLee skill set | `sol-swiftui-avdlee` |
| [`mac/round4-appkit-swift-opus`](mac/round4-appkit-swift-opus) | 4 (Mac) | Opus | AppKit (Swift) | Mac Campfire, no skills | `round4-appkit-swift-opus` |
| [`mac/round4-appkit-swift-sol`](mac/round4-appkit-swift-sol) | 4 (Mac) | Sol | AppKit (Swift) | same | `round4-appkit-swift-sol` |
| [`mac/round4-appkit-objc-opus`](mac/round4-appkit-objc-opus) | 4 (Mac) | Opus | AppKit (Objective-C) | same | `round4-appkit-objc-opus` |
| [`mac/round4-appkit-objc-sol`](mac/round4-appkit-objc-sol) | 4 (Mac) | Sol | AppKit (Objective-C) | same | `round4-appkit-objc-sol` |
| [`mac/round4-swiftui-mac-opus`](mac/round4-swiftui-mac-opus) | 4 (Mac) | Opus | SwiftUI for Mac | same | `round4-swiftui-mac-opus` |
| [`mac/round4-swiftui-mac-sol`](mac/round4-swiftui-mac-sol) | 4 (Mac) | Sol | SwiftUI for Mac | same | `round4-swiftui-mac-sol` |

Round 3 and Level 2 results: [`docs/results-round3.md`](../docs/results-round3.md), [`docs/results-l2-avdlee.md`](../docs/results-l2-avdlee.md). Round 4: [`docs/round4-results.md`](../docs/round4-results.md). Prompts are in [`prompts/`](../prompts).
