# Issue #5: count controller button presses as attended input

Issue: https://github.com/LeebsNick/tactician/issues/5 (labelled blocked)
Branch: `feat/5-controller-presses`, cut from `main` at 664e314 on 2026-10-27.

## Blocked

The issue waits on a CatsEyeXI GM confirming that controller input is acceptable under the Tier 1 attended-use condition, whose approval names "a key press". The code and the eligibility wording are ready on this branch as a draft PR. It must not merge until that confirmation is in hand; if the GM's wording differs, README and NOTICE take the GM's words.

## Acceptance

- [x] A gamepad button press wakes sleeping rules and resets the timeout. `afk.button` turns a button going down into the same input flag a key press sets; the driver registers `xinput_button` and `dinput_button`.
- [x] A held button counts once. The set of buttons down is kept per input API; a button already down is a hold, however often the pad reports it.
- [x] Stick movement and triggers held for camera do not count. Sticks are axes and raise no button event. A trigger the pad reports as a button counts once when it goes down, like any button, and holding it counts for nothing.
- [x] README, NOTICE and the eligibility section name controller presses alongside keyboard presses. Written as the wording would read once approved.

## Plan

1. RED in `afk_test.lua`: press, hold, release, press again; two buttons; DirectInput's 0x80; no mutation of the set; a fresh press wakes the gate.
2. GREEN in `lib/afk`: `button(down, e)` returning the new set and whether this is a press. Driver: two event registrations sharing one closure maker; `S.buttons` in `lib/session`.
3. Wording: README intro and eligibility, NOTICE, the chat line, `/tactician status`, the editor tips, the module headers.
4. Mutation pass on `lib/afk.lua`.

## Progress

- 2026-10-27: RED, 3 failing (`afk.button` nil). GREEN, 118 passed, `make check` clean. `make mutate MODULE=tactician/lib/afk.lua`: 16 mutants, 0 problems (4 new). Draft PR.

## Evidence

- RED: `luajit tests/run.lua tactician`: 3 failures in afk_test.lua, `attempt to call field 'button' (a nil value)`.
- GREEN: 118 passed, 0 failed. `make check` clean.
- Mutation: 16 mutants on afk.lua, 0 problems. New: state read as always down, state read inverted, release not clearing the set, hold counted as a press.
- Driver and editor: read only. Needs a controller session in Ashita to confirm the `state` values of both events and that triggers are not reported as buttons.

## Decisions

- One `afk.button` for both input APIs, keyed on `e.button` and `e.state`, the fields both Ashita events carry. Nonzero is down: XInput reports 1, DirectInput 0x80.
- Buttons down are kept per API (`S.buttons.xinput`, `S.buttons.dinput`) because the two number their buttons differently.
- The hold check is kept even if Ashita only reports changes: it costs a small table and makes "a held button counts once" true whatever the pad does.
