# Level roadmap

The Python game at
`C:\Users\kappe\Code\platformertwo\platformersecond` contains eleven explicit
levels. They are the primary idea bank for routes, mechanic order, hazards,
power-up placement, and experiments. Their coordinates, physics values, lives,
orbs, and numbering are not mandates for the current Godot campaign.

The Unreal prototype at `D:\UnrealProjects\Blocky3D` is a secondary reference
for the approved Level 1 and Level 2 reinterpretations. Godot is now canonical.

## Campaign structure

The campaign is organized into themed worlds containing separate short levels.
World 1 is the opening green-zone world and teaches the complete base movement
kit:

| World 1 level | Purpose | New capability | Status |
| --- | --- | --- | --- |
| 1: Fundamentals | Classic run, jump, gaps, enemies, stomp, knife, and finish | Base kit | Complete |
| 2: Gaps & Spikes | Longer precision rhythm, fair spikes, and protected checkpoints | None | Complete |
| 3: Double Jump | Safe introduction followed by required aerial crossings | Double jump | Complete |
| 4: Wall Jump | Turn the route upward and teach wall sensing, cling, and kick-off | Wall jump | Planned |
| 5: Dash | Teach ground and air use in distinct readable zones | Dash | Planned |

World 1 is internally the learning world, but it must not present itself as a
disposable tutorial island. These are the first real levels of the game.
Shortness supports fast retry and replay; the world supplies the larger arc.
By the end of Level 5, later worlds may assume the complete base movement kit.

Later world count, names, themes, and level counts are deliberately open until
World 1 establishes production cost and pacing. Legacy mastery levels may be
expanded, combined, split, redistributed, or discarded.

## Content selection rule

The Python campaign is a quarry, not a blueprint. Every legacy level is broken
into four kinds of evidence:

1. a mechanic worth implementing;
2. a teaching beat or obstacle sequence worth re-authoring;
3. a set-piece or route-shape idea worth saving for a suitable world;
4. prototype filler that should be discarded.

Coordinates, lives, orb economy, placeholder corridors, repeated generic
mastery stretches, and experimental code are not campaign content. Nothing is
retained solely because it appeared in the old game.

The final Python corridor is the clearest example. It is not a model for the
finished game's identity or a required campaign level. Its reactive spikes,
dropping floors, timed platforms, spawned platforms, and moving hazards are
individual mechanic prototypes that can become a reusable trap toolkit and be
placed wherever they support a real level.

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

### Level 3: Double Jump - complete

Level 3 re-authors the Python teaching sequence as a 108-metre Godot route:

- a physical permanent pickup on protected opening ground;
- an immediate height lesson across a clean lethal gap;
- a broad distance crossing that rewards delaying the second jump;
- alternating ordinary and Double Jump crossings so double-tapping does not
  replace timing;
- one focused spike runway with a full-speed safe landing zone;
- one isolated patrol encounter that supports melee, stomp, or aerial bypass;
- a long rise to a high final-proof platform followed by a drop to the chest;
- three grounded-only checkpoints.

The foundation now defines permanent ability ownership in versioned campaign
progress. Checkpoint death, manual restart, level transitions, and application
relaunch retain an earned unlock. Each `LevelDefinition` separately declares
which owned abilities are active there, so Levels 1 and 2 remain single-jump
courses.

The initial movement contract is explicit:

- Double Jump resets vertical velocity to the normal jump impulse and preserves
  horizontal momentum;
- early button release shortens either jump;
- a coyote-time jump remains the ground jump and preserves the aerial jump;
- running from a ledge leaves the aerial jump available;
- only one aerial jump is available until landing or respawn;
- pickup ownership survives every run reset;
- replay sessions start with the ability active and the pickup absent.

The route and mechanics pass automated full-speed completion, visual review,
and hands-on feel approval. Level 3 is now a protected regression baseline.

## Later system milestones

1. Build Wall Jump, directional wall rules, and vertical camera framing for
   World 1 Level 4.
2. Build Dash and distinct ground/air teaching zones for World 1 Level 5.
3. Review all five levels as one world: pacing, repeated material, difficulty,
   visual continuity, unlock flow, and world completion.
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

## Definition of done for a player ability

A new player ability is not complete when it merely works in its introduction
level. It must also:

- be registered as implemented and exposed automatically in the Animation Lab;
- have an immediate on/off toggle that never changes campaign save data;
- retain its selected lab state through `R`;
- have enough lab geometry to test its movement and animation transitions;
- preserve earlier level behavior when unavailable;
- receive focused runtime validation and hands-on feel testing.
