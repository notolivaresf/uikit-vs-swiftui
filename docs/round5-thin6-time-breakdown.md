# Round 5: where thin6's extra agent time goes

28 Oct. An analysis only; nothing was built for this note.

Sol with the thin6 skill passes 13/13 every time, but its agent time misses the bar. The median is 1,938 s raw and 1,674 s speed-corrected. The bar is 1,491 s, set by three same-day controls that used the older pair skill (v0.3-pair). This note splits every run's time into parts, finds the parts that grew, and ties them to the skill sentences behind them. It ends with a thin7 proposal.

Runs compared:

| Label | Run folder | Skill | Wall s | Output tokens | Speed tok/s |
|---|---|---|---|---|---|
| E30 | runs/sol-uikit-ours-chatlist-e30 | thin6 | 1,936 | 71.8k | 45.8 |
| E30b | runs/sol-uikit-ours-chatlist-e30b | thin6 | 2,280 | 77.6k | 38.0 |
| E30c | runs/sol-uikit-ours-chatlist-e30c | thin6 | 1,556 | 55.9k | 41.3 |
| E29 | runs/sol-uikit-ours-chatlist-thin5 | thin5 | 1,797 | n/a | 44.1 |
| ctl27a | runs/sol-uikit-ours-pair-ctl27a | v0.3-pair | 1,352 | 64.2k | 56.7 |
| ctl27b | runs/sol-uikit-ours-pair-ctl27b | v0.3-pair | 1,242 | 55.0k | 54.0 |
| ctl27c | runs/sol-uikit-ours-pair-ctl27c | v0.3-pair | 1,993 | 82.7k | 48.4 |

## Method

- **Timeline.** Each `transcript.jsonl` line is paired with its time in `transcript.times`. The events are the starts and ends of commands, agent messages and web searches. Codex records no separate thinking events and no per-step token counts.
- **Fixing late end times.** Commands run in the background while the model keeps working and reads their logs, and some end events arrive minutes late. In E30c two test runs show about 616 s, and a simulator `log stream` shows 922 s. So a build or test counts as finished at the first later read of its own log that shows a finish line (TEST SUCCEEDED or FAILED, "Executed N tests", BUILD FAILED and so on). `log stream` is not counted as waiting.
- **Sorting the time.** I stepped through every run 0.1 s at a time. Each moment went to the first of these that applies:
  1. a test run in progress (whole suite or whole target first, then `-only-testing:`);
  2. a build in progress;
  3. a simulator command;
  4. any other command;
  5. otherwise, model time.

  Model time is charged to whatever the model does next: the command it launches, its next message, or the final report.
- **Speed correction.** Only model time is scaled, by the run's speed divided by 54.0 tok/s, the controls' middle speed. Waiting on Xcode is left as measured.
- **What "failed builds" means.** The harness counts every `xcodebuild` command as a build, and any nonzero exit as a failure. Its failed-build count therefore includes failed test runs and asset-catalog errors. I split them by cause below.

## Time per run, raw seconds

| Part | E30 | E30b | E30c | E29 | ctl27a | ctl27b | ctl27c |
|---|---|---|---|---|---|---|---|
| Model: writing code, launching builds and tests | 705 | 819 | 538 | 672 | 615 | 645 | 810 |
| Model: reading build and test output | 217 | 201 | 130 | 167 | 3 | 109 | 130 |
| Model: progress messages, final report | 186 | 228 | 208 | 199 | 158 | 144 | 248 |
| Model: reference study (upstream icons, web, image tools) | 116 | 223 | 0 | 185 | 0 | 0 | 56 |
| Reading skill, prompt and kit | 19 | 18 | 8 | 51 | 21 | 27 | 29 |
| Simulator handling | 74 | 157 | 180 | 198 | 102 | 49 | 168 |
| Waiting: builds | 9 | 61 | 23 | 22 | 23 | 11 | 34 |
| Waiting: tests, whole suite or target | 220 | 147 | 103 | 93 | 272 | 256 | 367 |
| Waiting: tests, `-only-testing:` | 366 | 405 | 366 | 206 | 152 | 0 | 147 |
| Waiting: other commands | 25 | 20 | 1 | 5 | 5 | 0 | 4 |
| **Wall** | **1,936** | **2,280** | **1,556** | **1,797** | **1,352** | **1,242** | **1,993** |
| **Speed-corrected total** | 1,737 | 1,794 | 1,313 | 1,531 | 1,396 | 1,242 | 1,845 |

## Means: thin6 against the controls

| Part (speed-corrected) | thin6 mean | controls mean | difference |
|---|---|---|---|
| Waiting: tests, `-only-testing:` | 379 | 100 | **+279** |
| Waiting: tests, whole suite or target | 157 | 298 | −142 |
| *Test waiting, together* | *536* | *399* | ***+137*** |
| Model: reading build and test output | 142 | 77 | **+65** |
| Model: reference study | 85 | 17 | **+68** |
| Simulator handling | 107 | 102 | +5 |
| Waiting: builds | 31 | 23 | +8 |
| Waiting: other | 15 | 3 | +12 |
| Reading skill, prompt and kit | 12 | 25 | −13 |
| Model: progress messages | 159 | 178 | −18 |
| Model: writing code, launching | 529 | 672 | −144 |
| **Total** | **1,615** | **1,494** | **+121** |

Raw, the gap is 1,924 s against 1,529 s, or +395 s. After speed correction it is +121 s, so about 275 s of the raw gap is service speed: the thin6 runs drew slower tokens (38 to 46 tok/s against 48 to 57). The rest of this note is about the 121 s that remains. Output tokens are level (68.4k against 67.3k mean), so thin6 does not make Sol write more. It makes Sol wait on, and reread, more test runs.

## Test runs, per run

| Run | Test runs | Whole suite or target | `-only-testing:` | Test functions written | Log reads while a test ran |
|---|---|---|---|---|---|
| E30 | 13 | 3 | 10 | 12 | 16 |
| E30b | 10 | 3 | 7 | 10 | 14 |
| E30c | 11 | 1 | 10 | 7 | 11 |
| E29 (thin5) | 11 | 6 | 5 | 12 | 8 |
| ctl27a | 7 | 3 | 4 | 7 | 11 |
| ctl27b | 9 | 9 | 0 | 7 | 14 |
| ctl27c | 15 | 7 | 8 | 5 | 15 |

thin6 follows its closing sentence: whole-suite runs drop and `-only-testing:` runs take over. The trouble is which test gets rerun. In all three thin6 runs, the reruns go to the agent's own live-stream test, which waits on the timed feed for about 30 s. Each rerun costs about 32 to 42 s of test time, or about 50 s with its build. The controls' debug loops rerun quick geometry checks that take under a second, about 17 to 22 s per run with the build. How often the agent checked logs during runs (the last column) is about the same in both groups.

## Failed builds, per run

| Run | Harness "failed" | Compile errors | Asset catalog | Test failures | Other | Seconds inside failing runs |
|---|---|---|---|---|---|---|
| E30 | 9 | 1 (text view designated initialiser) | 1 (app icon) | 7 | 0 | 365 |
| E30b | 9 | 3 (style helper named like a function; `self` used before init) | 2 (app icon) | 4 | 0 | 352 |
| E30c | 9 | 1 (kit initialiser not public) | 0 | 8 | 0 | 368 |
| E29 | 4 | 1 (`selfSizingInvalidation` out of scope) | 0 | 2 | 1 | 162 |
| ctl27a | 5 | 1 (kit initialiser not public) | 0 | 4 (some UI test timeouts) | 0 | 441 |
| ctl27b | 8 | 1 (redeclared colours) | 0 | 5 (reference geometry) | 2 (one killed) | 184 |
| ctl27c | 10 | 1 (screenshot API) | 2 (app icon) | 7 | 0 | 270 |

Compile errors are rare and cheap in every run. Each run has one to three, and in every case the agent read the error before it rebuilt. Nobody rebuilt blind. The failed-build numbers are almost all failing tests, and that is where the time goes.

Simulator handling (boot, install, launch, screenshots, shutdown) is level: 107 s for thin6 against 102 s for the controls, speed-corrected. The skill's line "Close any simulator you started" costs nothing that shows.

## The top three costs

### 1. A loop debugging the live stream after trimming: about +280 s of focused test waiting, plus reading time

This happens in all three thin6 runs. It is not in E29 (thin5) or in any control.

- **E30, from 593 s to 1,152 s.** The stream test ran 6 times between 671 s and 1,117 s, and 5 of those runs failed. The agent's messages say the stream "drift starts when the window begins trimming old rows". Its trace shows the screen pinned before a trimming append (`pin true`), the offset shifting at completion, and the next append seeing `pin false`. The fix was a pinned flag that stays set (`followsBottom`), plus a pending bottom target inside `targetContentOffset`.
- **E30b, from 630 s to 1,083 s.** The pinned-stream test failed 3 times, landing 10 to 36 pt short of the bottom. The agent wrote: "UIKit adjusts the offset again after a trimming batch finishes". The fix was a collection-view subclass that keeps the bottom in `layoutSubviews` "until the reader drags".
- **E30c, from 409 s to 676 s.** The agent wrote: "UIKit was applying a later offset adjustment after my immediate restoration, which affected jumps and stream pinning". The fix was a pending anchor in `targetContentOffset` and overrides of the initial layout attributes.

Every thin6 run lands on the same fix: being pinned is a state that stays on, and while pinned the layout's target offset is the bottom. The skill never says this. These are the sentences that send the agent there:

- Rule 6: "Read "pinned" before it and set the bottom offset after it." This sentence works out pinned from the offset at every flush and fixes the offset afterwards. A batch that also trims moves the offset during layout, so the next flush reads "not pinned".
- Rule 7: "**Trim in the same batch:** deletes use old positions, inserts new ones: trimming k rows from the top while appending inserts at `oldCount - k`." Trimming on every append past the limit means every live arrival is also a trim, and a trim is exactly the case that breaks the sentence above.
- Rule 8: "the layout's `targetContentOffset(forProposedContentOffset:)` keeps the first visible row where it was, and runs only inside batch updates". While pinned, keeping the first visible row in place is the wrong target. During a trimming append the layout holds the top row while the agent then sets the bottom, and the two fight.

**What the controls do differently.** They use a compositional layout and diffable snapshots, with no `performBatchUpdates` at all. They trim only once the window runs about a page past its limit, and as a step of its own. They keep a follow flag. Trims are rare there, so a trim almost never lands on a live arrival, and the follow flag never gets worked out again from a moved offset. thin6's own layout is fine everywhere else: the controls' advantage here is how often they trim and how they hold the pinned state, not their layout class.

### 2. Reference study and upstream icons: +68 s corrected (+94 s raw)

- **E30 (116 s).** It cloned the upstream chat project (2 `git clone`, 2 web searches) to borrow its icons and styles, converted images with `sips`, and imported an app icon. One asset-catalog build failure followed.
- **E30b (223 s).** Web searches, image work with `sips` and PIL, and an app icon import. Two asset-catalog build failures followed.
- **E30c: 0 s.** ctl27a and ctl27b: 0 s. ctl27c: 56 s, and it also hit two app-icon failures. E29 (thin5): 185 s.

No skill sentence asks for this. The prompt says nothing about icons either: it asks only that the screenshots and constants match. It is a habit of Sol's that shows up in two of three thin6 runs and one of three controls. It adds the most variance of any part (0 to 223 s), so one sentence in the skill would remove a risk at almost no cost.

### 3. Reading build and test output: +65 s corrected (+102 s raw)

thin6 runs spend 130 to 217 s reading logs and result bundles. The controls spend 3 to 130 s. Most of the extra comes out of cost 1: every failing stream rerun means reading the log, adding a trace, and reading it again. In E30 alone, the trace reads between 593 s and 1,152 s add up to about 90 s. If cost 1 goes, most of this goes with it.

### Smaller items and offsets

- **Writing code is quicker under thin6 (−144 s).** The rules hand the agent a design, so it writes it with less exploring. The skill's design rules are worth keeping.
- **Whole-suite waiting is down (−142 s).** The closing sentence about `-only-testing:` works. Its savings are spent on cost 1.
- **More test functions.** thin6 writes 7 to 12, the controls 5 to 7. The line "These rules say how to build it; they are not a list to test." did not bring the count down to the controls' level, but the extra tests are cheap except the stream one.
- **Release builds are not a cost.** Release segments number 4, 6 and 3 for thin6, against 13, 0 and 6 for the controls.

## thin7 proposal

Every sentence below is generic UIKit advice, with no names and no numbers. Rule numbers follow thin6.

**Rule 6, change.** Replace the last sentence:

> Read "pinned" before it and set the bottom offset after it.

with:

> Keep "pinned to the bottom" as state: set it when the reader reaches the bottom, clear it only when the reader drags away, and never work it out again from the offset after a batch. While pinned, the layout's target offset is the bottom, so a flush that also trims stays at the bottom without a second offset fix.

**Rule 7, change.** Replace the heading sentence:

> **Trim in the same batch:** deletes use old positions, inserts new ones: trimming k rows from the top while appending inserts at `oldCount - k`.

with:

> **Trim rarely, in the same batch:** let the window run a page past its limit before trimming back to it, so most arrivals are plain appends. When a batch trims, deletes use old positions and inserts new ones: trimming k rows from the top while appending inserts at `oldCount - k`.

Keep the rest of rule 7, the `reconfigureItems` sentence, unchanged.

**Rule 8, change.** In

> the layout's `targetContentOffset(forProposedContentOffset:)` keeps the first visible row where it was, and runs only inside batch updates, never after `reloadData` or a plain invalidation.

replace "keeps the first visible row where it was" with "returns the bottom while pinned and otherwise keeps the first visible row where it was". The sentence then reads:

> the layout's `targetContentOffset(forProposedContentOffset:)` returns the bottom while pinned and otherwise keeps the first visible row where it was, and runs only inside batch updates, never after `reloadData` or a plain invalidation.

**Add one sentence to "Text and menus"**, after "These rules say how to build it; they are not a list to test.":

> Draw icons with system symbols; don't download or import image assets or an app icon.

**Add one sentence to the closing paragraph**, before "Check each behaviour once the screen works…":

> When a check waits on timed arrivals, drive the arrivals faster in your own check than the app's default pace.

This one is optional and the riskiest of the five, because it nudges the agent toward test plumbing. Try it in a second arm, not the first.

**Cut: nothing.** The `UIPasteboard` clause in rule 1 and the tolerance clause in rule 8 cost nothing that shows in these transcripts. Cutting them risks the 13/13.

**What to expect.** If the stream loop goes, about 250 to 300 s of raw focused test waiting and about 60 to 90 s of log reading go with it. The icon line removes up to about 220 s more in an unlucky run. The speed-corrected mean would land at about 1,300 to 1,350 s, under the 1,491 s bar. This is an estimate from these seven transcripts, not a measurement: confirm it with three thin7 repeats next to one control on the same day.
