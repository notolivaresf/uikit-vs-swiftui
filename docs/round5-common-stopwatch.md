# Round 5: one stopwatch for every build

27 Oct, simulator uvs-r3-a (iPhone 17 Pro, iOS 26.4), 3 passes per build, run back to back on the same sitting. Data: `runs/stopwatch-r5/<build>/pass<n>/stopwatch.json` and `median.json`. Tools: `Harness/stopwatch.sh`, `Harness/stopwatch.py`, `Harness/stopwatch/UVSStopwatch.m`; how to run them is in `docs/harness.md`.

## Why

Four scorecard rows (load older, jump to message 2,500, text size at the bottom, text size mid-list) took the `ms` that each app writes on its own state label. `docs/round5-list-code-diff.md` showed that the builds start and stop that clock at different moments: some start at the touch, some when the button's action runs; some stop before anything is drawn, some one or two frames later. So the rows did not compare, and the 2x gap between E26 and E28 was mostly where each app stopped its clock.

## The method

Options weighed:

1. **Tell every agent how to time it.** Ruled out: benchmark prompts state outcomes only, and the app would still own the clock.
2. **Time it inside the app with a harness-owned display link or Core Animation commit hook.** Closer, but the harness would have to guess, from inside the process, which commit "is" the result, and anything in-process shares the main thread with the app.
3. **Instruments (frame lifetimes, hitches) per tap.** No common start point without a signpost in the app's code, and a heavy trace per tap.
4. **Film the screen and mark the touch on the same film (chosen).** What the person sees is the result, and the app's code cannot move either end.

How it works: the harness injects a small library into the app (`DYLD_INSERT_LIBRARIES`, only in stopwatch mode; the build itself is unchanged). On every touch that ends, before the app receives it, the library paints an 8-cell black and white code in a strip at the top of the window and commits it at once, so the next frame carries the touch whatever the app then does on its main thread. `simctl io recordVideo` films the simulator while the unchanged UI test plays. `stopwatch.py` then reads the film: the **touch** is the frame where the code changes; the **result** is the first frame from which the list area already shows the picture it settles on (status bar, debug bar buttons and the state label left out; a pixel counts as changed above 16 grey levels, a frame above 3 changed pixels at 1 px per 2 pt). When the list does not change at all, the result is the first frame where the state label shows its final text.

Resolution and noise, measured on these 21 runs:

- **Clock:** the film's time base is 1/600 s (1.7 ms). Frames arrive about every 16.7 ms (median step 16.67 ms in every run), with occasional short frames of 3 to 5 ms, so a reading moves in steps of about one frame.
- **Per tap:** within one pass the taps of a row spread by 5 to 15 ms (up to one frame); see the "taps" ranges in `stopwatch.json`.
- **Pass to pass:** of the 28 build-rows, 27 have their three pass medians within 5 ms of each other (22 within 1.7 ms). One spread a full frame: Opus control load older, 16.7 / 33.3 / 16.7 ms.
- **Not counted:** the time from the touch's event timestamp to its delivery to the app, 13.1 to 13.8 ms median, the same for every build (logged as `dispatch_lag_ms`). App clocks that start at the event timestamp include it; the stopwatch does not.
- **Unsettled taps:** 3 of 63 load-older taps (E26 2, E28 1) had no label change to read; their row median uses the other taps.

Limits:

- **Load older is a state-label reading.** A good load older keeps the same rows on screen (that is the test), so in six of seven builds nothing in the list changes and the only visible result is the state label. The app chooses when it writes that label, so this row can still be delayed (never shortened) by the app's own code: E28 and the Opus control write it from a display-link callback, a frame or two after the work. Only the Sol control's list visibly moves on load older.
- Simulator on the Max, not a phone: frames are the simulator's 60 Hz output. The comparison between builds is fair; the absolute numbers are not a device's.

## Results

Medians of 3 passes, ms. "App" is the app's own `ms` from the same taps in the same sitting (the "app-reported" column the scorecard now keeps). A lower stopwatch number is faster.

| Build | Load older: stopwatch | app | Jump: stopwatch | app | Text bottom: stopwatch | app | Text mid: stopwatch | app |
|---|---|---|---|---|---|---|---|---|
| Opus control (round 3 UIKit Swift) | 16.7 | 38 | 28.3 | 51 | 13.3 | 42 | 20.0 | 42 |
| E26 Opus + thin4 | 5.8 | 23 | 25.0 | 34 | 16.7 | 20 | 21.7 | 27 |
| E28 Opus + thin4, repeat | 33.3 | 40 | 20.0 | 43 | 15.0 | 47 | 21.7 | 46 |
| E24 Opus, no skill | 31.7 | 52 | 23.3 | 43 | 26.7 | 48 | 46.7 | 62 |
| Sol control (round 3 UIKit Swift) | 35.0 | 26 | 35.0 | 26 | 20.0 | 14 | 30.0 | 26 |
| E27 Sol + thin4 | 16.7 | 10 | 23.3 | 17 | 20.0 | 16 | 20.0 | 14 |
| E25 Sol, no skill | 25.0 | 23 | 31.7 | 26 | 15.0 | 14 | 26.7 | 23 |

Pass medians (stopwatch): Opus control 16.7/33.3/16.7, 28.3 x3, 13.3 x3, 20.0/21.7/20.0; E26 5.0/6.7/5.9, 25.0 x3, 16.7/16.7/18.3, 21.7 x3; E28 33.3/32.5/33.3, 16.7/20.0/20.0, 15.0/16.7/15.0, 20.0/21.7/21.7; E24 31.7/31.7/35.0, 23.3 x3, 26.7 x3, 46.7/45.0/48.3; Sol control 35.0/35.0/30.0, 35.0 x3, 20.0/20.0/18.3, 25.0/30.0/30.0; E27 16.7 x3, 23.3 x3, 20.0 x3, 20.0 x3; E25 25.0/26.7/25.0, 31.7/31.7/33.3, 15.0/16.7/15.0, 26.7/25.0/26.7.

## Which earlier conclusions change

1. **E26 is not twice as fast as E28.** App-reported, E26 was about 2x faster on every row. On the film, the three rows where the list moves are level: jump 25.0 against 20.0 (E28 faster), text at the bottom 16.7 against 15.0, mid-list 21.7 against 21.7. That confirms `docs/round5-list-code-diff.md`: the gap was where each app stopped its clock. Load older still differs (5.8 against 33.3), but that row reads the state label, and E28 writes its label from a new display link one to two frames after the work; the film cannot tell that wait from real work.

2. **E28's bar 3 verdict needs a new yardstick.** Against the Opus control on the film: jump -29 %, text at the bottom +13 % (1.7 ms, one tick of the film's clock), text mid-list +8 %, load older +100 % (33.3 against 16.7, one frame, and a label-timing row). A +10 % line is below what the film can resolve on 15 to 20 ms rows: 10 % is one tick of the clock, a tenth of a frame. Suggested yardstick for the speed rows: no worse than the control by more than one frame (17 ms). On that yardstick E28 passes all four rows; on the old +10 % rule it still "misses" on load older, now for a reason we know is the label, not the list.

3. **The Sol builds were not the fastest; their low numbers were the clock.** App-reported, the Sol control beat the Opus control on every row (26/26/14/26 against 38/51/42/42). On the film it is slower on every row: load older 35.0 against 16.7, jump 35.0 against 28.3, text at the bottom 20.0 against 13.3, mid-list 30.0 against 20.0. The Sol clocks start when the button's action runs and stop before a frame, so they leave out both the touch delivery and the drawing.

4. **The skill's gain on text size for Opus is real and larger than reported.** Opus with no skill (E24) takes 46.7 ms mid-list and 26.7 ms at the bottom on the film; both thin4 builds take 21.7 and about 16, close to the Opus control (20.0, 13.3). App-reported the gap looked like +35 % (62 against 46); on the film it is about 2x. Jump is level (E24 23.3).

5. **Sol with the skill (E27) beats the Sol control on three of four rows, by more than the app said** on load older (16.7 against 35.0) and jump (23.3 against 35.0) and mid-list (20.0 against 30.0); text at the bottom is level (20.0). E27 against Sol with no skill (E25): faster on load older, jump and mid-list, slower at the bottom (20.0 against 15.0).

6. **Unchanged:** E28 is still level with the Opus control on the list rows (the repeat is not a regression), and every build here stays under two frames on jump and text size except E24 mid-list (46.7) and the Sol control's jump (35.0).

## Scorecard

`scorecard.py --stopwatch runs/stopwatch-r5/<build>/median.json` (or a single pass's `stopwatch.json`) shows each of the four rows twice: "(app-reported)", the old figure, and "(stopwatch)", the common one. The stopwatch rows are the ones to compare across builds.
