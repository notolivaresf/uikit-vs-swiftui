# Prompts, exactly as each agent got them

[`PROMPT.md`](../PROMPT.md) at the top of the repo is the template. Before each build, the harness (`Harness/launch-build.sh`) fills in line 3 with the build's stack. For Round 2 it also adds one line under it. The files here are the filled-in prompts, copied from the builds themselves (`builds/<build>/PROMPT.md`). Opus and Sol got the same text.

| Prompt | Used by |
|---|---|
| [`round1-uikit-swift.md`](round1-uikit-swift.md) | round1-uikit-swift-opus, round1-uikit-swift-sol |
| [`round1-swiftui.md`](round1-swiftui.md) | round1-swiftui-opus, round1-swiftui-sol |
| [`round2-uikit-swift.md`](round2-uikit-swift.md) | round2-uikit-swift-opus, round2-uikit-swift-sol |
| [`round2-uikit-objc.md`](round2-uikit-objc.md) | round2-uikit-objc-opus, round2-uikit-objc-sol |
| [`round2-swiftui.md`](round2-swiftui.md) | round2-swiftui-opus, round2-swiftui-sol |

Round 2 differs from Round 1 in a single line: "Agent skills are installed in this project; use any that help." The skills themselves are in [`skills/`](../skills) (ours). Apple's SwiftUI pair is not stored here; see [`builds/README.md`](../builds/README.md). Each agent was started with the same one sentence, "Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions."
