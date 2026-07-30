# Level roadmap

The Python game at
`C:\Users\kappe\Code\platformertwo\platformersecond` contains eleven explicit
levels. They are the primary idea bank for routes, mechanic order, hazards,
power-up placement, and experiments. Their coordinates, physics values, lives,
orbs, and numbering are not mandates for the current Godot campaign.

The Unreal prototype at `D:\UnrealProjects\Blocky3D` is a secondary reference
for the approved Level 1 and Level 2 reinterpretations. Godot is now canonical.

## Campaign spine

The current target teaches the complete base movement kit early:

| Campaign level | Purpose | New capability | Status |
| --- | --- | --- | --- |
| 1: Fundamentals | Classic run, jump, gaps, enemies, stomp, knife, and finish | Base kit | Complete |
| 2: Gaps & Spikes | Longer precision rhythm, fair spikes, and protected checkpoints | None | Complete |
| 3: Double Jump | Safe introduction followed by required aerial crossings | Double jump | Next |
| 4: Wall Jump | Turn the route upward and teach wall sensing, cling, and kick-off | Wall jump | Planned |
| 5: Dash | Teach ground and air use in distinct readable zones | Dash | Planned |

Later campaign numbering is deliberately open. Legacy mastery levels may be
expanded, combined, split, reordered, or replaced once the reusable toolkit
exists.

## Current levels

### Level 1: Fundamentals — complete

Level 1 is the production vertical slice. Its six-platform route establishes
the approved movement, orthographic camera, pixel-art pipeline, first patrol
enemy, stomp and knife rules, restrained combat feedback, chest goal, and fast
full restart.

It preserves the classic opening intent of Python Level 1 without copying that
level's full length or coordinates. It is deliberately straightforward:
movement and encounter readability matter more than camera novelty.

### Level 2: Gaps & Spikes — complete

Level 2 is the longer fundamentals regression course:

- 22 platforms across a 131-metre route
- five visible spike rows with inset foot-level damage
- six patrol enemies
- four invisible grounded-only checkpoints
- opening stairs, separated islands, a precision staircase, a two-row spike
  run, narrow rising blocks, and a final climb
- no hidden safety ground beneath raised platforming routes

Floating spike rows are centered between neighboring platform edges by
default. Width and position remain independent so future levels can author
equal margins, edge contact, or intentional asymmetry.

Automated checks cover authored counts, route measurements, spike fairness,
spike centering, checkpoint earning, death respawn, manual restart, and a full
input-driven completion.

## Eleven-level legacy idea bank

| Python reference | Core idea worth preserving | Current use |
| --- | --- | --- |
| 1: Easy Stroll | A welcoming Mario-like run with basic platforms, pits, spikes, enemies, collectibles, checkpoints, and a clear flag | Condensed into current Level 1; longer route remains optional material |
| 2: Gaps & Spikes | Longer fundamentals, rising steps, narrow landings, ground hazards, and repeated pacing checkpoints | Re-authored as current Level 2 |
| 3: Double Jump | Pickup near the opening, immediate tutorial, broad gaps, elevated landings, and a final aerial proof | Basis for campaign Level 3 |
| 4: Mastery | Combine established movement under pressure with spike beds, enemies, mirrored routes, and optional rewards | Combination material after Double Jump; not tied to campaign Level 4 |
| 5: Wall Jump | Opening pickup, a safe wall shaft, horizontal breathers, then a tall alternating-wall finish | Basis for campaign Level 4 |
| 6: Mastery II | Extend wall movement with directional wall spikes, longer vertical climbs, enemies, and reward ledges | Later combined-ability and directional-hazard material |
| 7: Saws | Horizontal and vertical moving hazards inside climbing and runway sections | Basis for a reusable path-mover hazard family |
| 8: Long Way Around | A large route that climbs right, drops, returns left below the start, climbs again, and finishes across a top trial | Basis for multidirectional routes, camera rails, and meaningful 2.5D turns; must be re-scaled |
| 9: Stepping Stones | Long precision endurance: small platforms, extended wall climbs, hard aerial gaps, and a chasing saw | Mastery/endurance material; must be re-scaled rather than preserving the cramped footprint |
| 10: Dash | Five teaching zones: long ground gap, jump-then-air-dash, low ceiling dash, vertical combination climb, and delayed dash drop | Move the useful teaching zones forward into campaign Level 5 |
| 11: Corridor Test | Reactive spike triggers, landing-dependent spikes, dropping floors, timed platforms, spawned platforms, and spawned saws | Source for a reusable reactive-level toolkit, not necessarily one final corridor level |

## Level 3 brief: Double Jump

Level 3 is the next milestone. The Python layout is evidence for a teaching
sequence, not a coordinate sheet.

The new level should contain:

1. A protected opening and the Double Jump unlock.
2. A safe space where the second jump can be discovered without dying.
3. A crossing that clearly cannot be completed with one jump.
4. Several variations: extra height, extra distance, and delayed timing.
5. Recovery or checkpoint placement that supports learning without erasing the
   challenge.
6. A final section that proves the ability while still using the established
   enemy, spike, and melee rules.

Before geometry is finalized, define:

- where ability ownership lives;
- whether a checkpoint respawn retains the unlock;
- whether manual restart retains it;
- how level transitions and application relaunch persist it;
- how falling from a ledge, coyote time, buffering, and variable jump height
  interact with the available aerial jump;
- how future wall jump and dash refresh rules will compose with it.

Level 1 and Level 2 must remain single-jump regression levels unless their
future level data explicitly grants another ability.

## Later system milestones

1. Ability ownership, versioned progression, and Double Jump through Level 3.
2. Wall movement, directional hazards, and vertical camera framing.
3. Dash moved into the early campaign and tested with the earlier abilities.
4. Generic moving hazards developed from the saw levels.
5. Camera rails, route turns, large-level state, and multi-direction traversal
   developed from Long Way Around and Stepping Stones.
6. Telegraph/trigger/active/cooldown/reset state machines developed from
   Corridor Test and the shaking-block spike idea.
7. Campaign progression, records, settings, accessibility, audio, packaging,
   and content expansion.

## Definition of done for a level

A level is complete when:

- its lesson and intended route can be stated clearly;
- required abilities are taught or assumed deliberately;
- jumps, hazards, attacks, and recoveries feel fair at running speed;
- checkpoints can only be earned through successful grounded traversal;
- death and manual restart restore every mutable actor correctly;
- the intended route is readable and common accidental shortcuts are handled;
- decoration never hides gameplay or implies false collision;
- reusable behavior is not hidden in a level-specific patch;
- automated runtime and full-route validation cover its lasting contracts;
- visual captures and hands-on playtesting agree.
