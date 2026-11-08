# Controller input: a button press counts as presence, under the keyboard's restrictions

Branch: `feat/controller-input`, cut from `main` at 668f0f7 on 2026-11-08.

## Acceptance

- [x] A controller button going down wakes the rules and restarts the sleep timer, the way a key press does; XInput and DirectInput both.
- [x] The keyboard's restrictions apply: a button counts once, when it goes down; its release and a button held down count for nothing.
- [x] Sticks, triggers and other axes count for nothing, however far they move: a stick is walking and camera, and a drifting stick is not a hand.
- [x] Input injected by Ashita or another addon counts for nothing: only a human at the pad produces a press.
- [x] A press while the game window is not in front counts for nothing.
- [x] Every line that says "key press" says "key or button press", in chat, the editor, README and NOTICE.

## Plan

1. RED: `lib/pad` reads an `xinput_button` or `dinput_button` event and says whether it is a fresh press, tracking what is held per device; `lib/afk` ignores input while the window is in the background; the WHY lines name buttons.
2. GREEN in `lib/pad` and `lib/afk`; `tactician.lua` registers the two events and latches `S.input`; `lib/session` carries the pad state; editor tip, README, NOTICE.
3. Mutation pass over `lib/pad` and the `lib/afk` change, every new branch recorded in `tools/mutants.txt`.

## Progress

- 2026-11-08: RED, 4 failing (pad module missing, background press, two WHY lines). GREEN, 149 passed, `make check` clean. `make mutate`: 78 mutants, 0 problems (21 new in pad, 1 changed and 1 new in afk, 2 accepted equivalents). Plan, branch; commit and PR pending approval.

## Evidence

- RED: `luajit tests/run.lua tactician`: 138 passed, 4 failed; `lib.pad` not found, the background press restarted the timer, the two WHY lines still said "key press".
- GREEN: 149 passed, 0 failed. `make check` clean.
- Mutation: `make mutate`, 78 mutants, 0 problems. New in pad: button count boundary (both ways), axis guard, hat and button offsets, centre and down bits, hat read, injected guard, fresh needs down and not held, state copied not shared, no-button reading. Changed in afk: presence needs focus. Accepted equivalents: XInput down as `== 1` and DirectInput down as `~= 0`, since Ashita reports only 1/0 and 0x80/0.
- Driver, session and editor tip: read only, not run in Ashita. In game, check: an XInput pad (Xbox) and a DirectInput pad (DualSense) each wake the rules on a face button; a held button does not re-wake after the minute; a stick or trigger alone lets them sleep; with Ashita's gamepad-in-background on, a press while another window is in front leaves them asleep.

## Decisions

- Ashita facts from the SDK header (`plugins/sdk/Ashita.h`: `xinputcallback_f(uint8_t* button, int16_t* state, bool injected, bool blocked)`, `controllercallback_f(uint32_t* dwOfs, int32_t* dwData, ...)`) and the official example addon's event list. XInput ids 0 to 15 are digital with state 1 down; 16 and up are triggers and sticks. DirectInput `button` is the DIJOFS offset: axes below 32, the hat at 32 to 47 (centred is -1, or 0xFFFF in the low word on some drivers), buttons from 48 with 0x80 while down. tCrossBar and cBind read them the same way in production.
- The hat (DirectInput d-pad) is a button: leaving centre is one press, moving between directions while held is not.
- Triggers are axes on XInput and both an axis and a button on a DualSense over DirectInput. The axis counts for nothing; the DualSense's button form (offsets 54 and 55) counts like any button.
- `e.blocked` is not consulted: a button another addon consumed was still pressed by a human.
- NOTICE and README's eligibility paragraph describe the attended-use checks as approved by CatsEyeXI. They now say "key or controller button press"; the approval was given against the key-only wording and should be re-confirmed before this ships.
