# Level roadmap

This document separates the production campaign from the protected prototype
baseline. The prototypes prove mechanics; they do not dictate the final number,
size, or order of levels.

The Python game at
`C:\Users\kappe\Code\platformertwo\platformersecond` remains the primary idea
bank for routes, hazards, power-up placement, and experiments. The Unreal
prototype at `D:\UnrealProjects\Blocky3D` is a secondary visual and layout
reference. Godot is canonical.

## Current implementation

Arrival / Shoreline is the only current production campaign entry. Six short
Green Zone prototypes remain playable through a separate regression catalog:

| Prototype | Proven material | Migration role |
| --- | --- | --- |
| 1: Fundamentals | Base movement, patrol, stomp, knife, death, goal, and camera | Opening language for new Level 1 |
| 2: Gaps & Spikes | Longer rhythm, spike fairness, platform spacing, and checkpoints | Route material for new Level 1 |
| 3: Double Jump | Pickup, persistence, jump timing, and aerial proof | Second half of new Level 1 |
| 4: Wall Jump | Wall sensing, slide, kick, lockout, vertical camera, and shafts | Opening language for new Level 2 |
| 5: Dash | Ground and air Dash, required crossing envelope, and flow enemies | Second half of new Level 2 |
| 6: Green Zone Finale | Full-kit combinations and capstone route fragments | Material for new Level 3 |

These scenes and their focused tests remain protected during re-authoring. They
are regression evidence, not six finished campaign levels and not production
selector entries. Once the replacement campaign preserves every useful
contract, obsolete fixtures, captures, and tests are removed together. Git is
the long-term archive.

## Target World 1 structure

World 1 is the opening Green Zone, informally the tutorial island. It consists
of approximately three substantial levels with internal sections, fast
checkpoints, and meaningful escalation. It begins with beach and natural
imagery while the Biker, interface, machinery, and enemies foreshadow the
larger cyberpunk setting.

| Target level | Core arc | New capability | Status |
| --- | --- | --- | --- |
| 1: Arrival / Shoreline | Classic fundamentals grow into an aerial route | Double Jump | Shoreline, Green Threshold, and Thorn Garden approved; open-air Double Jump rise awaiting hands-on review |
| 2: Overgrown Coastal Ascent | Horizontal travel turns upward, then accelerates | Wall Jump and Dash | Planned from proven prototypes |
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
8. mix in a flow encounter, final checkpoint, spike recap, and combined finish.

The production level is being authored in reviewable slices rather than padded
to its target runtime in one pass. Its locked opening includes the shoreline,
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
small permanent spike cluster positioned on the ordinary forward-fall line,
while committing the Double Jump farther forward clears it. The temporary goal
now sits beyond that landing. Finale material remains
planned rather than present.

#### Current route-section contract

The current review section develops the ability Level 1 actually owns without
importing Level 2's spatial language:

1. Begin at the Thorn Garden exit without changing any approved earlier route
   geometry, checkpoint behavior, camera composition, or background timing.
2. Continue through open-air Green Zone terrain. A short ladder-like rise may
   vary the silhouette, but Level 1 does not introduce Wall Jump and does not
   suddenly become a shaft, corridor, folded return route, or indoor puzzle.
3. Develop Double Jump through a small number of distinct height, distance,
   correction, recovery, and route-reading beats rather than a repeated
   platform staircase.
4. Build each beat from environmental forms already available in the imported
   Green Zone library, auditioning the actual art before committing geometry.
   Use props and structures because they belong in the place, not because the
   engine can support them.
5. Keep the established horizontal camera framing unless a modest open-air rise
   genuinely needs the already-proven opt-in vertical camera region. Sustained
   shafts and Wall Jump camera work belong to Level 2.
6. Keep decoration behind readable gameplay unless a deliberately foregrounded
   object has been proven not to hide the player, enemies, hazards, or implied
   collision.
7. Author a short, coherent gameplay phrase first, capture it at the relevant
   elevations, then let human playtesting decide whether it deserves extension.
   Automated traversal proves legality only and never determines difficulty.

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
established Green Zone depth as the camera travels inland. Prototype Levels
1-6 exercise the shared rig only as regression fixtures and are not visual
polish targets. The environment colour deliberately owns complete vertical sky
coverage; horizon and decorative tracks need not fill the screen vertically.
Any future layer that promises full-height artwork must declare and validate
that contract explicitly rather than changing the shared default.

### Level 2: Overgrown Coastal Ascent

Level 2 develops movement rather than waiting half a level to use its unlocks:

1. one familiar opening jump confirms ordinary control;
2. Wall Jump is introduced and immediately required in a safe shaft;
3. horizontal breathers and recovery landings vary the vertical rhythm;
4. increasingly offset shafts combine Wall Jump with saved Double Jump;
5. Dash is introduced and immediately opens a crossing ordinary jumps cannot;
6. the final sections combine walls, open void, Dash gaps, and flow encounters.

Floating playable surfaces do not sit over hidden or unnecessary safety ground.
Water, rocks, retaining structures, bridge or ruin elements, and restrained
borrowed assets may support an overgrown coastal ascent without forcing a
literal cliff. Every background prop remains visually grounded and clear of
combat silhouettes.

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

### Needed for new Level 1

1. Completed: promote Arrival / Shoreline into the production campaign while
   preserving all six prototypes in a separate regression catalog.
2. Completed: add reusable typed platform styles without changing the shared
   1.28-metre gameplay grid.
3. Completed: curate only the beach/green-zone art used by the opening slice.
4. Completed: build and capture the opening slice at 1920x1080.
5. Completed: validate movement, collision, session-local unlock/checkpoint
   behavior, camera bounds, prop grounding, route completion, and legacy
   regressions.
6. Completed: replace oversized hand-placed parallax sprites with the
   native-scale reusable background rig; validate flat projection,
   horizontal/ultrawide recycling, and vertical-camera coverage.
7. Completed: hands-on review of the slice at normal speed. Its opening
   composition, development overlay, cloud behavior, and transition timing are
   locked.
8. Completed: author the shoreline surf as small lapping crests at the terrain
   pixel scale, breaking at the sand and handing off to a splash. Sprites anchor
   on the art's own waterline and visible leading edge rather than on frame
   bounds.
9. Completed: add a named scene-owned background transition
   anchor at the shoreline/Green Zone seam. Express the forest and cloud fade
   windows as offsets from that anchor, and validate that moving the anchor
   keeps presentation synchronized with the motivating terrain.
10. Completed: remove the rejected stitched-tree ascent completely and return
    the production scene to the approved Thorn Garden endpoint.
11. Completed: prove an opt-in vertical camera region and a folded dual-route
    greybox in isolation. Human review confirmed the camera tool works but the
    corridor/fold language belongs to later indoor or Level 2 material, so the
    disposable route proof was removed instead of being forced into Level 1.
12. Completed: author one coherent open-air Double Jump phrase after Thorn
    Garden, with alternating elevations, a continuous thorn basin, and no Wall
    Jump, shaft, corridor fold, or return-route language.
13. Completed: make the final descent a camera-framing lesson rather than a
    spawned trap. The landing spike always exists below the high ledge; a focused
    runtime check proves it begins outside the frame, becomes visible during the
    fall, punishes its authored drop line, and can be cleared by moving forward.
14. Current: retain the accepted route and camera feel while human-tuning the
    concealed cluster's horizontal placement. It is not yet dangerous enough to
    catch the player's ordinary run-off trajectory, so its final position is not
    locked by this checkpoint commit.
15. Next developer-tooling task: add an explicitly toggled, development-only
    free-flight/noclip mode. It should let the user inspect geometry, spacing,
    camera transitions, and distant scenery quickly without changing campaign
    progression, checkpoints, collision rules, or release play.
16. Then: hand the tuned section to the user for difficulty, fairness, pacing,
    readability, and composition review. Bot success proves legality only and
    must never authorize easier geometry.

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

## Current review gate

Arrival / Shoreline is now the production campaign's Level 1. The shoreline,
Green Threshold, and Thorn Garden form the approved authored baseline. The
replacement open-air Double Jump rise is implemented after Thorn Garden and is
the current human-review target; the temporary goal marks its lower landing.
Automation checks loading, collision support, hazards, checkpoints, reset,
completion, camera/background coverage, the concealed-spike reveal, and visual
regressions without tuning the route around bot skill. Human review accepts the
new camera movement and overall route, but the concealed cluster must still move
onto the natural run-off line. The user owns the difficulty, fairness, pacing,
and feel verdict after playing the build. Tune reported beats in place, then
choose the next section; do not add new systems or begin Level 2 until Level 1
is accepted. Guns, crafting, saws, secrets, currency, lives, and new enemy
families remain outside Level 1.
