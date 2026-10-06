# tactician

A player-authored combat rules system for CatsEyeXI. Build your own conditional actions, inspired by Final Fantasy XII's Gambit system. Ashita only.

Each rule is a gambit: a scope / if / then line for your own character, read top down every third of a second. The first one that fits is sent as the slash command you would have typed.

It casts, uses abilities and items, and fires weapon skills and ranged attacks. It never engages, moves, targets or claims, and it has no say over trusts or other players. Anything aimed at the monster waits until you are engaged. After ten minutes without a step or a key press from you the rules sleep, whatever the party is doing, and only your own movement or key press wakes them. Rules are off at every load; `/tactician on` starts them.

It is an attended helper, not a bot: it only sends the slash commands you could type, through the same path as typed text, it never pulls, and it stops acting when you stop being there. Check your server's rules on addons before running it.

## Install

Download `tactician-vX.Y.Z-ashita.zip` from [releases](../../releases), unzip it into `Ashita/addons/`, and `/addon load tactician`.

## Rules

One file per job, `config/addons/tactician/<character>/<JOB>.txt`, one rule per line. The editor (`/tactician`) writes it, `/tactician add` appends to it, and a text editor works too.

```
party hpp_lt:50 ma:highest:Cure
party_dead always ma:Raise
self not_status:Protect ma:highest:Protect retry:10
target casting_ma ma:Stun
self tp_gte:1000 ws:"Fast Blade"
off self hpp_lt:30 item:Hi-Potion
```

A rule is `[off] <scope> <if> [and|or <if>] <then> [retry:<seconds>]`. Quote a name with a space or colon in it. `#` starts a comment. A line that does not parse is kept and shown in the editor with the error.

| scope | reads |
|---|---|
| `self` | you |
| `party` | anyone in the party, you included, lowest HP first |
| `tank`, `melee`, `ranged`, `caster` | party members by main job |
| `party_dead` | a party member at 0 HP |
| `target` | the monster you have targeted |
| `pet` | your pet, avatar or automaton |

| if | argument | readable for |
|---|---|---|
| `always` | | anyone |
| `hpp_lt`, `hpp_gte` | percent | anyone |
| `mpp_lt` | percent | you, party, pet |
| `tp_lt`, `tp_gte` | TP | you, party, pet |
| `status`, `not_status` | effect name | you, party |
| `hp_missing` | HP | you |
| `random` | percent chance | anyone |
| `casting_ma`, `readying_ms` | | the target |

| then | example |
|---|---|
| `ma:<spell>` | `ma:"Cure III"` |
| `ma:highest:<family>` | `ma:highest:Cure`, the highest tier learned, usable, affordable and off recast |
| `ja:<ability>`, `ja:highest:<family>` | `ja:Provoke`, `ja:highest:"Curing Waltz"` |
| `ws:<weapon skill>` | `ws:"Fast Blade"` |
| `rattack` | |
| `item:<item>` | `item:Hi-Potion`, from your inventory or temporary items |

A spell or ability lands on the scope when it can. One that only lands on a monster goes to your target, as do weapon skills and ranged attacks. Items are used on you. `retry` rests a rule after it fires; without it the recast decides. A command the game refuses rests its rule for five seconds.

## Commands

| command | does |
|---|---|
| `/tactician` | toggle the editor |
| `/tactician on`, `/tactician off` | run or stop the saved rules |
| `/tactician list` | print this job's rules |
| `/tactician add <rule>` | append a rule |
| `/tactician template` | append the job's starting set, when one ships |
| `/tactician del <n>`, `/tactician move <n> <m>`, `/tactician toggle <n>` | edit by number |
| `/tactician reload` | re-read the file |
| `/tactician status` | running, asleep or stopped, what was last sent, and the frame cost of the tick and the editor |

An empty job offers its template in the editor footer. The editor edits a copy; nothing runs until Save. The row that fired last is shaded green. A rule number marked `!` can never fire as written and says why on hover.

## Templates

A starting set per job under `templates/<JOB>.txt`, in rule syntax, ordered so the setup a job needs comes before anything that depends on it. Scholar puts Light Arts up before any cure or buff and keeps Sublimation charging. Edit the result; it is a start, not a build.

| job | template |
|---|---|
| SCH | Light Arts, cures, Raise, Sublimation tap at low MP, Protect, Shell, Regen, Sublimation charge |

## Development

`tactician/tactician.lua` is the driver and lists the modules. `tactician/lib/` is pure logic, tested with `make test`, except `session`, `resources`, `commands` and `editor`, which need Ashita. The vocabulary keys and ids are CatsEyeXI's `scripts/globals/gambits.lua` trimmed to what a client can read about itself, its party and its target; `pet` and `item` are the two additions.

```
make check            # luacheck + tests
make stage            # unzipped tree under dist/stage/ashita/tactician/ to symlink into Ashita/addons/
make dist VER=1.0.0   # release zip under dist/
make mutate           # the recorded mutants in tools/mutants.txt
```

Releases are cut by release-please from the conventional commits on main; see [CONTRIBUTING](CONTRIBUTING.md).
