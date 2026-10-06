# Changelog

## 1.0.0 (2026-10-05)

tactician moved out of [ffxi-addons](https://github.com/LeebsNick/ffxi-addons), where it shipped as gambits in 1.4.0 through 1.6.0. Everything below lands here as 1.0.0.

### Features

* add the Ashita entry point, editor window and commands
* decode the incoming action packet header and target ids
* define the who, when and do vocabulary
* evaluate when a condition holds for a subject
* gambit rules addon for CatsEyeXI
* hold monster-aimed actions until I am engaged
* index spells, abilities, weapon skills, statuses and items by name
* keep the per-job rule file as an ordered document
* lay out the editor window from the document and engine state
* meter the addon's frame cost
* pace one action in flight at a time
* parse and print a rule as one line
* pick the first rule that fires, with per-rule retry and backoff
* read spell families and tiers from names alone
* render a resolved action as the slash command a player would type
* resolve a rule's who to the subjects it may fire for
* restyle the editor after the Sidekick mock
* restyle the editor in the house palette and rewrite its pickers
* ship per-job rule templates, Scholar first
* short README and an editor restyled after the Sidekick mock
* sleep the rules when nobody moves or fights for ten minutes
* snapshot the game state the rules read
* template panel in the editor
* track what other actors are casting or readying
* turn a rule's do into one usable action or the reason it cannot fire

### Bug Fixes

* editor sizing, retry buttons, a template panel and a frame-cost meter
* list each status once in the picker
* size dropdowns to the window and give retry its own buttons
