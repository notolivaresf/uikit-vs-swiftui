# Skills used in Round 2

Round 2 gives each build a pair of agent skills (see `docs/harness.md`, "Round 2"). `Harness/skillset.py` installs them into the build folder, and checks the installed copy against the hash below.

## Ours, Swift (vendored here)

`skills/uikit/` holds a copy of two skills from the private repo `notolivaresf/uikit-skill` (local clone `~/olivares-burgos/uikit-skill`), tag `v0.3-pair`, commit `131b2a90a78a2b9359de728f021ba8db146c8f58` (plugin version 0.3.0). Taken with `git archive v0.3-pair skills/uikit-specialist skills/uikit-whats-new-27`. The slim skill is not included.

| Skill | Files | sha256 of the folder |
|---|---|---|
| `uikit-specialist` | 16 | `d0efa31320575071a130ddf8649dba282c7b928af8ae906e9d639c98ea3a9974` |
| `uikit-whats-new-27` | 11 | `0be4f5408dcf79409cedcd731ae1d9abd930e9b1c79d2a33956db63cb09b1334` |

Folder hash: sha256 of the text made of one line `<sha256 of file>  skills/<folder>/<path>` per file, files sorted by path (`python3 Harness/skillset.py --kind ours-pair`).

Used by: Swift UIKit builds, `--skills ours-pair`.

## Ours, Objective-C (vendored here)

`skills/uikit-objc/` holds a copy of two skills from the private repo `notolivaresf/uikit-skill` (local clone `~/olivares-burgos/uikit-skill`), tag `v0.4-objc-pair`, commit `4f62bfd7a8b8b51fa0ea30bedc697dd7ad8173d1`. Taken with `git archive v0.4-objc-pair skills/uikit-specialist-objc skills/uikit-whats-new-27-objc`.

| Skill | Files | sha256 of the folder |
|---|---|---|
| `uikit-specialist-objc` | 16 | `30d8d4dbf32885e220b03383b18189274f7eab4ae1a2c335299906d15dde992c` |
| `uikit-whats-new-27-objc` | 11 | `3dad207663da3f5265277a57162f5cb97bc5949e1081a3cbcdedb7d1dc223631` |

Same folder-hash formula as above (`python3 Harness/skillset.py --kind ours-objc-pair`).

Used by: Objective-C builds, `--skills ours-objc-pair`.

## Apple's (not vendored)

Apple's two skills, `swiftui-specialist` and `swiftui-whats-new-27`, are Apple's text and are not copied into this repo. Only their source and hashes are recorded:

- Source: the community mirror https://github.com/artemnovichkov/xcode-skills at commit `876d18c9beda08649e927d6c2df573899382601d` ("Update with Xcode 27 RC", Xcode 27.0 RC build 27A266a). Kept outside every repo in `~/uvs-skills/apple-27.0-rc/`.
- `swiftui-specialist`: 10 files, `14b2ac3082c01b9970ace22d730d6cf35979e1fade02f52a42ba58c936c7c4f4`
- `swiftui-whats-new-27`: 8 files, `5cfdad876e1a192fbe741694c3b694545a174ae7abe02eeb5806294f160e604f`

Used by: SwiftUI builds, `--skills apple`.

## Third-party, AvdLee (vendored here)

`skills/avdlee/swiftui-expert-skill/` is Antoine van der Lee's SwiftUI skill from https://github.com/AvdLee/SwiftUI-Agent-Skill, commit `204dba7c67256a8b707ee3fbc5759a824191974f` (6 Oct 2026, plugin version 5.2.1), MIT licence (`skills/avdlee/LICENSE`, copied unchanged). Taken with `git archive 204dba7 skills/swiftui-expert-skill LICENSE`. The upstream plugin ships this one skill; the repo's other skill, `.agents/skills/update-swiftui-apis`, is a maintainer tool for updating the skill itself (it needs an outside documentation server) and is not part of the plugin, so it is not used.

| Skill | Files | sha256 of the folder |
|---|---|---|
| `swiftui-expert-skill` | 51 | `bf151a948a006007ec175e898ba5689ed90a283e6e74634382165ee0487d3b4f` |

Same folder-hash formula as above (`python3 Harness/skillset.py --kind avdlee`).

Used by: the Level 2 third-party arm, SwiftUI builds, `--skills avdlee` (Fernando, 21 Oct). See `docs/results-l2-avdlee.md`.
