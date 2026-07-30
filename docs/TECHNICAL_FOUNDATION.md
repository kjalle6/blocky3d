# Technical foundation

This document records the current Godot architecture and the contracts future
levels must preserve. It describes responsibilities, not a frozen class
hierarchy.

## Runtime ownership

| Responsibility | Current or intended owner |
| --- | --- |
| Application flow | `GameRoot`: active world container, interface container, and catalog-driven level selector |
| Campaign content | `CampaignCatalog`, typed `WorldDefinition`, and typed `LevelDefinition` resources; no level-number behavior branches |
| Level run state | `LevelSession3D`: player wiring, death, checkpoint respawn, full restart, and completion |
| Locomotion | `PlayerCharacter` plus typed `PlayerMovementConfig` tuning |
| Route plane | `TraversalRail3D`: world position and tangent for path-relative movement |
| Camera | `PixelSideCamera3D`, independent from player movement ownership |
| Player presentation | `PixelPlayerVisual3D`, separate from movement and gameplay collision |
| Enemy behavior | Focused enemy scenes/scripts with separate body, stomp, attack, hurt, and presentation contracts |
| Hazards | Reusable hazard areas; spike art and damage geometry remain independently authored |
| Feedback | Replaceable presentation owner for flashes, hit pause, and future named audio cues |
| Progression | `ProgressionStore` owns versioned `GameProgress` save data and permanent ability ownership |
| Ability pickups | Focused pickup actors request unlocks through `LevelSession3D`; they never write save data directly |

`GameRoot` has two stable top-level containers:

- `World` for the active 3D level
- `Interface` for menus, HUD, transitions, and accessibility UI

Gameplay behavior does not accumulate directly on `GameRoot`.

During active development, `GameRoot.developer_fresh_level_runs` is enabled.
Each level selection therefore receives an empty progression view without
reading or modifying the campaign save. Unlocks remain active through death
and manual restart inside that loaded session, then clear when another level
session is created. Disabling the mode restores the versioned persistent
campaign behavior without changing level code.

`GameRoot.developer_tools_enabled` adds a separate Animation Lab to the
selector. It is a disposable `LevelSession3D` test course, not a campaign
world or level. Current test abilities are granted as session-local unlocks:
they survive `R`, never enter the save payload, and never mark campaign
completion. An in-room panel toggles each implemented ability immediately.
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

`PixelSideCamera3D` keeps a continuous internal follow position but quantizes
its rendered transform to the current viewport's output-pixel grid. Static
nearest-filtered world art therefore retains a stable sampling phase during
long camera travel. Parallax layers snap to the same grid after applying their
individual movement factors. Levels opt into vertical follow explicitly;
camera and parallax layers then share pixel-quantized vertical motion while
earlier horizontal levels retain their approved framing.

The reusable `pixel_level_base.tscn` scene owns the common green-zone runtime
frame: session, feedback, environment, traversal rail, parallax background,
route containers, player, camera, and kill plane. Individual level scenes
inherit it and contain only authored route content and intentional overrides.

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
expects the player to own on entry. Fresh development sessions seed only that
set without writing save data. This lets Level 4 begin with Double Jump while
still presenting Wall Jump as its own pickup.

The first `WorldDefinition`, Green Zone, contains all five opening levels.
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
- Do not mix visual packs without a deliberate palette and style decision.

The shared green-zone runtime set is refreshed through
`tools/prepare_green_zone_assets.ps1`; its manifest and license notes live
beneath `assets/art/green_zone`.

## Validation and visual review

Every lasting system receives focused validation. The current suite covers:

- application and world-grouped level-selector structure, including keyboard
  navigation and the development-only Animation Lab;
- Animation Lab isolation, expanded geometry, immediate ability toggles,
  reset, and session-local ability policy;
- campaign catalog integrity, versioned progress serialization, and
  per-level ability filtering;
- fresh-per-level development progression versus same-session restart
  retention;
- output-pixel camera stability during long horizontal travel;
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
  policy, checkpoints, reset, and full production-input completion.

Graphical capture scripts render deterministic 1920x1080 review positions for
all current levels. Visual changes are inspected in the running game;
screenshots do not replace hands-on movement and collision testing.

Before committing a gameplay milestone:

1. Run every existing validation, not only the new level's check.
2. Capture representative visual states.
3. Inspect silhouettes, scenery grounding, hazard clarity, camera framing, and
   platform spacing.
4. Play the complete route at normal speed.
5. Confirm `git diff --check` and review the staged file set.

## Current baseline — 30 July 2026

Levels 1–4 are protected regression baselines. New abilities and systems must
not silently change earlier movement, collision, enemy, checkpoint, or restart
behavior.

The typed world catalog and grouped selector, versioned progression payload,
permanent ability ownership, per-level ability policy, Double Jump, reusable
pickup actors, non-pausing ability tutorials, Wall Jump, opt-in vertical camera
framing, Dash, and fresh-per-level development mode are established. The next
milestone is hands-on Level 5 tuning followed by a full World 1 review.
