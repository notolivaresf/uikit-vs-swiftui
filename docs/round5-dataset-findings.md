# Round 5: what the Rounds 1 to 4 dataset says about a UIKit chat-list skill

> Fernando, 26 Oct: "We should use the huge dataset we have already. We have complete freedom of having one massive skill, many small ones, any mix of them. I'm happy if we even end up with an agent itself. Or two."

This is step E6's groundwork in [round5-plan.md](round5-plan.md). It mines every build of Rounds 1 to 4 for the skill: their source, the agents' transcripts, the harness results, the Round 3 notes and the Round 2 to Round 3 diffs. Nothing was rebuilt or measured for this page. The spikes in `spikes/round5/` (E1 to E4) are not covered here; section 4 says where their answers plug in.

**Sources.** The numbers come from [results-round1.md](results-round1.md), [results-round2.md](results-round2.md), [optimal-gap-round2.md](optimal-gap-round2.md), [results-round3.md](results-round3.md), [results-l2-avdlee.md](results-l2-avdlee.md), [round4-results.md](round4-results.md) and `runs/round3-*/verify.md`. Code is in `builds/<build>/Campfire/<file>:<line>`, and the agents' own notes are in `builds/round3-*/NOTES.md`. Agent behaviour comes from `runs/<run>/transcript.jsonl` with `transcript.times` (kept locally, not committed). The source reads were done by four reading agents on 26 Oct, and a sample of their line references was checked by hand.

**Read the numbers with these limits.**

- Every build has one measured pass, so a few ms is noise.
- Rounds 1 and 2 ran on the iPhone 12 (marked **dev**). Round 3 ran on the iPhone 17 simulator (marked **sim**). The two are never compared with each other.
- Round 4 is the Mac.
- Short names: O1/O2/O3 are `round{1,2,3}-uikit-swift-opus` and S1/S2/S3 are `round{1,2,3}-uikit-swift-sol`. OC2/OC3 and SC2/SC3 are the Objective-C (`uikit-objc`) builds by Opus and by Sol.

**A finding about the measurements themselves.** Every timing row (first rows, jump, load older, text size) is the app's own ms label. Each build wrote its own timing code, and Round 3 pinned it as it was in Round 2. The two models wrote different clocks:

- **Opus builds** start the clock at the touch's own timestamp and stop it at the next display-link frame. See `round3-uikit-objc-opus/Campfire/CFRoomViewController.m:821` (`touchUpTimeForEvent:`) and `:918-931`.
- **Sol builds** start the clock inside the button action and stop it in the update's completion, before any frame is drawn. See `round3-uikit-objc-sol/Campfire/CFRoomController.m:188`, `:256`, `:262` and `round3-uikit-swift-sol/Campfire/RoomViewController.swift:298`, `:370`, `:435`.

The prompt asks for touch up until the rows are on screen (PROMPT.md:51). O3's notes measured what the Sol clock leaves out: 5 to 21 ms of event delivery plus 13 to 28 ms waiting for the first frame. So a comparison between a Sol build and an Opus build on these rows favours Sol by up to about 20 to 45 ms. Comparisons within one build, before and after, are fair. This is bigger than the two "Bent rules" in results-round3.md. The spikes avoid it by sharing one debug bar, and the skill should state the correct clock if it says anything about timing (section 1.10).

## 1. Per behaviour: what the best and worst builds did

The shape every fast UIKit build converged on is a collection view (or a plain scroll view) whose layout object holds exact, precomputed row frames, with heights measured once per message and kept by message id. **No build in any round used `UITableView`, `NSTableView` or `NSCollectionView`.** On iOS, all ten UIKit builds used `UICollectionView`, except OC3, which replaced it with its own `UIScrollView` recycler. On the Mac, all four AppKit builds tile their own row views in an `NSScrollView`. So the table view question has no data of ours; E1 supplies it.

### 1.1 Live stream: 600 messages at 20 a second, pinned to the bottom

| Build | Approach | Stream CPU |
|---|---|---|
| S1 | Custom layout, one rebuild per message, no batching | 11.7 s dev (best dev) |
| O1 | Custom layout, one `insertItems` per message (`RoomViewController.swift:272-298`), no batching | 11.8 s dev |
| S2 | Compositional layout, **one section per message**, diffable snapshot of every section on each 80 ms flush; every loaded row's `LayoutKey` compared each time (`RoomViewController.swift:75-81`, `:207-227`) | 12.0 s dev, 9.8 s sim |
| O2 | Diffable data source plus 50 ms coalescing (`RoomViewController.swift:378`), but `prepare()` recomputes every frame on each invalidation (`RoomLayout.swift:22-46`) | 12.2 s dev |
| SC2 | Per message: capture the anchor, measure, build a full snapshot of N sections, `invalidateLayout`, `layoutIfNeeded` twice (`CFRoomController.m:165-181`, `:263-276`) | 18.7 s dev, 15.6 s sim (worst UIKit) |
| S3 | One section, custom `RoomRowsLayout` over a Fenwick height index (`MessageLayout.swift:233-343`), `selfSizingInvalidation = .disabled` (`RoomViewController.swift:71`), `reconfigureItems` only for changed ids, incremental layouts (`:189-235`) | 7.5 s sim (clean best) |
| SC3 | One section, `CFChatLayout` over a treap of heights, explicit `insertItemsAtIndexPaths:` and `reconfigureItemsAtIndexPaths:` in `performBatchUpdates` | 8.8 s sim |
| O3 | Incremental frames (`RoomLayout.swift:31-43`), id-merge inserts, **100 ms coalescing** (`RoomViewController.swift:494`) | 6.4 s sim (bent) |
| OC3 | `UIScrollView` recycler (`CFRoomViewController.m:558-615`), append lays out only the new rows (`:377`), **100 ms flush and 100 ms label throttle** (`:794`, `:935-945`) | 4.6 s sim (bent) |

What moved the number:

- **Cost per update matters, not update count.** On the phone, the uncoalesced O1 and S1 (11.7 to 11.8 s) cost the same as the coalesced O2 and S2 (12.0 to 12.2 s).
- **Section count and full-list work are the cost.** Going from one section per message to one section took S3 from 9.7 to 7.4 s (S3 NOTES) and SC3 from 15.5 to 9.6 s.
- **The wider window is part of the bent result.** In O3, widening the window from 50 to 100 ms accounts for about 0.7 s of its 1.8 s drop (O3 NOTES).
- **The collection view's own overhead.** OC3's notes put batch-update bookkeeping at about 7 ms per live update. Dropping the collection view, plus fitting the label font once instead of `adjustsFontSizeToFitWidth` (about 1.3 s), and the 100 ms flush together gave 8.4 → 4.6 s. These were not separated.
- **Pinning** is the same in every build: read "pinned" before the update, then set the offset after it (O1 `:291-292`; S3 `restore(anchor)` at `:338-355`).

**Transfers from other stacks.**

- **SwiftUI.** The lever is laziness. Round 2 SwiftUI used a plain `VStack` and every row reported its frame and could start a scroll correction: 425 and 242 hitches (dev). Round 3 Opus switched to `LazyVStack` and stream CPU fell 30.7 → 9.9 s sim. The UIKit translation is to never lay out or compare the whole loaded window per message, and never observe per-row geometry.
- **Mac.** AppKit ObjC Sol rebuilt all 300 layouts per message, and its lookup by id was a linear scan (`mac/round4-appkit-objc-sol/Sources/RoomController.m:95-108`). Its stream hitch was 3,533 ms, against 242 ms for AppKit Swift Opus, which appends one item and restores the anchor (`mac/round4-appkit-swift-opus/Campfire/RoomController.swift:437-447`).

### 1.2 First 40 rows at launch

| Build | Approach | First 40 rows, cold |
|---|---|---|
| OC2 | Data generated on a user-interactive queue started from `main.m` (`CFLaunch.m:7-13`); 40 rows laid out on main | 158 ms dev (best dev) |
| O1 | Data on a background thread; plain cells | 172 ms dev; cold launch 596 ms (best) |
| O2 | Same as O1, plus five icons created per cell, a code highlighter and image decode (`MessageCell.swift:19-25`, `Views.swift:117-121`) | 252 ms dev (worst UIKit); cold launch 843 ms |
| S3 | Dataset generation moved before `UIApplicationMain` (`main.swift:7-10`); timestamp strings cached by minute; patterns compiled once | 195 → 130 ms sim (best sim) |
| OC3 | Store, first page and 40 row layouts built in the background, with width and text size **saved in user defaults from the last launch** (`CFLaunch.m:14-30`); rarely used cell subviews created lazily (`CFMessageCell.m:117-149`) | 165 → 135 ms sim (carried state) |
| SC2/SC3 | Data loaded from `viewDidLoad` (starts later); a revision guard skips cell rebuilds (`CFMessageView.m:52-54`) | 175 → 161 ms sim (worst sim) |

**Transfer.** SwiftUI Round 3 Opus went from 583 to 181 ms sim just by making the list lazy.

**Rule from this.** Start building the data before the first view controller loads. Build nothing per cell that most rows do not show. A guessed width is fine only if it is checked against the real one; O3 throws its prefetch away when the width differs (`RoomStore.swift:47-52`).

### 1.3 Jump to message 2,500

| Build | Approach | Jump |
|---|---|---|
| O1 | `reloadData` of a fresh window, offset from the layout's own frames (`RoomViewController.swift:243-259`) | 52 ms dev (best dev) |
| OC2 | Loads 81 rows around the target, measured serially (`CFRoomViewController.m:775-787`) | 67 ms dev |
| O2 | Same as O1, but each text measured twice (`RowLayout.swift:238`, `:243`, `:299`, `:307`) | 90 ms dev |
| SC2 | 81 rows plus an 81-section snapshot | 109 ms dev (worst UIKit) |
| S3 | `applySnapshotUsingReloadData` (`RoomViewController.swift:320`), then `scrollToItem(..., .top)` (`:347`) | 38 → 32 ms sim |
| O3 | Offset placed by arithmetic before layout (`:417-421`) | 60 → 41 ms sim |
| OC3 | One page, 10 rows above and 29 below (`CFRoomViewController.m:16`, `:842-857`) | 37 → 40 ms sim (no gain: the floor is outside the app) |

**Common mistake.** Landing one row off ("2499 not 2500"), seen in O2 at minute 28.8 and SC2 at minute 6.2. The old skill's fix (scroll, `layoutIfNeeded()`, scroll again; `updates-and-scrolling.md:150`) covers `scrollToItem` only. With a custom layout the offset comes from the layout's frame for the target row.

**Transfer.** SwiftUI Round 3 Opus reached 19 ms sim by realizing the target row by id and then setting an exact y (`round3-swiftui-opus/Campfire/RoomView.swift:79-92`). The AppKit tilers took 15 to 33 ms on the Mac. AppKit ObjC Opus binary-searches its row tops (`mac/round4-appkit-objc-opus/App/CFRoomView.m:135-143`).

### 1.4 Load older, keeping the place

Every passing build anchors the same way: remember the top visible row's id and its offset, then put it back after the insert. Drift was at most 0.3 pt in every UIKit build. What varies is how much work the insert does.

| Build | Approach | Load older |
|---|---|---|
| OC2 | Batch insert, but `rebuildFrames` walks every loaded row (`CFRoomViewController.m:351-385`) | 34 ms dev (best dev) |
| S1 | Custom layout, id diff | 61 ms dev |
| O2 | Diffable; every frame recomputed | 93 ms dev |
| SC2 | **Re-measures every loaded row, up to 300**, not just the 40 new ones (`CFRoomController.m:156-161`, `:243`) | 106 ms dev (worst) |
| O3 | Offset supplied from `targetContentOffset(forProposedContentOffset:)` (`RoomLayout.swift:122`) and placed before layout (`RoomViewController.swift:241`), so no cells are made for the wrong place first | 55 → 39 ms sim |
| S3 | `layoutAttributesForElements` plus `setContentOffset` (`:327-355`) | 33 → 31 ms sim |
| SC3 | Measures only the new page (`CFRoomController.m:160`), prepends to the height tree | 59 → 4 ms sim (short clock and a timer covering part of the work: bent) |
| OC3 | Next older page prefetched and laid out in the background (`CFRoomViewController.m:650-670`) | 41 → 42 ms sim (no gain on this clock) |

**The bug that cost the most debugging time.** When rows are removed or heights shrink, UIKit animates the content offset back into range. That undoes the anchor or the pin.

| Build | When it appeared | Time to fix | Fix |
|---|---|---|---|
| OC2 | minute 32 | about 7 min | swizzled the scroll methods to find it |
| O3 | minute 65.8 | 14 min | |
| SC3 | 35.5 to 55.0 | about 20 min | intermittent Reset failures |

The fix in every case: supply the final offset from `targetContentOffset(forProposedContentOffset:)`, or set it before layout; use `reloadData` rather than an animated batch for removals (O3 NOTES). The old skill does not mention `targetContentOffset` anywhere.

**Transfer.** AppKit ObjC Opus reached 9 ms on the Mac with the anchor kept as a message id plus a fractional offset.

### 1.5 Text size change, at the bottom and mid-list

| Build | Approach | Text size, bottom / mid-list |
|---|---|---|
| S1 | Own size index, re-measure, `reloadData` | 51 / 70 ms dev (best dev) |
| S2 | Same, compositional | 53 / 70 ms dev |
| O1 | `traitOverrides.preferredContentSizeCategory` on the window (`RoomViewController.swift:360-372`) | 63 / 74 ms dev |
| OC2 | Serial `rebuildFrames`, `reloadData`, two `layoutIfNeeded`; every visible text view's `attributedText` set again (`CFMessageCell.m:254`) | 77 / 93 ms dev |
| O2 | Same as O1, measuring twice | 83 / 103 ms dev (worst UIKit) |
| S3 | `refreshHeights` with the anchored offset from `targetContentOffset(forProposedContentOffset:)` | 20 → 18 / 31 → 30 ms sim |
| SC3 | Same idea | 18 → 12 / 41 → 23 → 21 ms sim (Sol clock) |
| O3 | Rows laid out in parallel with `DispatchQueue.concurrentPerform`, one measurer per worker (`RowLayout.swift:144-160`); measures once when the natural width fits (`:335`) | 49 → 44 / 67 → 42 ms sim |
| OC3 | Bodies drawn from a pre-measured TextKit 1 layout, a real `UITextView` swapped in from `hitTest:` (`CFMessageCell.m:50-176`, about 130 lines) | 44 → 46 / 45 → 44 ms sim |

Notes on what the numbers show:

- **Every build re-measures the whole loaded window on a size change** (O3 `rowCache.removeAll()` at `:168`; S3 `rowLayouts.removeAll()` at `:199`). Measuring only what changed, and measuring each text once, is what separates them.
- **OC3's text-view swap removed 9 of 10.5 ms of app work in its notes and moved the reported number by nothing.** Most of the reported time is outside the app.
- **Transfer.** SwiftUI's best (Round 1 Opus, 35 / 54 ms dev; Round 3 Opus, 8 ms sim at the bottom) came from laying out only the visible rows. AppKit ObjC Opus did 9 / 10 ms on the Mac with hand-drawn text.

### 1.6 Rotation

All UIKit builds pass, with drift at most 0.2 pt, using one of two equal methods:

- Capture the anchor in `viewWillTransition(to:with:)` and restore it in `animate(alongsideTransition:completion:)` (Sol builds; OC2 `CFRoomViewController.m:270-288`).
- Restore it when `viewDidLayoutSubviews` sees a new width (O1 `:71-100`, O3 `:114-145`).

No ranking is possible from the data. On the Mac, every build measured an 8 ms resize hitch, and the resize checks failed on every build (probably a harness fault, round4-results.md).

### 1.7 Text selection and the context menu

The check that failed most, and the clearest rule in the dataset.

- **Round 1.** O1 failed: it returned a fresh menu plus its own `UIEditMenuInteraction` (`MessageCell.swift:62`, `:215-235`). S1 passed: it kept the system sub-menus (`[copy, reply] + suggestedActions.filter { $0 is UIMenu }`, `MessageCell.swift:187`).
- **Round 2.** 3 of 4 UIKit builds failed:
  - S2 returned `UIMenu(children: [copy, reply])` (`round2-uikit-swift-sol/Campfire/MessageCell.swift:19-26`).
  - OC2 and SC2 did the same in Objective-C (`CFMessageCell.m:351-376`, `CFMessageView.m:255-260`).
  - Only O2 passed. It inserts Reply right after the system's Copy in `suggestedActions` (`round2-uikit-swift-opus/Campfire/MessageCell.swift:191-209`).
- **Round 3.** All three that had failed fixed it the same way: `UIMenu(children: [reply] + suggestedActions)`, Reply first, from both `textView(_:editMenuForTextIn:suggestedActions:)` and the iOS 26 `textView(_:editMenuForTextInRanges:suggestedActions:)` (S3 `MessageCell.swift:24-29`, OC3 `CFMessageCell.m:378-391`).
- **Why first.** With Reply appended at the end, it lands on the edit menu's second page. O2 found this from its own failing test at minute 25.2 and fixed it at 30.9. OC3's notes say Reply goes first "so it stays on the menu's first page".
- **The old skill teaches the losing form.** Both of its examples append (`skills/uikit/uikit-specialist/references/text.md:86`, `interactions.md:63`: `suggestedActions + [quote]`). text.md was read by all three Round 2 builds that failed.
- **The bubble's context menu** is a `UIContextMenuInteraction` that returns nil over the text (O2 `MessageCell.swift:63`; S2/S3 attach it to the meta line, placeholder and file label instead, `:91-99`). A long-press recognizer on the whole bubble competes with selection (optimal-gap-round2.md).
- **Transfer.** No SwiftUI skill fixed this. SwiftUI Round 3 Opus passed with a read-only `TextEditor` laid over the text (`round3-swiftui-opus/Campfire/Selection.swift:57`, `:81`). It also passed the stack rule only by deleting `import UIKit` while still using `UIPasteboard` through the SwiftUI import. In UIKit it is a one-line fix.

### 1.8 Peak memory

| Build | Approach | Peak memory |
|---|---|---|
| SC2 | Solid-colour placeholders, trims to 300 rows | 35.0 MB dev (best) |
| S1 | Placeholder as `backgroundColor` (`MessageCell.swift:139-140`) | 39.7 MB dev |
| O1 | Same | 43.9 MB dev |
| S2 | Same | 44.5 MB dev |
| OC2 | Decoded thumbnails in an `NSCache` with a 64 MB cost limit; unbounded layout cache and item list (`CFMessageCell.m:21-22`, `CFRoomViewController.m:111-113`) | 52.0 MB dev |
| O2 | Placeholder rendered to PNG, decoded at up to 1200 × 900 with `preparingForDisplay()`, kept in an **uncapped** `NSCache` (`MessageCell.swift:238-261`) | 107.9 MB dev (worst UIKit) |
| O3 | Went back to a solid colour (`MessageCell.swift:133-140`) | 117.6 → 53.9 MB sim |
| OC3 | Filled view, layout kept on the item | 67.9 → 52.8 MB sim |

**The skill regressed memory once.** O1 had 43.9 MB without the skill; O2, with it, cached full-size decoded images (the old skill's `list-performance.md` teaches decoding and caching, not "don't make bitmaps you don't need").

**Transfer.** Non-lazy SwiftUI lists reached 215 MB (iOS, dev) and 217 MB (Mac). The lean builds keep few views alive and cache measurements, never views or rendered text.

### 1.9 App size

All the Round 3 gains are build settings, not code. Release `STRIP_INSTALLED_PRODUCT`, `STRIP_STYLE: all`, `DEPLOYMENT_POSTPROCESSING` and `DEAD_CODE_STRIPPING` in `project.yml` took:

- O3 from 1.34 to 0.84 MB (`round3-uikit-swift-opus/project.yml:37-43`).
- S3 from 1.20 to 0.79 MB.
- OC3 from 1.18 to 0.71 MB.

SC2/SC3's 2.7 to 2.8 MB is a 2.1 MB uncompressed app icon. The agent fetched it with `curl` mid-run.

### 1.10 The shortcuts the skill must name as not allowed

These come from results-round3.md "Bent rules", the verify notes and the readers above. Each makes a row read better without doing the work faster:

- Redrawing the stream only every 100 ms, and throttling the state label to 100 ms (O3, OC3).
- Timing only part of load older (SC3).
- Starting the clock inside the action instead of at touch up, or stopping it before the frame is drawn (every Sol build, inherited from Round 2).
- Laying out the first page from geometry saved by the previous launch (OC3).
- Skipping work when Reset follows Reset (SC3, `CFRoomController.m:245-249`).

The skill states the rule (apply every message as it arrives, or in batches no wider than one frame; time from the touch's timestamp to the next frame), not the benchmark.

### 1.11 What the old skill told agents that the evidence contradicts

This skill is the vendored `skills/uikit/uikit-specialist`, v0.3-pair. None of these lines should carry over:

| Old skill says | The evidence |
|---|---|
| "Lists and grids: `UICollectionView` with a compositional layout and a diffable data source" (SKILL.md, first core rule) | Only S2 and SC2 followed it, and both were then rewritten in Round 3 to one-section custom layouts, for their largest gains (stream 9.8 → 7.5 s, 15.6 → 8.8 s). |
| "Do not ... write a custom `UICollectionViewLayout` unless the layout cannot be described with items, groups and sections" (`collection-layout.md:21`) | Eight of ten UIKit builds wrote one. They include every build that led a row. |
| "Do not measure cells by hand ...; let self-sizing measure" (`list-performance.md:146`) | Every UIKit build measured by hand and cached by id. S3 turned self-sizing invalidation off. E2 tests whether that is worth it. |
| `UIMenu(children: suggestedActions + [quote])` (`text.md:86`, `interactions.md:63`) | Appended items fall to the second page. The passing form puts the item first. |
| Nothing on `targetContentOffset(forProposedContentOffset:)`, on section count, or on not rebuilding the whole snapshot per update | These were the three costliest gaps (sections 1.1, 1.4, 2.2). |

## 2. Agent behaviour

### 2.1 Skills are read once, in the first two minutes, and mostly not past the main file

The old skill is SKILL.md (949 words) plus 15 references (about 16,200 words), and a second skill, `uikit-whats-new-27` (817 words plus 10 references).

| Run | When SKILL.md was read | References opened | Never opened |
|---|---|---|---|
| Round 2, Opus Swift | 0.4 min | 1 (updates-and-scrolling), plus a grep in text.md | 13 |
| Round 2, Sol Swift | 0.1 min | 6 in one `cat` at 0.3 min | 9 |
| Round 2, Opus ObjC | 1.1 min | 2 | 13 |
| Round 2, Sol ObjC | 0.1 min | 5 at 0.2 min | 10 |
| Round 3, Opus Swift | 0.0 min (the main file only) | 0 | 15 |
| Round 3, Opus ObjC | **never** | 0 | 15 |
| Round 3, Sol Swift | 0.1 min | 5 in the first 1.5 min; came back for 2 at 30.9 and 44.8 min | 8 |
| Round 3, Sol ObjC | 0.2 min | 4 by 1.8 min | 11 |

What this shows:

- **Opus reads 0 to 2 references per run; Sol reads 4 to 6.**
- **Only one run ever came back.** Round 3 Sol Swift, and only for concurrency and accessibility.
- **Never opened in any UIKit run:** interactions (which held the second edit-menu example), animation, navigation-and-bars, dataflow, traits-and-environment, deprecated-apis, and all of `whats-new-27` beyond one `head -80`.
- **No docs or web.** No UIKit run used the web. Sol grepped SDK headers (`UITextView.h`, `UICollectionView.h`, `targetContentOffset`, `SelfSizingInvalidation`) for names it already knew.
- **The one file every agent saw was the main file's core rules,** and its first rule pointed the wrong way (section 1.11).
- **Contrast on the SwiftUI side.** Sol with AvdLee read about 10 references in its first minute. AvdLee's Opus build used `LazyVStack` (its checklist says "Large lists use LazyVStack", `skills/avdlee/swiftui-expert-skill/references/performance-patterns.md:393`) and beat Apple's skills on 6 of 9 simulator rows. That is the one case where a skill line visibly changed the shape of a build. It cost 4.3× the wall time.

### 2.2 Wrong first, fixed later

| Mistake | Where and when | Cost | Old skill had the rule? |
|---|---|---|---|
| Custom menu replaces the system's, or Reply appended to page two | S2, OC2, SC2 shipped it; O2 at 25.2 → 30.9 min; S3, OC3, SC3 each spent 5 to 11 min plus a 4-min bench run fixing it | 3 of 4 Round 2 failures; about 25 agent minutes in Round 3 | Yes, with the wrong example; text.md read by every build that failed |
| Offset animated back after removal or shrink, undoing anchor or pin | OC2 32 min, O3 65.8 min, SC3 35.5 to 55 min | about 7, 14 and 20 min | No |
| One section per message, whole snapshot per batch | S2, SC2 shipped it | the largest stream CPU gap among UIKit builds | No; the core rule led there |
| Jump lands one row off | O2 28.8 min, SC2 6.2 min | about 2 min each | Partly (`scrollToItem` only) |
| Measuring every text twice | O2 shipped it (`RowLayout.swift:238-307`) | an estimated 15 to 40 ms on load older and text size (optimal-gap-round2.md) | No |
| Full-size decoded image cache | O2 shipped it; fixed in O3 | 64 MB | No; the reference teaches caching |
| Sliver of a pixel after a jump; anchor read from stale cached attributes | S3 43.7 and 57.9 min | about 14 min | No |

Round 2 → Round 3 in one line: the three-hour pass fixed the menu (3 builds), went to one section with a custom layout (2 Sol builds), set offsets before layout (O3), removed bitmap caches (O3, OC3), made list changes cost only the changed rows (all four), and stripped Release builds (all four). Two Opus builds also took the 100 ms shortcut.

### 2.3 Time sinks

From the transcripts. "Tests" is time in the agent's own test runs; the prompt never asks for tests.

| Run | Wall | Own tests | Notes |
|---|---|---|---|
| Round 1, Opus | 43.9 min | 18.7 min (43 %) | first code at 13.0 min |
| Round 1, Sol | 20.0 min | 7.8 min | |
| Round 2, Opus Swift | 37.2 min | 8.2 min | 10.7 min measuring screenshots pixel by pixel before the first line of code; first own test at 25.2 min (68 %) |
| Round 2, Sol Swift | 20.5 min | 10.4 min (51 %) | code at 1.9 min; 12 test runs |
| Round 2, Opus ObjC | 48.0 min | 13.2 min | 11.4 min on screenshots; first test at 26.2 min |
| Round 2, Sol ObjC | 21.6 min | 14.4 min (67 %) | about 20 test runs |
| Round 3, four UIKit runs | 73 to 126 min | none | 64 to 87 % of wall time inside `./bench` (build, install, measure, queue) |

The time went to six things:

- **Screenshot measuring.** Opus spends 10 to 11 minutes (24 to 28 % of the run) measuring the reference screenshots, even after reading `Fixtures/constants.json`, which already has the numbers. Sol starts code within 2 minutes.
- **Own tests.** Sol's "7 of 14 failed builds" in Round 2 are test runs, not compile errors. Only one was a real build error (a Swift 6 data-race error in its own UI-test class). The rest were:
  - state-label wait time-outs;
  - a test tapping before rotation finished;
  - its own geometry assertions.

  SC2's failures are the same mix, plus one compile error and an app-icon asset error.
- **Results bundles.** Five turns across two Sol runs went to `xcresulttool export` on a results bundle that did not exist.
- **Stale installs in Round 3.** In all four Round 3 UIKit runs a quick `./bench <row>` measured the previously installed app. The runs noticed at minutes 4.2, 17.4, 22.3 and 63.9. Round 3 Sol Swift judged three anchor "fixes" on identical stale numbers. This is a harness fault, not a skill gap.
- **Dead experiments in Round 3.** These were measured and reverted:
  - pre-rendered images and commit-timing ideas (OC3);
  - text-view pooling and direct configuration updates (SC3);
  - a split history and moving invalidation first (S3).
- **The Mac contrast.** AppKit builds wrote no test loop: Opus 36.5 min, Sol 24.7 min. SwiftUI with AvdLee (Opus) ran 307 min, 174 of them in tests.

### 2.4 Mistakes the skill could have prevented

Ordered by cost:

1. **Edit menu: Reply first, system items kept.** Prevents the single most common failure (5 of 6 Round 2 builds across stacks, 3 of 4 UIKit) and about 25 minutes of Round 3 time.
2. **Removal or shrink: give the final offset through `targetContentOffset(forProposedContentOffset:)`, or before layout.** About 41 minutes across three runs, plus intermittent Reset failures.
3. **One section, stable ids, only changed rows measured, inserted or reconfigured.** The biggest stream and load-older gaps.
4. **No decoded bitmaps for placeholders; any image cache capped and sized to display.** 64 MB in O2.
5. **Measure each text once, with the same text engine the view draws with.** Every Opus build pairs a TextKit 1 measurer with TextKit 1 text views (`UITextView(usingTextLayoutManager: false)`). Sol's `boundingRect` with TextKit 2 views also held drift under 0.2 pt.
6. **Jump: take the target offset from the layout's own frame.** About 2 minutes per run.
7. **Release strip settings.** Free.
8. **A working order:** code first, from the given constants; tests once, at the end, one per behaviour; never judge a change on an install you did not just make. This is about 10 to 20 minutes per run, but it is process, not UIKit (section 3).

## 3. What we ship: the recommended shape

### 3.1 The evidence that decides it

- **Agents read the main file once and rarely go further** (2.1). Anything outside the main file is read by Sol and skipped by Opus. A rule that must hold, like the edit menu, has to be in the main file, near the top.
- **Many small skills fail the same way the 15 references did.** Each extra skill is a description an agent must match at minute 0. The old pair already shows a second skill (`whats-new-27`) being ignored by every UIKit run.
- **The costliest faults were "read but done wrong" or "found late by a failing test",** not "never heard of it". The menu rule was in a file all three failing builds read. The offset clamp surfaced only at minutes 32 to 65. A second look at the code before the agent's own tests would catch both in a minute or two, against 7 to 20 minutes of test debugging each.
- **Process lessons are real but not UIKit.** The process losses are screenshot measuring, tests run 6 to 20 times, and stale installs (2.3). E6 says the skill names no benchmark and no test. Process belongs either in a short general section or in a separate agent.
- **Sol (Codex) and Opus (Claude Code) both load skills from `.agents/skills` and `.claude/skills`** (research note "Skills load in both agents"). There is no evidence yet that Codex runs a Claude-style subagent definition. Anything in an agent must therefore also exist as text the skill carries.
- **One variable at a time.** E7 measures the skill against the Round 2 control. Shipping a skill and an agent together means E7 needs one more arm to know which helped.

### 3.2 Top option: one skill, plus one reviewer subagent

**Skill `uikit-chat-list`.** The whole recipe for this kind of screen lives in the main file, with two references at most. **Subagent `uikit-list-reviewer`.** It is read-only, and the building agent calls it once the room first works and again before it stops. It reads the diff against a fixed list of failure patterns and returns findings with file and line. It never edits, builds or runs tests. The same checklist sits at the end of the skill's main file, so a Codex agent, or one that never calls the reviewer, still has it.

Why this shape:

- **The skill carries the rules.** Every rule in it is traced to an E1 to E5 answer or an Apple citation (E6's measure).
- **The reviewer catches the two failure kinds the skill alone did not prevent** (2.2): rules done wrong, and faults found late. It is also the cheapest test of Fernando's "an agent itself" idea. It costs one small file and does not change the build agent.
- **E7 can measure it cleanly in two steps:** run the skill alone first (the plan as written), then the skill with the reviewer as a third build pair.

**Draft outline, skill.** Main file under 2,000 words.

```
uikit-chat-list/
  SKILL.md                     about 1,800 words
  references/
    custom-layout.md           about 900 words: the layout class in full (frames array or height index,
                               layoutAttributesForElements(in:) by binary search, prepare() incremental,
                               targetContentOffset(forProposedContentOffset:), invalidation contexts)
    measuring-text.md          about 600 words: one measurer per thread, TextKit 1 pairing, measure once,
                               cache by (id, width, text size, revision)
```

SKILL.md headings and word budgets:

| Heading | Words | Content (source) |
|---|---|---|
| When to use | 60 | long chat or feed lists: streaming rows, older pages above, jump to an item, text size, rotation, selectable text |
| Core rules (read these even if nothing else) | 250 | one line each, the eight from 2.4 items 1 to 7 plus the clock rule; the edit-menu rule first |
| The list | 250 | the view (E1's answer); one section; stable ids; a custom layout with exact frames, or the E1 winner's equivalent; why not one section per message (1.1) |
| Heights | 200 | measured once per message, kept by id and width and text size; self-sizing on or off (E2's answer); placeholders as plain colour (1.8) |
| Live updates and pinning | 250 | read pinned before; apply as messages arrive or batch to at most one frame (E1 data); only new rows measured and inserted; `reconfigureItems` for changed ids; never rebuild the whole snapshot (1.1) |
| Older messages above | 200 | the anchor approach E3 picks; the offset clamp and `targetContentOffset(forProposedContentOffset:)`; `reloadData` for removals (1.4) |
| Jump to a message | 120 | load one page around the target, offset from the layout's frame, no animation (1.3) |
| Text size and rotation | 150 | re-measure what changed, keep the anchor through `viewWillTransition(to:with:)` and trait changes (1.5, 1.6) |
| Selectable text and menus | 150 | a non-editable `UITextView`; `[reply] + suggestedActions` from both delegate methods; context menu only off the text (1.7; E4's answer) |
| Launch | 100 | data before the first view controller, nothing built per cell that most rows do not show, Release strip settings (1.2, 1.9) |
| Shortcuts that do not count | 100 | the list in 1.10, stated as rules of timing, not of a benchmark |
| How to work | 80 | write code from the given numbers first; one check per behaviour, at the end; always measure a fresh install |
| Self-review checklist | 120 | the reviewer's list, for agents without it |

**Draft outline, subagent.** About 600 words in `agents/uikit-list-reviewer.md`. Its frontmatter limits it to read and search tools. It holds:

- **Its job** (60 words).
- **What to read** (80 words): the view controller, the layout, the cell, the update path.
- **The checklist**, each item with the pattern to search for and the one-line fix (350 words):
  1. edit menu returns `suggestedActions` with custom items first;
  2. no per-message section and no whole snapshot per update;
  3. an insert or prepend measures only new rows;
  4. removals and shrinks set the final offset first;
  5. no decoded bitmaps or uncapped caches;
  6. each text measured once;
  7. no formatter, regex or image creation in configure;
  8. the timing clock starts at the touch's timestamp and stops at the next frame;
  9. Release strip settings.
- **The report format** (100 words): finding, file:line, fix, in severity order.

### 3.3 Alternative: one skill, no agent

The plan as written in round5-plan.md E6, with the same SKILL.md outline as above and the self-review checklist as its last section. Choose it if E7's first pair already passes 13 of 13 with the skill alone, if adding a reviewer makes E7 harder to read, or if the first pair shows agents not calling the reviewer. It is the smallest thing that tests the main hypothesis: a focused main file with the right core rules fixes the menu, the offset clamp and the section shape.

### 3.4 Shapes considered and set aside

- **Many small skills** (list, text, updates, menus). This repeats the old pair's failure mode: Opus opened 0 to 2 of 15 references. A rule an agent must follow cannot sit behind a second description match.
- **One massive skill** (the old 16,000-word specialist made chat-specific). Same problem: the extra words are never read, and the main file's first lines are all that reliably land.
- **Two agents: a builder and a reviewer.** A builder agent could hold the working order (2.3) and the skill together, and it is the best answer to the 10 to 20 minutes of process loss per run. But it replaces the benchmark's own agent and prompt. That changes what E7 compares against the Round 2 control, and it does not exist for Codex. It is worth a later round as its own experiment: same skill, with and without the builder.
- **A harness-checker agent** (writes and runs the 13 checks in parallel). This would cut most own-test time, but it is about our benchmark, not UIKit. That breaks E6's "says nothing about this benchmark". It belongs to the testing hypotheses kept at the end of round5-plan.md.

## 4. Open questions the spikes answer, and where they plug in

| Question | Experiment | Where it goes in the skill | What the dataset already says |
|---|---|---|---|
| Table view or collection view with a custom layout, for a streaming list? | E1, stream CPU | "The list"; core rule on the view; whether `custom-layout.md` exists at all | No build ever used a table view (1). The best collection-view builds reached 7.5 s clean (S3) on the simulator. OC3's scroll view beat both but bent the stream. If E1 is within 10 %, the skill names the one with less list code. |
| Is a hand-rolled `UIScrollView` recycler worth it over either view? | not in E1 to E5 | a sentence in "The list", or nothing | OC3 says collection-view batch bookkeeping costs about 7 ms per live update. That is unmeasured separately, and the scroll view loses diffable data, cell reuse and the accessibility containers. Default: do not recommend it unless E1's numbers leave a large gap. |
| Saved heights or self-sizing? | E2, mid-list text size | "Heights"; core rule; `measuring-text.md` | Every build saved heights. S3 turned self-sizing invalidation off. Nobody measured the alternative. |
| How far may batching go? | E1 data (both spikes apply each message as it arrives) | "Live updates" | Uncoalesced and 50 to 80 ms coalesced cost the same on the phone (1.1). 100 ms was ruled a bend. A likely rule is "at most one frame", which E1 can confirm by logging update counts. |
| Which anchor approach for load older? | E3, drift | "Older messages above" | All passing builds used the top row's id and offset (approach a). O3 added `targetContentOffset(forProposedContentOffset:)`. Approach (b), adding the inserted height to the offset, was used by none. |
| Does the offset clamp after removal still bite in the E1 winner? | E3 (and E2 when heights shrink) | "Older messages above" warning | It cost 7 to 20 minutes in three runs (1.4). The spike should include a Reset after a scroll to show it. |
| Which menu form passes? | E4 | "Selectable text and menus"; the first core rule | `[reply] + suggestedActions` passed in four builds and fixed every failure (1.7). E4's (b) and (c) should reproduce the Round 2 failures. |
| TextKit 1 or TextKit 2 text views, and which measurer? | not tested; record in E1 | `measuring-text.md` | TextKit 1 pairs (Opus) and `boundingRect` with TextKit 2 views (Sol) both held drift under 0.2 pt. The spikes' shared row view should name which it uses, so the skill can say "this is what was measured". |
| Does `DispatchQueue.concurrentPerform` row layout move any number? | not tested | `measuring-text.md`, or nothing | O3 used it with mixed changes. OC3's version moved no reported number. Leave it out unless a spike shows a gain. |
| Does the order hold on the iPhone 12? | E5 | none if it holds; a note if it flips | Rounds 1 and 2 are the only phone data. Round 3 has none. |
| The timing clock | all spikes (shared debug bar) | "Shortcuts that do not count", reviewer item 8 | The Sol and Opus clocks differ by up to about 20 to 45 ms (top of this page). The spikes' shared clock should start at the touch's timestamp and stop at the next frame, so their numbers are honest for the skill's claims. |

For E7: the reviewer subagent (3.2) is the one addition that needs its own build pair. Everything else above is the skill's text.
