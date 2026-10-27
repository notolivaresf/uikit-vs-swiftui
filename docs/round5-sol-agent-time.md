# Round 5: where Sol's wall time goes

The Sol builds keep missing the time bar of 1,356 s, which is the control's 1,233 s plus 10%. Their times: E21 thin2 1,593 s, E23 thin3 2,366 s, E25 no skill 1,954 s, E27 thin4 2,279 s, E29 thin5 1,799 s. This note reads the five transcripts side by side and asks three things. What do the slow builds do that the control doesn't? Which of those habits does the skill cause? And how much of the gap is noise?

**Short answer:** most of the miss is not a habit. The model service has been about 30% slower since 19 Oct, measured in output tokens per second. Every Round 5 build is being compared with one control that ran at the old speed. Two habits add real time on top of that:

- Sol tests every rule it is given, and reruns the whole suite.
- Sometimes it does a pixel study of the reference screenshots. That one also happens without the skill.

Reading is not repeated.

## Method

Runs compared:

| Label | Run folder | Skill |
|---|---|---|
| Control | `runs/sol-uikit-ours-pair` | v0.3-pair |
| E21 | `runs/sol-uikit-ours-chatlist-thin2` | v0.11.2-thin2 |
| E25 | `runs/sol-uikit-none-x` | none |
| E27 | `runs/sol-uikit-ours-chatlist-thin4` | v0.11.4-thin4 |
| E29 | `runs/sol-uikit-ours-chatlist-thin5` | v0.11.5-thin5 |

E23 (thin3) is used only for token counts.

Each `transcript.jsonl` line has a timestamp in `transcript.times`. Codex runs commands in the background: a long `xcodebuild test` keeps running while the model reads output and writes the next file. So adding up command durations double counts. Instead, each interval between two consecutive events goes to the event that ends it:

- If the next event is a command finishing, the interval counts as **waiting**.
- Otherwise it counts as **model time**: thinking, writing and messaging.

The category of a stretch of model time is the category of the command it led to.

The phase table in `round5-e29-results.md` (Reading 446 s, Reference 338 s, Own UI tests 582 s) used a rougher split. It charged heredoc file writes to reading, so its reading figure is really code writing. The figures below replace it.

The analysis scripts are not committed. They are short Python readers of the transcripts and could be rebuilt from this description.

## 1. The agent waits on commands very little

Waiting and model time per run, in seconds:

| Run | Waiting on commands | Model time | Wall |
|---|---|---|---|
| Control | 177 | 1,054 | 1,231 |
| E21 thin2 | 243 | 1,350 | 1,593 |
| E25 no skill | 213 | 1,741 | 1,954 |
| E27 thin4 | 221 | 2,056 | 2,276 |
| E29 thin5 | 128 | 1,669 | 1,797 |

In every run, waiting is only 128 to 243 s. The rest of the wall time is the model producing tokens one after another. So wall time follows **output tokens ÷ service speed**.

Model time by the kind of work it led to, in seconds:

| Kind | Control | E21 | E25 | E27 | E29 |
|---|---|---|---|---|---|
| Reading (prompt, skill, kit) | 13 | 11 | 170 | 109 | 51 |
| Reference study (screenshots, icons) | 0 | 40 | 216 | 72 | 190 |
| Writing code | 258 | 171 | 370 | 208 | 241 |
| Builds | 25 | 157 | 39 | 113 | 152 |
| Simulator | 36 | 74 | 46 | 53 | 98 |
| Own tests (writing, running, reading results) | 587 | 619 | 644 | 1,247 | 700 |
| Progress messages and final report | 135 | 277 | 256 | 254 | 237 |

## 2. The habits

### Own tests: every run does it, the control included

| Run | Test runs | Test run time (s) | Runs of the whole target | Test functions |
|---|---|---|---|---|
| Control | 11 | 675 | 7 | 8 |
| E21 thin2 | 12 | 525 | 8 | 7 |
| E25 no skill | 9 | 1,580 (two runs of 613 s and 672 s overlap) | all | not counted (written with file edits) |
| E27 thin4 | 19 to 21 | 1,450 | 18 | 9 |
| E29 thin5 | 11 | 574 | 6 | 12 |

The prompt never asks for tests, and the harness checks are not listed in it. Even so, every run writes UI and unit tests that rebuild the prompt's behaviours in its own words: pinned stream, prepend restore, reference-row geometry. In substance these duplicate the hidden checks. The control spends about as much time on them as the thin skills do (587 s of model time). **Testing in itself is Sol's own habit**, not something the skill adds.

The skill changes two things: **how many** tests Sol writes, and **how it reruns** them.

- **One test per rule.** Sol writes a test for each rule the skill gives it. E29's tests include `testTransparentImageMarginDoesNotCountAsVisibleMessage` and `testPrependAndHeightChangesRestoreTheSameVisibleContent` (rule 8), `testAppendRetainsExistingAttributesAndPixelSnapsRows` (rule 3) and `testStreamStaysPinnedThroughWindowTrimming` (rule 7). E21 wrote `testLayoutBoundsAndBinarySearch` from thin2's binary-search rule. E29 has 12 test functions against the control's 8. The rules behind them, quoted from thin5:
  - Rule 3: "snapped to the pixel grid … An append adds frames; a changed height shifts the tops below it"
  - Rule 7: trim in the same batch
  - Rule 8, new in thin5: "The top row counts only once its visible content is below the top edge: ignore transparent margin and sub-point rounding remainders (small tolerance). Use it to capture the anchor and read the top row after restoring, so a re-layout never names the row above."
- **Whole-suite reruns.** thin3, thin4 and thin5 close with: "Run `xcodebuild test` for the test you changed (`-only-testing:`) with `-test-timeouts-enabled YES -default-test-execution-time-allowance 60`: a test stuck on a system prompt then fails in a minute instead of holding the run." Rule 1 also says: "never read `UIPasteboard` from a UI test, it waits on the paste prompt."
  - Sol does follow the form: the flag appears. But it passes the whole test target as the selector. In E27, 18 of 19 runs covered the whole target. In E29, 6 of 11 did.
  - The sentence did not reduce the number of runs. E27 ran tests 19 to 21 times, the most of any build, and spent 1,247 s of model time on tests, twice the control.
  - thin2 has no test sentence and was the fastest Round 5 build.
  - Naming the test tool seems to invite more test cycles, not fewer.

Cost: tests account for about 600 to 700 s of model time in every run (1,247 s in E27). The extra over the control is about 30 to 110 s for E21, E25 and E29, and about 660 s for E27.

### Reference-screenshot study: Sol does it without the skill

"Reference study" means time spent studying the given screenshots and assets, rather than building from `constants.json`.

- **Control:** none. No pixel scripts and no `sips` calls.
- **E29 thin5:** about 190 s. It ran 6 Python Imaging Library (PIL) scripts comparing `screenshots/*.png` pixel by pixel against images exported from the test results. It also used `sips` to measure sizes, and `ffmpeg` to pull frames from a test recording.
- **E25 no skill:** about 216 s. It ran 6 PIL scripts of the same kind.
- **E21, E23, E27:** a web search and a `curl` of the public Campfire repository's icons. That took about 40 s in E21, and about 72 s plus the asset fetch in E27.

No skill version says anything about screenshots, pixels or icons. The no-skill build does the most of it. So this is Sol's own habit and varies from run to run: the control simply happened not to do it. **The skill does not cause it.**

### Reading: not repeated

Every run reads the prompt, the skill and `constants.json` once, reads the kit once, and reads the bridge header later when it needs it. No file is read again and again.

- E25's 170 s is the no-skill build working out kit details that the skill would have given it.
- E27's 109 s is mostly paging through test output.

### Release builds and size checks: small, and possibly rule 11

| | Control | E21 | E25 | E27 | E29 |
|---|---|---|---|---|---|
| Release builds | 3 | 5 | 3 | 3 | 4 |
| Binary size and strip checks | 0 | 2 | 0 | 4 | 3 |
| Own simulator created | 0 | 1 | 0 | 1 | 1 |

The size and strip checks appear only in builds whose skill has rule 11: "The app target's Release build strips: …". The control and the no-skill build skip them. Together with the extra Release build, this costs about 100 to 150 s of model time over the control. **The skill likely causes it, but it is small.**

### Messages

Progress messages and the final report take 237 to 277 s, against 135 s in the control. Every Round 5 run writes longer progress notes, the no-skill run included. This is not caused by a skill sentence.

### Summary of causes

| Habit | Extra model time over control (s) | Cause |
|---|---|---|
| Slower service, same tokens | about 450 to 500 (see section 3) | Neither: measurement |
| One test per rule, whole-suite reruns | 30 to 110; 660 in E27 | **Skill**: rules 3, 7, 8 and the closing "Run `xcodebuild test`…" sentence (thin3 onward) |
| Reference pixel study | 40 to 216 | **Sol anyway** (biggest in no-skill E25) |
| Release size and strip checks | 100 to 150 | **Skill, likely**: rule 11 |
| Longer progress messages | 100 to 140 | **Sol anyway** (E25 too) |
| Repeated reading | none | not present |

## 3. Variance: the control is stale

Service speed is output tokens per second of model time. Same CLI (`codex-cli 0.162.1`), same effort setting (high):

| When | Runs | Speed (output tok/s) |
|---|---|---|
| 18 to 19 Oct (control and Round 1 to 2) | control 58.6, `sol-uikit` 61.6, objc pair 66.7, swiftui 59.0, swiftui-apple 52.9 | 52.9 to 66.7 |
| 21 Oct onward | all later Sol runs | 30 to 49 |
| 26 to 27 Oct (Round 5) | E21 39.2, E25 41.7, E27 43.1, E29 44.1 | 37.5 to 48.9 |

Output tokens per run: control 61.8k, E21 52.9k, E25 72.5k, E29 73.6k, E23 80.5k, E27 88.7k. E17, the shortest thin build, used 51.4k.

Across the 10 Round 5 Sol runs, wall time fits **264 s + 23.5 s per 1k output tokens** (R² 0.89).

- At today's speed, the control's own 61.8k tokens predict **about 1,700 s**. That is well over its own bar.
- Meeting 1,356 s today would take about 46k output tokens or fewer. No Sol build has ever gone under 48.9k.
- Replayed at the control's speed:
  - E21: about 1,150 s (passes)
  - E29: about 1,380 s (just over)
  - E25: about 1,450 s
  - E27: about 1,730 s

So **at equal speed, E21 beats the control and E29 is within 2% of the bar**. The remaining gap is the test habit in section 2.

**Repeat spread.** Same-skill Opus pairs differ by 5% (v0.9.0: 2,115 against 2,221 s) and 17% (thin4: 1,546 against 1,807 s). Wall SD across Round 5 Sol runs is 330 s on a mean of 1,825 s. The coefficient of variation (spread relative to the mean) for one build repeated is about 10 to 15%, which is wider than the 10% allowance in the bar.

**How many control runs would settle it:**

- A single control cannot tell a 10% difference from noise.
- Showing a 10% difference at 80% power would take about 20 runs per side. That is not practical.
- What would settle the bar is **three control runs on the same day as the builds**, run in between them, with medians compared. That removes the service-speed drift, which is about 30% here and the largest effect.
- Report output tokens and turns next to wall time. They do not depend on service speed.
- Log tokens per second for every run, so a slow day shows up as a slow day.

## 4. Proposed skill edits for thin6

Two edits. Both remove words.

**Edit 1: replace the closing test-run sentence and the UI-test clause in rule 1 with one practice.**

Remove from rule 1:

> never read `UIPasteboard` from a UI test, it waits on the paste prompt.

Replace the closing "Run `xcodebuild test` … allowance 60 … Close any simulator you started when you stop." with:

> Check each behaviour once the screen works, and rerun only what failed. Close any simulator you started.

Expected saving:

- fewer whole-suite reruns and fewer test cycles;
- about 100 to 300 s of the 600 to 1,250 s of model time spent on tests (the E27 pattern was the worst);
- per run, about 5 to 15% of wall time.

thin2, which had no test sentence, already ran closest to this.

**Edit 2: say the rules are for building, not for testing, and drop the tolerance detail from rule 8.**

Add one line before the rules:

> These rules say how to build it; they are not a list to test.

In rule 8, cut "ignore transparent margin and sub-point rounding remainders (small tolerance)".

Expected saving:

- fewer rule-derived test functions, which brings E29's 12 back toward the control's 8;
- about 100 to 200 s of model time.

If rule 11's Release-strip line can go with it, add another 100 to 150 s of size checks.

Even with both edits, a Sol build at today's speed will probably not reach 1,356 s against a control measured at last week's speed. Fix the bar first (section 3), then judge thin6.
