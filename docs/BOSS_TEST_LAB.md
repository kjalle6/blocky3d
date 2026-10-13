# Boss Test Lab

**Active priority: finish the connected Level 3 boss encounter.** The scaffold
pit, entry cutscene, checkpoint retries, defeat, warhead and blast-door ending
are implemented. The flat lab remains the isolated attack fixture; Boss Arena
WIP uses the pit's geometry with lab controls. Follow the
[boss completion checklist](LEVEL_ROADMAP.md#next-priority-finish-the-green-zone-boss)
for full-fight tuning, arena presentation, camera coverage, audio and connected
playtesting. Implementation does not establish final acceptance. HP is a
provisional 2000; the final value is TBD. Further asset expansion remains
queued behind this encounter.

Open **Development selector → Boss Test Lab** (shortcut **9**). This is a fresh,
isolated test session with all movement abilities, a handgun, 12 loaded rounds,
and 60 reserve rounds. **Infinite ammo** is on by default in both boss labs: the
reserve tops back up to 60, while reloads still happen; F1 toggles it, and the
no-ammo test mode overrides it. This lab does not advance or save campaign
progress. The campaign encounter is the [Level 3 boss pit](#level-3-boss-pit).

**F1** opens the fight controls: reset/refill, mixed attacks, missiles only,
jumps only, firebombs only, no ammo, infinite ammo, and boss active. Changing a test option resets the fight;
the selection survives player death and subsequent resets. Ordinary weapon and
movement controls are unchanged. In no-ammo mode, select the knife with **1**.
The head-landing test button resets the fight and drops the player above the
boss to exercise the real smoke response.
The close-pressure test button selects missiles, enables the boss, and places
the player close to it to exercise the body charge and ranged follow-up.
The two rocket-ripple buttons reset into an 8 m firing setup facing left or
right, for comparing tube origins and flight at normal gameplay zoom.
The crowding-during-fire button starts a committed salvo with the player 5 m
away. Run toward the boss to test its shove without interrupting the barrage.

The enclosed room has a flat floor and two wall-jump surfaces. Its playable
interior is 57.6 m wide and 30.72 m high: three times the original 19.2 × 10.24 m.
It expands to both sides of the original center and upward from the floor;
spawns, actor scale, tile size, and wall thickness are preserved. The camera
follows the player with a modest encounter composition: nearby combat gets a
22% wider view and a 35% shift toward the boss, equally in either direction.
Full framing lasts through 18 m horizontal separation, easing back to ordinary
player follow between 18 and 24 m. Large vertical separations similarly release
the boss between 9 and 15 m; ordinary jumps retain it. Zoom and movement ease
smoothly, room-edge limits account for the wider view, and inspection or defeat
returns to normal framing. These player-led settings belong to the flat lab.
The scaffold arena uses the same camera script in fit-both mode, described
below. The flat room remains a movement/combat fixture.

The lab's separate night backdrop uses the supported integer 2× distant-art
scale to cover the wider combat view. Its flat sky follows camera height for
coverage through the tall test room; the forest keeps its world-height anchor.
The floor extends 3.84 m downward (six tile rows), keeping its walkable top at
Y0 and covering the bottom of the widest combat view.

The boss uses only its large encounter health bar. Boss actors belong to the
`boss_enemy` group, which excludes them from regular enemies' small overhead
health bars even after taking damage.

## Current prototype

- **Solid body:** while supported by terrain, the boss blocks running and ground
  dashing from either side, including on raised platforms. The player must clear
  its body with a jump; the lab's double jump provides enough height. Ordinary
  side contact outside an active attack deals no damage and never triggers
  smoke. While firing missiles, the close-contact shove below is active. The
  airborne boss still leaves passage underneath, and its smoke escape lets the
  captured player drop onto the floor. Landing overlaps are separated along the play
  plane before solid collision resumes; defeat clears the obstruction.
- **Missiles:** a six-rocket ripple empties the launcher's two rows of three tubes.
  The six-frame `Sneer.png` swivel settles over 0.3 seconds, then `Attack1.png`
  frames 1–6 release one rocket each at 0.12-second intervals. The rockets emerge
  from the matching tube centers, mirrored for left/right, with small differences
  in departure angle. They accelerate from 4.5 to 11 m/s and boost outward/upward
  for 0.24 seconds before curving toward a fixed 1.5 m-wide area around the
  player's position when the salvo started. Their turn rate is limited; the
  target area stays committed and they do not track player movement.
  After passing the target's horizontal position, they keep flying rather than
  circling back. The authored rocket's tilted nose is aligned to its actual
  trajectory. They hit solid terrain or the player and produce an explosion.
  Each rocket carries a flickering exhaust flame on its tail and, once it has
  boosted clear of the launcher, releases muted smoke puffs along its path.
  The puffs stay where they were released and fade within half a second; the
  flame leaves with the rocket. Neither affects flight or timing.
  `tools/capture_boss_rockets.gd` (run with **-Visual**) saves a salvo at
  normal zoom under `build/previews/boss_rockets`.
  This is a stylized rapid rocket barrage, not a historical weapon simulation.
- **Jump:** a thruster-assisted arc toward the player's position at takeoff,
  limited to 14 m horizontally and clamped inside the walls. It does not retarget
  in flight. The boss passes the
  player's body and lands on terrain. Landing on its head triggers the defensive
  smoke escape below instead of damaging it.
- **Landing:** a low blast starts on physical floor contact. Its VFX and damage
  start together, with no advance markers, warnings, prompts, or added warning
  phase. Each landing can damage the player once. Moving away or getting above
  the blast avoids it. The impact shows a large shockwave ring flattened round
  the feet (`landing_ring_large.png`), ground dust rolling out both ways
  (`landing_dust.png`) and debris at each foot, tinted the smoke's grey-green.
  The camera shakes in whole screen pixels (`landing_shake`, `landing_shake_time`
  on the boss; `add_shake()` on the side camera).
- **Walking:** the six-frame `Walk.png` cycle accompanies actual grounded
  movement. Between attacks the boss approaches distant players or steps away
  from very close players to regain roughly 6–8 m of space, within the room.
  Its 2.6 m/s walk is slower than the player's run.
- **Close pressure before missiles:** if the boss chooses a ready missile attack
  while the player is within 4 m and body height, it first uses a short body
  charge. It faces the player, plants for 0.22 seconds, then rushes up to 2.4 m
  at 10 m/s using the faster walking cycle. Direction is committed at the start.
  Front contact deals one 25-damage hit and pushes the player away; a miss stops
  at the committed distance or terrain. Jumping over or dashing away can evade
  it. The push starts at 24 m/s and decays at 32 m/s², moving a passive player
  roughly 9 m on open ground. Its initial momentum dominates ordinary running
  toward the boss; countersteering blends back as the shove slows below normal
  running speed. Jump remains available, and dash or wall jump cancels the
  remaining push. Physical walls stop it. There is no
  smoke or grounded stun from this attack.
  Player damage uses the shared two-frame Hurt reaction, including while the
  charge pushes the player; the normal weapon pose returns after recovery.
  After 0.45 seconds of recovery and the normal reposition interval, the boss
  tries missiles again. The charge recharges for 4 seconds independently; while
  it recharges, the boss backs away if still crowded. It does not interrupt
  attacks already underway or replace a chosen jump. No new warning overlays
  or effects are added.
- **Crowding during missiles:** throughout the launcher swivel, all six releases
  and the closing firing frames, body-height contact within 2.2 m can trigger a
  stationary shove. It deals one 25-damage hit with the same 24 m/s push and
  32 m/s² decay as the charge. It pushes away from whichever side the player
  approaches, while preserving the launcher's committed direction, target area,
  six-shot count and firing cadence. Its independent 0.6-second cooldown lets
  it repel a returning player even while the opening charge recharges, without
  dealing damage every physics frame. Remaining pressed against it can trigger
  another shove after that interval. Vertical clearance and solid terrain block
  contact; a descending head landing still uses smoke. This defense stops when
  missile recovery starts, and adds no smoke, ground hold or warning overlay.
- **Recovery and cooldowns:** the boss holds still for 1.6 seconds after each
  attack, then gets at least 0.65 seconds to reposition. Missiles recharge for
  5 seconds after a salvo; jump recharges for 6.5 seconds after landing. Both
  timers advance during the other attack, recovery, and walking. Mixed mode
  prefers the other attack when both are ready and otherwise uses an eligible
  ready attack. Single-attack modes respect that attack's cooldown too.
  Knife and handgun damage work throughout. The two-frame Hurt sheet plays for
  0.18 seconds without changing attack timing, movement, or cooldowns. The boss
  starts attacks only when visible in the gameplay camera.
- **Descending head landing / smoke escape:** the boss takes no stomp damage and gives no
  bounce. A dense burst of layered pixel smoke puffs appears on contact and may
  fully hide the player during the stun. The player drops under gravity to the floor
  and cannot move, jump, dash, attack, reload, heal, or save until the boss has
  moved 9 m clear and a further 1.5 seconds have passed. The boss retreats at
  6 m/s, choosing room away from a nearby wall, then immediately counterattacks
  while the player is still held. Mixed/missile mode uses the six-rocket salvo;
  jumps-only mode uses a committed leap. This defensive counterattack can bypass
  the interrupted attack's recharge, then restarts its normal full cooldown.
  An interrupted leap does not produce a second landing blast. An inactive boss
  remains inactive, and counterattacks still require it to be in the camera.
  Smoke itself neither deals damage nor grants invulnerability: incoming attacks hurt.
  A blocked retreat releases after 2.5 seconds;
  reset, death, inspection mode, or removing the boss also clear the hold. The
  smoke follows the player's body as they drop to the ground, stays dense during
  retreat, and thins over the counterattack hold with 0.6 seconds of wisps after
  control returns. Reset/death clears both the hold and the smoke immediately.
  Walking into its sides, crossing upward, knife/bullet hits, and the boss's own
  landing blast never trigger this response.
- **Defeat:** attacks stop, its remaining missiles are removed, and an airborne
  corpse falls to the floor without creating a landing attack. Reset restores
  health and collision/hurtbox state.

Initial tuning is deliberately provisional:

**Boss HP is a provisional 2000** (raised from the 300 lab placeholder on
2026-10-09 for playtesting): 80 handgun hits or 160 knife swings. The final
value and target number of openings are not agreed. Tune durability with the attack pattern and actual arena, keeping
a no-ammo melee win viable. The shared roster and combat rules are in
[Combat balance](COMBAT_BALANCE.md).

| Setting | Value |
| --- | --- |
| Boss health | 2000, provisional (final TBD) |
| Machine knife armor | 50% reduction: 12.5 per swing; 160 swings at 2000 HP |
| Handgun / stomp damage to boss | 25 / 0 |
| Smoke retreat speed / clearance | 6 m/s / 9 m |
| Hold after retreat / final smoke tail | 1.5 s / 0.6 s |
| Body charge trigger / travel / speed | 4 m / 2.4 m / 10 m/s |
| Body charge plant / recovery / cooldown | 0.22 s / 0.45 s / 4 s |
| Body charge damage / push | 25 / 24 m/s horizontal, decaying at 32 m/s² |
| Firing shove reach / repeat interval | 2.2 m at body height / 0.6 s |
| Blocked retreat timeout | 2.5 s |
| Hurt presentation | 2 frames over 0.18 s; no attack interruption |
| Missile / landing damage | 25 |
| Rockets per salvo / interval | 6 / 0.12 s (0.6 s first-to-last) |
| Launcher swivel / complete attack | 0.3 s / 1.14 s |
| Rocket launch / cruise speed / acceleration | 4.5 / 11 m/s / 24 m/s² |
| Rocket boost / departure angles / turn rate | 0.24 s / 16–24 degrees upward / 2.4 rad/s |
| Committed ripple spread | ±0.75 m horizontally around the initial target |
| Jump arc duration / gravity | 1.25 s / 32 m/s² |
| Maximum jump reach / missile start range | 14 m / 18 m |
| Landing horizontal radius / height | 2.8 m / 1.4 m |
| Landing damage duration | 0.16 s, once per target |
| Recovery after attack | 1.6 s |
| Missile cooldown / jump cooldown | 5 s after salvo / 6.5 s after landing |
| Minimum reposition time after recovery | 0.65 s |
| Walking speed / acceleration | 2.6 m/s / 10 m/s² |

The landing is a ground-level box across the 2D play plane. Its effect is an
expanded ring from the VFX catalog, flattened to the blast height. Boss sounds
use the **Boss · S.T.O.M.P.** slots in the audio tool, which ship trial picks; see
[Audio tuning](AUDIO_TUNING.md#boss-sounds-stomp). The flat lab has no second
phase; the scaffold arena's flying-machine phase is described below.

## Boss Arena WIP graybox

**Development selector → Boss Arena WIP** is the real Level 3
boss pit (below) with the lab's F1 fight controls and loadout added. It inherits
`scenes/dev/green_zone_finale_boss_pit.tscn`, so the two share one geometry; it
spawns on the floor, skips the entry beat, and uses the lab's own health bar.
The Boss Test Lab above stays the flat attack-testing fixture. The interior is
48.64 m wide and 46 m tall, narrowed from 64 m so the boss camera can keep both
actors in view across most of it:

The pit is a construction-scaffold complex; rock is limited to the walls,
ceiling and grass floor.

- **Main tower** (left): 10.24 m wide, eight decks 4.16 m apart up to 33.28 m,
  posts running on to the ceiling. Alternate floors extend a 2.56 m balcony
  past a post; the top balcony points right toward the crossing.
- **Two ceiling-hung platforms** step down to the right (bottom decks at 30.72
  and 24.96 m), each a braced box with a second deck on top. The higher one
  holds a supply chest.
- **Two stepped towers** stand under the hanging platforms (tops at 20.8 m and
  12.48 m, each with a chest), so the player can drop through a hanging deck
  onto them. The tall one lines up with the main tower's 20.8 m balcony; the
  short one ends 5.12 m from the right wall, where a long wall slide returns to
  the floor. Crossing gaps are 2.56-5.76 m.
- **The three chests** use the **Boss arena supplies** pool: each always gives
  34-40 handgun rounds (at least 100, up to 120 across the arena, against the
  80 hits the provisional 2000 HP takes), plus a 50% chance of medicine. Pit chests refill
  on every retry. See [supply chests](CHEST_LOOT.md).

**Camera.** The arena's boss camera runs in fit-both mode: it frames the
midpoint between the player and the boss and zooms out only as far as needed
to keep both in view. There is no fixed cap; only the arena limits the zoom, so
the view never shows beyond the walls, floor or ceiling (about 2.3× here, the
whole width). If even that cannot hold both, the framing keeps the player in
view. After comparing caps of 1.22-2.0×, an arena this size needs none. A fixed
cap (`encounter_maximum_zoom`) remains available for a much larger arena, where
the camera eases back to player framing past it. The flat lab keeps its
original player-led camera.

**One-way decks.** Decks are the only solid scaffold parts; posts and braces are
a passable frame drawn behind them. The player rises through a deck from below,
stands on it, and presses **move_down** (S, down arrow, stick down or D-pad down)
to drop through. Decks sit on physics layer 7, which the player and boss stand
on and which bullets and rockets do not query, so shots cross decks. The
scaffold script is `scripts/props/scaffold_tower_3d.gd`; the wall-jump scaffold
prop is unchanged.

**Firebombs (arena).** The boss lobs incendiary canisters with its otherwise
unused `Attack2` pod-tilt animation: two canisters, committed like the missiles
to where the player stands when the lob starts, the second 4.2 m to the side the
player is moving (or toward the room's middle). They fly a fixed arc, pass up
through decks, pass any deck above their target on the way down (so the space
under the scaffolding is not a refuge), pass through characters, and burst into
a 3.84 m fire patch fitted inside the surface they land on. A fire burns for 30
seconds and there is no cap on how many burn at once. **Standing in fire costs
25 every second and never puts it out; the only way to put a fire out is to
land on it from the air (a jump up from inside it counts), which also costs 25**
and smothers it in smoke. Avoiding fire is the intended answer. The lob has an
8 s cooldown in the mixed rotation (after an attack leap), but a player who
stands on ordinary ground for 3 s is lobbed at whenever the boss is free,
ignoring the cooldown and the reposition pause; time on decks drains that
timer. Fires go out on reset and with the boss. The art is the bombs pack's
finned canister and the fire pack's ground-fire strip, promoted to
`assets/art/vfx/boss`; the fire grows and dies by revealing rows of the strip at
native pixel size. Scripts: `scripts/projectiles/boss_firebomb_3d.gd` and
`scripts/hazards/boss_fire_patch_3d.gd`; `firebomb_enabled` is off in the flat lab,
whose F1 "Firebombs only" pattern still lobs.

**Phase two (arena).** When the boss first falls to half health (1000 of 2000
HP), three dormant **shootable flying machines** arrive 0.5 s apart: one bobbing
in the gap between the main tower's top balcony and the high hanging platform,
one patrolling under the hanging platforms, and one riding the right-wall slide.
Each blinks harmlessly for 1 s before arming, so none can appear on top of the
player. Body contact and the discharge are lethal as usual, but three handgun
hits destroy one (75 HP); the knife cannot. This is where the player first
meets machines with a gun in hand. Any still flying are destroyed with the boss;
a death or reset returns them to dormant and the boss to phase one. The variant
is `scenes/enemies/green_zone_flyer_shootable.tscn`; the indestructible machine
and its script stay unchanged. Phase logic: the boss's `phase_changed` signal
and `scripts/level/boss_phase_flyers_3d.gd`.

**Pursuit (arena boss only).** The arena's boss walks at 4.5 m/s and has
`chase_enabled`: when the player stands at least 2 m above it, it leaps onto that
surface on its own 3-second cooldown, with a height-solved arc that peaks 1.5 m
above the target. Beyond its 19.2 m reach it lands on the highest surface in
reach below the player and continues from there. While a leap rises, it passes
through bodies in the `boss_pass_up` group. Descending, each surface turns solid
again once the boss is above it, unless that surface is higher than the leap's
target, so it never lands inside a deck. Ordinary attack leaps pass through
those surfaces too and land at the boss's own level, or a lower player's. Chase leaps may start while
the boss is below the camera, because it rises into view before landing; missiles
and attack leaps still need it on screen. Chase landings use the normal landing
blast. These settings default off, so the lab's tuning above is unchanged.

Focused check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_arena_wip.gd`.
It covers the room limits, chest placement on decks, one-way decks, the chase
onto a deck, the staged climb, the attack leap's return to its level, and the
fit-both camera from close range to the arena's full view, firebombs (floor and
deck landings, contact damage that leaves the fire burning, landing to put it out,
burn-out, ground punish despite the cooldown, defeat cleanup), and phase two:
dormant machines, harmless arming, lethal contact, three-hit destruction by
bullets, reset and defeat cleanup. Playtesting owns the feel, the camera
in the tall space, and HP.

## Level 3 boss pit

The pit is Level 3's last section (`green_zone_boss_pit`, registered for
layouts and saves alongside the outdoors and gun encounter). It continues
straight on from the gun encounter: walking off the end of the upper-route
plateau takes a fade into the pit, where the player stands on the same plateau's
grass lip, high on the pit's left wall. There is no entry door; the lip simply
runs in from the left edge of the view.

The enclosing walls extend 30.72 m outward, with the floor and ceiling widened
to meet them, so camera movement cannot reveal their thin outer edges. The
inner wall faces remain at x=0 and x=48.64; the entrance lip, cutscene path,
scaffold positions and exit doorway keep their original locations.

**Entry beat.** The cutscene takes over as the pit appears. It walks the
player to the brink of the lip, and the camera looks down into the pit. The
player drops onto the wall below and slides; partway down, the camera swings
right and down to S.T.O.M.P., which turns from looking away and raises its
pod at the player. With the pod raised, the game freezes for the boss reveal:
the frozen frame drains to night blue, a stepped magenta band with a cyan edge
slams across it, the boss pops on top in full colour at 8x with a white outline,
and its name lands on the band. The reveal holds for 2.4 s; after its first
moment a press ends it early. Its health bar fills as the reveal lets go. The
camera comes back quickly, and control returns near the bottom of the wall,
still sliding. The scripted
slide speeds up while the camera is on the boss so it reaches the release
height on time, starting and ending at the ordinary slide speed. A moment
later the boss fires the salvo it was shown readying, aimed at the wall where
the player was. Input does nothing during the cutscene. Timings and framing
are exports on `BossEncounter` (`scripts/level/green_zone_boss_encounter_3d.gd`);
the reveal is `scripts/ui/boss_reveal.gd`. The boss's display name is the
`display_name` export on the boss, which the bar and the reveal both read.

**Retries.** The pit never saves. Its retry point is `PlateauCheckpoint` in the
gun encounter, just past the plateau's last chest, which in campaign runs is
an ordinary non-healing autosave. A death in the pit fades back to that
checkpoint, restoring the run as it stood when the player reached it: health,
ammo and items, opened chests and defeated gunners. Pit chests refill.
Developer runs return the same way, from the run's in-memory record of the
checkpoint (`SessionSaveState.last_checkpoint`). The **Level 3 - Boss
encounter** shortcut starts in the pit and has no checkpoint behind it, so a
death there respawns on the lip.

**Skipping.** The cutscene plays on every arrival. A fresh press of jump,
attack or confirm skips it to its end: the player low on the wall, still
sliding, with the camera on them, the bar filling and the opening salvo about
to fire. A key held from walking off the plateau does not skip it. The name
reveal keeps its own press-to-continue.

**Saving.** While S.T.O.M.P. is alive, cutscene included, manual saves are
refused with "You can't save during a boss fight." Its death autosaves at the
first safe footing under the normal non-healing rules, and manual saves work
again from then on. The kill, the warhead being taken and the door being
opened are world flags kept with the run and its saves. A load, or a return
after a death, finds the wreck in its death pose, the warhead on the floor or
in hand, and the door open if it was blown, with no cutscene.

**Exit.** The only door is a steel blast door in the foot of the right wall.
Destroying the boss drops its warhead, which falls clear of the wreck on the
player's side. Walking into it takes it; reaching the door with it plants it.
The charge blinks through a 1.6 s fuse, blows, and the door panels open. Walking
into the open doorway ends Level 3. Door art is
`assets/library/environment/structures/doors_and_portals/1 Doors/5.png`; the
warhead is bombs-pack sheet 17_1, promoted to `assets/art/vfx/boss/warhead.png`.

Focused check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_pit.gd`.
It walks off the gun encounter's plateau for real, then covers the held walk to
the brink, the look down, the drop onto the wall, the camera's swing to the
boss mid-slide, control returning near the bottom while still sliding, the
opening salvo, the autosave flag, a valid pit save, a retry without the beat,
the sealed exit, the warhead drop and pickup, the blast and the level ending. The background is still the lab's night sky.

## Assets and tuning locations

The unmodified character 2 sprites are promoted from
`assets/library/enemies/green_zone_bosses/2` to
`assets/art/green_zone/bosses/launcher`. Impact effects come from
`assets/library/vfx/fire/5 Explosions`; smoke comes from
`assets/library/vfx/effects/1 Smoke` (sheets 7, 8 and 14). Production copies live under
`assets/art/vfx/boss`.
The boss folder's `source_manifest.json` records source paths, hashes, and
licenses. The boss uses 0.06 m per sprite pixel as an actor-scale choice; scenery
retains the existing 0.04 m pixel grid and nearest filtering.

- Scene and room: `scenes/enemies/green_zone_boss.tscn`, `scenes/dev/boss_test_lab.tscn`.
- Encounter camera: `scripts/camera/boss_arena_camera_3d.gd`.
- Lab backdrop: `resources/presentation/backgrounds/boss_test_lab_night.tres`.
- Attack parameters: `scripts/enemies/green_zone_boss_3d.gd`, exposed on the boss.
- Health/damage: `resources/combat/green_zone_boss.tres`.
- Smoke burst: `scripts/presentation/boss_smoke_burst_3d.gd`.
- Lab loadout/UI: `scripts/dev/boss_test_lab.gd`.
- Focused check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_test_lab.gd`.
- Smoke/Hurt check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_smoke_escape.gd`.
- Charge check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_charge.gd`.
- Player Hurt check: `tools/run_godot_tool.ps1 -Script res://tools/validate_player_hurt.gd`.
- Body blocking check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_body_block.gd`.
- Rocket ripple check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_missile_ripple.gd`.
- Firing shove check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_salvo_shove.gd`.
- Encounter camera check: `tools/run_godot_tool.ps1 -Script res://tools/validate_boss_camera.gd`.

For visual review, enter through the selector, observe a full mixed cycle,
then use F1 to isolate missiles and jumps. Check walking, both expanded room
edges, camera follow, floor contact, missile origins, flight framing, the landing
footprint, melee access, head-contact smoke/retreat/release, Hurt frames, and a reset. Use normal
play first, then diagnostic overlays as needed. Passing checks is not player
acceptance of the balance or appearance.

## Validation scope

The focused check runs the actual lab through its menu shortcut and exercises
physics-driven missiles and jumps, destination commitment, grounded damage,
horizontal/aerial evasion, duplicate-hit rejection, player bullets, defeat, and
reset/loadout/save isolation. The knife kill check holds the boss inactive to
isolate the real knife input and hit-detection path; it does not establish the
difficulty of winning a live no-ammo fight.

The expanded-room checks measure the interior, probe floor collision at both
ends, and check player framing within the bounded encounter zoom range. The
camera check covers both actors at 9/18 m separations, room edges, a high jump,
distant player follow, smooth transitions, inspection, defeat and reset. A mixed-pattern
physics run checks actual walk frames and distance, stationary attack/recovery,
room bounds, own-attack cooldown enforcement, and interleaved recharge.

The ripple check exercises both firing directions and verifies six distinct
tube origins, matching firing frames, cadence, fixed target spread, accelerating
straight boost and bounded turns. It complements the live visual check of the
launcher/rocket contact and trajectory; it does not establish visual acceptance.
