# Make your Campfire room faster

{{STACK_LINE}}

This folder holds the Campfire chat room you built in Round 2.
PROMPT.md is the original brief; it still applies in full.
Agent skills are installed in this project; use any that help.
Work only inside this folder. Don't read the git history, other folders on this Mac, or any write-up of this benchmark, here or online.
Find current best practices for your stack and use them: the installed skills, Apple's documentation, the web.

## Your scorecard

Measured in an iPhone 17 simulator (iOS 26.4) with `./bench`, on the app as it stands now. Lower is better in every row.

{{SCORECARD}}

{{CHECKS}}

## Measuring

Testing is unlimited: run it as many times as you like. If another build is being measured your request waits its turn.

- `./bench <number>` measures one number and prints its row next to your baseline, in about 30 seconds or less (`stream` and `memory` take about 50, because the stream itself plays for 30 s). It builds, launches, records and prints, nothing else. The numbers: `rows-cold`, `rows-repeat`, `stream`, `jump`, `older`, `textsize-bottom`, `textsize-mid`, `memory`, `size`. `./bench --help` lists them. It also prints the check that number feeds.
- `./bench` measures every number and runs all 13 checks (about 4 minutes). Use it to confirm, not to iterate.
- `./bench --build` only compiles (build errors and the stack rule).
- The debug bar's ms label measures each change on its own.

## Goal

Beat your scorecard on every number. Each number is a floor you already reached, not a ceiling.
{{FIX_FIRST}}- Then work through the scorecard, biggest gap first.
- A change to one message (a new one, a boost, a page of older ones) should cost about the same whether 50 or 5,000 messages are loaded.
- Measure before and after each change, with `./bench <number>`. Keep a change only if it helps.
- Same look, same behaviours, same 2 pt tolerances.
- Don't change `CampfireKit/`, `Fixtures/`, `screenshots/`, `PROMPT.md`, `bench`, `.bench/`, or the lines of the debug bar that start and stop its ms clock. `./bench` refuses to run if any of them changed. At the end all 13 checks run again, so keep every one that passes passing.
- Measure as often as you want; there is no limit on testing. You have 3 hours in total. You're done when every number beats the scorecard, or when you can show a number can't get there on this stack. Say which, and why, in NOTES.md.

When you're done, write NOTES.md: what you changed, and the before and after for each number.
