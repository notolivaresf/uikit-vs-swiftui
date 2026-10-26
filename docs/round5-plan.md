# Round 5: plan

> Fernando, 26 Oct: "Ok, let's cut the scope. Let's make a skill that is very good at handling this type of interface. For UIKit specifically, we should investigate whether UITableView or UICollectionView is more efficient. Best practices, etc. Let's plan for that."
>
> (Earlier the same day he asked what works and does not work with skills, and whether testing could be cut or moved to the end. Those findings are kept below as notes, not as the core of this round.)

Round 5 builds one focused UIKit skill for this kind of screen: a long chat or feed list with streaming rows, loading older messages, jumping to a message, text size changes, text selection and rotation. It has three steps: investigate table view against collection view for this screen, write the skill from what we find, then check the skill with benchmark builds against the Round 2 control. This page is the plan. Nothing here starts a build, a spike app, an agent or a simulator; Fernando gives the go.

## 1. What earlier rounds already tell us

Sources: `docs/results-round1.md`, `docs/results-round2.md`, `docs/optimal-gap-round2.md`, `docs/results-round3.md`, `runs/round3-*/verify.md`, the build source in `builds/`, and the run transcripts (`runs/<build>/transcript.jsonl` with `transcript.times`), read on 26 Oct.

- **No build has ever used a table view.** All ten UIKit builds (Rounds 1 to 3, Swift and Objective-C, Opus and Sol) chose a collection view. So the table view question has no data of ours yet; the investigation below supplies it.
- **Custom layout won over compositional layout.** Opus wrote a custom collection view layout with row heights computed and cached by message id in every round. Sol used the compositional layout with self-sizing cells in Round 2 (as our skill's first core rule says), then replaced it with a custom layout in Round 3 when told to make the build faster. Its own notes credit cached heights by id, a running index of heights for fast offset lookups, anchoring on the layout's own geometry and turning off automatic self-sizing invalidation.
- **The best numbers came from that shape.** Round 3, iPhone 17 simulator: the four UIKit builds reached 130 to 175 ms for the first 40 rows, 4.6 to 8.8 s of stream CPU, 32 to 42 ms for the jump and 44 to 58 MB peak memory. Two of the best rows bent the test (a stream redrawn only every 100 ms, a load older timer that covers part of the work; see `docs/results-round3.md`, "Bent rules"); the skill must say which shortcuts are not allowed.
- **Text selection is the check that fails.** In Round 2, 3 of the 4 UIKit builds failed it: a custom Copy and Reply menu replaced the system's own edit menu items, and a long-press menu on the whole bubble competed with selecting text (`docs/optimal-gap-round2.md`). Our skill already had the rule in a reference file that one of those agents read. It must be a core rule, stated once, at the top.
- **Stream handling.** The lowest Round 3 stream CPU (4.6 and 6.4 s, both Opus) came from batching streamed messages into one update every 100 ms, against 7.5 to 8.8 s for the Sol builds. Batching is fair as long as every message still shows up; the skill should say how far it may go.
- **Skills are read once.** Agents read the skill's main file and 1 to 6 references in the first minute and never return. Six of the 15 references and the whole iOS 27 skill were never read. A focused skill should fit in one file plus a few references, with the screen's whole recipe in the main file.
- **Memory.** Opus Swift went from 43.9 MB (Round 1, no skill) to 107.9 MB (Round 2, with skill) on the iPhone 12; the leanest builds (35 to 52 MB) kept few views alive and cached only measurements, not views or rendered text.

## 2. What the public evidence says

Cited for the investigation and the skill; nothing is copied from Apple. Session numbers are Apple's WWDC session ids.

- **Collection view as the modern list.** WWDC20 "Lists in UICollectionView" (10026) presents list layouts in collection views as a replacement for most table view uses; WWDC20 "Modern cell configuration" (10027) brings content and background configurations to both table view and collection view cells. Apple's "Implementing modern collection views" sample code shows both.
- **Layouts.** WWDC19 "Advances in Collection View Layout" (215) introduces the compositional layout; Apple's article "Customizing collection view layouts" and WWDC18 "A Tour of UICollectionView" (225) cover writing a custom layout, including caching attributes and invalidating only what changed.
- **Data and updates.** WWDC19 "Advances in UI Data Sources" (220) and WWDC20 "Advances in diffable data sources" (10045) cover diffable data sources for both views; WWDC21 "Make blazing fast lists and collection views" (10252) covers reconfiguring items instead of reloading them, cell registrations, prefetching and preparing images off the main thread.
- **Self-sizing.** WWDC22 "What's new in UIKit" (10068) adds automatic self-sizing invalidation for table view and collection view cells; the table view docs ("Estimating the height of a table's scrolling area") explain the cost of estimated heights.
- **Text.** WWDC21 "Meet TextKit 2" (10061) and WWDC22 "What's new in TextKit and text views" (10090) cover text views and layout; the `UITextViewDelegate` edit menu methods (iOS 16, and the multi-range form in the iOS 26 SDK) cover adding actions to the system menu.
- **Measuring.** WWDC21 "Explore UI animation hitches and the render loop" (10181) and WWDC23 "Analyze hangs with Instruments" (10248) define hitches and how to measure them, which is what our iPhone 12 pass reads.

What the public record does not give: a measured table view against collection view comparison for a long, growing chat list with streaming rows and prepends. That is what the investigation is for.

## 3. Investigation: table view or collection view

### The question

For this screen, holding everything else equal, which list view does the work with the least CPU, memory and delay, and passes all 13 checks: a table view, a collection view with the compositional layout, or a collection view with a custom layout?

### The spikes

One small spike app per variant, written by us (not by the benchmark agents), sharing everything except the list view:

| Spike | List view | Row sizing |
|---|---|---|
| S1 | table view, diffable data source | self-sizing cells with estimated heights |
| S2 | table view, diffable data source | heights computed off the main thread and cached by message id, returned from the height callback |
| S3 | collection view, compositional (list or single-column) layout | self-sizing cells with estimated heights |
| S4 | collection view, custom layout | heights computed and cached by message id (the Round 3 shape) |

Shared by all four, in one Swift package used by each spike: the data (`CampfireKit`), the row view (one message view class, the same text view, the same bubble, avatar and boost pills), the height measurer (S2 and S4 use it; S1 and S3 let the system measure), the stream batching, the bottom-pinning and anchor logic (written against a small protocol each spike implements), the debug bar and its state label. Each spike is a thin controller around its list view, a few hundred lines. The list view is the only variable; S1 against S2 and S3 against S4 also show what manual height caching is worth on each.

The spikes live in `spikes/round5/` here, built from one `project.yml` with four app targets, so one command builds all four.

### How it is measured

- **Same harness, same checks.** The Round 3 simulator harness (`./bench`) and the iPhone 12 pass (`Harness/record.sh`) run unchanged against each spike: the 13 checks, first 40 rows cold and repeated, stream CPU, jump to message 2,500, load older, text size at the bottom and mid-list, peak memory, app size; on the phone also cold launch, fling frames per second and hitches, stream hitches.
- **Simulator first.** Three full `./bench` passes per spike on one kept simulator (the Round 3 model and runtime), alternating spikes (S1 S2 S3 S4, three times), median per row. A spike that fails a check is fixed before its numbers count, so the comparison is between correct apps.
- **iPhone 12 for the final numbers.** Three full passes per spike, alternating, median per row. That is about 12 passes of about 45 minutes, so about 9 hours of phone time over one or two sittings.
- **Also recorded:** lines of code per spike (the controller only), and how many places in it needed workarounds to keep the position within 2 pt. Simple code matters for a skill: agents copy what the skill shows.
- **Fair-play rules:** the same batching interval and the same stream for all; no spike may skip work the test measures (the Round 3 "bent rules" list); Release builds; same Xcode for all.

### What would decide it

- A variant wins when it passes all 13 checks and is better on stream CPU, memory and the drift-sensitive timings (jump, load older, text size) by more than the spread of its own three passes.
- If table view and collection view tie within noise, the skill recommends the collection view (wider layout options and where Apple's newer work goes, per the sessions above) and notes the table view as equally good for a plain single-column list.
- If manual height caching (S2, S4) is not clearly faster than self-sizing (S1, S3), the skill recommends self-sizing, which is less code and fewer ways to drift.

## 4. What the skill will cover

Working name `uikit-chat-list` in `uikit-skill`, one `SKILL.md` with the screen's recipe up front and a few references. Each item is tied to evidence; the list view and sizing items are filled in from the investigation.

| Practice | Evidence |
|---|---|
| Which list view and layout to use for a long chat list (from the spikes) | investigation; WWDC20 10026, WWDC19 215 |
| Item identity is the message id; content changes reconfigure, never reload or delete and reinsert | WWDC21 10252; the boost-burst check (a row grows while the room stays pinned) |
| Row heights: measure once per message, width and text size; cache by id; invalidate only changed rows (or self-sizing, if the spikes say so) | Round 3 Sol notes; investigation S1 to S4; WWDC22 10068 |
| Load older: anchor on a visible row's id and its distance from the top, restore after the insert, no reversed list | Round 1 to 3 drift checks (all UIKit builds within 0.3 pt); `optimal-gap-round2.md` |
| Jump to a message: lay out to the target, then put its top under the header | Round 2 and 3 jump times (32 to 109 ms) |
| Bottom pinning: decide pinned before the update; stay pinned through inserts, boosts, rotation and text size | the pinned checks, every round |
| Streaming: batch incoming messages per frame or short interval, one update per batch, no per-message layout pass over all rows; and the rule that the batching must not skip work the user sees | Round 3 stream CPU, "Bent rules" |
| Text size and rotation: remeasure only loaded rows, keep the top row's anchor | Round 3 text size rows (12 to 46 ms) |
| Text selection and menus: a non-editable, selectable text view; add Copy and Reply to the system's suggested menu items, never replace them; do not let a whole-bubble long press take the press from the text | `optimal-gap-round2.md` (3 of 4 UIKit fails); WWDC22 10090 |
| Memory: keep few rows alive, cache measurements not views or rendered text, no per-row images kept off screen | Round 1 to 3 peak memory (35 to 108 MB) |
| Main thread: no formatter creation, text measuring loops or image decoding in cell configuration | WWDC21 10252, 10181; Round 3 cached timestamp formatting |
| How to check the work: what to measure (hitches, stream CPU, drift) and the shortcuts that do not count | WWDC21 10181, WWDC23 10248; our harness |

The skill names APIs freely (that is its job). It says nothing about this benchmark, its numbers or its tests: it must be a general skill for this kind of screen.

## 5. Validating the finished skill

Benchmark builds of the Campfire room with the new skill against the Round 2 control (our UIKit pair v0.3, the Round 2 Swift prompt), UIKit in Swift, iPhone, Opus 5.5 and Sol at high effort, same start sentence, empty folder, no memory, 2-hour cap.

| Arm | Skill | Opus | Sol | Builds |
|---|---|---|---|---|
| Control (twice, to see how much a rerun varies) | Round 2 pair v0.3 | 2 | 2 | 4 |
| New skill (twice) | `uikit-chat-list` | 2 | 2 | 4 |

8 builds, two at a time (the same arm for both models, one simulator each). Measures in order:

1. **Checks**: the 13 checks, run by us on the simulator after the agent stops, confirmed on the iPhone 12.
2. **App numbers**: the simulator scorecard, then the iPhone 12 full pass.
3. **Agent cost**: wall time, turns, builds, output tokens, cost where reported, skill files read (added to each run record by a small transcript reader, written before the first build).

The skill works if both models pass 13 of 13 in both runs (the control did not in Round 2), and its builds are within 15 % of the best Round 3 build on stream CPU, jump, load older and memory, without a bent rule. It fails if any check still fails or the numbers are no better than the control's.

The prompt rule stays: the benchmark prompt states outcomes and numbers only, never an API or framework name. The prompt is the Round 2 Swift prompt unchanged.

## Logistics

- **Simulators**: at most 2 booted on the Max at once, including any other lane's, through `simcap ensure`; kept simulators made with `Harness/sims.py ensure`; never deleted or erased; shut down when the step ends. The spikes need one; the validation builds two.
- **Builds** go through `buildslot`, so a compile never overlaps a measuring pass. Sandbox, guard, audit and lock checks as in Round 3 for the agent builds.
- **iPhone 12** for the final numbers of both the spikes and the validation builds, one at a time. Someone at the phone: unlocked, kept awake, Settings > Developer > Enable UI Automation on, several GB free.
- **Order**: spikes (simulator, then phone) → skill written and reviewed → validation builds → phone pass → write-up and charts (`Harness/tools/results_table.py`, a new mode).
- **Quota**: Sol runs use a shared Codex account; check its quota before each Sol pair.

## Notes kept for a later round (not the core of Round 5)

From the first draft of this plan (same day). Measured from the Round 1 and 2 UIKit transcripts:

| Build | Wall time | Turns | Own test runs | Time in own test runs | Output tokens |
|---|---|---|---|---|---|
| round1-uikit-swift-opus | 2633 s | 75 | 11 | 1124 s (43 %) | 143 k |
| round1-uikit-swift-sol | 1200 s | 102 | 10 | 534 s (45 %) | 69 k |
| round2-uikit-swift-opus | 2231 s | 95 | 6 | 492 s (22 %) | 169 k |
| round2-uikit-swift-sol | 1233 s | 90 | 12 | 675 s (55 %) | 62 k |
| round2-uikit-objc-opus | 2884 s | 106 | 6 | 794 s (28 %) | 196 k |
| round2-uikit-objc-sol | 1297 s | 118 | 20 | 924 s (71 %) | 77 k |

- The prompt never asks for tests, yet every agent wrote and ran its own UI tests: 22 to 71 % of wall time, against 5 to 18 % writing app code. One run of an agent's own suite took 100 to 235 s.
- Opus tests late (45 to 70 % into the run), Sol from the first minutes; Sol still finished in about half the time.
- Hypotheses for a later round: give the agent the 13 checks as one command in its folder (self-written test time down by half); tests once, at the end, one per behaviour (test runs at most 3); compile the tests once and rerun only the failing test (each run under 60 s); a helper agent writing tests in parallel.
- Missing data: no arm has run twice; tokens and test time are not in the run records yet; Round 3 has no phone numbers; the slim skill (1,669 words) was never run.
