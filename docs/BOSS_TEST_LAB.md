# Boss Test Lab

**Active priority: finish this boss and its final Level 3 arena.** The lab is the
working prototype, and its improved presentation does not mark the encounter
complete. Follow the [boss completion checklist](LEVEL_ROADMAP.md#next-priority-finish-the-green-zone-boss)
for arena construction, full-fight tuning, final HP, campaign integration and
acceptance. HP remains TBD; the current 300 is too low. Scanner integration and
further asset work are queued behind this encounter.

Open **Development selector → Boss Test Lab** (shortcut **8**). This is a fresh,
isolated test session with all movement abilities, a handgun, 12 loaded rounds,
and 60 reserve rounds. It does not advance or save campaign progress. The boss
has not been placed in Level 3 yet.

**F1** opens the fight controls: reset/refill, mixed attacks, missiles only,
jumps only, no ammo, and boss active. Changing a test option resets the fight;
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
returns to normal framing. This reusable camera is currently assigned only to
the lab. It is a movement/combat fixture, not the finished arena.

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
  This is a stylized rapid rocket barrage, not a historical weapon simulation.
- **Jump:** a thruster-assisted arc toward the player's position at takeoff,
  limited to 14 m horizontally and clamped inside the walls. It does not retarget
  in flight. The boss passes the
  player's body and lands on terrain. Landing on its head triggers the defensive
  smoke escape below instead of damaging it.
- **Landing:** a low blast starts on physical floor contact. Its VFX and damage
  start together, with no advance markers, warnings, prompts, or added warning
  phase. Each landing can damage the player once. Moving away or getting above
  the blast avoids it.
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

**Boss HP is TBD.** The current 300 HP is too low and remains only a runtime
lab placeholder. No replacement value or target number of hits/openings has
been agreed. Tune durability with the attack pattern and actual arena, keeping
a no-ammo melee win viable. The shared roster and combat rules are in
[Combat balance](COMBAT_BALANCE.md).

| Setting | Value |
| --- | --- |
| Boss health | TBD; 300 is the current lab placeholder, judged too low |
| Machine knife armor | 50% reduction: 12.5 per swing; 24 hits at the current placeholder HP only |
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
expanded ring from the VFX catalog, flattened to the blast height. Boss-specific
audio and later phases are not part of this first prototype.

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
