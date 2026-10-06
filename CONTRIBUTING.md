# Contributing

Bug reports and pull requests are welcome. Open an issue first for anything larger than a fix, so we can agree on the shape before you spend time on it.

## Setup

`luajit` runs the tests and `luacheck` lints. On macOS: `brew install luajit luacheck`. On Windows, LuaJIT ships with Ashita under `Ashita/bin/`, or install it from [luajit.org](https://luajit.org/install.html).

```
make check   # lint + tests
```

## How the code is laid out

`tactician/tactician.lua` is the driver: it owns the state table, runs the tick and registers the Ashita events. `tactician/lib/` holds the modules; `session`, `resources`, `commands` and `editor` talk to Ashita, everything else is pure logic with one `*_test.lua` per module under `tactician/tests/`. Anything that talks to the game client gets an object passed in so tests can hand it a plain table instead.

## Tests first

Write the failing test in `tactician/tests/`, then the smallest change in `tactician/lib/` that passes it. Changes to the four Ashita modules are the exception; say so in the PR and describe what you checked in game.

Test names describe the behaviour, not the function: `a rule aimed at the monster waits until engaged`, not `test resolve`.

After tests are green, run `make mutate` for the module you touched and add any new survivor you accept, with the reason, to `tools/mutants.txt`.

## Style

Follow the Ashita addon conventions already in the files: 4-space indent, single quotes, trailing semicolons, `if x then` without parentheses. Keep functions small and pure where possible. No new globals; luacheck will tell you.

Comments that start with `ponytail:` mark a known limitation or a shortcut taken on purpose. Use one when you leave something simpler than it could be.

## Pull requests

One change per PR. Commit messages use the `type: summary` form, for example `fix: list each status once in the picker`. CI must be green.

The summary of every `feat` and `fix` commit becomes a CHANGELOG line under the next release, so write it for someone reading the release notes: what changed in game. Do not bump `addon.version` or edit the CHANGELOG yourself; release-please does both in the release PR.
