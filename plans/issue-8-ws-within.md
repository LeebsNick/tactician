# Issue #8: fire a weapon skill after a party member's, for skillchains

Issue: https://github.com/LeebsNick/tactician/issues/8 (labelled needs-discussion; design choices below)
Branch: `feat/8-ws-within`, cut from `main` at 664e314 on 2026-10-27.

## Acceptance

- [x] A `self` rule can gate on a recent party WS: `self tp_gte:1000 and ws_within:6 ws:"Fast Blade"`.
- [x] The window is configurable in seconds: the condition's argument, 1 to 60.
- [x] Own WS does not satisfy the condition: the reading is taken over the other party members only.

## Plan

1. RED: tracker remembers a landed weapon skill (category 3) and answers its age; client folds the youngest age across the other members into `snap.me.party_ws`; the self subject carries it; `ws_within` compares it; vocab, rule, engine and view read it out.
2. GREEN in `lib/tracker`, `lib/client`, `lib/scope`, `lib/conditions`, `lib/vocab`; `tactician.lua` hands the snapshot a `ws_age` closure; `lib/editor` starts the slider at the condition's default; README row and sentence.
3. Mutation pass over the touched modules, every new branch recorded in `tools/mutants.txt`.

## Progress

- 2026-10-27: RED, 11 failing across 8 test files. GREEN, 126 passed, `make check` clean. `make mutate`: 29 mutants, 0 problems (17 new). WIP doc, commit, PR.

## Evidence

- RED: `luajit tests/run.lua tactician`: 11 failures, one per new test, in tracker (3), client (2), scope, conditions, vocab, rule, engine and view tests; `ws_age`/`party_ws` missing, `ws_within` an unknown condition.
- GREEN: 126 passed, 0 failed. `make check` clean.
- Mutation: `make mutate`, 29 mutants, 0 problems. New: tracker (category guard, window length, window boundary, age sign, prune keep, entry keep, mark set, mark carried), client (youngest wins, no tracker, snapshot wiring), scope (reading carried), conditions (boundary, argument used), vocab (max, min, subject).
- Editor and driver: read only, not run in Ashita.

## Decisions

- `ws_within` reads me, not a party member. The issue's `party ws_within:6` predates the `scope.condition` form of #7; under either grammar a party-scoped `ws_within` is refused with `ws_within cannot be read for party member`. Reading it per member (`party.ws_within:6` = any member) is a small follow-up in `lib/scope` and `lib/vocab` if preferred.
- No `skillchain_open` condition: the client does not expose the chain window. The seconds are the user's.
- A weapon skill that missed counts like one that hit; telling them apart means reading each action block's message id, which `lib/actionpacket` walks past. Marked `ponytail:` in `lib/tracker`.
- Trusts are party members, so a trust's weapon skill opens the window too.
- The tracker's memory is 60 seconds, the condition's maximum; a test ties the two.
