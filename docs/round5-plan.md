# Round 5: plan

> Fernando, 26 Oct: "Let's break this down into smaller experiments."
>
> Earlier the same day: "Ok, let's cut the scope. Let's make a skill that is very good at handling this type of interface. For UIKit specifically, we should investigate whether UITableView or UICollectionView is more efficient. Best practices, etc. Let's plan for that." (And before that he asked what works and does not work with skills, and whether testing could be cut or moved to the end; those findings are kept as notes at the end.)

Round 5 builds one focused UIKit skill for this kind of screen: a long chat or feed list with streaming rows, loading older messages, jumping to a message, text size changes, text selection and rotation. It is now a series of seven small experiments. Each answers one question, runs on its own in a few hours at most, and depends only on the answers before it. The cheapest and most decisive come first.

**Nothing here runs without Fernando's go, one experiment at a time.** This page starts no build, spike app, agent or simulator.

## The experiments at a glance

| # | Question | Decided by | Cost | iPhone 12 |
|---|---|---|---|---|
| E1 | Table view or custom collection view, for streaming text? | stream CPU | about 2.5 agent hours, 15 min simulator | no |
| E2 | Are saved row heights worth it? | text size change, mid-list | about 1 agent hour, 15 min simulator | no |
| E3 | Which way of keeping the place when older messages load? | drift in points | about 1.5 agent hours, 15 min simulator | no |
| E4 | How do we keep the system text selection menu? | selection check passes | about 1 agent hour, 10 min simulator | no |
| E5 | Does the simulator's answer hold on a real phone? (optional) | hitch time ratio while flinging | about 0.5 agent hours, about 1.5 h phone | yes |
| E6 | Write the skill from E1 to E5 | every rule traced to an answer or a citation | about 2 agent hours | no |
| E7 | Does the skill make better builds? | checks passed, of 13 | 2 builds of up to 2 h, about 1 h simulator, about 1.5 h phone | yes |

E4 does not depend on E1 to E3 and can run at any point, even alongside E1. Agent hours are our agents writing small spike apps or the skill; the benchmark agents only run in E7.

## How every spike experiment works (E1 to E5)

- **Small spike apps written by us**, not by the benchmark agents, in `spikes/round5/`, from one `project.yml`. They share one Swift package: the data (`CampfireKit`), one message row view (text view, bubble, avatar, boost pills), the height measurer, the bottom pinning and the debug bar the harness reads. Only the thing under test changes between two spikes.
- **No shortcuts.** Streamed messages are applied as they arrive (no timer that redraws every 100 ms), and every timed step times all of its work. The Round 3 "Bent rules" (`docs/results-round3.md`) do not count.
- **Same harness.** The Round 3 simulator harness (`./bench`) runs unchanged, but only the rows the experiment needs (one row takes 10 to 48 s; a full pass about 3.6 min). On the phone, `Harness/record.sh` quick passes (about 10 min each).
- **Three passes, alternating** spikes (A B A B A B) on one kept simulator, median per row. A spike that fails the check it is meant to pass is fixed before its numbers count.
- **Simulators**: one, through `simcap ensure`, kept with `Harness/sims.py ensure`, never deleted or erased, shut down when the experiment ends.

## E1: table view or custom collection view, for streaming text

- **Question.** With everything else the same, which list view costs less to keep a growing chat pinned to the bottom while messages stream in?
- **What we build.** The shared package plus two spike apps: A, a table view; B, a collection view with a custom layout (the shape every fast build so far used). Both use saved heights from the shared measurer, so heights are not the variable. Each opens at the bottom of 50,000 messages and streams 20 messages a second for 30 seconds. No load older, jump or menus yet.
- **Deciding measure.** Stream CPU (seconds of app CPU over the 30-second stream), median of three alternating passes. The 600 messages must all show and stay pinned; that check must pass for both.
- **Expected.** Within 10 % of each other. Round 3's custom layouts reached 4.6 to 8.8 s with different stream code, so both spikes should land near the bottom of that range.
- **Proved wrong if** one is more than 15 % lower in all three passes.
- **Cost.** About 2.5 agent hours (most of it the shared package, which E2 to E5 reuse); about 15 minutes of simulator. No phone.
- **Next.** The lower one is the base for E2 to E4. If they are within 10 %, the base is the one with fewer lines of list code, and the skill says either view is fine for this.

## E2: saved row heights, on or off

- **Question.** Is measuring and saving each row's height by message id worth the code, against letting the system size the rows?
- **What we build.** One more spike: the E1 winner with self-sizing rows (the system measures), against the E1 winner as it is (saved heights).
- **Deciding measure.** Time to apply a text size change in the middle of the list (ms), median of three. Stream CPU and the jump to message 2,500 are recorded alongside but do not decide.
- **Expected.** Saved heights at least a third faster. Round 3 builds with saved heights took 12 to 46 ms.
- **Proved wrong if** self-sizing comes within 20 %, or self-sizing jumps to message 2,500 at the wrong spot.
- **Cost.** About 1 agent hour; about 15 minutes of simulator. No phone.
- **Next.** If saved heights win, the measurer is a core rule of the skill and E3 uses it; if not, the skill says to let the system size rows, and E3 runs on self-sizing.

## E3: keeping the place when older messages load

- **Question.** Which approach keeps what the reader sees still when older messages are added above?
- **What we build.** The E2 base with load older, three ways: (a) remember the top visible row and its offset, put it back after the insert; (b) add the inserted rows' total height to the scroll offset; (c) the layout keeps its own anchor while it inserts (custom collection view only, so dropped if E1 chose the table view).
- **Deciding measure.** Drift in points after load older, from the harness, median of three; it must be 0. Load older time (ms) breaks a tie.
- **Expected.** All reach 0 points with saved heights; (b) drifts with self-sizing rows.
- **Proved wrong if** (a), the simplest, drifts with saved heights.
- **Cost.** About 1.5 agent hours; about 15 minutes of simulator. No phone.
- **Next.** The skill names the simplest approach that reached 0 points, and warns against the ones that drifted.

## E4: keeping the system text selection menu

- **Question.** How do we add Copy and Reply without losing the system's own menu when text is selected? This is the check 3 of the 4 Round 2 UIKit builds failed.
- **What we build.** One spike, three ways: (a) the system menu kept, Copy and Reply added to it through the text view's edit menu; (b) our own menu in place of it; (c) (a) plus a long press on the whole bubble, as the Round 2 builds had.
- **Deciding measure.** The harness's text selection check passes, in all three runs.
- **Expected.** (a) passes; (b) and (c) fail, as in Round 2.
- **Proved wrong if** (b) or (c) passes, or (a) fails.
- **Cost.** About 1 agent hour; about 10 minutes of simulator. No phone. Independent of E1 to E3.
- **Next.** The working way goes into the skill as a core rule at the top, with the two failures named.

## E5 (optional): the phone confirms the simulator

- **Question.** Does the E1 to E3 ranking hold on the iPhone 12?
- **What we run.** The E1 pair (and the E2 pair if its gap was under a third), three alternating quick passes each.
- **Deciding measure.** Hitch time ratio while flinging (Apple's measure from the tech talk 10855), median of three. Cold launch, stream hitches and memory are recorded alongside.
- **Expected.** Same order as on the simulator.
- **Proved wrong if** the order flips in all three passes.
- **Cost.** About half an agent hour; about 1.5 hours of phone time with someone at the phone (unlocked, kept awake, Settings > Developer > Enable UI Automation on, several GB free).
- **Next.** If the order holds, the skill keeps the simulator answer; if it flips, the phone wins and the skill says why. Skipped if E1 and E2 gaps were large.

## E6: write the skill

- **Question.** Can the answers become one short skill an agent reads once and follows?
- **What we write.** Skill `uikit-chat-list` in the skill repo: the whole recipe for this screen in the main file (list view, heights, stream updates, load older, jump, text size, rotation, text selection), a few references at most, and the shortcuts that do not count. It names APIs freely and says nothing about this benchmark, its numbers or its tests.
- **Deciding measure.** A separate reviewing agent traces every rule to an experiment answer or a citation in "Evidence: what Apple has published" below; no rule without one. Main file under about 2,000 words (agents read the main file and a few references in the first minute, then never return).
- **Expected.** Every rule traced.
- **Cost.** About 2 agent hours. No simulator, no phone.
- **Next.** E7 uses it.

## E7: validation builds

- **Question.** Do builds with the new skill pass more checks, at least as fast, than the Round 2 control?
- **What we run.** Two benchmark builds of the Campfire room with the new skill, UIKit in Swift, iPhone: Opus 5.5 and Sol, high effort, same start sentence, empty folder, no memory, 2-hour cap. The prompt is the Round 2 Swift prompt unchanged: it states outcomes and numbers only, never an API or framework name. The control is the Round 2 Swift builds already on record (our UIKit pair v0.3); they are not rebuilt.
- **Deciding measure.** Checks passed, of 13, run by us on the simulator after the agent stops. Then the simulator scorecard and one full iPhone 12 pass each.
- **Expected.** 13 of 13 for both, with text selection passing and numbers at or better than the Round 3 UIKit builds.
- **Proved wrong if** either build fails a check the skill covers.
- **Cost.** Two builds of up to 2 hours each (one at a time, or two simulators); about 1 hour of simulator scoring; about 1.5 hours of phone time (two full passes).
- **Next.** If both pass, a repeat pair shows whether it was luck; a failure goes back to E6 as a fixed rule.

## What we need from Fernando

A go for E1 (and E4 with it, since it stands alone). Each later experiment gets its own go, with the answer before it. E5 and E7 need someone at the iPhone 12.

## Evidence: what earlier rounds already tell us

Sources: `docs/results-round1.md`, `docs/results-round2.md`, `docs/optimal-gap-round2.md`, `docs/results-round3.md`, `runs/round3-*/verify.md`, the build source in `builds/`, and the run transcripts (`runs/<build>/transcript.jsonl` with `transcript.times`), read on 26 Oct.

- **No build has ever used a table view.** All ten UIKit builds (Rounds 1 to 3, Swift and Objective-C, Opus and Sol) chose a collection view. So the table view question has no data of ours yet; E1 supplies it.
- **Custom layout won over compositional layout.** Opus wrote a custom collection view layout with row heights computed and cached by message id in every round. Sol used the compositional layout with self-sizing cells in Round 2 (as our skill's first core rule says), then replaced it with a custom layout in Round 3 when told to make the build faster. Its own notes credit cached heights by id, a running index of heights for fast offset lookups, anchoring on the layout's own geometry and turning off automatic self-sizing invalidation.
- **The best numbers came from that shape.** Round 3, iPhone 17 simulator: the four UIKit builds reached 130 to 175 ms for the first 40 rows, 4.6 to 8.8 s of stream CPU, 32 to 42 ms for the jump and 44 to 58 MB peak memory. Two of the best rows bent the test (a stream redrawn only every 100 ms, a load older timer that covers part of the work; see `docs/results-round3.md`, "Bent rules"); the skill must say which shortcuts are not allowed.
- **Text selection is the check that fails.** In Round 2, 3 of the 4 UIKit builds failed it: a custom Copy and Reply menu replaced the system's own edit menu items, and a long-press menu on the whole bubble competed with selecting text (`docs/optimal-gap-round2.md`). Our skill already had the rule in a reference file that one of those agents read. It must be a core rule, stated once, at the top.
- **Stream handling.** The lowest Round 3 stream CPU (4.6 and 6.4 s, both Opus) came from batching streamed messages into one update every 100 ms, against 7.5 to 8.8 s for the Sol builds. Batching is fair as long as every message still shows up; the skill should say how far it may go.
- **Skills are read once.** Agents read the skill's main file and 1 to 6 references in the first minute and never return. Six of the 15 references and the whole iOS 27 skill were never read. A focused skill should fit in one file plus a few references, with the screen's whole recipe in the main file.
- **Memory.** Opus Swift went from 43.9 MB (Round 1, no skill) to 107.9 MB (Round 2, with skill) on the iPhone 12; the leanest builds (35 to 52 MB) kept few views alive and cached only measurements, not views or rendered text.

## Evidence: what Apple has published

Cited for the experiments and the skill; nothing is copied from Apple. Session numbers are Apple's WWDC session ids.

- **Collection view as the modern list.** WWDC20 "Lists in UICollectionView" (10026) presents list layouts in collection views as a replacement for most table view uses; WWDC20 "Modern cell configuration" (10027) brings content and background configurations to both table view and collection view cells. Apple's "Implementing modern collection views" sample code shows both.
- **Layouts.** WWDC19 "Advances in Collection View Layout" (215) introduces the compositional layout; Apple's article "Customizing collection view layouts" and WWDC18 "A Tour of UICollectionView" (225) cover writing a custom layout; the 2018 session shows caching computed attributes and invalidating only when the size changes.
- **Data and updates.** WWDC19 "Advances in UI Data Sources" (220) and WWDC20 "Advances in diffable data sources" (10045) cover diffable data sources for both views; WWDC21 "Make blazing fast lists and collection views" (10252) covers reconfiguring items instead of reloading them, cell registrations, prefetching and preparing images off the main thread.
- **Self-sizing.** WWDC22 "What's new in UIKit" (10068) adds automatic self-sizing invalidation for table view and collection view cells; the table view docs ("Estimating the height of a table's scrolling area") explain the cost of estimated heights.
- **Text.** WWDC21 "Meet TextKit 2" (10061) and WWDC22 "What's new in TextKit and text views" (10090) cover text views and layout; the `UITextViewDelegate` edit menu methods (iOS 16, and the multi-range form in the iOS 26 SDK) cover adding actions to the system menu.
- **Measuring.** the Apple tech talk "Explore UI animation hitches and the render loop" (2020, 10855) defines hitches and the hitch time ratio, and WWDC23 "Analyze hangs with Instruments" (10248) covers finding main-thread hangs; the first is what our iPhone 12 pass reads.

What the public record does not give: a measured table view against collection view comparison for a long, growing chat list with streaming rows and prepends. That is what E1 to E5 are for.

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
