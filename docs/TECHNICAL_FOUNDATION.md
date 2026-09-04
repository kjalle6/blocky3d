# Technical foundation

This document records the current Godot architecture and the contracts future
levels must preserve. It describes responsibilities, not a frozen class
hierarchy.

## Product name and implementation identity

The public title is TBD. `blocky3d` remains the internal repository codename
and stable technical identity. Public-facing title text must come from one
configuration source rather than being repeated through scenes and scripts.
Changing the title must not silently change the `user://` save location,
progress IDs, or other persisted identifiers; any eventual identifier migration
must be explicit and versioned.

The product is a 2D side-scrolling pixel-art platformer. Its use of `Node3D`,
`CharacterBody3D`, and orthographic cameras is an implementation technique for
composing layered depth in the presentation. Gameplay stays on one flat plane:
route turns and plane transitions are ruled out, so Z is for sorting art and
nothing else. Game logic must never require free 3D movement merely because the
scene tree is three-dimensional.

## Runtime ownership

| Responsibility | Current or intended owner |
| --- | --- |
| Application flow | `GameRoot`: active world container, interface container, and catalog-driven level selector |
| Campaign content | `CampaignCatalog`, typed `WorldDefinition`, and typed `LevelDefinition` resources; no level-number behavior branches |
| Level run state | `LevelSession3D`: player wiring, death, section-local checkpoint respawn, full restart, and completion |
| Level thresholds | `LevelTransition3D`: a doorway that hands the run to another scene or level. `GameRoot` fades out, swaps the scene behind the black, and fades back in. Source exit and destination entrance presentation are authored separately: stop, run, or disappear into an occluding doorway on exit; optionally run while black lifts on entry. Direct level loads remain stationary. A campaign threshold may set `completes_source_level` to record its source without showing the completion overlay. A same-level `target_scene` handoff preserves the active `LevelDefinition`, world identity, and explicitly carried ability state while replacing the source scene and `LevelSession3D`; the destination therefore owns its spawn and checkpoints |
| Locomotion | `PlayerCharacter` plus typed `PlayerMovementConfig` tuning |
| Route extent | `RouteExtent3D`: metadata describing the authored start and end of a level's route. Movement is plain +X; nothing projects onto a path |
| Camera | `PixelSideCamera3D`, independent from player movement ownership |
| Player presentation | `PixelPlayerVisual3D`, separate from movement and gameplay collision |
| Enemy behavior | Focused enemy scenes/scripts with separate body, stomp, attack, hurt, and presentation contracts |
| Hazards | Reusable hazard areas; spike art and damage geometry remain independently authored |
| Player combat | Focused melee and future firearm owners that request movement-compatible actions without owning locomotion |
| Projectiles | Reusable projectile contract with explicitly authored allegiance, collision, speed, damage, lifetime, and reset behavior |
| Firearms and ammo | Intended typed firearm data plus run-scoped ammo state; neither belongs in level geometry scripts |
| Boss encounters | Boss-specific state machines using shared damage, projectile, feedback, and deterministic-reset contracts |
| Feedback | Replaceable presentation owner for flashes, hit pause, and future named audio cues |
| Progression | `ProgressionStore` owns versioned `GameProgress` save data and permanent ability ownership |
| Ability pickups | Focused pickup actors request unlocks through `LevelSession3D`; they never write save data directly |
| Interface theme | Intended curated Godot `Theme` resources shared by start, selector, pause, options, HUD, and development tools |

`GameRoot` has two stable top-level containers:

- `World` for the active 3D level
- `Interface` for menus, HUD, transitions, and accessibility UI

Gameplay behavior does not accumulate directly on `GameRoot`.

The reusable `pixel_level_base.tscn` scene owns the common runtime frame and the
default `green_zone_day` background profile. Authored levels override the
profile resource, as Arrival does with `arrival_shoreline`, rather than adding
private background sprites or level-specific movement scripts. Individual
level scenes otherwise contain only authored route content and intentional
overrides.

## Developer tools

During active development, `GameRoot.developer_fresh_level_runs` is enabled.
Each level selection therefore receives a fresh level-defined entry state
without reading or modifying the campaign save. That state seeds the level's
declared `assumed_owned_abilities`; it is not necessarily an empty progression
view. Session abilities remain active through death and manual restart inside
that loaded session, then reset when another level session is created.
Disabling the mode restores the versioned persistent campaign behavior without
changing level code.

`GameRoot.developer_tools_enabled` adds separate Firearm Review Lab and Level
Design Lab entries to the selector. Both are development-only `LevelSession3D`
fixtures, not campaign worlds or levels. Firearm Review Lab is the repurposed
Animation Lab and retains its session-local test abilities: they survive `R`,
never enter the save payload, and never mark campaign completion. Its in-room
panel still toggles each implemented ability immediately.

The room retains clear surfaces for triggering and inspecting idle, run, jump,
Double Jump, wall contact, attack, landing, and transition timing, and now adds
one isolated shooter, a real collision cover rock, and focused projectile
cadence controls. It is a review fixture, not a mechanic course; gameplay feel
and teaching are approved in authored levels.

`PlayerAbility.IMPLEMENTED` is the tooling contract. The Firearm Review Lab
definition and toggle panel must expose that exact set. A new ability is not
finished until it can be enabled and disabled in the lab, survives a lab
restart while enabled, and its important animation states can be triggered
there. Focused runtime checks and its authored introduction level own mechanic
validation.

Level Design Lab is the reusable space for level-layout, terrain, and fixture
prototyping. Its current cave-terrain and construction-lift proofs remain as
useful starting content, but the lab does not define production Level 2 or its
campaign progression.

Gameplay tool panels are hidden when a session opens and toggle together with
`F1`; only the compact `F1 / ESC` reminder remains on screen. This keeps
composition inspection unobstructed without removing development controls.

`F11` independently toggles a development-only inspection state in any loaded
session. The real player becomes invulnerable and non-colliding, flies directly
with `WASD`/arrows (`Space` also rises and `Shift` accelerates), and drives the
existing camera without route clamps. Exiting keeps the inspected position but
restores body collision, the separate hazard sensor, gravity, and normal camera
policy. Entering F11 also grants every ability available in that level as a
session-local test unlock. Those abilities remain after exiting inspection and
through death or `R`, allowing a real-physics test from the inspected position;
reloading the level restores its genuine unlock state. The mode is gated by
`developer_tools_enabled`, never writes progression, and displays a persistent
warning so footage cannot be mistaken for release play.

`F10` toggles a world-locked measurement overlay during normal play or
inspection. Major lines are one 1.28 m terrain tile apart, minor lines half a
tile, and sparse axis labels report world coordinates. The HUD reports the
player's ground-contact point rather than the less intuitive centre of the
physics body, and a second readout follows the mouse, projecting the camera ray
onto the gameplay plane at Z = 0 so coordinates can be taken from level
geometry without moving the player. The grid recycles around the camera but
stays anchored to world zero, so screenshot feedback can name exact distances.
Both readouts and the grid are unavailable when developer tools are disabled.

F7 independently projects gameplay collision onto the side-scrolling plane.
It distinguishes terrain, player body and hazard sensor, enemy body and contact
sensor, lethal hazards, checkpoints, pickups, and goal/transition exits. Melee damage regions
are drawn only while their corresponding attack is active. The overlay is a
read-only visualization and does not modify physics layers, masks, or shapes.

Firearm Review Lab now owns the focused first-shooter animation, projectile
cadence, and cover proof. A broader Combat Lab should be added only when boss or
multi-enemy inspection outgrows that room; it would remain development-only and
must not substitute for testing complete encounters in authored levels.

Useful later candidates are checkpoint warping and a freeze-world toggle for
moving hazards and enemies. Add further tools only when a real authoring
problem justifies them.

## Camera and background

`PixelSideCamera3D` keeps a continuous follow position and quantizes its
rendered transform to the current output-pixel grid. The default side camera is
flat (`camera_height == target_height`), so equal world Y projects to equal
screen Y at every gameplay and background depth. Levels may override framing,
bounds, and opt-in vertical follow. Camera pitch is an authored exception and
requires projection and visual regression checks.

Scene-authored vertical framing regions are available rather than enabling
vertical follow for an entire mixed horizontal/vertical level.
A region declares when vertical tracking becomes active and the permitted
offset range; leaving or restarting restores deterministic framing. This keeps
ordinary jumps in the approved shoreline, threshold, and garden sections from
moving the camera while allowing sustained later climbs to reframe naturally.

`PixelBackgroundRig3D` owns presentation behind the route. It consumes a typed
`PixelBackgroundProfile` made of ordered `PixelBackgroundLayerProfile` tracks.
A track declares its texture, depth, tint, pixel offset, horizontal motion
policy, parallax amount, vertical policy, repeat policy, and optional camera-X
fades. The rig derives
every position from one stable initial camera reference and recycles a fixed
sprite pool. Checkpoints, death, manual restart, and direct camera teleports
therefore reproduce the same phase; restart snapping must not recapture the
reference.

Camera-height opacity windows are an opt-in extension to this typed profile.
They are expressed relative to a named scene-owned height anchor,
just as Arrival's horizontal fades are tied to its shoreline transition anchor.
The rig evaluates rendered camera Y rather than raw player Y, preventing a
single jump from flashing a new background band into view. Existing profiles
without vertical windows retain identical behavior.

Authored background regions are a separate opt-in visibility gate. A layer with
no zone tag remains continuous coverage; a tagged layer takes the strongest
weight from any region revealing that tag, preserving each region's blend ramp
without adding overlapping regions into an over-bright result. The weight is a
pure function of rendered camera position, so traversal in either direction,
restart, checkpoint respawn, and direct loads reproduce the same composition.
`invert_zone_visibility` lets a layer consume the complementary weight, so one
composition can disappear on exactly the curve that reveals another. Level 2
uses three inverted smoky-grey lower-cave layers and two upper water-cave layers
for a broad reversible handoff. Its regional grade and shared ceiling consume
the same upper-zone influence, keeping the entire presentation synchronized.

Viewport-covering background art uses the foreground pixel scale: 576x324
pixels at 0.04 metres per pixel produces a 23.04x12.96-metre panel matching the
16:9 framing. Coverage panels repeat only across X. Decorative tracks may use
smaller transparent textures and explicit repeat spacing, leaving the clean
environment sky visible between objects such as clouds. Mirrored repetition is
the default because the source images are not fully seamless, and complete
horizon art is never repeated vertically. `SCREEN_LOCKED` is the default
vertical policy, including climbing levels; `PARALLAX` and `WORLD_LOCKED`
require a deliberate level-specific composition.

Horizontal motion is likewise explicit: `SCREEN_LOCKED`, `PARALLAX`, or
`WORLD_LOCKED`. Terrain silhouettes use `PARALLAX`; decorative clouds may use
`WORLD_LOCKED` so they occupy stable world positions instead of appearing
attached to the camera. Autonomous drift is a separate future presentation
choice and must not be simulated with near-zero parallax.

Localized interior openings use `PixelVistaWindow3D` for layers that should not
fill every room. Its explicit root policy prevents camera behavior from being
smuggled into an arbitrary parallax value. Level 2 keeps each entire vista
world-authored on X but camera-locked on Y, so its lake and rocks remain
vertically static on screen while the player jumps. Foreground terrain masks
each vista's authored X edges. Level 2 lowers the lake crop by 2.0 m, and a
uniform one-pixel source row extends its deep-water fill below the kill plane.
The view is presentation-only and contains no collision.

`PixelCaveCeilingOverlay3D` owns the source artwork's rocky roof separately from
those water openings. Level 2 lays out five mirrored panels on authored world X,
locks their Y to the camera, and reveals them with the upper-zone influence. The
overlay contains no water or collision. The completed Level 2 interior combines
that ceiling and the localized vistas with its five-layer global cave profile.

World-locked global layers may request exact texture-height rows above or below
their authored base through `world_repeat_above` and `world_repeat_below`. The
background rig snaps the base row once, then derives every additional row from
the native texture height; it never re-snaps rows independently. This supplies
coverage for tall spaces without coupling art to camera Y or introducing fake
depth layers.

Camera regions select vertical framing and horizontal focus independently. A
narrow focus can therefore hold one shaft composition on X while a broader
region continues to track its climb on Y; neither policy has to replace the
other. The Level 2 interior uses that split for its Wall Jump shaft and its
28.0 m upper-floor camera offset. The vertical region clamps there so an
ordinary jump cannot move the whole upper cave shell. A second fixed region
holds the lift-exit composition while the deck rises. Normal horizontal
look-ahead resumes through the camera's smoothing when the player exits the
Wall Jump shaft. Level 3 WIP reuses the same independent policies: ordinary
forward look-ahead reveals the deceptive far ledge during the committed jump,
a broader vertical region waits until the player falls below the surface lip
before following the 25.6 m descent, a fixed bottom hold prevents the short
combat beat from bobbing with ordinary jumps, and a narrow horizontal focus
holds the 5.12 m return shaft while vertical tracking follows the climb. The
separate height-window extension remains dormant until an approved composition
needs fixed-scale depth, parallax, deliberate viewport cropping, and camera-height
fades; runtime scaling of scenery remains excluded because it reads as zooming
rather than travel.

## Engineering rules

- Use one Godot unit as one metre. Do not retain a pixel-to-world conversion
  layer from the Python source.
- Prefer composed scenes and focused components over inheritance-heavy entity
  trees or one controller that owns the entire game.
- Store authored tuning and level metadata in typed custom `Resource` classes
  when the data needs to persist or scale.
- Keep simulation, presentation, UI, audio, save data, and progression
  separate.
- Use signals for meaningful domain events, not instead of clear ownership.
- A reusable mechanic is never implemented privately inside one level.
- Level numbers are presentation and ordering only; behavior keys off stable
  level and ability identifiers.
- Death and restart reset every mutable actor deterministically.
- Movement and collision contracts do not silently change when art changes.
- Readable geometry enforces routes; invisible barriers are reserved for clear
  world boundaries.

## Pixel-art invariants

Two rules govern authored scenery. Each has been broken once, and both times the
symptom looked like something else, so both are now asserted by
`tools/validate_pixel_art_invariants.gd` rather than left to review.

- **Scenery renders at `PixelPlatform3D.TILE_PIXEL_SIZE` (0.04 m).** Art on any
  other scale re-rounds its pixels independently as the camera pans, so it
  jitters against its neighbours. Source art that is an exact integer upscale is
  downscaled to native resolution rather than shrunk at display time.
- **`render_priority = 0` is the terrain line.** Anything that should look
  bedded into the ground is negative and anything sitting on top is positive.
  Overlapping props get unique values, because equal-depth sprites fall back to
  distance sorting and can swap order as the camera moves.

Actors are a deliberate exception to the first rule. The player, enemies,
pickups, and the goal chest are authored at their own scales so they read at the
right size against the tiles; they are self-contained and never sit still beside
static art, so the sub-pixel cost never shows. The validator exempts them by
group and enforces the rule everywhere else.

A new level scene must be named in that validator as either checked or legacy.
It fails on any scene it has not been told about, so dressing cannot land
somewhere the rules are not applied.

## Gameplay collision

Visible artwork is not gameplay collision.

- The player's movement body handles navigation.
- A smaller foot region handles spike contact.
- Weapon reach is measured independently from the visible body.
- Enemy body, stomp, attack, and hurt behavior have distinct jobs.
- Clear near-misses should survive.
- Obvious contact should resolve.
- Lethal contact never begins outside the visible threat.

Full-speed playtesting decides final measurements. Sprite bounds are evidence,
not unquestionable truth.

The established interaction priority is:

1. a successful player melee impact;
2. a stomp from above;
3. an active enemy attack impact;
4. passive body contact.

Defeated enemies and dead players are ignored. New enemy families change
declared behavior rather than introducing collision-order exceptions.

Ordinary patrols still use wall and ledge sensing as their default movement
contract. A scene may additionally author independent `patrol_left_distance`
and `patrol_right_distance` values when a readable route must stop at a nearby
hazard instead of a terrain ledge. The bounds are measured from the enemy's
reset transform, reverse direction without teleporting, and are independently
optional per side. Leaving either distance at zero preserves natural wall and
ledge roaming on that side, so ordinary full-platform patrols do not change.

Spike rows use a small fixed horizontal collision inset at each visible end.
The inset must not scale with total row width: proportional shrinkage creates
large nonlethal gutters on long hazard beds even though spike art fills them.

## Wall movement contract

Wall Jump is route-relative and available only when the level exposes the
ability. Airborne wall contact is immediately jumpable; downward contact also
caps fall speed for a readable slide. A kick applies a short forced movement
away from the contacted wall before ordinary air control resumes. Its vertical
impulse is tuned independently from normal and Double Jump so wall routes can
climb decisively without altering the approved horizontal levels.

Wall Jump does not replenish Double Jump. After kicking from one wall, that
same wall cannot provide another Wall Jump until the player contacts the
opposite wall or lands. A previously unspent Double Jump remains available as
one recovery option. This preserves useful combinations without allowing
infinite single-wall spam.

## Dash movement contract

Dash is a short horizontal burst along the current traversal route. Held
direction takes priority; otherwise it uses player facing. The burst suspends
gravity, consumes one charge, ignores steering, cancels an active attack, and
ends immediately on solid wall contact. Natural exit retains a smaller amount
of forward speed rather than dropping the player to a dead stop.

Grounded contact restores Dash. Dash does not refill Double Jump, and Wall
Jump does not refill Dash, preventing renewable airborne loops. A valid jump
input can cancel Dash into the existing ground, wall, or Double Jump contract.
This leaves dash-jumping available as optional speed mastery while keeping
each ability's resource ownership independent.

## Firearm and ammunition contract

Player firearm acquisition, loadout, ammunition, and firing remain
unimplemented. The approved shooter, projectile, impact feedback, and short
introduction now run in the Level 3 WIP's sealed second section; Firearm Review
Lab remains a temporary cadence comparison until the firearm loop is complete.
The first approved player firearm remains a fixed weapon introduced shortly
before the World 1 boss. Green Zone enemy 2 is the selected first shooter visual
set; its death guarantees the gun pickup after an isolated encounter completed
with the existing movement and melee kit.

- Knife and gun remain separately selectable slots so obtaining a gun does not
  remove the dependable close-range verb. Slot `1` selects the knife, slot `2`
  selects the gun, the mouse wheel cycles slots, and a gamepad shoulder input
  cycles them. The equipped slot determines what the existing attack input
  does.
- A switch requested during an attack takes effect when that attack resolves;
  it never truncates presentation or changes an already-active damage window.
- Initial aim directions are route-horizontal and upward-diagonal. Free mouse
  aim and twin-stick behavior are outside the current direction.
- Enemy targeting is independent of those player controls. The production
  shooter resolves a normalized direction toward the player through the full
  360 degrees of the flat X/Y gameplay plane while keeping Z fixed. Paired
  rounds offset along the perpendicular lane axis. The same-height lab fixture
  therefore still reads as a horizontal cadence test without special behavior.
- A firearm definition owns visual references, projectile choice, cadence,
  supported directions, and ammo cost; it does not own player locomotion.
- Shooter presentation, ranged-enemy behavior, and projectile behavior remain
  separate contracts. The selected art does not define the AI.
- The selected first-shooter cadence is three quick dual-gun beats: two
  simultaneous projectiles per beat, six per burst, followed by recovery long
  enough to vault the encounter cover and close with the knife. The slower
  two-beat mode remains in the lab for comparison only.
- Shooter presentation replays the clean forward-firing portion of the source
  animation and returns to idle before its downward muzzle-flash frames; the
  source artwork itself remains unchanged. This first handgun enemy has no
  full-body colour-pulse telegraph; its pose and timing provide the warning.
- The first shooter is a required authored encounter and its gun reward is a
  visible physical pickup, not a loot roll or text-only award. It may kick free
  for presentation, but settles at a deterministic safe position. Death,
  checkpoint, and restart behavior may not duplicate or permanently lose the
  one required pickup.
- Ordinary authored collision may block projectiles and serve as cover. The
  first encounter uses one nearly player-height natural object; there is no
  crouch, cover button, or snap-to-cover state.
- Projectile appearance, collision, and damage geometry remain separate.
- A projectile ray hit preserves its exact world position, surface normal, and
  collider for presentation. `CombatFeedback3D` turns every handgun collision
  into the same self-terminating four-frame spark-and-fragment effect and emits
  the future `projectile_impact` audio cue. Material-specific impact routing is
  deliberately outside this first firearm milestone.
- Ammo is initially an authored run resource rather than a global stockpile.
- Death, checkpoint respawn, manual restart, and encounter reset must each have
  an explicit deterministic ammo/pickup policy before the system is accepted.
- Zero ammo cannot make an encounter impossible. Required damage always has a
  melee route or a deterministic replenishment rule.
- The firearm auto-equips on first pickup and briefly reveals the weapon-switch
  controls. A contextual two-slot weapon display then highlights the equipped
  knife or gun and shows remaining gun ammunition. It is absent before the
  player has a firearm and must be reusable inside the later character HUD.

Gun construction, crafting, inventories, skill trees, and permanent firearm
progression are not current technical milestones. The asset library makes them
possible; it does not authorize speculative architecture for them.

## Checkpoint contract

A checkpoint:

- activates only after stable grounded contact at the authored support height;
- never activates from an airborne pass or nearby fall;
- respawns the player fully supported and clear of edges and hazards;
- provides readable space before any reset enemy can attack;
- persists across ordinary death;
- clears on a manual full restart or when the run is abandoned.

## Level authoring

Levels are composed scenes. Spatial layout stays in level scenes; shared
behavior stays in reusable scripts and scenes. `LevelDefinition` identifies
the stable ID, display order, title, scene, prerequisite levels, and the
abilities available and required in that level. Music, records, collectible
targets, and theme metadata can be added there when their systems exist.

When adapting a Python level:

1. State the lesson, route rhythm, required abilities, hazards, and intended
   solution.
2. Rebuild that intent using current Godot movement measurements.
3. Add missing mechanics as reusable systems.
4. Validate jump envelopes, hazards, resets, checkpoints, and completion.
5. Expand scale, camera composition, and route shape where the old dimensions
   constrained the idea.
6. Add presentation only after the route reads and plays correctly.

## World composition

`CampaignCatalog` owns ordered typed `WorldDefinition` resources. A world
defines:

- stable `world_id`;
- display order, title, description, and stable theme ID;
- ordered `LevelDefinition` resources;

The catalog exposes both world-aware lookups and flattened stable-ID level
lookups for runtime loading and save compatibility. Level display numbers are
local to their owning world. Level IDs remain globally unique, and runtime
loading accepts those IDs rather than ambiguous global numbers.

`LevelDefinition` continues to own level metadata and scene references.
`GameRoot` renders world headings and their level buttons from the catalog; it
does not maintain a separate UI table. The active run retains both its level
definition and owning world definition for presentation and future
world-aware flow.

`LevelDefinition.assumed_owned_abilities` records abilities the campaign
expects the player to own on entry. A fresh level-defined development entry
state seeds exactly that set without writing save data. The developer levels
use this to test later abilities independently, and the campaign levels use the
same contract while introducing more than one ability within a substantial
level where appropriate.

The production `CampaignCatalog` contains two completed Green Zone levels:
Arrival / Shoreline and Overgrown Coastal Ascent. The six prototypes that
proved the movement kit are deleted, their contracts having moved to Firearm
Review Lab and those production levels. The target campaign structure
remains approximately three re-authored levels. Green Zone Finale now has a
development-only WIP proving its parked lift-top spawn and opening ravine: one
Double Jump gap, two Dash-required gaps, a Level 2-style paired vertical-flyer
patrol, a second ground enemy, a final spike-side landing, then another patrol
with a faster horizontal flyer across the joined continuation ground. The same
WIP adds a 20.48 m deceptive gap, safe 25.6 m fall, short deep-cave patrol and
5.12 m spike strip, then a hazard-free 5.12 m two-wall Wall Jump shaft back to
the surface. The drop has no hanging cave face. A three-tile (3.84 m) notch
under the takeoff starts the deep floor at world X 111.36, so a committed jump
reaches the safe route while a straight vertical drop reaches the kill plane.
The shaft's cave walls begin
under one-tile Green Zone shelf extensions at Y -6.40. The two Green Zone
underside junctions repeat the ordinary `deep_right` and `deep_left` side tiles
from directly above instead of introducing bottom corners. The same uncapped
deep row now finishes every Green Zone platform in this level, allowing the
surface terrain to read as continuing into the underground backdrop. The two
cave-wall faces are mirrored to match the Green Zone edges above them, making
the separate terrain materials read as one joined structure. Just beyond that
exit, a direct same-level `target_scene` threshold fades out and unloads the
traversal scene. A sealed shooter-area scene loads behind black under the same
Green Zone Finale definition with the full movement kit retained, but with its
own spawn and checkpoint state. It contains the real cover rock, turned-away
dormant enemy, ordered player-panic and enemy-panic close-ups, first-shot camera
whip and run to cover, and post-introduction checkpoint. The cutscene-owned
player notice uses the promoted six-frame reaction sheet as a deliberate
1 -> 2 -> 1 -> 6 pose sequence and keeps the idle knife overlay frozen on frame
1 to avoid a weapon pop. The enemy has no native reaction sheet, so its
presentation uses idle frames 1 -> 2 -> 1 -> 1 and an `AtlasTexture` containing
only the same nine overhead-mark pixels. The existing reveal marker becomes a
phase-driven camera target: it eases between close-up centers, then returns
size, target, look-ahead, and follow response without leaving a live tween that
could survive reset. Its solid left boundary and the freed source scene make
backtracking structurally impossible. The level is not yet catalogued as
production.
`resources/campaign/level_02.tres`
identifies Overgrown Coastal Ascent and loads
`scenes/levels/overgrown_coastal_ascent.tscn`; its cave threshold
continues into `scenes/levels/overgrown_coastal_ascent_interior.tscn` without
creating another campaign identity.
Missing future levels are not represented by fake scenes or disabled
placeholder buttons. Development mode keeps all authored levels selectable.
Production prerequisite/locking presentation is added only when campaign flow
is ready to be tested.

Completed level IDs and permanent ability IDs remain globally stable, so
introducing world grouping does not require changing the version-1 save
payload. World completion can be derived from its member levels until a real
world-specific reward requires persisted state.

World data owns organization, not gameplay. Level geometry stays in composed
scenes; themes select curated assets; movement abilities remain player
contracts; no mechanic branches on a world number.

## Asset pipeline

The complete downloaded packs and editable source documents remain outside the
repository at `D:\GodotProjects\blocky3dassets`. Runtime-ready visual files are
mirrored without modification beneath `assets/library` so the full owned
collection is searchable in Godot and by filesystem tooling during level
authoring. Approved or transformed production assets remain curated beneath
`assets/art`; the library is an audition catalog, not permission to reference
every downloaded pack from runtime scenes.

- Record source-relative paths, hashes, and supplied licenses.
- Keep original archives, PSD files, coupons, audio, and unsupported source
  documents outside the visual library mirror.
- Use nearest-neighbor filtering and consistent sprite scale for pixel art.
- Establish ground contact, pivots, frame dimensions, and transparent padding
  before placing scenery.
- Gameplay collision is authored separately from imported art.
- Asset-pack folders record source families rather than usage restrictions.
- Borrow across packs only through a deliberate palette, scale, silhouette, and
  local-composition decision.
- Curate GUI frames, button states, font, cursors, and required icons into a
  reusable theme; do not import the complete GUI pack.
- Do not infer gameplay systems from available crafting panels, skill icons,
  bars, weapon art, enemies, or bosses.

The shared green-zone runtime set is refreshed through
`tools/prepare_green_zone_assets.ps1`; its manifest and license notes live
beneath `assets/art/green_zone`.

Reviewed dressing assets are registered in typed `DressingPalette` resources.
Scene-authored `DressingZone3D` nodes describe intent and exclusions, while
accepted candidates are baked as ordinary named nodes with explicit bottom
contact, support-platform, depth, and collision-free contracts. Candidate
generation remains a preview tool rather than a runtime decorator. Arrival's
palette now includes its accepted foliage, stones, trees, tire-swing landmark,
and both native skate-ramp orientations.

Background textures are imported losslessly with mipmaps disabled and rendered
nearest-filtered. A world or zone profile is reusable theme data; camera-X fades
and per-track opacity and offsets create local transitions without making the
background part of gameplay geometry.

`PixelPlatformStyle` owns six required 32-pixel top/body textures, optional
deep and bottom triplets, and any style-specific top-row crop.
`PixelPlatform3D` retains collision size and the shared 1.28-metre grid, so
changing sand to grass cannot silently change jump measurements. Two-row
terrain remains top/body; three-row terrain becomes top/body/bottom; taller
terrain uses the tileset's calm dark deep fill before its authored bottom cap.
Exposed and joined side caps remain explicit. This prevents root/body art from
forming fake horizontal stripes when terrain becomes deeper.

Tile joins follow the source tileset's existing visual roles. Reuse the ordinary
side, deep, or floor tile that already matches the required connection, and use
its authored mirror on the opposite side. Do not rotate a corner tile merely to
move one edge: rotating it also moves the filled quadrant and creates false
notches. When terrain or an underground background visibly continues below a
platform, leave its bottom uncapped and finish with the normal deep row. Where a
wall meets that floor, use the same regular floor-top tile as its neighbours
unless the design specifically calls for a decorative corner.

The shoreline's generated transition finishes beneath a restrained half-tile
Green Zone rise with two adjoining, non-overlapping colliders. A scaled mossy
outcrop covers the full biome seam without dominating the screen. Curated low
bushes, grass, a smaller approach tree, and Green Zone stone are explicitly
bottom-anchored, non-colliding, and behind the player and enemy plane. All
downstream route geometry moves together, preserving the established gaps and
proof-jump deltas.
`PixelWaterStrip3D` reads the beach pack's four-frame by ten-band water atlas
instead of treating animation frames as spatial tile variants. Every visible
surface and depth tile advances on one clock, preserving seamless edges while
keeping the water body alive. `PixelShoreWave3D` independently recycles the
pack's subsiding wave strip through a deterministic two-wave set. A medium crest
enters offshore while the preceding small crest is still visible near shore, so
both occupy the narrow water strip together. Each retains the source pack's
right-facing silhouette and selects progressively smaller frames while travelling
toward positive X. A separate
low 48-pixel foam strip plays once at contact, preventing stacked effects.
Both systems are presentation-only; explicit hazard areas continue to own
death and reset behavior.

Approved replacement levels enter `CampaignCatalog`.
`GameRoot.developer_level_definitions` is reserved for tools and focused review
fixtures with a null world definition: Firearm Review Lab, Level Design Lab, and
the Green Zone Finale Level 3 WIP. Labs are temporary and single-purpose: once
their active experiment is integrated and their lasting contracts have moved,
delete them rather than repurposing them; create a fresh fixture for a future
experiment. Level 3 WIP starts with the full current movement kit on a parked
construction lift. Across two authored scenes, its isolated developer route now
contains four ground patrols, three hovering hazards, the live handgun shooter,
two spike rows, and four recovery checkpoints, but no goal or production
campaign identity. Its same-level handoff keeps the one Level 3 identity and
movement abilities while giving the shooter scene its own spawn, local
checkpoints, death, and restart lifecycle. The deep slice lowers the player's
authored fall-reset limit
to Y -31 and the global kill plane to Y -32 so the 25.6 m descent remains
playable. A second kill plane stays at Y -8 across only X 0.00–79.36, preserving
quick deaths in the three earlier gaps without touching the intended drop.
Level 3 WIP uses a spatial variation on Level 2's two-background structure. A
restrained blue-grey cave composition is shown at three-times integer scale and
world-locked vertically from Y -3.78 to Y -29.70. It meets six vertically
world-locked night-forest tracks at the same boundary, so the cave rises from
the bottom of the frame during the fall instead of dissolving the entire viewport. The
existing `surface` zone now drives only the synchronized regional grade, which
darkens the lower route without moving the authored background boundary. Reused
rock-underworks terrain forms the floor and two-face Wall Jump shaft. The
production Level 2 approach uses a direct
same-level `target_scene` handoff into its live interior. Focused validators,
captures, and probes load that interior scene directly under
`resources/campaign/level_02.tres`, preserving its production Level 2 identity
without a separate selector entry. Level 3 WIP uses the same identity-preserving
handoff pattern between its traversal and shooter scenes. Its destination begins
a forward run while black lifts, and neither authored section receives a second
selector entry or campaign identity.

## Validation and visual review

Every lasting system receives focused validation. The current suite covers:

- application and world-grouped level-selector structure, including keyboard
  navigation and the development-only Firearm Review Lab, Level Design Lab, and
  Level 3 WIP;
- Firearm Review Lab isolation, movement geometry, immediate ability toggles,
  reset, session-local ability policy, shooter cadence, real projectile damage,
  and collision-cover blocking;
- Level Design Lab isolation and its retained cave-terrain and construction-lift
  prototyping fixtures;
- Level 3 WIP isolation, full-kit entry state, parked lift-top spawn, grounded
  night scenery, measured ravine gaps, quick early-gap death planes, vertical
  flyers, patrol and spike placements, safe deep fall, rock terrain, regional
  grade, camera regions, checkpoints, and hazard-free two-wall return shaft;
- Level 3's same-definition section handoff, including fade-out, source unload,
  retained movement abilities, fresh destination spawn/checkpoint ownership,
  left-side containment, and death/manual restart remaining in the shooter area;
- the first shooter's fade-in approach, player close-up, pan to the enemy's
  matching panic, aim recovery, first-shot camera whip and evade, full run to
  cover, cover-and-volley completion barrier, cover respawn, and
  shooter-section restart behavior;
- campaign catalog integrity, versioned progress serialization, and
  per-level ability filtering, including the two-level World 1 order;
- fresh level-defined development entry state versus same-session restart
  retention;
- output-pixel camera stability during long horizontal travel;
- native background scale and import settings, flat-camera cross-depth
  projection, allocation-free pooled recycling through travel and teleports,
  16:9 and ultrawide edge coverage, mirrored joins, and screen-locked vertical
  coverage using the Level 2 interior's 28 m shaft as its fixture;
- movement, jump envelope, coyote time, buffering, and reset;
- Double Jump coyote, momentum, release, consumption, landing-refresh, and
  animation contracts;
- Wall Jump contact, slide, kick, same-wall lockout, opposite-wall refresh,
  Double Jump interaction, and Firearm Review Lab contracts;
- Dash direction, burst speed, gravity suspension, charge, jump cancellation,
  wall impact, attack priority, and Firearm Review Lab contracts;
- the completed Level 2 approach's native cave entrance, two broad patrol
  routes, continuous ground, slide interstitial, and ability-preserving
  same-level transition into the live interior;
- the completed Level 2 interior's enclosed terrain, pickup order, Wall Jump
  shaft, Dash crossings, hovering hazards, checkpoints, waterline death and
  splash presentation, zoned cave background, regional grade, shared ceiling,
  independent vertical and horizontal camera regions, exit gauntlet, fixed lift
  framing, stillness-gated departure, completion fade, containment, and
  real-input traversal;
- production Arrival / Shoreline's catalog identity, typed sand style,
  synchronized animated water, collision-free travelling shore wave, grounded
  scenery, session-local Double Jump pickup, checkpoint/reset policy, Green
  Threshold and Thorn Garden geometry, open-air rise, concealed-spike reveal,
  bounded patrol lanes, typed dressing palette, half-pipe support/depth rules,
  tire-swing-tree finish, matched transition into Level 2, overlay-free source
  completion, and focused real-input completion;
- development F7 collision overlays, F10 measurement grid and player-feet /
  cursor coordinates, and F11 inspection-mode isolation, ability policy,
  collision restoration, and camera behavior;
- Arrival dressing definition integrity, authored support contact, clean
  platform undersides, non-collision, gameplay-plane separation, and paired
  clean/diagnostic visual captures.
- pixel-art invariants across every checked level scene: authored scenery on the
  shared pixel scale, unique render priorities wherever props overlap at one
  depth, and a coverage guard that fails on any level scene the validator has
  not been told about;
- the Level 2 cave approach: a native-resolution entrance that still matches its
  4x art source pixel for pixel, authored ground contact, moving patrol bounds,
  and the Level Design Lab's retained cave-terrain grammar;
- the Level 2 interior: one-grid enclosed topology, pickup order,
  checkpoint policy, hazard dimensions, camera region, a validated 13.28 m
  17-spike Dash crossing beyond Double Jump reach, a 14.08 m
  single- and dual-machine gaps, the final Dash-required spike strip, enemy
  placement, lift boarding/ascent/completion timing, and a real-input traversal
  through Double Jump, repeated Wall Jumps, and Dashes.

Graphical capture scripts render deterministic 1920x1080 review positions for
all current levels. Visual changes are inspected in the running game;
screenshots do not replace hands-on movement and collision testing.
The rendered Level 2 background-drift and wall-jump-camera probes deliberately
remain outside the headless suite because they sample after `frame_post_draw`.

Automated playthroughs are technical legality checks, not difficulty judges.
They may prove that collision, inputs, checkpoints, and completion work, but
they cannot approve fairness, challenge, pacing, readability at speed, or feel.
A bot failure must first be treated as an automation limitation or a case for
human review; it does not authorize simplifying authored geometry. Human
playtesting owns those design decisions.

Before committing a gameplay milestone:

1. Run every existing validation, not only the new level's check.
2. Capture representative visual states.
3. Inspect silhouettes, scenery grounding, hazard clarity, camera framing,
   background phase, seams, repetition, gameplay/background separation, and
   platform spacing.
4. Play the complete route at normal speed.
5. Confirm `git diff --check` and review the staged file set.

## Current baseline - 1 September 2026

The movement, collision, enemy, checkpoint and restart behaviour that Prototype
Levels 1-6 used to protect is now proven in Firearm Review Lab, Arrival, and the
Level 2 interior. New abilities and systems must not silently change it.

The typed world catalog and grouped selector, versioned progression payload,
permanent ability ownership, per-level ability policy, Double Jump, reusable
pickup actors, non-pausing ability tutorials, Wall Jump, opt-in vertical camera
framing, flat cross-depth camera projection, the typed reusable background rig,
Dash, and fresh level-defined development entry mode are established.
The public title is TBD and `blocky3d` remains the internal codename. Arrival /
Shoreline is the completed first production campaign level, locked at commit
`59a034b`. Its shoreline, Green Threshold, Thorn Garden, open-air Double Jump
rise, concealed-spike lesson, patrol flow, typed set dressing, skate half-pipe,
and tire-swing-tree finish form the authored baseline. The rejected
stitched-tree and folded-corridor experiments remain removed rather than hidden
as production baggage.

Overgrown Coastal Ascent is the completed second production level. Its dusk
approach carries two broad-roaming patrols into a matched cave threshold, short
slide interstitial, and momentum-preserving interior run-in. The connected cave
then carries a combat-and-spike recap, Double Jump rise, Wall Jump pickup and
shaft, forced left turn to Dash, 13.28 m Dash return, two hovering-machine
chambers, and a final enemy-and-spike gauntlet into the lift departure. The
sustained shaft combines the reusable vertical camera region, capped at the
28.0 m upper-floor framing, with an independent horizontal focus that holds the
composition during rapid wall jumps.

The presentation uses a reversible five-layer smoky-lower to pale-upper cave
blend, matching regional grade, localized water vistas, raised foreground roof,
and shared upper ceiling. Green Zone enemy 5 remains a dedicated indestructible
flying-hazard archetype outside the `melee_target` and stomp contracts, with
explicit lethal body/electric contact and deterministic reset behavior. The
archetype's optional constant-speed horizontal triangle patrol defaults to zero
amplitude, preserving every established vertical-only machine. Level 3 opts one
flyer into a 4.0 m/s sweep across the entire joined runway, including its spike
strip, with only 0.64 m of vertical sway.
The first machine chamber offers above-air-Dash and below-ground-Dash routes; the
second places two opposite-phase flyers in its outer thirds. The final cave
lift waits for one continuous second of supported stillness, rises under fixed
camera framing, and begins the one-second completion fade at 62 percent ascent.
Its cave exit instance and Level 3's receiving instance both hide the reusable
lift's near-black shaft backdrop so their authored environments remain visible
through the framework. The packed lift keeps the backdrop available for labs or
future enclosed uses.
Arrival's final threshold marks Level 1 complete without showing its completion
overlay, then uses matched run-out/run-in presentation to preserve momentum into
the Level 2 approach. The cave threshold in turn uses a direct same-level scene
handoff into the slide and interior, preserving the Level 2 identity and run
state.

Green Zone Finale's development WIP now carries the parked receiving lift into
a night ravine recap with one Double Jump gap, two Dash gaps, paired vertical
flyers, three ground patrols, a faster horizontal flyer, and the spike-controlled
final landing. Its next 20.48 m gap intentionally exceeds the complete movement
envelope without advertising failure: a missed crossing becomes a safe 25.6 m
descent into a short, darkened rock-underworks pocket. One further patrol and a
5.12 m spike strip lead to a long, hazard-free 5.12 m two-wall Wall Jump shaft
that returns to the surface. The night forest gives way at a fixed Y -3.78
boundary to its dedicated subdued cave backdrop, then the spatial boundary
falls away on the climb. A grounded threshold beyond the return now fades to
black and unloads this traversal scene without completing Level 3. The sealed
shooter scene loads behind black under the same level identity and with the
learned abilities retained, but its fresh `LevelSession3D` owns all subsequent
spawns, checkpoints, death, and restart. The removed source and solid left
boundary prevent backtracking.

The destination starts the player running as black lifts. A close player frame
hides the dormant enemy, the player reacts, and the camera pans across the real
cover rock to reveal the enemy's matching surprise. The enemy recovers first;
its opening shot drives a quick camera return and sends the input-locked player
all the way to genuine collision cover while the view widens back to gameplay.
The cutscene releases only after both arrival and the full opening volley, and
its local checkpoint prevents it replaying after death. Pickup, player firearm,
firing lesson, later practice, and boss all remain future milestones inside this
second section.

Reusable height-aware background fades remain unused and opt-in; authored zone
regions are active. Structural, visual, and regression automation owns
technical confidence, while hands-on human review remains the gate for
presentation, difficulty, fairness, pacing, and feel. Player firearms, bosses, a
broader Combat Lab, and the curated cyberpunk UI theme follow only when their
campaign milestones require them. Moving saws are no longer a Level 3
prerequisite and remain reserved for a later level whose route benefits from them.
