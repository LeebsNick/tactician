# Issue #15: screenshot walk-through for install and first rule

Issue: https://github.com/LeebsNick/tactician/issues/15
Branch: `docs/15-walkthrough`, cut from `main` at 664e314 on 2026-10-27.

## Blocked on screenshots

The six PNGs need a game session. The text, file names, alt text and crop are ready so the shots drop in without touching the prose. Take them at the default UI scale, crop to the editor window, save as PNG under `docs/images/`, then replace each `vX.Y.Z` in `docs/walkthrough.md` with the version shot.

| file | shows |
|---|---|
| `docs/images/01-load.png` | chat log after `/addon load tactician` with the load line, editor opening on `/tactician` |
| `docs/images/02-empty-editor.png` | a job with no rules: header with Run, `0 rules, 0 on, 0 never fire`, footer with the `SCH template: 8 rules` header (shoot on SCH) |
| `docs/images/03-picker.png` | a new row half set, the family picker open, `Cure` found through the search box, a greyed entry visible with its reason |
| `docs/images/04-running.png` | Run ticked, the state beside it saying the rules run, footer `Saved config/addons/tactician/<character>/SCH.txt.` |
| `docs/images/05-fired-and-inert.png` | the cure row shaded green, footer `Last: 1. /ma "Cure IV" <p1> (3s ago)`, a second row numbered `2 !` in red with its hover tooltip showing |
| `docs/images/06-file-and-reload.png` | the rule file open in a text editor beside the game, chat line `Re-read ...` after `/tactician reload` |

Shoot after #11 and #12 merge if they go out in the same release, so the header state in 04 matches what a new user sees.

## Acceptance

- [ ] Each step has a screenshot and a one or two sentence caption. Captions written; screenshots pending (table above).
- [x] README links the walk-through from the Install section.
- [x] Images are in the repo, not hotlinked, and the release zip does not carry them. Relative `images/` links; `tools/dist.sh` packs `tactician/` only, and a probe file under `docs/images/` did not appear in the zip listing.
- [ ] A reader can go from fresh install to a saved, running rule by following only the walk-through. The text covers every step with its command and expected result; confirm with a fresh reader once the shots are in.

## Plan

1. `docs/walkthrough.md`: the six steps from the issue, in order, each with the command or click, the image, and what to expect.
2. README Install links it; troubleshooting stays in #10's section, which the walk-through points to.
3. Screenshots: table above.

## Progress

- 2026-10-27: text, links and README done; zip exclusion checked. Draft PR. Screenshots pending a game session.

## Evidence

- Tests: N/A, documentation only. `make check` run, nothing else moved.
- Mutation: N/A, documentation. Alternate evidence: the six steps map one to one onto the issue list; the README anchor `#nothing-happens` is the heading slug from PR #16; `sh tools/dist.sh 0.0.0 tactician` with a probe file under `docs/images/` listed zero `docs/` entries in the zip.

## Decisions

- Captions name the version as `(tactician vX.Y.Z)` to be filled when shot, per the issue's "note the version in the caption".
- Step 4 says the state beside Run goes "from off to running" rather than quoting `stopped`/`running`, since PR #12 changes those words to full sentences.
