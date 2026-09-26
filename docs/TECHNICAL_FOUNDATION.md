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
| Player combat | Focused melee and firearm owners that request movement-compatible actions without owning locomotion |
| Projectiles | Reusable projectile contract with explicitly authored allegiance, collision, speed, damage, lifetime, and reset behavior |
| Firearms and ammo | Typed firearm tuning, ownership, loaded rounds, inventory reserve, reload and exact snapshot restoration; capacity and reload timing remain provisional |
| Boss encounters | Boss-specific state machines using shared damage, projectile, feedback, and deterministic-reset contracts |
| Feedback | `CombatFeedback3D` owns impact presentation and emits live character/scenery cues; `combat_audio_3d.gd` owns their bounded spatial voice pool |
| Health and inventory | Per-actor `HealthState`, shared combat/item definitions, and `PlayerInventory` quantities and quick-slot references |
| Saves and progression | `SessionSaveState` captures sessions, `SaveSnapshot` validates payloads, and `ProgressionStore` owns versioned profiles and save slots |
| Ability pickups | Focused pickup actors request unlocks through `LevelSession3D`; they never write save data directly |
| Layout authoring | `LevelDesigner` owns edit/test state; document, resolver, store, and registered catalog helpers own validated persistent layout data |
| Developer audio | Audio tuning owns the working mix; `GameRoot` coordinates tool ownership so designer previews and audio tuning do not compete for input/pause state |
| Interface | Shared Cyberpunk GUI components for inventory, options, save/load, and recovery menus; separate HUD components read gameplay state |

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
New campaign/Continue/Load now explicitly select persistent play while the
development selector retains this fresh-run behavior. Campaign death uses the
save recovery menu; developer death still resets quickly. See
[SAVE_SYSTEM.md](SAVE_SYSTEM.md) for snapshot ownership and controls.

`GameRoot.developer_tools_enabled` adds separate Firearm Review Lab and Level
Design Lab entries to the selector. Both are development-only `LevelSession3D`
fixtures, not campaign worlds or levels. Firearm Review Lab is the repurposed
Animation Lab and retains its session-local test abilities: they survive F1's Reset lab,
never enter the save payload, and never mark campaign completion. Its in-room
panel still toggles each implemented ability immediately.
The lab grants and equips the handgun on entry and manual restart, alongside
the knife. Respawns retain ownership; leaving the lab does not grant a gun to
campaign levels.

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
through death or a developer restart, allowing a real-physics test from the inspected position;
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

### Level designer and layout persistence

The in-game designer opens through F1 in every registered section/lab.
The separate menu-7 sandbox supplies an empty protected foundation. Build uses
one persistent block brush organized by zone; browser/sidebar picture cards add
prepared enemies, hazards, autosave points, supply chests, and scenery. The user guide is
[LEVEL_DESIGNER.md](LEVEL_DESIGNER.md); the implementation record is retained
in [DEVELOPER_LEVEL_EDITOR_PLAN.md](DEVELOPER_LEVEL_EDITOR_PLAN.md).

`level_layout_registry.gd` maps stable section IDs to known scenes and structural
dependencies. `level_layout_document.gd` stores validated authored values and
undo snapshots; `level_layout_objects.gd` applies supported properties and creates
known object kinds. `level_layout_resolver.gd` preflights complete layouts and
applies them before runtime children initialize. Neither saves nor catalogs
accept arbitrary executable paths from a user layout.

Schema 3 JSON in `resources/level_layouts` stores overrides, removals, additions,
and signatures of the templates actually used. The structural scene remains the
base. Inspect `build/level_layouts_resolved.json`, generated by
`tools/inspect_level_layout.gd` through the runner, before changing a registered
scene. Also preserve current local recovery drafts. Changing used assets or
structural dependencies requires review; do not bypass it by rewriting hashes.

The store validates full documents, detects other writers/stale bases, verifies
temporary writes and replacement, and retains backups. Compatible local drafts
can be recovered for review. Preview actors suppress processing, collisions,
startup interactions, and audio. Test reconstructs a fresh run from the draft;
defeats, patrol motion, and checkpoint activation never mutate authored data.
Undo holds up to 80 completed document actions and survives Test transitions.

`level_object_catalog.gd` discovers zone JSON while `level_object_library.gd`
owns browser categories/defaults independently of saved runtime definitions.
Green Zone provides 96 tiles, 78 static props, and 5 animated props; Beach has
six native sand pieces. Tile placement uses the 32-pixel / 1.28 m grid, shaped
outer collision, and per-object footstep surfaces. Props are decorative unless
a separately supported gameplay kind provides behavior. Existing rectangles
remain editable, but new terrain uses blocks. Cameras and scripted sequences
remain protected and authored with Codex.

The LayoutSmoke export preset explicitly includes layout/catalog JSON and
production dependencies, excludes `assets/library`, and disables authoring in
the packaged runtime. Runner `-ExportPack` and `-MainPack` supervise the same
standard engine; pack probes run from an isolated build directory so missing
resources cannot fall back to the source checkout. This is a validation preset,
not a release configuration.

## Camera and background

The Level 3 gun-encounter section trials Phantom Camera with a visually authored
`Path3D` rail. Phantom owns following and damping; a small adapter preserves
pixel snapping, inspection and cinematic ownership. See
[Phantom Camera](PHANTOM_CAMERA.md) for editing, validation and addon limitations.
The region-based camera described below remains active in the other sections.

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

Entering, leaving, or switching framing regions blends the camera's target
composition over 0.65 seconds with an eased start and finish, before ordinary
follow smoothing. Horizontal and vertical handovers are independent; changing
shaft focus does not delay vertical tracking. Turning back across a boundary
starts from the in-progress framing. Ordinary follow response is unchanged,
and explicit spawn/load/inspection snaps clear the handover immediately.

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

Ground enemies use the authored damage box (`ProjectileHurtbox/Collision`)
for knife overlap, recentered on the sprite's torso including its facing and
the skater's registration offset. Stomps use that horizontal extent and a stable
`stomp_head_height` aligned with the artwork, excluding the projectile box's
transparent head padding. Their shorter movement bodies still handle navigation. A knife
checks overlap throughout its 0.13–0.27 second thrust window, once per target
per swing; windup and recovery do no damage. Starting or stopping movement
preserves that thrust's animation clock. Stomps resolve from the descending
feet crossing the head plane, with horizontal overlap measured at that
crossing, before enemy attack processing. This avoids relying on a one-time
area-entry signal or letting a fast fall sink through the visible head.
If an edge landing or short hop misses that plane but lands on the enemy's
solid body, the upward collision normal also confirms a stomp. Side and
underside collisions do not count, and the bounce keeps its existing strength.
`tools/validate_ground_combat_contacts.gd` covers these edge and timing cases,
including solid-body landings, rising, passive side contact, and clear misses.
Repeated hands-on testing accepted the solid-body landing fix, with no further
instances of standing on an enemy instead of stomping it.

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

Player firearm collection, two-slot selection, aiming, firing, ammunition, and
active reloads are implemented. Loaded rounds belong to `PlayerHandgun3D`, and
reserve rounds are an inventory stack. Campaign snapshots preserve both.
The shooter, projectile, impact feedback, introduction, and physical handgun
pickup run in Level 3's second section. Firearm Review Lab provides isolated
combat, animation, and reload tests.
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
- Mouse aim projects the cursor onto the X/Y gameplay plane and clamps to
  90 degrees above/below cursor-selected facing. A 0.13-world-unit horizontal
  tolerance retains facing near the player centre. This visual/firearm facing
  is separate from locomotion facing, preserving dash, wall-jump, and knife
  directions. The crosshair shows the actual
  muzzle ray; arm, gun, flash, and projectile origin share shoulder rotation.
  Keyboard/gamepad retain horizontal and upward-diagonal aiming. The native
  cursor returns when aiming stops, on pause, and when the HUD exits.
- Grounded retreat with mouse-aimed handgun uses 65% of normal maximum speed
  and the pack-1 Biker `Walk1.png` sheet played backward. The six-frame cycle
  advances by distance travelled (1.5 frames per world unit). Forward movement,
  aerial control, dash, wall jumps, and knife movement retain their tuning.
- The player uses the accepted compact muzzle texture and six-frame shot
  effect. The slim projectile rotates with its real trajectory; the firearm
  definition sets player projectile speed to 28 m/s. Double-jump firing preserves the
  flip animation and locomotion, using its registered gun-ready body/grip frames.
- Enemy targeting is independent of those player controls. The production
  shooter resolves a normalized direction toward the player through the full
  360 degrees of the flat X/Y gameplay plane while keeping Z fixed. Each round
  originates at its actual barrel in the chosen directional pose; prospective
  lane checks and released shots use the same muzzle math.
- A firearm definition owns projectile choice, cadence, supported directions,
  muzzle offsets, speed, range, magazine capacity, and reload timing. Inventory
  and loot definitions own reserve quantities and supplies.
- Shooter presentation, ranged-enemy behavior, and projectile behavior remain
  separate contracts. The selected art does not define the AI.
- The selected first-shooter cadence is three quick dual-gun beats: two
  simultaneous projectiles per beat, six per burst, followed by recovery long
  enough to vault the encounter cover and close with the knife. The slower
  two-beat mode remains in the lab for comparison only.
- Shooter presentation selects the forward, upward, or downward aim/flash/recoil
  group from the source sheet, mirrors facing, and tracks the player between
  beats. Each released beat locks its pose through flash/recoil, then returns
  to ready aim. There is no full-body color-pulse telegraph.
- Enemy shots damage other enemies through their existing projectile hurtboxes.
  Before each paired beat, the gunner queries both prospective barrel paths;
  an ally first in either lane makes the beat wait/re-aim without consuming it
  or playing a false flash/sound. A player or solid cover first in the lane
  shields any ally behind it, so firing need not wait in that case.
- Released bullets remain live if an enemy moves into them or their shooter
  is defeated. Run/encounter resets and teardown clear them. Melee and
  indestructible hazards keep their existing rules.
- `HandgunProjectile3D.cast_shot` is shared by real shots and firing checks. It
  raycasts solid bodies and enemy projectile hurt areas separately and selects
  the nearest hit. Contact/attack/trigger areas do not swallow bullets. The
  default mask is 5; source body and child collision RIDs are cached as exclusions
  at launch so owner death does not change collision identity.
- The first shooter is a required authored encounter and its gun reward is a
  visible physical pickup, not a loot roll or text-only award. It may kick free
  for presentation, but settles at a deterministic safe position. Death,
  checkpoint, and restart behavior may not duplicate or permanently lose the
  one required pickup.
- `HandgunPickup3D` owns that presentation without random physics. One hidden
  scene-authored actor listens to the shooter's one-shot `defeated` signal,
  switches to a diagonal source pose during a short deterministic arc, makes
  one restrained bounce, and snaps to `GunDropAnchor`. It is a
  `run_resettable` `weapon_pickup`, so a reset during flight cancels the motion
  instead of leaving a delayed duplicate. On contact it asks `LevelSession3D`
  for the one authoritative acquisition, becomes claimed, and auto-equips the
  handgun. Developer respawn retains session ownership, while a fresh section
  restart reconstructs the entry state. Campaign recovery restores weapon
  ownership, ammunition, and reward claims through the save system.
- The reward and player rig use pistol 4 from `weapons/guns_pack_1`:
  `2 Guns/4_1.png` and `4_2.png`, Biker set-1 idle/run/jump bodies,
  single firing-arm overlays `3.png`/`4.png`, the compact muzzle effect, and
  the promoted slim horizontal bullet texture. The body's other arm remains
  visible. Per-frame grip
  offsets register the firing arm to the shoulder; gun, flash, and projectile
  origin follow the same offset. Keyboard diagonal art uses pixel flips; mouse
  aim rotates the horizontal rig with nearest filtering. Mouse aiming and the slower backpedal have user visual/feel acceptance.
  Enemy gun/arm art uses the accepted directional dual-gun sheet; its projectile
  uses `assets/art/green_zone/projectiles/handgun_bullet.png` with independent
  speed and scale. Both source packs stay in separate folders because their
  relative filenames overlap.
- Ordinary authored collision may block projectiles and serve as cover. The
  first encounter uses one nearly player-height natural object; there is no
  crouch, cover button, or snap-to-cover state.
- Projectile appearance, collision, and damage geometry remain separate.
- A projectile ray hit preserves its exact world position, surface normal, and
  collider for presentation. `CombatFeedback3D` turns every handgun collision
  into a self-terminating impact effect. Combat audio routes character and
  scenery hits to separate live banks, including enemy-on-enemy impacts. One
  gunshot cue plays per simultaneous enemy pair; held beats create no cue.
  Finer material-specific impact routing remains deferred.
- Knife and stomp audio use the same level-owned voice pool. `PlayerCharacter`
  emits `melee_swung` on an accepted knife attack and `stomp_bounced` on the
  bounce requested by a confirmed enemy stomp. `CombatFeedback3D` also listens
  to `attack_connected`, presenting one knife hit sound per swing even when
  multiple targets take damage. Defeated melee targets are skipped before
  damage/contact reporting. These hooks preserve the existing animation and
  damage timing; ordinary jumps/landings retain their movement-audio hooks.
- PlayerHandgun3D owns loaded rounds and reload timing. PlayerInventory owns the
  handgun_ammo reserve stack. FirearmDefinition supplies provisional magazine
  capacity and reload duration. Player snapshots save both magazine and reserve;
  pickup/chest claims prevent repeated grants. See COMBAT_BALANCE.md for tuning.
- Zero ammo cannot make an encounter impossible. Required damage always has a
  melee route or a deterministic replenishment rule.
- The firearm auto-equips on first pickup and briefly reveals the weapon-switch
  controls. The compact bottom-left weapon HUD shows a gun icon, loaded/reserve
  counts. A fixed-size screen-space bar above the player shows the moving reload marker and
  a 0.2-second active window, randomly positioned once per reload with a start
  between 0.4 and 1.0 seconds; one timed second press completes the reload.
  A miss keeps the original duration. The knife has no weapon HUD. The separate aiming
  reticle remains active for mouse aiming.

Consumable inventory and persistent weapon ownership are implemented; their
state and UI are described in [SAVE_SYSTEM.md](SAVE_SYSTEM.md). Gun construction,
crafting, and skill trees remain possible future systems.

## Autosaves and recovery

Placeable autosave points keep the internal `checkpoint` identity for existing
scenes and layouts. They activate on stable grounded contact at the authored
support height. Campaign activation writes a snapshot without healing; developer
runs use the same placement for session-local respawn without writing saves.

Recovery positions need solid support, clearance from hazards, and space before
a reset enemy can attack. Manual saves add out-of-combat and stationary-ground
checks. `SessionSaveState` captures logical session state, `SaveSnapshot`
validates it, and `ProgressionStore` owns disk access. See
[SAVE_SYSTEM.md](SAVE_SYSTEM.md) for exact load and progression policies.

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

The production catalog contains Arrival / Shoreline and Overgrown Coastal
Ascent. Green Zone Finale remains a developer entry, while persistent campaign
flow can reach its unfinished sections. The [roadmap](LEVEL_ROADMAP.md) describes
content status and remaining work.

A level can span several authored scenes under one stable level identity.
Level 2's approach transitions into its cave, and Level 3's traversal transitions
into its shooter section. `GameRoot` swaps those scenes behind a fade, carrying
player state forward while each destination owns its local session and spawn.
Saved section IDs resolve to registered scenes when a campaign snapshot loads.

Completed level and ability IDs remain stable across presentation changes.
World completion can be derived from its member levels until a world-specific
reward needs additional persisted state.

## Asset pipeline

Source manifests, license records, and the short promotion workflow are indexed
in [Asset sources and credits](ASSET_CREDITS.md).

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
- Treat a numbered character, weapon, hand, muzzle-effect, and projectile set
  as one coherent production family when the source pack supplies those
  relationships. Verify the whole family before promoting one attractive
  sprite. A file from a constructor or component directory is not finished
  production art unless an explicit assembly task and visual review approve it.
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

## Validation and visual review

Use focused validators for the systems affected by a change, and
`tools/run_validation_suite.ps1` for changes spanning several systems. The suite
finds the current `tools/validate_*.gd` scripts automatically. Standalone checks
run through `tools/run_godot_tool.ps1`, which isolates test saves and records
process exits and script errors.

Use Godot MCP for live editor inspection, input, screenshots, and playtests.
Rendered probes cover camera/background cases that require frame output.
Hands-on review covers the full Level 2 route and establishes difficulty, pacing,
and feel. Automation setup and runner details live in [AGENTS.md](../AGENTS.md)
and [GODOT_MCP.md](GODOT_MCP.md).

The architecture above describes reusable behavior. Current campaign content
and upcoming work are tracked in [LEVEL_ROADMAP.md](LEVEL_ROADMAP.md).
