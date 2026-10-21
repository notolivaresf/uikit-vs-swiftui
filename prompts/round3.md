# Make your Campfire room faster

{{STACK_LINE}}

This folder holds the Campfire chat room you built in Round 2.
PROMPT.md is the original brief; it still applies in full.
Agent skills are installed in this project; use any that help.
Work only inside this folder. Don't read the git history, other folders on this Mac, or any write-up of this benchmark, here or online.
Find current best practices for your stack and use them: the installed skills, Apple's documentation, the web.

## Your scorecard

Measured on an iPhone 12. "Best seen" is the best value any build of this same app reached on this phone.

{{SCORECARD}}

{{CHECKS}}

## Measuring

Run `./bench` in this folder. It builds the app, measures it on the iPhone 12 and prints this same scorecard with your new values. It takes about 5 to 10 minutes; if another build is on the phone it waits its turn. Rows marked "full pass only" are not in `./bench`; we measure them at the end.

## Goal

Reach or beat best seen on every number. Best seen is a floor that another build already hit on this phone, not a ceiling: beating it is the point.
{{FIX_FIRST}}- Then work through the scorecard, biggest gap first.
- A change to one message (a new one, a boost, a page of older ones) should cost about the same whether 50 or 5,000 messages are loaded.
- Measure before and after each change with the debug bar's ms label and `./bench`. Keep a change only if it helps.
- Same look, same behaviours, same 2 pt tolerances.
- Don't change `CampfireKit/`, `Fixtures/`, `screenshots/`, `PROMPT.md`, `bench`, `.bench/`, or the lines of the debug bar that start and stop its ms clock. `./bench` refuses to run if any of them changed. At the end all 13 checks run again, so keep every one that passes passing.
- You have 2 hours in total. You're done when every number is at or under best seen, or when you can show a number can't get there on this stack. Say which, and why, in NOTES.md.

When you're done, write NOTES.md: what you changed, and the before and after for each number.
