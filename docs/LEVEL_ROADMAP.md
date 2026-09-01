# Level roadmap

This document owns the production campaign. The deleted prototypes proved
mechanics; they never dictated the final number,
size, or order of levels.

The Python game at
`C:\Users\kappe\Code\platformertwo\platformersecond` remains the primary idea
bank for routes, hazards, power-up placement, and experiments. The Unreal
prototype at `D:\UnrealProjects\Blocky3D` is a secondary visual and layout
reference. Godot is canonical.

## Current implementation

Arrival / Shoreline is the only production campaign entry. Overgrown Coastal
Ascent is complete and hands-on accepted through the developer entries; its
next step is a structural promotion into World 1 and a continuous handoff from
Level 1, not more level design.

The six Green Zone prototype levels that preceded this are deleted. They were
regression evidence for the movement kit, and that job is finished: every
contract they proved now lives somewhere permanent. Movement, Double Jump, Wall
Jump and Dash are validated in the Animation Lab, which is their declared home;
camera pixel stability runs against Arrival; fresh-per-load progression and
vertical background coverage run against the Level 2 interior, whose 28 m shaft
is a longer climb than either prototype offered. Only one assertion did not
survive the move - a level that starts with an ability locked - and the Level 2
Wall Jump pickup covers it with content that ships.

Deleting them removed six scenes, twelve validators, six capture scripts and
the regression catalog, and cut a full validation run from 282s to 150s. Git is
the archive if any of it is ever wanted again.

## Target World 1 structure

World 1 is the opening Green Zone, informally the tutorial island. It consists
of approximately three substantial levels with internal sections, fast
checkpoints, and meaningful escalation. It begins with beach and natural
imagery while the Biker, interface, machinery, and enemies foreshadow the
larger cyberpunk setting.

| Target level | Core arc | New capability | Status |
| --- | --- | --- | --- |
| 1: Arrival / Shoreline | Classic fundamentals grow into an aerial route | Double Jump | Complete and accepted; production baseline locked at commit `59a034b` |
| 2: Overgrown Coastal Ascent | A brief Green Zone approach gives way to an enclosed cavern / underworks route | Wall Jump and Dash | Complete and accepted in development form; pending campaign promotion |
| 3: Green Zone Finale | Full-kit mastery, saws, enemy escalation, gun lesson, and boss | Limited firearm | Planned concept |

These are working titles. A level should be long enough to develop several
connected ideas, but it should still end before repetition becomes padding.
Checkpoint spacing preserves the quick-retry rhythm inside the larger route.

### Level 1: Arrival / Shoreline

The opening must initially read like a confident classic platformer rather than
a tutorial interface:

1. arrive in a calm, readable beach/green-zone space;
2. establish running, variable jump height, gaps, and fast restart;
3. introduce one familiar patrol through jump-over, stomp, or knife options;
4. award Double Jump beside a protected checkpoint;
5. require it immediately for height and then distance;
6. establish fair spike rhythms and a second landmark checkpoint;
7. develop Double Jump through height, distance, and short-release timing;
8. mix in a flow encounter and spike recap, then end on safe flat ground at a
   tire-swing tree landmark rather than repeating the lesson.

The developer tooling used for hands-on layout review — the F10 measurement
grid, F11 inspection mode, and F7 collision overlay — is specified in
`docs/TECHNICAL_FOUNDATION.md` under Developer tools.

The production level was authored in reviewable slices rather than padded to
its target runtime in one pass. Its locked opening includes the shoreline,
one ordinary traversal beat, and one patrol encounter. Green Threshold adds a
short readable thorn row, protects the Double Jump unlock, then asks for an
immediate height proof and a landing encounter. Thorn Garden develops that
ability through two sunken lethal beds, raised recovery terrain, an enemy perch,
and a committed descent to a landmark checkpoint. A later stitched-tree ascent
was technically traversable but visually incoherent, so its geometry, scenery,
background layers, checkpoint, and goal placement were removed rather than
kept as baggage. The replacement open-air rise alternates ascending and
descending Double Jumps over a continuous thorn basin. Its last high ledge
frames a lower landing outside the player's view: dropping straight meets a
permanent spike cluster spanning the ordinary forward-fall line, while
committing the Double Jump farther forward clears it. Two familiar patrols add
optional stomp, jump-over, or knife beats without changing the route: one on
the small dip platform and one constrained to a safe lane beyond the blind
landing. Small foliage and one grounded tree dress those platforms behind the
gameplay plane without implying collision. Beyond the patrol lane, the landing
simply continues as safe flat ground toward a tire-swing tree landmark. An
invisible exit trigger in that clearing replaces the temporary chest and fades
to completion. No new terrain trick, hazard, enemy, checkpoint, or mechanic is
introduced. A reviewed, non-colliding skate half-pipe fills the final Thorn
Garden takeoff platform: its right lip ends at the terrain edge and points
toward the first aerial landing, while its matching left side turns the prop
into a coherent local landmark rather than a disconnected ramp.

#### Constraints that still bind Level 1

The rise is built and locked. Two of its authoring constraints continue to
apply to any later edit: Level 1 does not introduce Wall Jump and must not
become a shaft, corridor, folded return route, or indoor puzzle, and it keeps
the established horizontal camera framing. Sustained shafts and Wall Jump
camera work belong to Level 2. The broader rules that work produced — build
beats from art that belongs in the place, keep decoration behind readable
gameplay, and let human playtesting rather than the bot decide difficulty — are
recorded in `docs/SET_DRESSING_WORKFLOW.md` and `docs/TECHNICAL_FOUNDATION.md`.

The opening uses shoreline sand and water against the Green Zone background,
then joins directly into existing Green Zone terrain. Grounded land uses the
complete source-tile grammar: top and root rows, dark deep fill where needed,
and a proper bottom cap instead of repeated body art. The Green Zone side rises
half a tile above the beach at a scaled mossy outcrop, with low foliage and a
smaller tree carrying the transition into the zone without blocking actors.
Structural and session-isolation checks own technical correctness. Automated
traversal may prove that legal inputs can complete the current route, but it
does not approve difficulty, fairness, pacing, or feel. Those remain gated on
normal-speed human playtesting before the next section is authored.

The arrival water uses the beach pack's synchronized tile animation. Three
authored crests repeat on a fixed cycle, so the surf is deterministic and
survives death and restart without resetting. A crest is the source clip's low
frames played at the terrain pixel scale, never the full-size roller shrunk to a
finer resolution.

Crests swell, lap a short distance inshore, and sink back. They submerge less
the nearer they break, so waves grow toward the beach rather than a distant
swell towering over a near one, and each swell peaks on arrival so the wave is
still at full size when it lands. Only a crest that reaches the sand triggers
the shore splash; the splash lands on that crest's body and the crest is cut as
it appears, so the wave reads as becoming the effect. Sprites anchor on the
clip's own waterline and visible leading edge rather than on frame bounds, since
a submerged crest's tapering toe is masked by the water. None of this adds
collision or changes the lethal-water volume.

Deterministic capture frames cover both the offshore swell and the shore break
so future presentation changes cannot quietly desynchronize the effect.

Its authored background profile moves from a restrained coastal hint into
established Green Zone depth as the camera travels inland. The environment
colour deliberately owns complete vertical sky
coverage; horizon and decorative tracks need not fill the screen vertically.
Any future layer that promises full-height artwork must declare and validate
that contract explicitly rather than changing the shared default.

### Level 2: Overgrown Coastal Ascent

Level 2 begins with a brief Green Zone approach, then sends the player into a
cave, mine, tunnel, or collapsed maintenance underworks where the substantial
route takes place. The isolated terrain proof and editable interior establish a
coherent enclosed space; the exact fiction and final title remain provisional.
Walls, ceilings, shafts, and controlled sightlines give Wall Jump and Dash
geometry a natural visual cause. They are not permission to assemble a room
from unrelated props or collision patches.

The approach and the interior are two scenes joined by a fade, not one
continuous space. Running into the cave mouth triggers a `LevelTransition3D`,
the screen fades to black, the interior scene loads behind it, and the fade
lifts. This is a decision rather than a convenience:

- the outdoor approach is a short, low-stakes combat bridge whose two patrols
  roam from the opening tree line to the cave mouth; the cave remains the
  substantial route and escalation;
- the player arrives straight out of Level 1 still running, so the approach is a
  bridge rather than an opening beat;
- the black screen doubles as a time skip, which is what licenses the approach
  being late in the day when Level 1 ended in daylight;
- joining the outdoor platform grammar to the enclosed interior grid along a
  visible seam was tried and rejected. It produced a flat cliff face and leaked
  the outdoor sky through the interior chambers. A doorway costs nothing and
  reuses cleanly for any later door, tunnel, or building.

Matched thresholds author each half of that black screen separately. At the
cave, the source player disappears into the mouth rather than running past its
art. The black then reveals a short downhill slide, lands inside the cave, and
hands the player into the established rightward run with visible momentum.
Input returns when the entrance fade finishes. A direct menu or developer load
stays stationary. Continuous run-out/run-in remains the approved rule for the
Level 1-to-Level 2 cut; wiring that connection is the promotion step that
follows this completed-level checkpoint.

`scenes/dev/level_2_wip.tscn` currently owns this handoff and its dressing. The
approach uses the `green_zone_dusk` background; the interior owns its separate
cave environment. `docs/LEVEL_2_VISUAL_BRIEF.md` is the source of truth for its
accepted background zoning, regional grade, ceiling, and camera composition.

The approach now enters the live
`overgrown_coastal_ascent_interior.tscn`; the directly loadable Interior WIP
remains only a review shortcut. The earlier frozen snapshot is no longer the
handoff target. Hands-on review accepts the whole connected route, so promotion
must preserve this build rather than re-stage it.

The completed teaching arc is:

1. one familiar opening jump confirms ordinary control;
2. the player enters the enclosed route before the main lesson begins;
3. Wall Jump is introduced and immediately required in a safe shaft;
4. chambers, horizontal breathers, and recovery landings vary the vertical
   rhythm;
5. increasingly offset shafts combine Wall Jump with saved Double Jump;
6. Dash is introduced and immediately opens a crossing ordinary jumps cannot;
7. the upper route escalates through one slow hovering-machine chamber and a
   paired opposite-phase chamber;
8. a final run places enemies on both sides of a Dash-required spike strip; and
9. the player chooses a position on the cave lift, stands still for one second,
   then rides upward until the level fades out.

The interior implements the movement lessons as one connected route. A low
enclosed tunnel recaps an enemy and visible spikes, then three
separate unsupported platforms rise toward the shaft and require the owned
Double Jump. The player collects Wall Jump at the shaft floor, climbs between
two continuous walls, and meets a spiked right-hand cap that redirects them
left to the Dash pickup. Returning right now uses a 13.28 m row of 17 spikes:
the original left edge remains fixed and all four additions extend right. It is
beyond the 11.79 m Double Jump envelope but comfortably inside the Double Jump
plus Dash envelope, so the newly collected ability is required. Its following
checkpoint is shifted clear of the widened hazard.

The machine shaft is now built at the end of that route. The corridor breaks for
14.08 m, open floor to sky, with one hovering machine bobbing slowly in the gap;
falling in is a long drop past the kill plane. The machine is indestructible and
cannot be stabbed or stomped, its body is always lethal, and its electrical
discharge hangs beneath it, so the low route is the timed one. Its travel never
closes both routes at once, which the structural validator asserts. Hands-on
review accepts this first deliberately isolated, slow encounter. Later chambers
may vary speed, phase, and count, one at a time.

The immediate follow-up repeats that exact 14.08 m chamber after another
12.8 m readable run-up. The gap is divided into equal horizontal thirds: one
machine occupies each outer third with a small symmetric bias toward the empty
middle, giving both ledges extra clearance. They begin half a bob cycle apart,
so the left starts upward while the right starts downward. A checkpoint at the
start of the runway preserves the encounter boundary. Hands-on review accepts
the timing and readability of both machine chambers.

After their landing, a short readable run-up leads to the exit gauntlet. Two
ground enemies bracket a spike strip whose width requires Dash, so the player
must read enemy timing as part of the crossing rather than treating the finish
as an empty victory corridor. The route ends at a cave construction lift. Mere
proximity never steals control: the player must be fully supported by the deck
and stand still for one continuous second before departure. The camera remains
fixed while the lift rises, the ascent is visible, and the one-second completion
fade reaches black before the physical ceiling. This lift departure is the
accepted end of Level 2.

The asset audit and enclosed-terrain lab established the production direction:
a natural cavern or mine that can gradually reveal restrained buried
infrastructure. The reusable grid-driven terrain now owns connected floor,
ceiling, wall, corner art, and consolidated collision; props may dress or
explain the space but never hold its shell together. The lab remains a
disposable construction fixture rather than a miniature Level 2. That proof is
complete and is no longer an active milestone.

### Level 3: Green Zone Finale

The finale is a payoff level, not another isolated movement lesson:

1. recap fundamentals and the complete movement kit without prompts;
2. introduce reusable horizontal and vertical moving saws safely, then combine
   them with traversal;
3. escalate the enemy roster gradually rather than deploying every owned asset;
4. build one or more memorable full-kit sequences with recovery checkpoints;
5. place a fixed firearm shortly before the final encounter;
6. teach horizontal and upward-diagonal shooting in a short safe situation;
7. finish with a simple, readable first boss using movement, limited shooting,
   and viable melee openings.

The boss is never an ammunition check. Initial ammo is useful but not a license
to ignore the encounter, and zero ammo cannot make victory impossible. A few
meaningful vulnerability windows are preferable to a long health sponge. The
golf-cart/driver asset is the leading visual candidate because it supports a
movement set piece and a second form, but the selection remains open until the
Combat Lab can compare the available bosses at player scale.

## Content selection rule

The legacy games and asset library are quarries, not blueprints. Every old level
or downloaded asset is sorted into one of four categories:

1. a mechanic worth implementing;
2. a teaching beat or route shape worth re-authoring;
3. a presentation or set-piece idea worth saving for a suitable world;
4. prototype filler or unused art that should be discarded.

Coordinates, lives, orb economy, placeholder corridors, repeated mastery
stretches, folder names, and experimental code are not campaign content.
Nothing is retained solely because it already exists or was purchased.

Asset folders record likely future families, not walls between zones. Green
Zone remains visually coherent, but a small beach, factory, rock, bridge, or
other asset may be borrowed when it fits the local composition.

## Eleven-level legacy idea bank

| Python reference | Core idea worth preserving | Intended use |
| --- | --- | --- |
| 1: Easy Stroll | Welcoming fundamentals, pits, spikes, enemies, collectibles, checkpoints, and a clear finish | New Level 1 opening material |
| 2: Gaps & Spikes | Longer fundamentals, rising steps, narrow landings, and repeated pacing checkpoints | New Level 1 development material |
| 3: Double Jump | Early pickup, immediate tutorial, broad gaps, elevated landings, and final aerial proof | New Level 1 second half |
| 4: Mastery | Established movement under pressure with enemies and optional rewards | Combination material, not a dedicated remake |
| 5: Wall Jump | Early pickup, safe shaft, horizontal breathers, and alternating-wall finish | New Level 2 opening material |
| 6: Mastery II | Directional wall hazards, longer climbs, enemies, and reward ledges | New Level 2 and later mastery material |
| 7: Saws | Horizontal and vertical moving hazards in climbs and runways | New Level 3 reusable hazard family |
| 8: Long Way Around | A route that climbs, returns beneath itself, and finishes above | Discarded. It existed for multidirectional routes and 2.5D turns, which the game no longer does |
| 9: Stepping Stones | Small-platform endurance, wall climbs, hard gaps, and a chasing saw | Later mastery material after rescaling |
| 10: Dash | Ground gap, air Dash, low route, vertical combination, and delayed Dash | New Level 2 second half |
| 11: Corridor Test | Reactive spikes, dropping floors, timed and spawned platforms, and spawned saws | Reusable reactive-trap toolkit for later worlds |

## System roadmap

### Completed for Level 1

Level 1 is complete and locked: the shoreline opening, Green Threshold, Thorn
Garden, the open-air Double Jump rise with its concealed landing cluster, two
patrol encounters, the dressed Green Zone pass, and the tire-swing clearing
finish. The build record is in git history, and the rules that work produced are
recorded where they apply — set-dressing practice in
`docs/SET_DRESSING_WORKFLOW.md`, runtime and tooling contracts in
`docs/TECHNICAL_FOUNDATION.md`, and the level's own design statement above.

Two outcomes stay in view because they shaped what Level 2 may do. The
stitched-tree ascent was removed rather than kept as baggage once it proved
visually incoherent. The opt-in vertical camera region and the corridor/fold
route language were both proven in isolation and then deliberately withheld from
Level 1, leaving them for Level 2 to own.

### Completed Level 2 presentation

The completed development build owns the reviewed presentation from the dusk
approach through the lift departure:

- a five-layer smoky lower cave that blends broadly into the pale upper cave;
- a regional grade synchronized with that spatial handoff;
- localized water vistas plus one shared upper rocky ceiling; and
- independent horizontal shaft focus while the vertical camera follows the
  Wall Jump climb;
- a cave-slide interstitial and blended interior arrival; and
- fixed lift framing that lets the machinery move while the composition stays
  still.

Deterministic captures, focused automation, and hands-on traversal accept this
composition and the finished route. The user has explicitly approved production
promotion; promotion is a catalog/path/flow change and must not redesign the
accepted level.

### Needed before the finale

1. A reusable path-driven saw hazard with deterministic restart behavior.
2. Typed enemy visual sets separated from reusable behavior archetypes.
3. A focused projectile contract shared by enemies, firearms, and bosses where
   their rules genuinely overlap.
4. A firearm resource describing visuals, ammunition, cadence, projectile, and
   supported aiming directions without owning player movement.
5. Contextual ammo HUD that remains absent before a firearm is available.
6. A boss-specific state machine using shared damage, reset, and projectile
   contracts rather than a giant universal boss controller.
7. A development-only Combat Lab for enemy, melee, projectile, firearm, and boss
   inspection. Animation Lab remains focused on player presentation.

### Interface and optional systems

The cyberpunk GUI pack is the source for a future reusable Godot theme: start
screen, world/level selection, pause, options, accessibility, confirmations,
contextual HUD, and development controls. Import a curated subset rather than
the complete pack.

Weapon construction, crafting, skill trees, large inventories, collectible
economies, and advanced upgrades remain unapproved options. Their artwork may
inform later prototypes but does not place them on the production schedule.

## Definition of done for a level

A level is complete when:

- its lesson, progression, and intended route can be stated clearly;
- every new ability is used soon after acquisition;
- jumps, hazards, attacks, and recoveries feel fair at running speed;
- checkpoints require successful grounded traversal and cannot skip content;
- death and manual restart restore every mutable actor deterministically;
- the route is readable and common accidental shortcuts are handled;
- decoration never hides gameplay or implies false collision;
- reusable behavior is not hidden in a level-specific patch;
- focused runtime and input-driven route validation cover lasting contracts;
- visual captures and hands-on playtesting agree;
- automated completion is treated as technical evidence, never as the
  difficulty authority. If a legal route defeats the bot, improve the bot or
  flag the case for human review rather than silently softening the level.

## Known visual defects

- **Death animation flashes at respawn.** Occasionally the death strip is
  visible for a frame or two as the player respawns. Intermittent and not yet
  reproduced. What is already ruled out: `PlayerCharacter.reset_at()` sets the
  spawn transform, clears `_dead`, and forces the visual to `idle` in one
  synchronous call, and `PixelPlayerVisual3D.set_state()` assigns the texture
  immediately rather than deferring to the next tick, so there is no window
  where a stale strip is drawn at the new position. Two facts worth carrying
  into the next attempt: checkpoints respawn the player at
  `global_position + UP * respawn_height`, so the player is dropped in rather
  than placed, and `reset_delay` is 0.5 s while the death animation is 6 frames
  at 13 fps = 0.46 s, so the animation ends almost exactly when the respawn
  fires. A probe that samples every rendered frame across many deaths did not
  reproduce it; a real reproduction likely needs the windowed game rather than
  a headless harness. Low priority - cosmetic only.

## Candidate movement upgrades

Ideas raised in play that are not scheduled and not approved. They exist here so
they are not rediscovered from scratch, not because anything is committed.

- **Dash refresh on wall contact.** Dash currently cannot be used again after a
  jump-Dash or Double-Jump-Dash onto another wall. That limit is accepted for
  now, and the Level 2 crossings are sized around it. Refreshing Dash when the
  player touches a new wall would open chained wall-to-wall Dash routes and is
  worth considering as a later unlock rather than a tuning change, since every
  authored gap assumes the current reach.

## Definition of done for a player ability

A new player ability is not complete when it merely works in its introduction
level. It must also:

- be registered as implemented and exposed automatically in Animation Lab;
- have an immediate lab-only on/off toggle that never changes campaign data;
- retain its selected lab state through `R`;
- expose its important animation states clearly in the lab;
- be taught and tested as a mechanic in an authored campaign level;
- preserve earlier level behavior when unavailable;
- receive focused runtime validation and hands-on feel testing.

## Current milestone

Arrival / Shoreline is now the production campaign's Level 1. The shoreline,
Green Threshold, Thorn Garden, open-air Double Jump rise, final landing fight,
skate-half-pipe takeoff, and flat tire-swing-tree exit form the complete and
accepted authored route.
Automation checks loading, collision support, hazards, checkpoints, reset,
completion, camera/background coverage, exact spike reach, the concealed-spike
reveal, bounded patrol behavior, and visual regressions without tuning the route
around bot skill. Human review accepts the route gameplay and concealed hazard.
Human review also accepts the finish clearing, completion fade, environmental
dressing, and half-pipe composition. Commit `59a034b` is the Level 1 baseline.

Overgrown Coastal Ascent is now complete and hands-on accepted in development
form. Its dusk approach, two roaming patrols, cave-slide handoff, movement
progression, machine chambers, exit gauntlet, background blend, regional grade,
shared ceiling, water vistas, focused Wall Jump camera, and cave-lift departure
form one finished level. The next milestone is explicitly authorized: promote
that accepted build into World 1, retire the obsolete WIP/snapshot identities,
and make Level 1 continue naturally into Level 2.
