# Round 5: why both E7 builds missed, and what changes in skill v0.7

## In plain words

- **The Opus "crash during the run" was not a crash of the scored app.** Both crash reports were made by the agent's own debug runs while it was still building (13:57 and 13:59). The bug that caused them was real: when the list trimmed its oldest rows, the same batch also inserted the new message at the bottom, using a position counted before the trim. The agent found and fixed it two minutes later, and the shipped build does not have it. The scored passes failed for another reason: the Sol agent, still building, installed and tested its own app on the same simulator during Opus pass 2 and pass 3 (all builds share one bundle id), which replaced or killed the app under test. Confidence: high.
- **The Opus stream number is not a clean loss.** The control's 5.65 s came from a remeasure that ran while the Sol agent was running unit tests on that simulator; one control pass never finished the stream and the other two read 4.89 s and 6.40 s. The quiet baseline for the same control was 8.15 s, so the build (8.44 s, two tight passes) is about 3.5 % over it, inside the bar. There are still two real, measurable-in-the-code reasons the build does more work than the control: it applies every message and every boost as its own batch update (the control groups what arrives in a tenth of a second), and on every update it rebuilds every row top and throws away every cached layout attribute (the control's layout keeps rows that did not change). Confidence: medium that load is most of the gap; high that the full rebuild is waste.
- **Sol's 8 failed builds and +35 % wall time were mostly self-inflicted testing.** One failure was a compile error against the kit (not the skill). The other seven were its own tests failing: five from a unit test that compared row geometry to the reference screenshots pixel by pixel, two from its own UI tests. Its test commands added up to about 1,920 s against the control's 675 s; two UI test runs took 12 and 11 minutes each because they ran while the Opus scoring passes were on the same machine, and two test runs overlapped on one simulator. Confidence: high on the cause, medium on how much of it the skill's wording ("write checks ... one per behaviour", "run the checklist again before you stop") prompted.
- **Sol's jump (+81 %) and text size at the bottom (+72 %) are consistent over all 3 passes**, so they are real, but reading the code did not single out one cause. Both go through one "replace everything" path (measure every loaded row, `reloadData`, two layout passes, restore the offset); a text size change also redraws every mention badge bitmap. The control does the same amount of measuring with a different text structure. Confidence: low; no skill change is made for them.
- **Noise:** one build per arm; both controls flake on this harness; agents and scoring shared the two simulators; Opus first-40, older and mid-list text size differences are within run-to-run spread.

## What v0.7 changes

1. New core rule: never delete at the top and insert at the bottom in one batch. Trim with `reloadData` plus the final offset, without animation, as its own step (the control's recipe; it never crashed).
2. The layout rule now says what the Opus build broke: an append or one changed height keeps every other cached frame and attribute; never rebuild all tops or empty the attribute cache for it.
3. Live updates: each update costs only the changed rows; it no longer claims batching "gains nothing" (the control that groups updates was not slower, and the claim is not re-measured).
4. How to work: no tests that compare row geometry with screenshots pixel by pixel; one test run at a time on a simulator nothing else is using; the checklist runs once, before stopping.

## Evidence

### The Opus crash

- Crash reports `Campfire-2026-10-26-135741.ips` and `-135949.ips`: `NSAssertionHandler` in `-[UICollectionView _endItemAnimations...]` from `performBatchUpdates`, frames in `Campfire.debug.dylib` (a Debug build), one on an iPhone 17 Pro simulator. The agent's build ran 13:36 to 14:14. No crash reports after 13:59.
- The faulty batch: delete `0..<trimmed` and insert at `oldCount...` in one `performBatchUpdates`. Inside one batch, deletes are indexed in the old list and inserts in the new one, so the insert pointed past the end. The agent's fix at 14:00:27 changed the start to `oldCount - trimmed`; the shipped `ChatViewController.swift` has the fix.
- The scored failures (Opus pass 3: 6 checks, "Application campfire.bench is not running" / "Lost connection") line up with the Sol agent's own commands on uvs-r3-a: `simctl install` and `launch` of the same bundle id at 14:21:09, `xcodebuild test` at 14:22:42, 14:23:41, 14:25:07, 14:26:11, 14:26:37. Opus passes ran 14:14 to 14:18:47 (clean), 14:18:47 to 14:22:56 and 14:22:56 to 14:27:05.
- docs/round5-e7-results.md attributed the crash to the scored passes; that is corrected here.

### Opus stream CPU

| Arm | Pass 1 | Pass 2 | Pass 3 |
|---|---|---|---|
| Opus + skill v0.6.2 | 8.435 s | 8.436 s | (pass lost to the shared simulator) |
| Opus control, remeasure 14:28 to 14:41 | 4.894 s | stream never finished | 6.40 s |
| Opus control, earlier quiet sitting | 8.15 s | | |

The remeasure overlapped the Sol agent's unit test runs on uvs-r3-a (14:30:15, 14:31:36, 14:33:30). The stream score is CPU while the UI test polls the screen, so it moves with machine load as well as with the app's work.

Code differences that remain, independent of noise:

- Build: each live message goes `appendLive` → `appendRows` → one `performBatchUpdates`; each boost one `reconfigureItems`. Control: events go to a pending list flushed every 0.1 s, so roughly half as many updates.
- Build: `pushLayout()` maps every row's height and top and calls `rebuild()`, which recomputes all tops, resets the attribute cache and invalidates the whole layout, on every update. Control: `invalidateRows(from:)` recomputes only from the first changed row and keeps the cache. This breaks the skill's own "appends compute frames only for the new rows".
- The control trims with `reloadData` and a computed offset, never inside a batch.

A quiet-sitting rerun of both arms (`record.sh --only testLiveStream`, alternating) was not done in this lane; it is the first thing to run if the next build's stream number is close to the bar.

### Sol

- Build failures: 1 compile error (the kit's `Dataset` and `Boost` initialisers are internal); 5 exit-65 runs from its own `MessageLayoutTests` (10 reference-row geometry checks against the screenshots plus measuring checks); 2 from its own UI anchor tests (state label wait timeouts; a jump reporting the row before).
- Test time: 14 test runs, about 1,921 s, two of them 731 s (from 14:26:30) and 670 s (from 14:30:47) on uvs-r3-b while the Opus control and Opus scoring ran; the control build made 12 test runs of at most 128 s each, 675 s in all. The agent wrote 35 tests, including the pixel-geometry ones.
- Its jump replaces the window with one page and goes through `replaceRows` (measure all loaded rows, `reloadData`, `layoutIfNeeded`, restore, `layoutIfNeeded`); its text size change empties the measuring cache and the mention bitmaps and goes through the same path. The control's text size path (`render(reconfigureAll:)`) does comparable work. No single cause was isolated.
- The Sol scoring passes (14:42 to 14:53) and the Sol control remeasure (14:41 to 14:52) ran at the same time on the two simulators.

### For the next round

- One scoring at a time, and no agent building while scoring runs on the same simulators (all builds share the bundle id).
- Consider a second build per arm before reading a speed difference under about 20 %.
