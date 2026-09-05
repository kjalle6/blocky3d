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

Arrival / Shoreline and Overgrown Coastal Ascent are the first two production
campaign entries. Level 1 now records completion and continues directly into
Level 2 through a matched run-out/run-in handoff without showing the completion
overlay. Level 2's accepted route and presentation remain the production
baseline. A development-only Level 3 WIP now proves Green Zone Finale's opening:
the player begins on Level 2's construction lift at its upper landing and steps
into a ravine traversal under the accepted dark-blue night forest, then falls
safely into a short deep-cave interruption and Wall Jumps back to the surface.
A same-level fade threshold then hands the run to a sealed shooter-area scene,
keeping the long traversal and the firearm arc as two authored sections of one
level. It is not yet a production campaign entry.

The six Green Zone prototype levels that preceded this are deleted. They were
regression evidence for the movement kit, and that job is finished: every
contract they proved now lives somewhere permanent. Movement, Double Jump, Wall
Jump and Dash are validated in Firearm Review Lab, which retains the former
Animation Lab's movement-contract role;
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
| 2: Overgrown Coastal Ascent | A brief Green Zone approach gives way to an enclosed cavern / underworks route | Wall Jump and Dash | Complete, hands-on accepted, and in production as World 1's second level |
| 3: Green Zone Finale | Lift-top night opening, full-kit mastery, enemy escalation, gun lesson, and boss | Limited firearm | Developer WIP: ravine opener, surprise descent, and Wall Jump return |

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
invisible exit threshold in that clearing replaces the temporary chest. It
records Level 1 completion without displaying the completion overlay and
carries the run directly into Level 2. No new terrain trick, hazard, enemy,
checkpoint, or mechanic is introduced. A reviewed, non-colliding skate
half-pipe fills the final Thorn Garden takeoff platform: its right lip ends at
the terrain edge and points
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
stays stationary. The Level 1-to-Level 2 cut now uses continuous matched
run-out/run-in presentation and marks Level 1 complete without interrupting the
journey with its completion overlay.

`scenes/levels/overgrown_coastal_ascent.tscn` owns the production approach and
its dressing, and `resources/campaign/level_02.tres` gives the whole route one
stable campaign identity. The approach uses the `green_zone_dusk` background;
the interior owns its separate cave environment.
`docs/LEVEL_2_VISUAL_BRIEF.md` is the source of truth for its accepted
background zoning, regional grade, ceiling, and camera composition.

The cave threshold enters
`scenes/levels/overgrown_coastal_ascent_interior.tscn` through a direct
same-level `target_scene` handoff, preserving abilities and active run state.
Focused validators, captures, and probes load that scene directly under
`resources/campaign/level_02.tres`, so the interior keeps its production Level 2
identity instead of appearing as a separate developer level.

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

The asset audit and Level Design Lab's retained cave-terrain proof established
the production direction: a natural cavern or mine that can gradually reveal
restrained buried infrastructure. The reusable grid-driven terrain now owns
connected floor, ceiling, wall, corner art, and consolidated collision; props
may dress or explain the space but never hold its shell together. Level Design
Lab remains a reusable space for level-layout, terrain, and fixture prototyping,
with the current cave terrain and construction lift kept as useful starting
fixtures rather than a miniature Level 2.

### Level 3: Green Zone Finale

The finale is a payoff level, not another isolated movement lesson:

1. arrive from Level 2 on the construction lift at night;
2. recap learned jumping and Dash without prompts, beginning with one familiar
   ground patrol followed by two familiar flyers and another ground patrol;
3. introduce exactly one new ordinary enemy in isolation: the armed humanoid
   from `assets/library/enemies/green_zone_enemies/2/`, presented as a handgun
   shooter using readable bursts while the player still relies on movement and
   melee;
4. make one nearly player-height Green Zone rock or similarly natural solid
   object real projectile cover during that approach, with no crouch, cover
   button, or snap-to-cover system;
5. guarantee a physical gun pickup when that shooter dies: the weapon kicks
   free, settles at a deterministic safe position, and cannot be lost to random
   drop physics or skipped as unrelated floating loot;
6. auto-equip the gun on contact, briefly show the weapon-switch controls, and
   teach basic shooting in a short safe situation before combining the gun with
   the complete learned movement kit and familiar enemies;
7. build one or more memorable full-kit sequences with recovery checkpoints;
8. finish with a simple, readable first boss using movement, limited shooting,
   and viable melee openings.

The current WIP implements the approved opening recap. The parked lift meets a
short shelf guarded by one familiar ground patrol, then one continuous deep
ravine carries three distinct landing islands. The first 8.96 m gap requires
Double Jump, while the following two 14.08 m gaps sit beyond Double Jump reach
and require Dash. Two familiar flyers move vertically and out of phase through
the first Dash gap, reusing the readable over-or-under timing language from
Level 2. Another ground patrol occupies their landing island. The broad last
landing leaves 4.16 m of safe touchdown before a 7.36 m spike row running from
world X 72.00 to its far edge; the terrain joins directly into safe checkpoint
ground beyond the spikes without an unnecessary seam or hole. The final surface
run-up lets one more familiar ground enemy free-roam from 0.72 m beyond the
spike strip to its natural clearance at the fake-gap ledge. A flyer crosses the
entire joined platform, including the spikes, at 4.0 m/s versus the ground
enemy's 2.0 m/s while bobbing only 0.64 m vertically. Both turn 0.72 m before
the fake lip.

This ravine is only the opening phrase of a deliberately long level. It stops
on joined continuation ground before a 20.48 m gap that looks plausibly
crossable but sits just beyond the combined Double Jump and Dash envelope. A
committed attempt therefore becomes a consequence-free surprise descent rather
than an obvious instruction to fall. The open drop runs about 25.6 m, with no
hanging cave face beside it. The first three tiles of the deep floor are
notched away beneath the takeoff: an honest, committed jump carries into the
safe lower route, while stepping straight down continues to the kill plane
instead of revealing the route for free.
A separate shallow kill plane covers only the three earlier ravine gaps,
so missing those crossings still resets quickly instead of borrowing the deep
route's longer fall.

The bottom deliberately stays brief. Reused Level 2 rock-underworks terrain
frames one familiar ground enemy and one 5.12 m spike strip against a subdued
blue-grey cave backdrop. Its upper edge meets the forest at Y -3.78:
the forest therefore travels upward with the surface during the fall and the
cave physically enters from the bottom of the frame instead of replacing the
whole screen through a dissolve. A recovery checkpoint feeds directly into a
5.12 m-wide two-wall shaft. Its long climb roughly matches the descent and
contains no spikes or other hazards: this is a clean Wall Jump mastery beat, not
a repeat of Level 2's trapped shaft. At the top, both Green Zone shelves extend
one tile over the shaft walls while the cave tiles begin at their undersides,
so the two materials meet without exposed cave columns beside the surface. A
second checkpoint returns the player to the surface shelf at the current WIP
endpoint.

The active build milestone now begins at this endpoint with a true authored
section boundary rather than appending the whole firearm arc to the already long
traversal scene. A grounded in-world threshold fades to black without completing
the level, unloads the traversal scene, and loads a sealed shooter-area scene
behind the black. Both scenes use the same Green Zone Finale `LevelDefinition`
and preserve the unlocked movement abilities. The destination nevertheless owns
a fresh local spawn and checkpoint chain; the source no longer exists, a solid
left boundary seals the new route, and the player cannot run back. Death and
manual restart after the handoff remain in the shooter section rather than
returning to the ravine or Wall Jump route.

The fade lifts over the player's continuing run into the isolated cover
encounter. A close camera first excludes the turned-away enemy while the player
notices the unseen threat through a sparse normal -> reaction frame 2 -> normal
-> reaction frame 6 sequence. The camera then crosses the cover rock and finds
the enemy making the same four-beat panic response with its own idle frames and
the shared overhead mark. The enemy recovers first, raises both guns, and its
opening muzzle flash triggers both a fast camera whip back and the input-locked
player's collision-aware run all the way to the real cover rock. The camera
widens back into gameplay during that run. Control returns only after both the
player has reached cover and the three-beat opening burst has entered recovery.
The section-local checkpoint then resumes a death safely behind cover without
replaying the introduction, while a full section restart rearms the sequence at
the shooter-area spawn. This introduces line-of-fire cover as ordinary world
geometry rather than a new character stance or cover mechanic.

The player uses the shooter's recovery opening to vault the cover and finish
the encounter with the existing knife. That death now kicks one visible handgun
through a short authored arc into the existing safe drop anchor. A second
diagonal source pose keeps the airborne weapon crisp without rotating pixels;
one small bounce ends at the exact grounded transform. The actor is pre-authored
and resettable, so repeated damage cannot duplicate it and restarting during
the arc cannot leave a delayed or lost reward. Collection now hands the reward
to authoritative session-local weapon ownership. Death and checkpoint respawn
preserve it, while a full section restart clears the gun and deterministically
rearms the shooter and drop.

The reward now uses compact pistol 4 from `weapons/guns_pack_1`, replacing
the longer gun previously sourced from pack 2. Pickup, HUD, and held weapon
share its horizontal/diagonal art. The player uses Biker set-1 bodies and
single firing-arm overlays `3.png`/`4.png`, with frame-specific shoulder
registration and matching muzzle effects/projectiles. The user has accepted the pistol pose, mouse aiming, and slower backpedal.

The physical reward, player's two-slot weapon state, and basic firing contract
are implemented. The remaining milestones are the short safe firing lesson
immediately after acquisition. That lesson, later full-kit practice, and boss all
remain in this second section so the new firearm state does not need to cross
another scene boundary.

Firearm Review Lab selected the three-beat dual-gun pattern as the production
baseline. Each beat fires both guns together, producing two projectiles per beat
and six across the burst. Its post-burst recovery gives the player enough time
to vault the approved cover rock and close for a knife kill. The slower two-beat
pattern remains only as a comparison fixture, not the intended encounter
cadence. Presentation replays the clean forward-firing portion of the source
animation and returns to idle before its downward muzzle-flash frames. This
specific enemy does not use a full-body blinking or colour-pulse telegraph; its
aiming posture, burst rhythm, and recovery carry the warning.

Every handgun round now uses one surface-agnostic four-frame contact effect: a
restrained spark with a tiny fragment layer, placed at the ray hit and oriented
by the reported surface normal. Rock, terrain, and other colliders share it; the
first firearm does not justify a material-response system.

The production shooter now resolves a normalized direction toward the player
through the full 360 degrees of the flat X/Y gameplay plane. Its dual rounds use
perpendicular lane offsets, so a same-height Firearm Review Lab setup remains a
clean horizontal cadence test without a separate aiming mode. This
enemy-targeting behavior does not broaden the player firearm's planned
horizontal and upward-diagonal controls.

The loadout is deliberately small: slot `1` selects the knife, slot `2` selects
the gun, the mouse wheel cycles slots, and one gamepad shoulder input cycles
them. The currently selected slot owns the existing attack input. A switch
requested during an attack resolves after that attack instead of interrupting
its animation or hit timing. The gun auto-equips when first collected.

The acquisition uses the agreed complete pixel-gun family and its gun-ready
Biker pose/hand layers; it is not represented by a text-only reward. A brief
`1 KNIFE  2 GUN  WHEEL / RB: SWITCH` hint accompanies the pickup. From then on,
a small contextual two-slot display highlights the equipped weapon. It is absent
before the firearm exists and intentionally contains no ammunition display until
ammo appearance and drop behavior are designed. The reusable component can later
move into the proper character HUD rather than becoming throwaway prototype UI.
Full inventory, crafting, and weapon-menu work remain outside this milestone.

The boss remains unbuilt and is a later build decision after the current pickup,
weapon switching, minimal no-ammo HUD, and safe firing lesson are accepted in
play.

A literal moon was tested and rejected. The subtler moonlight-through-trees idea
is deferred rather than worth delaying the level over; the dark forest treatment
is the accepted starting point. Moving saws were also cut from Level 3 because
its movement, enemy, firearm, and boss arcs already carry enough ideas. They
remain available to a later level where they fit the route.

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
| 7: Saws | Horizontal and vertical moving hazards in climbs and runways | Reserved for a later level; cut from Level 3 |
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

The completed production build owns the reviewed presentation from the dusk
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
composition and the finished route. Production paths and campaign flow preserve
the accepted level without redesigning it.

### Needed before the finale

1. Promote the selected Green Zone enemy 2 animation set into `assets/art` and
   keep its armed-shooter visuals separate from its reusable behavior contract.
2. A focused projectile contract shared by the shooter, firearm, and boss only
   where their rules genuinely overlap.
3. A deterministic death-gated gun pickup contract: the selected shooter always
   awards it, never through chance, and cannot be bypassed while still advancing
   the route.
4. A firearm resource describing cadence, projectile, muzzle placement, range,
   and supported aiming directions without owning player movement or inventing
   an ammunition policy.
5. A contextual weapon HUD that remains absent before a firearm is available;
   ammunition presentation is a separate pending design decision.
6. A boss-specific state machine using shared damage, reset, and projectile
   contracts rather than a giant universal boss controller.
7. Firearm Review Lab, formerly Animation Lab, now owns focused shooter
   animation, projectile cadence, and cover review while retaining its movement
   and presentation regression fixtures. Add a broader Combat Lab only when boss
   or multi-enemy inspection outgrows this focused room.

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

- be registered as implemented and exposed automatically in Firearm Review Lab;
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
Human review also accepts the finish clearing, matched exit fade, environmental
dressing, and half-pipe composition. Commit `59a034b` is the Level 1 geometry
baseline.

Overgrown Coastal Ascent is complete, hands-on accepted, and now World 1's
second production level. Its dusk approach, two roaming patrols, cave-slide
handoff, movement progression, machine chambers, exit gauntlet, background
blend, regional grade,
shared ceiling, water vistas, focused Wall Jump camera, and cave-lift departure
form one finished level. Commit `4bd953b` is the accepted Level 2 content
baseline. Arrival now marks Level 1 complete without its
completion overlay and carries the player through a continuous matched
run-out/run-in handoff into this route. The next campaign milestone is Green
Zone Finale.
