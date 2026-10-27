# Issue #10: README "nothing happens" troubleshooting section

Issue: https://github.com/LeebsNick/tactician/issues/10
Branch: `docs/10-nothing-happens`, cut from `main` at 664e314 on 2026-10-27.

## Acceptance

- [x] README has a troubleshooting section with the four checks: rules off at load, active window, 60 second sleep, `party` vs `self` scope for curing others.
- [x] Each check names the command or action that resolves it.
- [x] Linked from the Install section.

## Plan

1. Add a `## Nothing happens` section after Commands, one numbered check each, resolution named in the same sentence.
2. Point to it from Install, right after the load command, since that is where a new user stops reading.
3. Keep the status wording generic (`/tactician status` says which applies) so the section stays true once PR #12 changes the status sentences.

## Progress

- 2026-10-27: section and Install link written. `make check` clean. Anchor `#nothing-happens` is the GitHub slug of the heading.

## Evidence

- Tests: N/A, documentation only. No Lua changed; `make check` run to confirm nothing else moved.
- Mutation: N/A, documentation. Alternate evidence: the four checks map one to one onto the issue list; each names its fix (`/tactician on` or Run, click the window, press a key, change `self` to `party`); the link target is the heading's slug.

## Decisions

- Placed after Commands rather than inside Install so Install stays one short paragraph.
- The section does not quote the exact `/tactician status` words. PR #12 rewrites them, and the section should read the same before and after that merge.
