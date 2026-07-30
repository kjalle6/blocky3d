# Game direction

This document is the canonical statement of what Blocky 3D is trying to be.
When an older Python, Godot, or Unreal note disagrees with it, this document
wins.

## North star

Blocky 3D is a fast, demanding 2.5D precision platformer with the immediate
retry rhythm and authored challenge associated with *Super Meat Boy*. It uses
side-scroller controls, crisp pixel art, and a 3D Godot world that gives level
designers room to turn, climb, descend, and occasionally move through depth
without becoming a free-roaming 3D platformer.

The game began as a learning project, but the current Godot implementation is
the real game. The Python and Unreal versions are design evidence, not products
that must be ported literally.

## Player experience

- Movement is fast, exact, expressive, and fair.
- A skilled player should be able to preserve momentum and make the game look
  faster as their mastery improves.
- Death is readable and retry is quick enough to remain part of the rhythm.
- Difficulty comes from execution, route reading, and combining known rules,
  not ambiguous collision or surprise punishment.
- Levels teach an intended solution without relying on arbitrary invisible
  walls. Readable geometry and mechanic rules enforce the route.
- Every obstacle must look as deliberate as it behaves. Correct collision is
  not enough if spacing or presentation feels sloppy.

## Presentation

The current pixel-art style is the game direction, not a temporary skin waiting
for full 3D replacement. Pixel characters, enemies, props, tile faces, and
layered backgrounds are staged in a 3D world with nearest-neighbor filtering
and an orthographic side view.

Individual levels may have substantially different themes, palettes, and
atmospheres, but each level must be internally coherent. Assets are selected
because they belong together, not merely because they are available.

Presentation rules:

- Gameplay silhouettes win over decoration.
- Trees, fences, benches, and other props may create depth, but must not hide
  the player, hazards, or enemies during demanding play.
- Props touch their intended surfaces and never imply false collision.
- Hazards are visually distinct and their placement looks authored.
- VFX remain restrained until the underlying movement and encounter are good.
- 1920x1080 is the minimum presentation target. The game should remain smooth
  at high refresh rates on ordinary hardware.

Final audio, music, and richer impact effects are still open. Current flashes,
animation, and short hit pauses are useful placeholders, not the final sound
identity.

## Movement and camera

Each local section plays on a clear side-scrolling plane. Later routes may bend
toward or away from the former camera, wrap around a structure, climb, descend,
or transition between planes. The player should never have to guess which
screen direction corresponds to ambiguous world depth.

The camera interprets the route; it does not own player movement. Camera turns
and vertical reframing are authored separately from collision and abilities.
There is no requirement to build a true free-camera 3D level.

## Combat and enemies

Melee is a compact platforming verb, not a commitment to an RPG combat tree.
It should preserve the game's momentum and remain subordinate to traversal.

The first patrol establishes the default enemy language:

- passive body contact is solid and nonlethal;
- the enemy turns at walls and ledges;
- its visible attack has a separate measured damage moment;
- a stomp defeats it and bounces the player;
- a successful knife attack defeats it;
- dying and defeated enemies are harmless;
- presentation, body collision, stomp detection, attack range, and hurt range
  remain separate contracts.

Future enemies may chase, charge, fly, shoot, resist stomps, or be lethal on
touch, but those differences must be visually communicated rather than hidden
inside collision exceptions.

## Hazards, checkpoints, and reactive traps

Player, enemy, weapon, and hazard hitboxes are tuned for enjoyable contact
rather than copied from sprite bounds. A clear near-miss survives; an obvious
connection resolves.

Spikes use a dedicated foot-contact region inset from the visible art. A row
may touch a platform, sit with even margins inside a gap, or be intentionally
asymmetric, but accidental partial support or careless spacing is not allowed.

A checkpoint is earned only after stable grounded contact on its authored
surface. Falling or jumping through a nearby trigger never advances progress.
Respawns must be supported, clear of edges and hazards, and outside immediate
enemy attack range.

Rage-platformer ideas are occasional seasoning, not the game's identity. The
shaking block that produces a spike where the player touched it remains a good
example: it should telegraph, activate, cool down or reset deterministically,
and be used where it creates a readable decision rather than a cheap death.

## Progression

The base movement kit should be learned across roughly five campaign levels:

1. Run, jump, stomp, knife, and fast restart.
2. Harder fundamentals with gaps, spikes, and checkpoints.
3. Double jump.
4. Wall jump.
5. Dash.

This is a progression target, not a promise that the final campaign has only
five levels. Later levels combine the kit, add hazards and enemy families,
explore route turns, and introduce original mechanics.

Those five levels form World 1: the opening green-zone world. It is the
player's learning arc, but it is not a separate tutorial that precedes the
game. Level 1 is where the game begins. Each World 1 level must teach through
play, contain a real execution test, and remain worth replaying after its
lesson is understood.

A world is a themed collection of separate levels, not one continuous route.
Worlds provide the larger pacing arc, visual identity, mechanic combinations,
and escalation; individual levels retain the short, fast-retry structure that
suits the game. A level should end when its idea has been introduced,
developed, and tested. It should not be lengthened merely to appear more
substantial.

The final number of worlds and levels remains open until World 1 reveals the
real production cost. The campaign will extend well beyond the opening five
levels; the eleven Python levels do not define its final size.

Permanent ability ownership, save data, upgrades, collectibles, scoring, and
records require explicit designs before implementation. The Python game's
three lives and ten-orbs-for-an-extra-life system is legacy evidence, not an
approved rule for the current fast-retry game.

## Settled decisions

- Godot 4.6 is the canonical engine and repository.
- The game is an original precision platformer, not a literal port.
- The presentation is coherent pixel-art 2.5D inside a 3D world.
- The game is not designed as a rage game.
- The base ability kit is introduced early, over roughly five levels.
- Those five levels are World 1, where teaching is embedded in the real game.
- Worlds contain multiple short, replayable levels with a coherent theme and
  escalation.
- Permanent ability ownership uses versioned save data and per-level ability
  availability.
- Melee stays a focused traversal-compatible verb.
- Collision, checkpoints, attacks, and hazards are authored for feel and
  readability.
- Levels 1–3 are completed regression baselines.

## Open decisions

- Final protagonist and world fiction
- Exact campaign order and final level count
- Upgrade structure and what collectibles are for
- Time, death, collectible, rank, or score records
- Final audio identity and ownership of any legacy music
- Accessibility, rebinding, and difficulty-assist options

Open decisions should be resolved when the next real level requires them, not
through speculative systems.
