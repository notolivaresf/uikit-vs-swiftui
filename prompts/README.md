# Prompts, exactly as each agent got them

[`PROMPT.md`](../PROMPT.md) at the top of the repo is the template. Before each build, the harness (`Harness/launch-build.sh`) fills in line 3 with the build's stack. For Round 2 it also adds one line under it. The files here are the filled-in prompts, copied from the builds themselves (`builds/<build>/PROMPT.md`). Opus and Sol got the same text.

| Prompt | Used by |
|---|---|
| [`round1-uikit-swift.md`](round1-uikit-swift.md) | round1-uikit-swift-opus, round1-uikit-swift-sol |
| [`round1-swiftui.md`](round1-swiftui.md) | round1-swiftui-opus, round1-swiftui-sol |
| [`round2-uikit-swift.md`](round2-uikit-swift.md) | round2-uikit-swift-opus, round2-uikit-swift-sol |
| [`round2-uikit-objc.md`](round2-uikit-objc.md) | round2-uikit-objc-opus, round2-uikit-objc-sol |
| [`round2-swiftui.md`](round2-swiftui.md) | round2-swiftui-opus, round2-swiftui-sol |
| [`round4-appkit-swift.md`](round4-appkit-swift.md) | round4-appkit-swift-opus, round4-appkit-swift-sol |
| [`round4-appkit-objc.md`](round4-appkit-objc.md) | round4-appkit-objc-opus, round4-appkit-objc-sol |
| [`round4-swiftui-mac.md`](round4-swiftui-mac.md) | round4-swiftui-mac-opus, round4-swiftui-mac-sol |

Round 2 differs from Round 1 in a single line: "Agent skills are installed in this project; use any that help." The skills themselves are in [`skills/`](../skills) (ours). Apple's SwiftUI pair is not stored here; see [`builds/README.md`](../builds/README.md). Each agent was started with the same one sentence, "Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions."

Round 4 (Mac, 21 Oct) uses its own template, [`PROMPT-mac.md`](../PROMPT-mac.md): the same room, behaviours and debug bar as `PROMPT.md`, worded for one Mac window (393 × 852 pt at launch, resizable) instead of a phone, with the app's own text size, right-click for the context menu and document-style text selection. No skills, so no skill line. The three files above are rendered from that template by the launcher's stack lines; once the builds run, the copies in each build folder are the record. See [`docs/round4-plan.md`](../docs/round4-plan.md).
