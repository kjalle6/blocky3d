# Game direction

This document is the canonical statement of what the game is trying to be.
When an older Python, Godot, Unreal, or prototype note disagrees with it, this
document wins.

## Working title and identity

The public title is **TBD**. `blocky3d` and "Blocky 3D" are internal codenames
retained for repository paths, stable IDs, and development convenience. They
are not promises about the eventual title or a description of the finished
game.

The game is a fast, demanding pixel-art precision platformer with the immediate
retry rhythm and authored challenge associated with *Super Meat Boy*. It is a
2D side-scroller, and that is settled. The Godot implementation uses 3D nodes to
stage pixel art on layered depth planes, but the game plays on a single flat
plane: no route turns, no plane transitions, no 2.5D. A level may run flat,
climb, or descend, and that is the whole of its dimensionality.

The larger world has a cyberpunk identity. It opens on a beach and in a green,
natural area because that contrast is part of the appeal: technology, machinery,
industry, and dense cyberpunk cities can reveal themselves gradually. The
cyberpunk protagonist and persistent interface provide continuity before the
environment fully reveals that setting.

The game began as a learning project, but the current Godot implementation is
the real game. The Python and Unreal versions are design evidence, not products
that must be ported literally.

## Player experience

- Movement is fast, exact, expressive, and fair.
- A skilled player can preserve momentum and make the game look faster as their
  mastery improves.
- Death is readable and retry is quick enough to remain part of the rhythm.
- Difficulty comes from execution, route reading, and combining known rules,
  not ambiguous collision or surprise punishment.
- Levels teach intended solutions through readable geometry and mechanic rules,
  not arbitrary invisible walls.
- Every obstacle must look as deliberate as it behaves. Correct collision is
  not enough when spacing or presentation feels sloppy.
- New abilities are taught by doing and become part of real levels rather than
  being isolated in disposable tutorial rooms.

The game is not a rage game. Rage-platformer ideas are occasional seasoning:
they may surprise the player after a fair telegraph, but they must remain
deterministic, learnable, and enjoyable on a retry. The shaking block that
produces a spike where the player touched it is the model for this kind of
borrowed idea, not permission for arbitrary traps.

## Presentation

The current pixel-art style is the game direction, not a temporary skin waiting
for full 3D replacement. Characters, enemies, props, terrain, effects, and
layered backgrounds use crisp nearest-neighbor presentation.

Worlds may have substantially different themes, palettes, and atmospheres, but
each world and local level section must remain coherent. Asset-pack folder names
record useful source families; they are not restrictions. A small asset may be
borrowed from another family when it improves the scene without muddying its
visual language.

Presentation rules:

- Gameplay silhouettes win over decoration.
- Trees, fences, benches, and other props may create depth, but must not hide the
  player, hazards, or enemies during demanding play.
- Props touch their intended surfaces and never imply false collision.
- Hazards are visually distinct and their placement looks authored.
- VFX remain restrained until the movement and encounter underneath them work.
- 1920x1080 is the minimum presentation target, with smooth high-refresh play on
  ordinary hardware.

The interface is allowed to express the cyberpunk identity from the opening
screen onward. The selected GUI family shares a visual language with the Biker
character and can provide a consistent shell across natural, industrial, and
urban worlds. The GUI asset pack is a parts library, not a feature mandate:
crafting layouts, skill icons, health bars, and inventory frames do not commit
the game to those systems.

Final music, audio, and richer impact effects remain open. Available audio packs
are a useful library, but route and encounter quality still comes first.

## Movement and camera

The whole game plays on one side-scrolling plane. Routes run flat, climb, or
descend; they never bend toward or away from the camera, wrap around a
structure, or transition between planes. World depth is a presentation tool for
layering art, never something the player navigates, so no input is ever
ambiguous about it.

The camera interprets the route; it does not own player movement. Vertical
reframing is authored separately from collision and abilities. There is no
free camera, no camera turn, and no free-roaming 3D level.

The opening movement kit consists of ordinary running and jumping, Double Jump,
Wall Jump, and Dash. Stomping and the knife complement traversal. Ability rules
remain independent so combinations are expressive without creating infinite
airborne loops.

## Combat and enemies

Combat is a supporting platforming language, not the main genre. It should
create route decisions, preserve momentum, and remain readable at running speed.

The first patrol establishes the default enemy contract:

- passive body contact is solid and nonlethal;
- the enemy turns at walls and ledges;
- its visible attack has a separate measured damage moment;
- a stomp defeats it and bounces the player;
- a successful knife attack defeats it;
- dying and defeated enemies are harmless;
- presentation, body collision, stomp detection, attack range, and hurt range
  remain separate contracts.

Future enemies may chase, charge, fly, shoot, resist stomps, or be lethal on
touch, but those differences must be communicated visually rather than hidden
inside collision exceptions. Available enemy, boss, melee-weapon, and firearm
packs are a roster of options, not a quota.

### Firearms

World 1 is intended to introduce one fixed firearm shortly before its final
boss. A safe, brief encounter teaches firing before the player is under
meaningful pressure.
The initial platformer-friendly aiming language is horizontal fire plus an
upward diagonal shot; free mouse aim is not planned.

Ammunition is sparse and initially scoped to the authored level. Shooting is a
tactical advantage, not a replacement for movement or melee. Running out of
ammunition must never make a boss or level impossible: melee remains viable,
and melee openings may replenish a small amount of ammunition when an encounter
needs that safety valve.

The gun constructor, crafting layouts, advanced weapon icons, and skill-tree
assets are future options only. They are not approved gameplay systems. If a
weapon bench is eventually justified, parts should create clear behavioral
changes rather than a fog of minor percentage statistics.

## Hazards and checkpoints

Player, enemy, weapon, and hazard hitboxes are tuned for enjoyable contact
rather than copied from sprite bounds. A clear near-miss survives; an obvious
connection resolves.

Spikes use a dedicated foot-contact region inset from the visible art. A row may
touch a platform, sit with even margins inside a gap, or be intentionally
asymmetric, but accidental partial support or careless spacing is not allowed.
Saws become the first reusable moving-hazard family in the re-authored World 1
finale.

A checkpoint is earned only after stable grounded contact on its authored
surface. Falling or jumping through a nearby trigger never advances progress.
Respawns must be supported, clear of edges and hazards, and outside immediate
enemy attack range.

## Campaign and progression

The campaign is organized into themed worlds containing substantial, replayable
levels. A level may contain several distinct areas and teaching beats; an
ability does not require an entire tiny level to itself. Levels still end before
they become padded endurance courses, and checkpoints preserve quick iteration
inside longer routes.

World 1 is the Green Zone, informally the tutorial island. It is the beginning
of the real game rather than a tutorial that precedes it. Its current target is
three re-authored levels:

1. **Arrival / Shoreline** establishes running, jumping, gaps, spikes, enemies,
   stomping, knife combat, and fast restart, then introduces Double Jump.
2. **Overgrown Coastal Ascent** turns the route upward and introduces Wall Jump
   and Dash through increasingly connected movement.
3. **Green Zone Finale** tests the complete movement kit, introduces moving
   saws and a small escalation of the enemy roster, then teaches a limited gun
   before a simple first boss.

The existing six short Godot levels are validated prototypes and regression
evidence for these mechanics. They are not the final campaign structure. They
remain during migration, then leave the menu and repository after replacement
levels preserve their useful gameplay contracts. Git remains the archive.

The eleven Python levels continue to supply ideas for hazards, route shapes,
power-up placement, and experiments. Their coordinates, ordering, lives, orb
economy, and filler are not mandates.

Permanent ability ownership and versioned save data already exist. Collectible
economies, weapon construction, skill trees, records, and broader upgrades
require explicit designs before implementation.

## Settled decisions

- The public title is TBD; `blocky3d` remains the stable internal codename.
- Godot 4.6 is the canonical engine and repository.
- The product is a pixel-art side-scrolling precision platformer, not a 3D game.
- The game is 2D. Route turns, plane transitions, and 2.5D are ruled out, not
  deferred. 3D nodes stage layered art; they never carry gameplay depth.
- The larger setting and persistent interface have a cyberpunk identity.
- World 1 intentionally begins with beach and green-zone imagery.
- The game is original, movement-first, and not designed as a rage game.
- World 1 is being re-authored as roughly three substantial campaign levels.
- The complete base movement kit is learned across those levels rather than one
  ability per tiny stage.
- Melee stays a focused traversal-compatible verb.
- One limited firearm and a simple boss are the intended World 1 payoff.
- Firearms must never create ammunition soft locks or displace movement.
- GUI, crafting, constructor, and skill assets provide options, not commitments.
- Collision, checkpoints, attacks, and hazards are authored for feel and
  readability.
- The current six levels remain temporary regression baselines during migration.

## Open decisions

- Final public title, protagonist identity, and detailed fiction
- Exact campaign order, world count, and final level count after World 1
- Exact first boss selection and encounter structure
- Whether the first firearm becomes a permanent post-World 1 tool
- Whether a weapon bench, construction system, or skill system ever earns a
  place in the game
- Collectibles, upgrades, records, ranks, and scoring
- Final audio identity and selection from the available music and SFX
- Accessibility, rebinding, and difficulty-assist options

Open decisions are resolved when the next real level requires them, not because
an available asset suggests a feature.
