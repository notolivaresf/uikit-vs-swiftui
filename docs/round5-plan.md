# Round 5: plan

> Fernando, 26 Oct: "For round 5, I'd like us to figure out what works and doesn't work with skills. For example, we will only do UIKit. Can we speed things up somehow? Can we polish the skills so it's more efficient? Can we get the architecture right? For example, we could reduce unit tests or build them at the end? Let's come up with a plan and a few hypotheses to figure this out."

Round 5 is UIKit only. It asks which parts of a skill make an agent build the same chat room faster, cheaper and right the first time. Each arm changes one thing against a control, and the score is read in a fixed order: checks passing first, then agent cost, then the app's own numbers on the iPhone 12. This page is the plan. Nothing here starts a build, an agent or a simulator; Fernando gives the go.

## What earlier rounds tell us

Sources: `docs/results-round1.md`, `docs/results-round2.md`, `docs/results-round2-handoff.md`, `docs/optimal-gap-round2.md`, `docs/results-round3.md`, `runs/round3-*/verify.md`, `docs/round4-results.md`, and the transcripts in `runs/<build>/transcript.jsonl` with their per-line clock (`transcript.times`). The time split below was read from the transcripts on 26 Oct: each tool call's own duration plus the thinking before it, grouped by what the call did. Sol (Codex) sometimes runs commands side by side, so its shares are approximate and can overlap.

### Agent cost of the UIKit builds (Swift and Objective-C, iPhone)

| Build | Skills | Wall time | Turns | Builds (failed) | Own test runs | Time in own test runs | First test activity | Output tokens (of which thinking) | Cost |
|---|---|---|---|---|---|---|---|---|---|
| round1-uikit-swift-opus | none | 2633 s | 75 | 22 (2) | 11 | 1124 s (43 %) | 1180 s | 143 k (77 k) | $7.57 |
| round1-uikit-swift-sol | none | 1200 s | 102 | 15 (3) | 10 | 534 s (45 %) | 347 s | 69 k (33 k) | not reported |
| round2-uikit-swift-opus | our pair | 2231 s | 95 | 12 (0) | 6 | 492 s (22 %) | 1510 s | 169 k (87 k) | $9.31 |
| round2-uikit-swift-sol | our pair | 1233 s | 90 | 14 (7) | 12 | 675 s (55 %) | 67 s | 62 k (28 k) | not reported |
| round2-uikit-objc-opus | our Objective-C pair | 2884 s | 106 | 12 (0) | 6 | 794 s (28 %) | 1567 s | 196 k (87 k) | $10.91 |
| round2-uikit-objc-sol | our Objective-C pair | 1297 s | 118 | 24 (8) | 20 | 924 s (71 %) | 228 s | 77 k (42 k) | not reported |

Round 3 (three hours to optimise, measuring through `./bench`): 4396 to 7572 s, 132 to 354 turns, 23 to 54 measuring requests per build; waiting on measuring passes was 29 to 79 % of the run. Round 4 (AppKit, no skills, Mac): 978 to 2570 s, 51 to 133 turns.

### What that says

1. **Testing is the biggest single cost.** The prompt never asks for tests, yet every UIKit agent wrote its own UI test suite and ran it 6 to 20 times. A full run of its own suite took 100 to 235 s. That is 22 to 71 % of wall time; writing app code (the edit calls and the thinking before them) is 5 to 18 %.
2. **Opus tests at the end, Sol throughout.** Opus's first test activity came 45 to 70 % into the run; Sol's in the first 1 to 6 minutes. Both reached the same checks, and Sol finished in about half the time. So "tests at the end" alone is not what makes a build fast; how long each run takes and how many there are matters more.
3. **Skills are read once, at the start, and only a few files.** Every skilled run read `SKILL.md` and 1 to 6 references in its first minute and never opened the skill again. Read at least once across all UIKit runs: `updates-and-scrolling`, `text`, `collection-layout`, `cells`, `layout`, `list-performance`, `diffable-data`, and in Round 3 `accessibility` and `concurrency`. Never read: `navigation-and-bars`, `dataflow`, `traits-and-environment`, `animation`, `interactions`, `deprecated-apis`. The iOS 27 skill was opened once (the first 80 lines of its `SKILL.md`, by Opus Swift) and never used: the app targets iOS 18. The installed pair is about 24,700 words; what was read is about 3,000 to 9,000.
4. **The one check skills kept failing is text selection, and the skill already had the rule.** In Round 2, 3 of the 4 UIKit builds (all but Opus Swift) failed selection, because a custom Copy and Reply menu replaced the system's own items (`docs/optimal-gap-round2.md`). The skill's `text.md` says to add actions to the suggested ones, and Sol read that file before failing. A rule buried in a reference is not enough; the checks caught it. In Round 3, with the 13 checks available through `./bench`, every UIKit build fixed it.
5. **The architecture that won is not the one the skill recommends.** The skill's first core rule is a compositional layout with a diffable data source. Both Sol builds followed it in Round 2; in Round 3 both replaced it with a custom collection view layout that caches row heights by message id and anchors on the layout's own geometry, which is what Opus had written from the start in both rounds. Round 3's numbers came mostly from that change plus coalesced stream updates and cached formatting.
6. **Fewer builds did not mean less time.** Opus with skills ran half the builds of Opus without (12 against 22) and saved 400 s; Sol ran about the same number either way. Most of the time was test runs, not compiles: all plain compiles of a run together took 11 to 75 s.
7. **Skills cost little and did not clearly help.** Round 1 against Round 2, same model and stack: Opus Swift 2633 to 2231 s, Sol Swift 1200 to 1233 s; one check gained, one lost; Opus's peak memory went from 43.9 to 107.9 MB. With one build per arm, none of these differences is outside noise.

### What we do not have

- **One build per arm.** No arm has been run twice, so we do not know how much a rerun of the same arm varies. Round 5 runs the control twice for that.
- **Tokens and test time are not in the records.** `meta.json` holds wall time, turns and build counts only. Tokens, cost, test runs and skill files read had to be dug out of transcripts by hand (Sol's cost is never reported by Codex). Round 5 adds them to the run record (see Measures).
- **No Round 3 phone numbers.** Round 3 was scored on the simulator only; fling, hitches and cold launch on the iPhone 12 are missing for it.
- **Time per phase is approximate.** The split above comes from tool-call clocks; it cannot tell reading the screenshots from thinking about layout.
- **The slim skill was never run.** `uikit-specialist-slim` (1,669 words) exists but no benchmark build used it.
- **Round 4 is AppKit, Mac.** Its numbers do not carry over to UIKit; it is only a hint that agents with no skills test less on the Mac.

## Goal

Find which skill changes make a UIKit build pass all 13 checks on the first try at less agent cost, without losing app speed, and fold the ones that work into the next skill version (`uikit-specialist` v0.5).

## Hypotheses

Each hypothesis changes one thing against the control (C: the Round 2 set-up, our Swift pair v0.3, the Round 2 prompt). "Agent cost" means wall time first, then turns, builds and output tokens. With two runs of the control per model, a change counts only when it is larger than the gap between those two runs.

| | What we change | Measure that should move | By how much | It is false if |
|---|---|---|---|---|
| H1. Trimmed skill | Ship only `SKILL.md` and the seven references agents read (scrolling, text, collection layout, cells, layout, list performance, diffable data); drop the iOS 27 skill and the unread references | Input tokens and time to first code; checks unchanged | Skill words read down by at least half; checks the same as C | Checks drop below C, or the agent goes looking for a missing topic (searches, web) and wall time rises |
| H2. A recommended architecture | Add a short "chat and feed lists" section at the top of `SKILL.md`: custom layout with heights cached by id, anchor on layout geometry for prepend and rotation, coalesce stream updates, keep the system text menu and add to it. Move the text-menu rule from `text.md` into the core rules | First-pass app numbers and checks | 13 of 13 on the first build of both models; first 40 rows, jump, load older and stream CPU within 15 % of the best Round 3 build on the same simulator | Either model still fails selection, or the first-pass numbers are no closer to Round 3 than C's |
| H3. The checks come with the folder | Put the 13 checks in the build folder as one command (the Round 3 `./bench`, simulator only); the prompt says the command exists and what it reports | Time in self-written test runs; checks passed | Self-written test time down by at least half; wall time down 25 %; 13 of 13 for both models | The agent writes its own suite anyway, or waits on `./bench` so long that wall time does not drop |
| H4. Tests once, at the end, small | The skill's "How to work" says: build the screen and check it by eye on the simulator first; then write one UI test file, one test per behaviour, and run it once or twice | Number of test runs and time in them | Test runs at most 3; test time under 20 % of wall time; wall time down 25 % against C | Checks drop below C, or the agent finds bugs late and wall time rises |
| H5. Build once, test many | The skill's "How to work" says: compile the tests once and rerun only the failing test after each change (build-for-testing, then test-without-building with a single test selected), and keep one simulator booted | Seconds per test run; total time in test runs | Median test run under 60 s (from 100 to 235 s); total test time down a third | Runs are no shorter (the cost is launching the app, not compiling), or the agent reruns everything anyway |
| H6. Parallel work (stretch) | The skill suggests a helper agent writes the UI tests while the main agent writes the app | Wall time; tokens | Wall time down 20 %; tokens may rise up to 50 % | Wall time does not drop, or the two halves disagree and the agent spends the saving reconciling them |

H4 and H5 overlap on purpose: H4 tests *when and how many*, H5 tests *how long each one takes*. Insight 2 says the second may matter more. H6 is last because it needs a second simulator per build, which halves how many builds can run at once; it runs only if the core arms finish in time.

All changes in H1, H2, H4, H5 and H6 live in the skill, which may name frameworks and calls. The benchmark prompt keeps its rule: it states outcomes and numbers only, never an API or framework name. H3's one prompt line names the command and what it reports, nothing else.

## Build matrix

UIKit in Swift only, iPhone, iOS 18 target. Models: Opus 5.5 and Sol, each at high effort, as in Rounds 1 to 3. Objective-C stays out unless Fernando wants it: it doubles the builds and Round 2 showed the same patterns in both languages.

| Arm | Skill | Prompt | Opus | Sol | Builds |
|---|---|---|---|---|---|
| C1, C2. Control, twice | our pair v0.3 (as Round 2) | Round 2 Swift prompt | 2 | 2 | 4 |
| T. Trimmed (H1) | v0.5-trim | same | 1 | 1 | 2 |
| A. Architecture (H2) | v0.3 + architecture section | same | 1 | 1 | 2 |
| K. Checks in the folder (H3) | v0.3 | same + one line about `./bench` | 1 | 1 | 2 |
| E. Tests at the end (H4) | v0.3 + test-at-end lines | same | 1 | 1 | 2 |
| B. Build once, test many (H5) | v0.3 + build-once lines | same | 1 | 1 | 2 |
| P. Parallel (H6, stretch) | v0.3 + helper-agent lines | same | 1 | 1 | 2 |
| X. Combined (after the others) | v0.5: every change that won | same | 1 | 1 | 2 |

14 core builds, 16 with the stretch arm, 18 with the combined arm. Each skill variant is a tag in `uikit-skill` (for example `v0.5-trim`, `v0.5-arch`), vendored into `skills/` here with its hash, so every build records exactly what it had. The combined arm is decided after the core results, not before.

Every build starts the same way as Round 2: an empty folder with `PROMPT.md`, `CampfireKit`, `Fixtures`, `screenshots` and the skills; the one sentence "Read PROMPT.md in this folder and do what it says. Work alone until the app is done; do not ask questions."; no memory, project settings only. A 2-hour cap per build (Round 2's slowest UIKit build took 48 minutes), recorded as `stopped_by_limit`.

## Measures, in order

1. **Checks.** The 13 checks (stack rule plus the 12 numbers of `PROMPT.md`), run by us on the simulator with the Round 3 harness after the agent stops, then confirmed on the iPhone 12. A build that fails a check loses to one that passes, whatever its cost.
2. **Agent cost.** Wall time; turns; Xcode builds and failed builds; own test runs, their count and seconds; output tokens (thinking separately), input and cache tokens; cost in dollars where the tool reports it; skill files read. Added to `meta.json` by a small reader of the transcript (the counting done by hand for this page), written and tested before the first build.
3. **App numbers, simulator.** The Round 3 `./bench` scorecard: first 40 rows cold and repeated, stream CPU, jump, load older, text size at the bottom and mid-list, peak memory, app size. Same simulator model and runtime as Round 3, so the numbers line up with its best builds.
4. **App numbers, iPhone 12.** The full harness pass (`record.sh`, Instruments): cold launch, fling frames per second and hitches, stream hitches, memory. Final score.

A build "wins" its arm's hypothesis only when its model's two control runs are both worse by more than they differ from each other.

## Run logistics

- **Simulators during agent runs.** Two kept simulators, `uvs-r5-a` and `uvs-r5-b` (same model and iOS as Round 3), made with `Harness/sims.py ensure` through `simcap ensure`. At most 2 booted at once on the Max, including any other lane's; never deleted or erased; shut down when the round ends.
- **Two builds at a time**, the same arm for Opus and Sol, one simulator each, so both see the same load. The stretch arm (P) runs alone, since it may need both simulators.
- **Sandbox and audit as in Round 3**: each agent sees only its folder; `round3-guard.py`, `round3-audit.py` and the lock checks run unchanged. Arm K also uses the measuring broker (`bench-broker.py`), started before the pair.
- **Builds go through `buildslot`**, as in every round, so measuring passes never overlap a compile.
- **iPhone 12 for the final score**, one build at a time, after all agent runs. Someone has to be at the phone: unlocked, kept awake, Settings > Developer > Enable UI Automation on, several GB free (the Round 2 attempts stopped on automation timeouts and a full phone).
- **Xcode**: the version used for Rounds 1 to 3 for building, recorded in each `meta.json`.
- **Time**: about 7 pairs at up to an hour each for the core arms, plus about 10 minutes per build on the simulator and about 45 minutes per build for the full phone pass.
- **Quota**: Sol runs use a shared Codex account; check its quota before each Sol pair.

## Before the first build

1. Write the transcript reader that adds tokens, test runs, test time and skill files read to `meta.json`; check it gives the numbers in the table above for the Round 2 runs.
2. Cut the skill variants in `uikit-skill` (one tag each), vendor them here with hashes, and add each arm to `Harness/skillset.py` and the launcher.
3. Prepare arm K's folder layout (the Round 3 `./bench` and broker, without a baseline scorecard).
4. Dry run every arm (`--dry-run`) and show the prompts and skill lists for review.
5. Wait for Fernando's go.
