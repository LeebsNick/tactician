# Issue #15: screenshot walk-through for install and first rule

Issue: https://github.com/LeebsNick/tactician/issues/15
Branch: `docs/15-walkthrough`, cut from `main` at 664e314 on 2026-10-27.

## Pictures

The six PNGs under `docs/images/` are renders, not game captures: `docs/images/src/mock.html` draws the editor window from the layout and palette in `tactician/lib/editor.lua` (the seven columns, header, footer, template panel, picker popup, tooltip) and `tools/render-docs.sh` renders one step each with headless Chrome at the window's default 1300x520. Steps 1 and 6 are composites with a chat line and a text editor. Re-render after the editor changes, then update the version in the captions.

| file | shows |
|---|---|
| `01-load.png` | the chat line the load prints, the editor open on `/tactician` |
| `02-empty-editor.png` | a job with no rules: header with Run and `stopped`, `0 rules, 0 on, 0 never fire`, footer placeholder, `SCH template: 8 rules` header |
| `03-picker.png` | a new row set to Party member / HP below 50% / Cast a spell: best tier of a family, the family picker open on `cur` with `Cure` and two greyed entries |
| `04-running.png` | Run ticked, `running`, footer `Saved C:\Games\Ashita\config\addons\tactician\Aurelie\SCH.txt.` |
| `05-fired-and-inert.png` | the cure row shaded green, footer `Last: 1. /ma "Cure III" <p1> (3s ago)`, row `2 !` with its hover text |
| `06-file-and-reload.png` | the rule file in a text editor, chat line `Re-read ...` after `/tactician reload` |

The header state words are main's (`stopped`, `running`); PR #12 turns them into sentences. Re-render once it merges.

## Acceptance

- [x] Each step has a picture and a one or two sentence caption. Renders, by agreement, not screenshots.
- [x] README links the walk-through from the Install section.
- [x] Images are in the repo, not hotlinked, and the release zip does not carry them. `tools/dist.sh` packs `tactician/` only; a probe file under `docs/images/` did not appear in the zip listing.
- [x] A reader can go from fresh install to a saved, running rule by following only the walk-through. Every step names its command or click and the exact text the addon prints, taken from the source.

## Plan

1. `docs/walkthrough.md`: the six steps from the issue, in order, each with the command or click, the picture, and what to expect.
2. README Install links it; troubleshooting stays in #10's section, which the walk-through points to.
3. Pictures: mock-up plus render script, so they can be redrawn.

## Progress

- 2026-10-27: text, links and README done; zip exclusion checked; draft PR #20 opened with image references and no images.
- 2026-10-27, later: the pictures were missing from the branch while the text referenced them. Replaced with renders from a mock-up of the editor, committed with the mock-up and the render script.

## Evidence

- Tests: N/A, documentation only. `make check` run, nothing else moved.
- Mutation: N/A, documentation. Alternate evidence: the six steps map one to one onto the issue list; every PNG referenced exists and was viewed after rendering; the README anchor `#nothing-happens` is the heading slug from PR #16; `sh tools/dist.sh 0.0.0 tactician` with a probe file under `docs/images/` listed zero `docs/` entries in the zip.

## Decisions

- Renders instead of screenshots: no game session is available here, and a reference to a file that is not in the tree is a broken page. The mock-up follows `editor.lua`, so the pictures match the layout and the words; they do not show the game behind the window.
- Step 4 says the state beside Run goes "from off to running" rather than quoting `stopped`/`running`, since PR #12 changes those words to full sentences.
