# Issue #14: scope every picker to the active job and refuse unlearned entries

Issue: https://github.com/LeebsNick/tactician/issues/14 (also closes #6, the weapon skill slice)
Branch: `feat/14-picker-job-scope`, cut from `main` at 664e314 on 2026-10-27.

## Acceptance

- [x] Spell, family, ability and weapon skill pickers list only entries the active main or sub job can use at some level.
  Spells and spell families: by the per-job level table. Abilities and weapon skills: what the character has now (see Decisions).
- [x] Entries the job can use but the character has not learned, or is under level for, stay listed, dimmed, with the reason beside the name. Spells and spell families.
- [x] A dimmed entry cannot be picked. `ImGuiSelectableFlags_Disabled` on the row; a click leaves the rule unchanged and the popup open. Editor change, not testable here.
- [x] Changing job refreshes every picker's list. The tick clears `S.cat` after `session.switch`, so the same tick rebuilds the catalog, `known` and `S.picks`. Driver change, not testable here.
- [x] A rule file that names a spell or weapon skill outside the filtered list still parses and shows that name in the row. Test added.
- [x] Items and statuses are not filtered. Test added.

## Plan

1. RED in `view_test.lua`: Stun and Utsusemi absent for a WHM/BLM, Sleepga present greyed via the sub job, a job change moves the list, Stun family absent, Provoke and Combo absent, items and statuses untouched, a hand-written Stun rule still reads `Cast Stun` with `not learned`.
2. GREEN in `lib/view.lua`: `for_job` on the spell level table; spell families cut to the tiers the job pair has; abilities, ability families and weapon skills cut to what is known.
3. `lib/editor.lua`: disabled flag on greyed rows. `tactician.lua`: force the refresh on job change. README: one paragraph on what the pickers offer.
4. Mutation pass on `lib/view.lua`, survivors recorded in `tools/mutants.txt`.

## Progress

- 2026-10-27: RED, 4 failing. GREEN, 118 passed, `make check` clean. Mutation: 11 mutants on view.lua, 0 problems. WIP doc, commit, PR.

## Evidence

- RED: `luajit tests/run.lua tactician`, 4 failures in view_test.lua: `a dark knight spell is not offered to a WHM/BLM` (Stun present), `and the black magic went with BLM` (Sleepga present), `no tier of it is for a WHM/BLM` (Stun family present), `Provoke is not mine` (four abilities listed).
- GREEN: 118 passed, 0 failed. `make check` clean.
- Mutation: `make mutate MODULE=tactician/lib/view.lua`, 11 mutants, 0 problems. All eleven are new, one per added branch (job filter, sub job half of it, each known filter, the family why fallbacks).
- Editor and driver: read only, not run in Ashita.

## Decisions

- Abilities and weapon skills list what the character has, nothing greyed. The DAT entries for abilities and weapon skills carry no job or level, so `not for X/Y` and `needs X N` cannot be computed for them; the client's own `HasAbility`/`HasWeaponSkill` already reflect the job pair at its current levels. A greyed entry that could never become pickable would be noise, which is what the issue is about. Writing ahead of the level for those two kinds means typing the rule in the file, as before for any name the picker lacks.
- Spells keep `not learned` ahead of `needs X N`, as before: the learned check is the cheaper fact and the one a player acts on first.
- `S.cat = nil` after a job switch rather than a new flag: `cat == nil` is already the documented way the tick forces a rebuild, and the refresh clears `S.picks`.
