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
| Level run state | `LevelSession3D`: player wiring, death, checkpoint respawn, full restart, and completion |
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

During active development, `GameRoot.developer_fresh_level_runs` is enabled.
Each level selection therefore receives a fresh level-defined entry state
without reading or modifying the campaign save. That state seeds the level's
declared `assumed_owned_abilities`; it is not necessarily an empty progression
view. Session abilities remain active through death and manual restart inside
that loaded session, then reset when another level session is created.
Disabling the mode restores the versioned persistent campaign behavior without
changing level code.

`GameRoot.developer_tools_enabled` adds a separate Animation Lab to the
selector. It is a disposable `LevelSession3D` test course, not a campaign
world or level. Current test abilities are granted as session-local unlocks:
they survive `R`, never enter the save payload, and never mark campaign
completion. An in-room panel toggles each implemented ability immediately.
Gameplay tool panels are hidden when a session opens and toggle together with
`F1`; only the compact `F1 / ESC` reminder remains on screen. This keeps
composition inspection unobstructed without removing development controls.
The room provides clear surfaces for triggering and inspecting idle, run,
jump, Double Jump, wall contact, attack, landing, and transition timing
without level hazards or scenery. It is an animation lab, not a mechanic
course; gameplay feel and teaching are approved in authored levels.

`PlayerAbility.IMPLEMENTED` is the tooling contract. The Animation Lab
definition and toggle panel must expose that exact set. A new ability is not
finished until it can be enabled and disabled in the lab, survives a lab
restart while enabled, and its important animation states can be triggered
there. Focused runtime checks and its authored introduction level own mechanic
validation.

A separate Combat Lab is planned before firearm and boss production. It will
preview enemy behavior and animation, body/attack/hurt/stomp geometry, melee
visual sets, projectiles, firearm poses and aim angles, ammo behavior, and boss
states. It must remain development-only and must not become a substitute for
testing complete encounters in authored levels.

`PixelSideCamera3D` keeps a continuous follow position and quantizes its
rendered transform to the current output-pixel grid. The default side camera is
flat (`camera_height == target_height`), so equal world Y projects to equal
screen Y at every gameplay and background depth. Levels may override framing,
bounds, and opt-in vertical follow. Camera pitch is an authored exception and
requires projection and visual regression checks.

`PixelBackgroundRig3D` owns presentation behind the route. It consumes a typed
`PixelBackgroundProfile` made of ordered `PixelBackgroundLayerProfile` tracks.
A track declares its texture, depth, tint, pixel offset, horizontal motion
policy, parallax amount, vertical policy, repeat policy, and optional camera-X
fades. The rig derives
every position from one stable initial camera reference and recycles a fixed
sprite pool. Checkpoints, death, manual restart, and direct camera teleports
therefore reproduce the same phase; restart snapping must not recapture the
reference.

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

The reusable `pixel_level_base.tscn` scene owns the common runtime frame and the
default `green_zone_day` background profile. Authored levels override the
profile resource, as Arrival does with `arrival_shoreline`, rather than adding
private background sprites or level-specific movement scripts. Individual
level scenes otherwise contain only authored route content and intentional
overrides.

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

Firearms are planned, not currently implemented. Their first approved use is a
fixed weapon introduced shortly before the World 1 boss.

- Melee and shooting remain distinct actions so obtaining a gun does not remove
  the dependable close-range verb.
- Initial aim directions are route-horizontal and upward-diagonal. Free mouse
  aim and twin-stick behavior are outside the current direction.
- A firearm definition owns visual references, projectile choice, cadence,
  supported directions, and ammo cost; it does not own player locomotion.
- Projectile appearance, collision, and damage geometry remain separate.
- Ammo is initially an authored run resource rather than a global stockpile.
- Death, checkpoint respawn, manual restart, and encounter reset must each have
  an explicit deterministic ammo/pickup policy before the system is accepted.
- Zero ammo cannot make an encounter impossible. Required damage always has a
  melee route or a deterministic replenishment rule.
- The contextual ammo HUD is absent before the player has a firearm.

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
state seeds exactly that set without writing save data. The current prototypes
use this to test later abilities independently. The replacement campaign levels
will use the same contract while introducing more than one ability within a
substantial level where appropriate.

The current first `WorldDefinition`, Green Zone, still contains six validated
prototype levels. The target campaign structure is approximately three
re-authored levels: Arrival / Shoreline, Overgrown Coastal Ascent, and Green
Zone Finale. Both sets may coexist in development during migration, but only
the replacement set belongs in the eventual production catalog.
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

The complete downloaded packs remain outside the repository at
`D:\GodotProjects\blocky3dassets`. Only the curated runtime subset belongs in
the game repository.

- Record source-relative paths, hashes, and supplied licenses.
- Keep original archives, PSD files, coupons, and unused pack contents outside
  the runtime tree.
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

Replacement slices remain outside `CampaignCatalog` while they are candidates.
`GameRoot.developer_level_definitions` exposes them under Developer Tools with a
null world definition, so completion and pickups cannot mutate campaign saves.
Animation Lab remains the only developer level with ability toggles.

## Validation and visual review

Every lasting system receives focused validation. The current suite covers:

- application and world-grouped level-selector structure, including keyboard
  navigation and the development-only Animation Lab;
- Animation Lab isolation, expanded geometry, immediate ability toggles,
  reset, and session-local ability policy;
- campaign catalog integrity, versioned progress serialization, and
  per-level ability filtering;
- fresh level-defined development entry state versus same-session restart
  retention;
- output-pixel camera stability during long horizontal travel;
- native background scale and import settings, flat-camera cross-depth
  projection, allocation-free pooled recycling through travel and teleports,
  16:9 and ultrawide edge coverage, mirrored joins, and screen-locked vertical
  coverage using prototype Levels 4 and 6 as regression fixtures;
- movement, jump envelope, coyote time, buffering, and reset;
- Level 1 combat, goal flow, reset, and full completion;
- Level 2 route measurements, spike collision and centering, checkpoints,
  reset, and full completion.
- Double Jump coyote, momentum, release, consumption, landing-refresh, and
  animation contracts;
- Level 3 route measurements, permanent pickup and replay behavior,
  checkpoints, reset, and full completion;
- Wall Jump contact, slide, kick, same-wall lockout, opposite-wall refresh,
  Double Jump interaction, and Animation Lab contracts;
- Level 4 route measurements, pickup policy, vertical camera, checkpoints,
  reset, and full input-driven completion;
- Dash direction, burst speed, gravity suspension, charge, jump cancellation,
  wall impact, attack priority, and Animation Lab contracts;
- Level 5 route measurements, six Dash-required crossings, the rule prohibiting
  vertically stacked playable surfaces, safely spaced flow encounters, pickup
  policy, checkpoints, reset, and full production-input completion;
- Level 6's two recap sections, strict Dash gap, full-kit entry policy,
  uninterrupted Wall Jump, Double Jump, and Dash final proof, checkpoints,
  mutable-actor reset, raised-chest goal, and full production-input completion.
- the Arrival / Shoreline candidate's catalog isolation, typed sand style,
  synchronized animated water, collision-free travelling shore wave, grounded
  scenery, session-local Double Jump pickup, checkpoint/reset policy, two
  required proof jumps, and real-input completion.

Graphical capture scripts render deterministic 1920x1080 review positions for
all current levels. Visual changes are inspected in the running game;
screenshots do not replace hands-on movement and collision testing.

Before committing a gameplay milestone:

1. Run every existing validation, not only the new level's check.
2. Capture representative visual states.
3. Inspect silhouettes, scenery grounding, hazard clarity, camera framing,
   background phase, seams, repetition, gameplay/background separation, and
   platform spacing.
4. Play the complete route at normal speed.
5. Confirm `git diff --check` and review the staged file set.

## Current baseline - 2 August 2026

Prototype Levels 1-5 are protected regression baselines, and prototype Level 6
is a validated playable first pass. New abilities and systems must not silently
change their proven movement, collision, enemy, checkpoint, or restart behavior
during campaign migration.

The typed world catalog and grouped selector, versioned progression payload,
permanent ability ownership, per-level ability policy, Double Jump, reusable
pickup actors, non-pausing ability tutorials, Wall Jump, opt-in vertical camera
framing, flat cross-depth camera projection, the typed reusable background rig,
Dash, and fresh level-defined development entry mode are established.
The public title is TBD and `blocky3d` remains the internal codename. A polished
20-30 second Arrival / Shoreline candidate now passes structural, real-input,
legacy-regression, and 1920x1080 capture checks. Hands-on review is the current
gate before it expands into the complete re-authored level. Firearms, saws,
bosses, Combat Lab, and the curated cyberpunk UI theme follow only when their
corresponding campaign milestone requires them.
