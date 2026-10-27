# Changelog

## [1.2.0](https://github.com/LeebsNick/tactician/compare/v1.1.1...v1.2.0) (2026-10-27)


### Features

* fire a weapon skill after a party member's, ws_within:6 for closing skillchains ([#18](https://github.com/LeebsNick/tactician/issues/18)) ([8d2dd6a](https://github.com/LeebsNick/tactician/commit/8d2dd6a29670b6ab475163346b912005478e1bd1)), closes [#8](https://github.com/LeebsNick/tactician/issues/8)
* let a condition read another scope, target.hpp_gte:10 beside a self rule ([#11](https://github.com/LeebsNick/tactician/issues/11)) ([8ca5c27](https://github.com/LeebsNick/tactician/commit/8ca5c27647e60e44fd5616717e151ad18dde6c6a)), closes [#7](https://github.com/LeebsNick/tactician/issues/7)
* offer only what the job can use in the editor pickers, and grey out what cannot be picked yet ([#17](https://github.com/LeebsNick/tactician/issues/17)) ([bf1646b](https://github.com/LeebsNick/tactician/commit/bf1646bf312553a26b2aea5642e1b2c493a0b347)), closes [#14](https://github.com/LeebsNick/tactician/issues/14)
* say why nothing fires, off, paused or asleep, in the editor and in chat ([#12](https://github.com/LeebsNick/tactician/issues/12)) ([de1677f](https://github.com/LeebsNick/tactician/commit/de1677f46f1e72988901a44634d1e8810d12f0b9))

## [1.1.1](https://github.com/LeebsNick/tactician/compare/v1.1.0...v1.1.1) (2026-10-24)


### Miscellaneous Chores

* cut 1.1.1 so the release zip carries NOTICE ([18b7e3e](https://github.com/LeebsNick/tactician/commit/18b7e3eea5f3a505b6c7b74135be615745a55798))

## [1.1.0](https://github.com/LeebsNick/tactician/compare/v1.0.0...v1.1.0) (2026-10-17)


### Features

* run only while attended, window in front and a key press within the last minute ([#1](https://github.com/LeebsNick/tactician/issues/1)) ([c3dfdb4](https://github.com/LeebsNick/tactician/commit/c3dfdb49b5c6c25cb7492809749e731ed338e358))

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
