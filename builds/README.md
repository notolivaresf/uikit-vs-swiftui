# Builds

The ten builds measured in [`docs/results-l1.md`](../docs/results-l1.md) (Level 1) and [`docs/results-l2.md`](../docs/results-l2.md) (Level 2). Each is the app source as the model left it: no code was changed here. Each build's own `.git` folder is not included; its last commit is listed instead. Build output (`DerivedData`, `build/`, `.build/`, `*.xcresult`, `xcuserdata`) is left out, and so are agent skill folders (`.claude/`, `.agents/`).

| Folder | Level | Model | Stack | What it is | Source commit |
|---|---|---|---|---|---|
| [`opus-uikit`](opus-uikit) | 1 | Opus | UIKit (Swift) | No skills | `c0e6bb088f3e111cae11913a9042b5740d8e08c1` |
| [`opus-swiftui`](opus-swiftui) | 1 | Opus | SwiftUI | No skills | `daf271b6fc36dcc7a92eea242d36d3b032d2dbba` |
| [`sol-uikit`](sol-uikit) | 1 | Sol | UIKit (Swift) | No skills | `9131ccaf114d8df79f9d9bbc136eff39ee815d04` |
| [`sol-swiftui`](sol-swiftui) | 1 | Sol | SwiftUI | No skills | `795a82f550d8a3f7fd821d0574ac0451d2c4698a` |
| [`opus-uikit-ours-pair`](opus-uikit-ours-pair) | 2 | Opus | UIKit (Swift) | With our UIKit skill pair | `4f635a6d3a8f5a998713a5c0a1cb1b75c08aa47f` |
| [`sol-uikit-ours-pair`](sol-uikit-ours-pair) | 2 | Sol | UIKit (Swift) | With our UIKit skill pair | `e77677a939d22791520259b93df2ecf66c4e837d` |
| [`opus-swiftui-apple`](opus-swiftui-apple) | 2 | Opus | SwiftUI | With Apple's SwiftUI skills | `09f40f30f752fdc1d363c02f7bfa2e6f06376afa` |
| [`sol-swiftui-apple`](sol-swiftui-apple) | 2 | Sol | SwiftUI | With Apple's SwiftUI skills | `86dce034f4ea7da66adba0ce0a7992658ade81e8` |
| [`opus-objc-ours-objc-pair`](opus-objc-ours-objc-pair) | 2 | Opus | UIKit (Objective-C) | With our Objective-C UIKit skill pair | `e8c96a5a3e696623942a7d49ff432f0018ce86ed` |
| [`sol-objc-ours-objc-pair`](sol-objc-ours-objc-pair) | 2 | Sol | UIKit (Objective-C) | With our Objective-C UIKit skill pair | `560c09bf728b6567be6102d64b09eb83d617952d` |

Several source commits (Level 1: opus-uikit, sol-uikit, sol-swiftui; Level 2: the Sol builds and opus-uikit-ours-pair) are only the harness operator's starting commit or a save of the model's uncommitted work. In those, the app source here is the final working tree, which is newer than the listed commit.

## Skills

The Level 2 UIKit builds used our own skills, which are public in [`skills/`](../skills) and in [notolivaresf/uikit-skill](https://github.com/notolivaresf/uikit-skill). The skills folders the agents had installed are not copied into the builds.

Apple's skills used by the two `-apple` SwiftUI builds are not included in this repo. They come from the [artemnovichkov/xcode-skills](https://github.com/artemnovichkov/xcode-skills) mirror at commit `876d18c` (Apple's Xcode 27.0 release candidate skills).

## Other omissions

- `sol-objc-ours-objc-pair/Campfire/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1.3 MB) is left out to keep files under 1 MB; the icon is a plain image and does not affect the measurements.
- Transcripts are not kept in this repo.
