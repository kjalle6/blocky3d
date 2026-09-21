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

The intended difficulty is hard without tedious retries or a Soulslike recovery
loop. Health and healing should support that goal; failure should not turn into
repetitive resource farming before the next meaningful attempt.

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

The currently implemented first patrol establishes the default enemy contract:

- passive body contact is solid and nonlethal;
- the enemy turns at walls and ledges;
- its visible attack has a separate measured damage moment;
- a stomp defeats it and bounces the player;
- a successful knife attack defeats it;
- dying and defeated enemies are harmless;
- presentation, body collision, stomp detection, attack range, and hurt range
  remain separate contracts.

The planned health-and-damage pass changes bat patrols and skaters to two knife
hits, starting with one stomp for the first balance test. Flyers remain
indestructible and instantly lethal: they are platforming hazards. Start testing
ordinary combat without general invulnerability after damage, using readable
enemy attacks and recovery periods. Hits interrupt attacks on both sides and
need clear visual/audio impact feedback even when the target survives. Review
overlapping attacks and repeated interruptions in play.
[Combat balance](COMBAT_BALANCE.md) records the accepted targets and separates
them from current one-hit behavior.

Future enemies may chase, charge, fly, shoot, resist stomps, or be lethal on
touch, but those differences must be communicated visually rather than hidden
inside collision exceptions. Available enemy, boss, melee-weapon, and firearm
packs are a roster of options, not a quota.

### Firearms

World 1 introduces one fixed firearm shortly before its final boss. The player
first defeats one newly introduced armed Green Zone humanoid using the existing
movement and melee kit; that specific enemy then guarantees the gun pickup. A
safe, brief follow-up teaches firing before the player is under meaningful
pressure.
The fixed reward uses pistol 4 from `weapons/guns_pack_1/2 Guns/4_1.png`
and `4_2.png`. Its player rig uses the same pack's Biker set-1 body, single
firing-arm overlay `3.png`/`4.png`, muzzle effects, and projectiles. The body
supplies the other arm. The current pistol composition, mouse aiming, and backpedal have been accepted.
The enemy retains its existing baked-in dual-gun art.
Mouse aim uses a visible crosshair within a 180-degree forward arc (90 degrees
above and below horizontal). With mouse aim active, the cursor selects facing,
allowing targets on either side. A small centre tolerance prevents vertical-aim
flicker. Movement remains independent, including retreating fire. The firing arm and
gun rotate together around the shoulder, with nearest texture filtering.
Keyboard/gamepad retain horizontal fire and the upward-diagonal aim input.
Enemy ranged targeting is a separate language: production shooters may aim
directly toward the player through the full 360 degrees of the flat X/Y gameplay
plane while keeping depth fixed. Their visible guns use the appropriate
forward/up/down pose. The player can shoot throughout the double-jump flip;
retreating on the ground uses a slower upright backpedal. These are accepted
movement/shooting combinations, while bullet time and renewable jump chains
remain ideas for later.

Enemy friendly fire is accepted: bullets can damage other enemies, while a
gunner waits if a teammate already blocks either gun. Once released, a bullet
remains dangerous even if its shooter dies. This lets movement and positioning
create accidental crossfire without deliberately shooting through a waiting
teammate. Reset clears the projectiles; melee and indestructible hazards keep
their existing rules.

The introduction uses one solid natural object as honest projectile cover,
without adding a crouch or snap-to-cover mechanic. The defeated shooter visibly
drops the weapon into a guaranteed safe pickup position, and collecting it
auto-equips it rather than presenting a text-only reward. Knife and gun form a
two-slot loadout selected with `1`, `2`, the mouse wheel, or one gamepad cycle
input. A small contextual weapon display appears only after the gun is earned,
contains no premature ammo fiction, and is intended to become part of the later
character HUD.

Ammunition is deliberately not implemented yet. Its visual language, capacity,
ownership scope, depletion, pickups, drops, and reset behavior will be chosen as
one explicit design decision after the no-ammo firearm controls are reviewed.
Whatever that decision becomes, shooting remains a tactical advantage rather
than a replacement for movement or melee, and zero ammo cannot make a boss or
level impossible.

The gun constructor, crafting layouts, advanced weapon icons, and skill-tree
assets are future options only. They are not approved gameplay systems. If a
weapon bench is eventually justified, parts should create clear behavioral
changes rather than a fog of minor percentage statistics.

### Inventory and consumables

The planned player inventory holds carried consumables, with better healing
items introduced through progression. Start with no supplies and no healing-item
carry cap. The basic healing item restores 25 HP instantly, with a brief player
indicator and sound; movement remains available, while attacks are briefly
locked for that feedback duration.

Use an always-visible quick-use bar for more than one item type, without opening
a selection menu. Extending weapon number keys or using up to four slots with
keys such as R/T/F/G are alternatives for review, not final controls. Enemy
healing/ammo drops and chest rewards are possible supply sources that reduce
loose pickup clutter; their quantities and chances are undecided. Status-effect
items and crafting from bought ingredients remain possible later additions.
Details are recorded in [Combat balance](COMBAT_BALANCE.md).

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

The planned health pass turns the existing placeable checkpoints into autosave
points in both presentation and persistent saving. Their grounded trigger areas
remain editable in the level designer. Activation saves without healing. Separate
manual save slots preserve player-chosen backups and cannot be overwritten by
autosaves. Manual saving is available from the pause menu while safely grounded
and out of combat, capturing the current safe position and state.
Death presents Continue from last save, Load Save, and Quit. Continue
loads the most recent manual or automatic save; Load Save lets the player choose
an earlier backup. Loading restores that save's exact HP and consumable
quantities, with no separate health refill. Healing pickups are a separate
mechanic; permanent upgrades and completed bosses persist through ordinary
retries. Whether loading an older manual save rolls back later permanent
progress remains to be decided.
[Combat balance](COMBAT_BALANCE.md) owns the detailed recovery and save rules.

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
   stomping, knife combat, and fast restart, then introduces Double Jump. Its
   finish carries the run directly into Level 2 through a matched run-out/run-in
   transition, recording completion without showing an intervening completion
   overlay.
2. **Overgrown Coastal Ascent** begins with a brief Green Zone approach and then
   enters an enclosed cavern, mine, tunnel, or collapsed underworks through a
   short slide-and-run-in cutscene. Its connected interior introduces Wall Jump
   and Dash, escalates through two hovering-machine chambers and a final
   enemy-and-spike gauntlet, then departs on a cave construction lift. The full
   level and its authored cave treatment are complete, hands-on accepted, and
   form World 1's second production level.
3. **Green Zone Finale** begins at night on the construction lift that ended
   Level 2, then immediately crosses a deep open ravine through one Double Jump
   and two Dash-required island gaps. Its opening recap uses one familiar ground
   enemy followed by two familiar flyers moving out of phase and another ground
   enemy on their landing platform, with spikes controlling the last landing
   rather than turning the opener into a tall climb. A further ground enemy
   free-roams from the spike strip's far edge to the final ledge while a faster
   horizontal flyer crosses the entire joined platform over those spikes with
   only a slight vertical sway. A deceptively plausible gap then drops the
   player safely into a brief dark cave run before a long,
   hazard-free two-wall Wall Jump shaft returns them to the surface. A grounded
   in-world threshold then fades to black, unloads that traversal scene, and
   loads a sealed shooter area under black. Both authored scenes remain sections
   of the same Green Zone Finale level and retain the learned movement kit, but
   the new area owns its spawn and checkpoints; death and restart remain there,
   and the unloaded route cannot be backtracked into. As the fade lifts, the
   player runs into an isolated encounter with one new armed humanoid. The enemy
   begins outside the close player framing: the player panics first, the camera
   crosses the cover rock to reveal that the surprised enemy panics too, and
   the enemy recovers first. Its opening muzzle flash whips the camera back and
   sends the player all the way to real collision cover before control returns.
   Defeating the shooter guarantees the collectible gun, which now auto-equips
   into a two-slot knife/handgun loadout and supports horizontal or
   upward-diagonal fire. Shooting is taught safely before it is mixed with the
   learned movement and enemy language, followed by a simple first boss. The
   lesson, ammunition decision, and boss all stay in this second section and are
   not integrated yet. Moving saws were cut from
   this level and reserved for a later campaign fit.

The six short Godot prototype levels are deleted; they were regression
evidence for these mechanics, not the final campaign structure. Their useful
movement and progression contracts now run against active production levels,
development levels, and Firearm Review Lab (formerly Animation Lab). Git remains
the archive for the old layouts.

Development labs are temporary, single-purpose review fixtures. Finish the
feature they isolate, move lasting contracts to the production level or a
focused validator, then delete the lab instead of repurposing it into an
accumulating test room. A later experiment earns a fresh fixture of its own.

The eleven Python levels continue to supply ideas for hazards, route shapes,
power-up placement, and experiments. Their coordinates, ordering, lives, orb
economy, and filler are not mandates.

Permanent ability ownership and versioned save data already exist. Collectible
economies, weapon construction, skill trees, records, and broader upgrades
require explicit designs before implementation.

## Collaborative level authoring

The accepted in-game level designer supports block-by-block terrain building,
prepared enemies/props/hazards, patrol tuning, and permanent per-section saves.
Assets are organized by zone, starting with Green Zone and Beach. Codex and
the user still plan the level and camera together; scripted sequences remain
with Codex. Tool availability does not make every asset appropriate to every
encounter. See [LEVEL_DESIGNER.md](LEVEL_DESIGNER.md) for the current controls.

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
- Deleted prototypes are not active regression fixtures; reusable contracts
  must run against current production or deliberately maintained development
  content.

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
