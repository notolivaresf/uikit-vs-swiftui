# UIKit vs SwiftUI: working notes

## Shareable result images

Every shareable results image is made with `Harness/tools/results_table.py`, never by hand or with a new HTML style. It writes a light and a dark version into `docs/images/` as `results-<name>.png` and `results-<name>-dark.png`. The numbers live in the script (copied from the matching `docs/*results*.md`); winners are computed. Run from the repo root:

| Image | Command |
|---|---|
| `results-round1` and `results-round1-best` | `python3 Harness/tools/results_table.py` |
| `results-round2` | `python3 Harness/tools/results_table.py --round2` |
| `results-round2-best3` | `python3 Harness/tools/results_table.py --round2-best3` |
| `results-round2-best` | `python3 Harness/tools/results_table.py --round2-best` |
| `optimal-gap-round2` | `python3 Harness/tools/results_table.py --round2-gap` |
| `results-round3-best` | `python3 Harness/tools/results_table.py --round3-best` |
| `results-swiftui-3way` | `python3 Harness/tools/results_table.py --swiftui-3way` |
| `results-swiftui-skills` | `python3 Harness/tools/results_table.py --swiftui-skills` |
| `results-uikit-vs-swiftui-skills` | `python3 Harness/tools/results_table.py --uikit-vs-swiftui-skills` |
| `results-round4-appkit-vs-swiftui` (Mac, two columns: best of the four AppKit builds vs best of the two SwiftUI builds) | `python3 Harness/tools/results_table.py --round4-appkit-vs-swiftui` |
| `results-round4-all` (Mac: all six builds) | `python3 Harness/tools/results_table.py --round4-all` |

For a new round or comparison, add a mode to the script (data, a spec dict, a flag, a line in its docstring) and a row in this table, then look at both PNGs before committing.

## Where build source lives

All experiment source is in `builds/` (source, Xcode project and `project.yml`, assets, fixtures, the build's own notes and screenshots). Nothing else is copied.

- iPhone builds: `builds/round<N>-<stack>-<model>/` (rounds 1 to 3).
- Level 2 SwiftUI with the AvdLee skills: `builds/level2-swiftui-avdlee-<model>/`.
- Mac builds (AppKit and SwiftUI for Mac, round 4 onward): `builds/mac/round<N>-<stack>-<model>/`. Never put a Mac build in the iPhone list.
- New builds are copied with `rsync -a` excluding `.git`, `.agents`, `.claude`, `.bench*`, `build/`, `DerivedData`, `.build`, `xcuserdata`, `*.xcresult`, `*.trace`, `*.log`, `runs/`. Add a row to `builds/README.md`.
- Never copy a Codex or Claude `-config` folder (it holds login files). Transcripts are not kept.
- `runs/mac-screens-round4/`: real in-app renders of the six built Round 4 Mac apps (not the prompt's reference images in `builds/*/screenshots`).
- Recordings, traces, logs and transcripts stay local (`.gitignore` covers them under `runs/`). Before committing, scan for home paths, emails, team ids, signing identities, keys.
