# Naming build lanes and reading tokens

Why: the second half of the experiment is how many tokens, turns and minutes each model needs to build the same Campfire chat screen in UIKit and in SwiftUI. Tokens live in the subagent transcripts, so every lane name must be machine-matchable.

## Lane names

The Agent `description` of a build lane is the key, exact pattern:

`UVS <stack> <model> run <N> <level>`

- `<stack>`: `uikit` or `swiftui`
- `<model>`: `haiku`, `sonnet` or `opus` (the `model` parameter passed, not guessed)
- `<N>`: 1, 2, 3 (a repeat of the same cell)
- `<level>`: `L1` (builds and shows the data), `L2` (passes the behaviour tests), `L3` (performance work with the same optimisation budget)

Example: `UVS swiftui sonnet run 2 L1`. One lane per level; level N+1 starts from the committed result of level N with a fresh lane so context sizes are comparable. Lanes of a cell share the same brief file (`docs/briefs/<stack>-<level>.md`, to be written), the same turn budget (stop after 70 turns or 3 commits) and no human help. A lane starts with `Card: <url>` and its stack's folder: `uikit-vs-swiftui/uikit/` or `uikit-vs-swiftui/swiftui/`. Opening line of the final report: `UVS <stack> <model> run <N> <level> done, commit <sha>`.

## Where the numbers are

- Transcript: `~/.claude/projects/-Users-amazinghumans-olivares-burgos/<session>/subagents/agent-<id>.jsonl`; beside it `agent-<id>.meta.json` holds `description` (our key) and `model`.
- Each assistant record has `message.usage`: `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`. The same API message can appear on several lines (streamed), so count each message id once.

## What the existing tools already compute (read-only, unchanged)

- `glue/agent_tokens.py [minutes] [--session ID]`: per subagent active in the window, TSV: description, model, turns, total tokens processed (input + cache writes + cache reads + output), current context (last turn's input side), output tokens, age. Good for a quick look; its window is by file modification time.
- `lane-review/collect.py`: the fuller pass, one usage per message id, gaps over 20 minutes counted as idle (so wall time is "active" seconds), a `tool_use` with no result is a hang, and `buildslot run` commands counted as builds with their seconds. It reads the same `.meta.json`.

## Row we record per lane

A later small script (`uikit-vs-swiftui/tools/lane_row.py`, not written yet) reads one lane by description and appends a line to `results/lanes.jsonl`:

| Field | How |
|---|---|
| key, stack, model, run, level | parse description |
| input, cache_read, cache_write, output tokens | sum of usage, each message id once |
| turns | assistant messages |
| active seconds, idle seconds | gaps under / over 20 min (collect.py rule) |
| build count, failed builds | `buildslot run` / `remote-build run` / `xcodebuild` Bash calls; failed = non-zero exit in the tool result |
| commits | git log lines carrying the lane's Co-Authored-By time window, or count from the report |
| test failures per level | from the verifying agent, not the lane |
| lines of code | `cloc`-style count of the stack folder at the lane's last commit |
| benchmark medians | harness result bundle after L3 |

Dollar cost is derived afterwards from published per-model prices; transcripts hold tokens, not dollars.

## Fairness reminders

Fix the spec (`docs/spec.md`), harness and CampfireKit before any lane starts; freeze them with a git tag (`uvs-baseline-1`) and record the tag in every row. Count iterations and fix rounds, since the Campfire ports compared effort, not languages. Verification of "done" comes from a separate checker running the harness, never the lane's own summary.
