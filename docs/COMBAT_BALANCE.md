# Combat balance

Numbers-only reference: [Combat stats spreadsheet](../outputs/01a0ee28-cea0-7d82-b0a7-f548e4c665b0/Combat_Stats.xlsx).

The opening balance aims for demanding platforming with short, readable fights.
Ordinary combat allows a few recoverable mistakes, while spikes, pits, water
contact hazards and flying machines remain instantly lethal. Health, healing, ammunition, and save recovery
are implemented; the remaining work is tuning them together in actual levels.

This is the shared combat reference for development and the planned scanner.
The roster and values below were checked against current resources, scripts,
enemy scenes and authored level overrides on **2026-09-30**. Values describe
implemented behavior unless explicitly marked planned or TBD. Reusable defaults
and placement-specific overrides are identified separately; unused art-library
characters are not implemented enemies.

## Current roster and starting balance

| Actor or action | Current baseline | What it means |
| --- | --- | --- |
| Player | 100 maximum HP | Survives three ordinary hits; the fourth kills without healing |
| Bat patrol | 50 HP, 25 attack damage | Two knife or handgun hits, or one stomp |
| Skater | 50 HP, 25 attack damage | Same toughness as the bat; rolling attack has different timing and reach |
| Knife | 25 damage | Close-range commitment |
| Stomp | 50 damage | Rewards positioning above an enemy and preserves the bounce |
| Handgun | 25 damage, 0.20 seconds between shots or empty trigger clicks | Provisional; compare its reach and firing opportunities with melee |
| Stationary / introduction dual-gun enemy | 50 HP, 25 per firing beat | Provisional; two simultaneous bullets share one damaging hit per target |
| Moving route gunner | 50 HP, 25 per firing beat | Mobile dual-gun variant; six reserve rounds on defeat |
| Elevated stationary guard | 50 HP, 25 per firing beat | Route-gunner variant with walking disabled and increased vertical detection; six reserve rounds on defeat |
| Green Zone tank | 200 HP, 25 attack damage | Eight handgun hits or sixteen knife hits; immune to stomps and nonlethal interruption |
| Green Zone launcher boss | **HP TBD**; 25 per damaging attack | Runtime lab placeholder is 300 HP and is too low; stomp triggers smoke escape instead of damage |
| Individual wooden crate | 50 HP | Two ordinary hits or one tank shell; the breaking shot is absorbed |
| Flying machine, vertical or horizontal patrol | No HP; indestructible | Body always kills on contact; electrical discharge below it is lethal only while active |
| Ground / wall spikes and spike-pit fill | No HP; instantly lethal | Contact kills irrespective of remaining HP |
| Shore and machine-pool water contacts | No HP; instantly lethal | Entering an authored water hazard causes water death |
| Pit / out-of-bounds kill regions | No HP; instantly lethal | Authored kill areas and the player's fall limit cause death |

The player, bat, skater, knife, and stomp values are the agreed starting balance.
Handgun and gunner values are test values. One stomp is the current choice for
ordinary enemies; revisit it only if playtesting shows a need.

**Boss maximum HP is unresolved.** The current 300 HP is a lab placeholder,
explicitly judged too low, not an accepted encounter target. It currently takes
12 handgun hits or 24 knife hits, but those counts must not set the final fight
length. Choose the replacement after testing attack patterns, vulnerability
windows and the actual arena. There is no agreed final HP, hit count or number
of openings. Melee must remain viable without arriving with ammunition.

### Player attacks and mobility

| Action | Current tuning | Combat meaning |
| --- | --- | --- |
| Knife | 25 damage; 0.34 s action; contact begins at 0.13 s and lasts 0.14 s; 1.25 m forward reach, 0.9 m vertical tolerance | One hit per target per swing; an interrupted or missed swing proves no resistance |
| Ordinary stomp | 50 damage; 10 m/s upward bounce on eligible enemies | One stomp defeats a bat, skater or gunner; tank and boss have separate defensive responses |
| Handgun | 25 damage; 0.20 s fire interval; 28 m/s projectile, 26 m maximum travel | Camera clipping usually limits useful range before maximum travel; 12-round magazine and reload rules below |
| Running | 8 m/s maximum; 65 m/s² ground acceleration, 80 m/s² deceleration, 42 m/s² air acceleration | Baseline for closing distance and escaping attacks |
| Jump / Double Jump | 14 m/s jump velocity; gravity 38 m/s²; maximum fall speed 28 m/s | Variable jump height and an unlocked second jump support aerial avoidance |
| Dash | 22 m/s for 0.25 s; exit speed 11 m/s | Horizontal movement with no contact invulnerability; solid terrain and the grounded boss still block it |
| Wall movement | Slide fall speed capped at 4.5 m/s; Wall Jump launches at 16.5 m/s upward and 10.5 m/s outward | Gives the player height, waiting space and another escape direction |

Use the full unlocked movement kit when judging boss attacks and the eventual
arena. Do not weaken movement to manufacture difficulty. The lab grants all
abilities; campaign access follows unlocks. Movement values come from
[default movement](../resources/player/default_movement.tres); the
[game direction](GAME_DIRECTION.md) owns the broader movement rules.

### Armor and boss defenses

Machine armor halves incoming knife damage on the Green Zone tank and launcher
boss: a 25-damage swing deals 12.5. Fractional damage carries between hits, so
two swings deal exactly 25 rather than rounding each swing. The integer health
display rounds remaining HP up. Reset and full healing clear that fraction.
Bullets retain full damage. Ordinary enemies and wooden cover have no knife
resistance; flyers remain indestructible.

Landing on the launcher boss does no damage and gives no bounce. It releases
smoke, grounds and holds the player, and retreats until 9 m clear. It then
counterattacks while the player remains held for another 1.5 seconds. The smoke
follows the player and gradually thins, with a 0.6-second tail after release.
The hold has no damage or invulnerability of its own, and resets/death always
clear it. A blocked retreat releases after 2.5 seconds. Its normal knife/bullet
Hurt animation uses two frames over 0.18 seconds and does not interrupt attacks.
Only a descending landing on its head triggers this defense; side contact,
ordinary weapon hits and the boss's own landing blast do not. The hold blocks
running, jumping, dashing, attacking, reloading, healing and saving, and pulls
the player down under gravity. Dense smoke may obscure the player completely
while held. An interrupted boss jump does not produce a false landing blast.
See [Boss Test Lab](BOSS_TEST_LAB.md).

The grounded launcher boss has a solid body: running and ground dashing cannot
cross it, including on raised solid surfaces. Jumping over its body can cross.
Side contact outside active attacks is harmless. Its leap, head-contact escape
and defeated body allow passage so landings and the smoke hold cannot trap the
player.

When a ready missile attack is crowded, the launcher boss can first make a
short committed body charge. It deals one 25-damage hit, pushes the player away,
and recovers before trying missiles again. The 24 m/s shove decays at 32 m/s²
and travels roughly 9 m without movement input. Running toward the boss regains
influence as the impulse falls below normal running speed, so holding run cannot
immediately cancel the hit. Its independent 4-second cooldown prevents repeated
charges. Jumping above or dashing away can evade it;
terrain stops the push, and movement abilities remain usable afterward. This
does not trigger the head-contact smoke or grounded hold. Jump remains usable;
a successful Dash or Wall Jump cancels the remaining shove impulse.

During the missile swivel and firing sequence, the boss can also shove a player
within 2.2 m at body height, from either side, using the same damage and impulse.
This has its own 0.6-second repeat interval and leaves the six-shot volley,
target and facing untouched. It works even while the opening charge recharges.
The firing shove ends at missile recovery; overhead clearance and intervening
terrain prevent it, while descending head contact retains its smoke response.

The launcher empties all six tubes in a rapid ripple, one rocket every 0.12
seconds. Each still deals 25 damage; six launches do not guarantee six hits.
The rockets commit to a narrow area around the player's initial position, with
small spread and no tracking of subsequent movement. The brief launcher swivel,
tube-by-tube release and outward boost accompany the attack; no warning overlay
is added. Rocket impact explosions are visual effects, not a second splash
damage attack; the boss's ground landing is the damaging AoE.

### Launcher boss attack tuning

Selected actor: **Green Zone bosses, character 2**. This kit is playable in the
lab; the final arena, HP and encounter difficulty remain unfinished.

| Attack / behavior | Current tuning | Damage, commitment and recovery |
| --- | --- | --- |
| Walk / reposition | 2.6 m/s, acceleration 10 m/s²; preferred distance 7 m | Walk animation used between attacks; at least 0.65 s reposition after normal recovery |
| Missile salvo | Start within 18 m; 0.3 s Sneer launcher swivel; six tubes at 0.12 s intervals; 1.14 s complete sequence | 25 per rocket; first-to-last launch 0.6 s; committed initial target with ±0.75 m horizontal spread; 1.6 s recovery |
| Rocket flight | 4.5 m/s launch, 11 m/s cruise, 24 m/s² acceleration; 0.24 s outward boost; 16–24° upward departure; 2.4 rad/s turn limit; 32 m travel limit | Curves toward the committed area, never follows later player movement or loops back after passing it; tube origins and art mirror with facing |
| Jump / landing AoE | 1.25 s arc, gravity 32 m/s²; maximum horizontal reach 14 m; committed destination clamped to room | 25 damage once per landing; ground-level box with 2.8 m horizontal half-width and 1.4 m height, active for 0.16 s; overlap includes player body width; 1.6 s recovery |
| Opening body charge | Trigger within 4 m when preparing missiles; 0.22 s plant, up to 2.4 m travel at 10 m/s | 25 damage once per charge, 24 m/s shove decaying at 32 m/s²; 0.45 s recovery; separate 4 s cooldown |
| Shove during missile firing | Within 2.2 m at body height, either side; repeat interval 0.6 s | Same 25 damage and shove impulse; works throughout swivel/firing without cancelling or redirecting the salvo; ends at recovery |
| Head-landing smoke escape | No stomp damage or bounce; retreat at 6 m/s until 9 m clear; blocked timeout 2.5 s | No direct damage; grounded player hold through retreat and another 1.5 s during the counterattack; smoke fades with a final 0.6 s tail |

Missiles recharge for **5 seconds after the salvo**, and jumps for **6.5 seconds
after landing**. These are independent timers: one attack can recharge while
the other is used. The head-landing defense interrupts the current action and
creates an immediate counterattack after escape, bypassing the ordinary choice
of ready attacks; its counterattack then starts the normal cooldown again.

There are no advance landing markers, danger circles, countdowns, warning audio
or separate warning effects. The blast effect appears when the boss lands and
damage starts. All explosions, smoke and supporting effects come from the
existing `assets/library/vfx` catalog, with selected runtime assets promoted
under `assets/art/vfx/boss`. The lab guide owns art selection and camera details.

Bosses use only the large encounter health bar, never a small overhead enemy
strip. Defeat stops attacks, removes this boss's remaining missiles and allows
passage through its body. An airborne corpse falls without a landing blast.
Reset restores health and collision. Boss-specific audio and later phases
remain unimplemented.

### Level 3 tank and later gunner variants

The gun-enemy stretch now begins with the moving Green Zone tank, using
`resources/combat/tank.tres`: 200 HP, eight 25-damage handgun hits. Initial
movement is 1.25 m/s. One shell travels at 9 m/s after a 0.65-second
tell, followed by the 0.36-second firing animation and 1.15-second recovery.
That gives roughly 2.2 seconds between shells. These values remain provisional.

The initial approach still starts the fight near the crates. Once engaged, the
tank pursues the player at its normal movement speed, turns after a jump-over,
and closes to a four-unit firing distance. Idle patrol endpoints do not leash
an active pursuit. Crates stop its body but do not break engagement: it shoots
them apart. Ledges, hazards and solid walls stop ordinary ground pursuit.
The Level 3 clearing and climb use an authored engagement boundary, so camera
scrolling does not reset the fight. After engagement, that tank keeps shooting
up the authored shaft while any of the wall-jump area remains in camera view,
including from the upper route and chest roof. It cannot acquire a new target
off screen. Other placed tanks still disengage when they leave
the camera. A player hit can also draw attention.

The tank is an explicit exception to ordinary hit interruption. Nonlethal hits
apply its knife armor but do not stagger it, knock it back, cancel a pending shot,
or reset its firing timer or movement. Its chosen attack cycle continues under
fire. Use impact sparks, sound, and the health strip to acknowledge damage without
replacing its attack animation with a blocking hurt animation. Defeat still
stops movement and cancels unfired attacks; released projectiles remain live.

Landing on the brain triggers a psychic pulse: 25 damage and a 0.7-second
player freeze, without damaging or interrupting the tank. It retreats at 2 m/s
during the freeze, then resumes its normal movement; the shell firing cycle
continues unchanged. A shell can damage the player during the freeze as a separate hit. Each landing triggers one pulse,
rearming after the player leaves the head area. Purple rings, a tinted player,
a brief label, and a separate audio-tool cue identify the attack. Knife hits deal
half damage and handgun hits retain full damage. Repeat pulses restart the same
effect rather than stacking rings and labels.

A full 12-round magazine would retain four rounds after eight accurate shots.
The tank's defeat should provide a clear opportunity and cue to reload before
the next encounter; it does not guarantee an empty magazine. Normal reloads
remain sufficient, and the timed second press is an optional faster finish.

The reusable moving dual-gun variant has 50 HP and deals 25 damage per paired
beat. It walks at 2.6 m/s, closes to six metres, stops for its 0.55-second tell,
commits to a three-beat burst, then recovers for 0.85 seconds. It turns after
recovery when jumped over. It requires camera visibility to engage, takes
normal hit interruption, and awards six reserve rounds once. Defeat and reward
are restored together by saves. Walking can be disabled for a stationary guard.
The rebuilt Level 3 upper route now contains both a moving gunner and a
stationary elevated guard. The latter has 14 m vertical detection tolerance
instead of the usual 3 m; it retains the same damage and burst/recovery tuning.
Layout JSON may move these placements. Encounter and visual acceptance remain
playtest work; see the [upper gunner route](LEVEL_ROADMAP.md#upper-gunner-route).

Judge the tank's cadence by the time available to recognise breaking crate
cover and move before the next shot. Its interruption immunity and knife armor
are separate rules; the other enemies retain their existing interruption rules.

Player bullets stop just outside the current camera view, with an edge allowance
of 2.5% of the viewport's smaller dimension for partially visible targets. The
whole movement segment is clipped before collision detection, so a fast round
cannot damage distant off-screen enemies or crates. The tall Level 3 shaft's
tank has a 48 m shell range to cover its visible roof; other tank placements retain 22 m.

The clearing now ends in a wall-jump climb between a solid steel scaffold and
the upper ground. A surviving tank moves beneath it and aims upward, retaining
the clearing cadence and 9 m/s shell speed. Two spike patches interrupt the
right-hand wall. The firing animation commits the direction; shells do
not home. Solid upper ground blocks shots, but pursuit and firing end only once
the shaft/scaffold leaves the view. Defeat grants 30
reserve handgun rounds (22 net after eight accurate hits), without refilling
the magazine. The reward and defeat persist together in saves. Reward amounts
remain provisional until the later encounters exist. The
[level roadmap](LEVEL_ROADMAP.md#tank-exit-wall-jumping-under-fire) owns the layout.

## Damage and enemy behavior

### Ordinary enemy attacks

All three gunner roles share the gunner health profile: two knife or handgun
hits, or one stomp, defeat them. Bat and skater use their own profiles with the
same current HP and damage. These shared numbers do not make their movement or
attack patterns identical.

| Enemy / variant | Movement and engagement | Attack timing and reach |
| --- | --- | --- |
| Bat patrol | 2 m/s reusable patrol default; some authored patrols use 1.7 m/s; notices the player within 4 m horizontally and 3.5 m vertically on a safe ground route | Stationary 0.60 s swing, impact at 0.38 s, 1.25 m damage/start reach, 0.9 m vertical tolerance; 0.65 s recovery |
| Skater | 2 m/s patrol default; same ground-route engagement rules | Rolls at 4 m/s during its 0.60 s attack; impact at 0.30 s; starts within 1.65 m, actual damage reach 0.8 m and vertical tolerance 0.9 m; 0.65 s recovery |
| Stationary / introduction dual-gun enemy | No walking; base detection 18 m horizontally and 3 m vertically; each firing beat aims at the player | 0.55 s tell, default three paired beats with 0.18 s interval setting, 0.85 s recovery; two-beat option uses 0.55 s interval setting |
| Moving route gunner | 2.6 m/s, seeks 6 m firing distance inside its authored route; camera visibility required | Same three-beat timing, but commits aim for the burst and turns after recovery; stops walking throughout tell, burst and recovery |
| Elevated stationary guard | Route gunner with walking disabled; current upper-route placement detects across 14 m vertically | Same committed burst, damage and recovery as the moving variant |

Gunner bullets travel at 8.5 m/s, with a 22 m maximum distance. Each beat emits
two bullets, so the default three-beat burst releases six projectiles but can
deal at most three 25-damage hits to one target. The alternate two-beat pattern
releases four projectiles. Launches follow animation frames; interval settings
alone are not the entire attack duration. A teammate blocking a muzzle's firing
lane delays that beat until clear; released bullets can still hit other enemies.

### Shared hit and interruption rules

Each attack can damage a target once. Separate attacks remain separate damage
opportunities: there is no general invulnerability period after an ordinary hit.
The gunner's two simultaneous bullets share one hit identity per beat, preventing
an accidental double application on one target.

For the current player and ordinary enemies, nonlethal hits interrupt attacks
on both sides. The tank and launcher boss are the exceptions described above. Pending attack
damage is cancelled, while already-fired ordinary-enemy projectiles remain live.
The player hurt attack lock is 0.18 seconds. Bat/skater hits apply a 0.18-second
hurt reaction and at least 0.65-second attack recovery; a gunner interruption
enters its 0.85-second recovery. A visible Hurt reaction is not a universal stun
duration. Repeated knife interruptions, simultaneous attacks, and
multiple enemies need continued testing for unavoidable stun loops.

Ground-enemy body contact is solid and harmless. Bats and skaters stop during
attack recovery, including recovery from an interrupted swing, and hold their
facing through that sequence. Current recovery is 0.65 seconds. The bat begins
its windup within its 1.25-unit damage reach; the skater retains its rolling
approach.

They notice a player within 4 units horizontally and 3.5 vertically when there
is a safe ground route; a nonlethal hit also gets their attention. Once engaged,
they turn after recovery and pursue at patrol speed, including after a jump-over.
Ledges, active hazards, walls, authored patrol limits, or the entire sprite
leaving the camera end pursuit. They then walk back toward their patrol position
without healing. They do not jump gaps or navigate around obstacles.

Hits need clear impact feedback and sound, including when an enemy survives.
Every accepted nonlethal player hit now plays the existing two-frame Hurt
animation during the 0.18-second hurt attack lock, alongside the existing red
flash, hit pause, and configured hit sound. Ordinary hits previously flashed
the current movement sprite without selecting that animation. Movement stays
available; afterward the current movement and equipped-weapon pose return.
Death and the special psychic/smoke holds retain their own presentation.
Ordinary enemy health strips appear after the first damage and hide on reset.
Ground contact, stomp detection, attack reach, and projectile hurt regions remain
separate from the artwork and from each other.

## Lethal hazards

These use instant death, not a large ordinary damage number. They have no HP,
knife resistance percentage, ammo reward or ordinary enemy health bar. Knife,
handgun and stomp do not destroy them, and Dash gives no hazard invulnerability.

| Hazard | When it is lethal | Current timing / placement rules |
| --- | --- | --- |
| Flying machine body | Always lethal on player contact, even between discharges | Indestructible traversal actor; vertical bob by default, optional horizontal patrol |
| Flying machine electrical discharge | Contact with the spark below the machine while active, including already overlapping when it switches on | Active 0.6 s in each 2.4 s cycle; attack art accompanies the live spark; the body stays lethal throughout |
| Ground or wall spike row | Contact with its lethal collision region | Continuous; default row is 2.5 m wide, with 0.2 m inset at either end and 0.36 m collision height; authored width/rotation can differ |
| Spike-pit lethal fill | Entering the filled region beneath/among the visible spikes | Continuous; prevents the bottom of an enclosed spike pit becoming safe ground |
| Shore water | Entering Arrival's `ShoreWaterContact` | Immediate water death; no swimming, drowning timer or gradual HP loss |
| Machine-shaft pools | Entering Level 2's `MachineShaftWaterContact` or `DualMachineShaftWaterContact` | Immediate water death; contact height follows the associated water surface with an authored offset |
| Pit / void kill region | Entering an authored kill area or dropping below the player's `fall_limit_y` | Immediate death; threshold and bounds belong to the level, not an enemy attack |

Water artwork by itself does not establish a lethal area: the contact regions
above implement it. Background-only water is scenery. Likewise, empty pit space
will need an explicit scan target before the scanner can identify it reliably.

Flyer motion is placement-specific. Its reusable default bobs ±1.2 m on a
3-second cycle with no horizontal patrol. Current Level 2 machine shafts and
the Level 3 machine pair use ±3.585 m on the same 3-second cycle; paired machines
use different starting phases. The Level 3 ravine patrol bobs ±0.64 m and sweeps
±20.4 m horizontally at 4 m/s, giving a 20.4-second full horizontal cycle. These
placements retain the 0.6 / 2.4-second discharge tuning. Reset restarts each
machine's local clock and authored phase.

The body and spark are separate danger facts for learning: knowing that contact
with the machine kills does not automatically reveal its discharge timing.

## Cover and other combat objects

Each wooden crate has its own 50 HP, no knife armor and no current loot reward.
Two 25-damage knife or handgun hits break one; a tank shell explicitly breaks
an intact crate in one hit without changing its 25 damage against the player.
The breaking projectile is absorbed rather than penetrating the crate behind
it. Stomping is not a crate-breaking attack.

Unsupported stacked crates fall under gravity; they currently have no falling
damage or crush attack. Broken state participates in world saves. Solid terrain
and rock cover block shots without a destructible HP pool; a decorative prop
without collision does not provide cover. Shared projectiles stop at their first
collision or range limit, with no implied splash damage from impact artwork.

## Unfinished balance and future content

- **First priority: finish the Green Zone boss in its final arena.** Tune the
  full fight and connect its defeat/Level 3 ending before scanner integration
  or further asset expansion. The [roadmap checklist](LEVEL_ROADMAP.md#next-priority-finish-the-green-zone-boss)
  defines the milestone; the lab remains the behavior test fixture.
- Launcher boss HP is **TBD**; 300 remains only the inadequate runtime lab
  placeholder. Final arena size, encounter length, attack tuning, later phases
  and boss-specific audio are not settled. The boss is not connected to Level 3.
- Moving saws are reserved for a later level, not implemented in the current
  roster. Their damage, speed, route and timing are TBD.
- General enemy drops, additional status effects and unused enemy/hazard assets
  have no agreed combat values. Document them here when actually designed;
  do not infer a mechanic from a sprite sheet or a folder name.
- Scanner rules below are a planned feature. Existing combat facts are the
  reference it will learn from, not knowledge awarded at first scan.

## Enemy and hazard scanner (planned)

**Status: data catalog and reader implemented; gameplay/UI not connected.**
[Scanner data](SCANNER_DATA.md) holds the reusable entries, current-stat bindings
and fact-by-fact evidence contract. A cyberpunk eye implant, glasses,
or similar device lets the player identify enemies and hazards, learn about
them through experience, and later give them personal names. The device's final
form and overlay artwork are still to be chosen. The combat values and effects
above remain the underlying rules; scanning changes what the player knows.

### Agreed interaction

1. Toggle a cyberpunk scanning overlay on or off quickly. Scanning happens in
   the live world, with normal running, jumping, Double Jump, Dash and Wall Jump
   available according to the player's unlocked abilities. Entering scan mode
   grants no protection from existing damage, stuns or other movement restrictions.
2. Hold **left-click on a particular enemy or hazard** to perform its initial
   scan. Player attacks are disabled throughout scan mode. Switching back to
   combat should be immediate, without firing a leftover scan click.
3. A completed initial scan registers the target under its game-provided name
   and activates learning about it. It does not reveal all HP, attacks,
   resistances, weaknesses, status effects or danger information at once.
4. After scanning, actual encounters gradually reveal individual facts. This
   learning continues during ordinary play with the scanner switched off;
   otherwise the player could never test their own attacks. Switching modes
   should not interrupt movement or require a menu confirmation.
5. **Right-click an identified enemy or hazard** to inspect its entry: the
   player-given name when present, otherwise its game name, plus discovered
   stats, effects and dangers. Naming is optional and comes after experience,
   with a rename action in the entry rather than a forced first-scan prompt.
   The exact point at which renaming becomes available remains open.

The scanner records lessons learned in play. It does not add advance warnings
for undiscovered attacks or replace the existing boss landing VFX with warning
markers. Detailed entries and a brief targeting/progress display serve different
purposes; the overlay's final presentation is still to be designed.

### Discovery and evidence

Each fact needs its own qualifying experience after the initial scan. Taking
one rocket hit must not also reveal the same enemy's head retaliation, landing
blast or knife armor. A successful knife hit establishes knife effectiveness;
it does not establish bullet or stomp effectiveness.

Keep **unknown**, **confirmed effective**, **reduced damage**, and **confirmed
ineffective** distinct. A missed swing, obstructed bullet, out-of-range attempt,
or attack cancelled before impact cannot prove resistance. A visible Hurt
animation alone cannot prove that the enemy's attack was interrupted: the
launcher boss can display Hurt while continuing to fire.

The following maps existing combat rules to proposed discovery evidence. Actor
names are the current reference names, not final device-screen copy. Each row
contains separate facts to unlock, not a bundle awarded by any one interaction.
Numerical baselines stay in the tables and actor descriptions above.

| Enemy or hazard | Existing rules the entry could record | Experience needed for the corresponding fact |
| --- | --- | --- |
| Bat patrol / skater | Knife, bullet and stomp effectiveness; attack damage; hit interruption | A confirmed connection with each tested attack; receiving its attack; interrupting an attack through a hit |
| Stationary / moving / elevated dual-gun enemy | Weapon effectiveness; gunfire damage; paired bullets form one damaging beat; hit interruption; applicable movement and burst behavior | The corresponding weapon hit, received firing beat, interrupted attack or observed behavior; one bullet observation must not reveal every burst pattern or variant |
| Green Zone tank | Reduced knife damage, full bullet damage, ineffective stomps; attacks continue through nonlethal hits; head contact causes psychic damage and a freeze while the tank retreats | Test the relevant weapon or head contact; experience the pulse/freeze; observe a pending attack continue through a confirmed hit |
| Green Zone launcher boss | Reduced knife damage, full bullet damage, ineffective stomps; head contact causes smoke, grounded hold, retreat and counterattack; landing AoE; charge/firing shove; missile damage | Separate confirmed weapon tests, descending head contact, landing-blast contact, charge/shove contact and rocket hits; smoke itself is not the source of rocket damage |
| Flying machine body / discharge | Always-lethal body contact; timed lethal electrical spark below it; ineffective attacks; observed patrol behavior | Body contact and active-spark contact establish separate dangers; a missed or passing projectile proves no resistance. Reliable ineffective-attack evidence needs implementation because the flyer is outside ordinary combat-target contracts |
| Ground/wall spikes, pit fill / void | Lethality irrespective of remaining HP | The relevant lethal encounter; initial scanning alone does not fill its danger entry. Target selection for empty pit space still needs design |
| Shore / machine-pool water | Immediate water death at the actual contact surface | Entering the corresponding lethal water region; observing decorative water alone establishes no damage rule |

Learning an effect and knowing its exact numbers are separate decisions. Do not
automatically reveal maximum HP, exact cooldowns, stun duration or attack range
from a first scan or an unrelated hit. The conditions for unlocking those values
still need definition. A killing blow's overkill or rounded health display is
not an accurate measurement of maximum HP or fractional damage.

### Keeping records consistent

- Combat profiles, attack/weapon resources and actor/status logic remain the
  source of truth. Scanner entries should reference those definitions and
  record which facts are known, rather than maintain another set of HP/damage
  constants. Damage descriptions must distinguish authored attack damage from
  damage actually received after a resistance or other modifier.
- Keep a stable target identity and canonical game name separate from the
  player's optional alias. Renaming must not change combat identity, values,
  discovery ownership or save references.
- Record the responsible source, attack and interaction condition. For example,
  the tank's psychic pulse and its shell are separate hits; the boss's smoke
  hold and a rocket arriving during it are separate effects. Do not award
  knowledge of unexperienced abilities just because they share an actor profile.
- The catalog reader checks supplied evidence, but gameplay event adapters and
  player knowledge storage are still a future integration requirement.
  Existing attacks may need explicit hit/resistance results before they can
  support reliable learning. Development lab runs must remain separate from
  campaign knowledge and names.

Still to decide before implementation:

- Scan toggle binding/controller controls, scan duration and range, targeting,
  line of sight, and whether interrupted scans retain progress.
- Whether personal names and knowledge apply to a type or an individual;
  type-wide entries with distinct variants were suggested but are not settled.
- Which facts require taking an effect versus observing it, how exact HP and
  timing values are learned, and when the rename action becomes available.
- Whether right-click details pause play; the scanning overlay itself stays live.
- Persistence through death, Continue, older saves and new campaigns. Keeping
  discoveries through death was suggested, but is not yet an agreed save policy.
  Lethal hazards require a deliberate decision about retaining their final event.
- Device appearance, overlay assets, acquisition point and campaign introduction.

## Healing and inventory

| Item | Healing | Current availability |
| --- | --- | --- |
| Medicine packet | 25 HP | Opening-level pools and fixed rewards |
| Open medical kit | 50 HP | Green Zone pool from Level 2 onward and fixed rewards |
| Medical bag with a cross | 75 HP | Explicit chest overrides and the lab |

Campaigns begin with no healing supplies. There is no carrying cap. Q/E limit
which two item types are immediately available, while the Tab inventory lets the
player change assignments by hovering an item and pressing the desired key.
Both slots can reference one shared stack. The full inventory pauses the game.

Healing restores HP immediately, consumes one item, and produces a brief player
indicator and sound. It cancels an active attack and prevents attacks or another
use for 0.25 seconds while all movement remains available. At full HP, use does
not consume an item. Feedback timing and sound can still be tuned.

The compact player HUD sits at the top left, with HP numbers centered inside the
bar and Q/E items below. Bar width follows maximum HP: 110 maximum HP is 10%
wider than 100. Taking damage changes the fill, not the bar's outer width.
The Firearm Lab's F1 Health Bar Preview provides comparison sizes.

## Ammunition and reloading

The handgun holds 12 rounds and draws reloads from the `handgun_ammo` inventory
stack. Reloading tops up the magazine without discarding remaining rounds or
creating separate magazine items. Each successful shot spends one loaded round.
The bottom-left gun icon shows loaded/reserve counts and hides for the knife.

Normal reload duration is 1.5 seconds. A 0.2-second active-reload window starts
at a random time between 0.4 and 1.0 seconds on each reload. One second R press
inside that window finishes the reload immediately; an early or late attempt
leaves the original completion time unchanged. Repeated presses do not grant
another attempt. There is no damage bonus or jam penalty.

The timing bar follows the player. A short 0.4-second gun/arm pull-in and return
provides a reload gesture, while the bar and audio show the remaining duration.
The character packs have no dedicated reload animation. Capacity, duration,
window size, and the bar's final appearance remain tunable.

Switching to the knife, taking damage, healing, death, or reset cancels the reload
without spending reserve rounds. Inventory and pause suspend its timer and sound.
Completion transfers only the missing rounds, limited by the available reserve.

The first Level 3 handgun pickup grants 30 total rounds: 12 loaded and 18 reserve.
The Firearm Lab starts with 12 loaded and 30 reserve; its chest adds one medicine
and 30 reserve rounds. Other sources have their own authored quantities.

## Supplies and pickup feedback

Supply chests use level-based weighted pools, variable quantities, and a possible
second item type. Random ammo rewards require handgun ownership. The designer
also supports fixed bundles for guaranteed supplies. Pool definitions, sample
placements, and save repeatability are described in [CHEST_LOOT.md](CHEST_LOOT.md).
General enemy drop rates remain open.

Rewards enter the inventory immediately. Icons and +quantities then pop up above
the player in sequence, rising and fading while movement continues. Entries are
about 0.57 seconds apart and last about 1.09 seconds each. Pausing freezes the
sequence; death, reset, and scene changes clear it.

The first handgun opens a separate paused unlock showcase with the weapon,
its name, and a Continue button. Its 30-round reward is added on collection;
the gun HUD shows loaded and reserve ammunition. The firing and reload lesson
will introduce the controls in play.

With unlimited carrying capacity, balance supply amounts over whole sections
and between saves. Check whether players accumulate enough healing or ammo to
bypass the intended challenge, and whether a poor attempt creates tedious
resource recovery. Stronger healing, future status effects, shops, and crafting
need to be assessed against the same pacing.

## Saves and recovery

Autosave points store health and supplies without healing. Players also have
three protected manual slots and three rotating autosaves. Manual saving is
available from safe stationary ground outside combat; active pursuit prevents it.
Death offers Continue, Load Save, and quit options.

Loading restores saved HP, inventory, and reward claims together. Explicitly
choosing an older save restores all progression to that snapshot. Continue from
an autosave can retain later permanent unlocks; Continue from a manual save
restores that manual snapshot. Quitting does not write a new snapshot.
See [SAVE_SYSTEM.md](SAVE_SYSTEM.md) for the complete policy and safety checks.

## Editing values and reviewing balance

Keep this document and the combat stats spreadsheet current when a combat value or mechanic changes, including
the scanner's future evidence mapping. Record instance overrides instead of
quietly treating a reusable default as universal. Keep unimplemented decisions
separate from tested behavior, and synchronize boss tuning with the lab guide.

| Runtime family | Definitions and behavior sources |
| --- | --- |
| Player / weapons | [Player](../scripts/player/player_character.gd), [combat profiles and attacks](../resources/combat), [handgun definition](../resources/weapons/first_handgun.tres), [movement](../resources/player/default_movement.tres) |
| Bat / skater | [Patrol scene](../scenes/enemies/pixel_patrol_enemy.tscn), [skater overrides](../scenes/enemies/pixel_skater_enemy.tscn), [shared melee AI](../scripts/enemies/stompable_enemy_3d.gd) |
| Stationary / moving / elevated gunners | [Base gunner](../scenes/enemies/handgun_enemy.tscn), [route gunner](../scenes/enemies/route_gunner.tscn), [gunner AI](../scripts/enemies/handgun_enemy_3d.gd), [route behavior](../scripts/enemies/route_gunner_3d.gd), [upper-route placements](../scenes/dev/green_zone_finale_shooter_area_wip.tscn), [layout overrides](../resources/level_layouts/green_zone_shooter_area.json) |
| Tank | [Scene](../scenes/enemies/green_zone_tank.tscn), [profile](../resources/combat/tank.tres), [AI / psychic response](../scripts/enemies/tank_enemy_3d.gd) |
| Launcher boss | [Scene](../scenes/enemies/green_zone_boss.tscn), [profile](../resources/combat/green_zone_boss.tres), [attacks / defenses](../scripts/enemies/green_zone_boss_3d.gd), [rocket flight](../scripts/projectiles/boss_missile_3d.gd), [Boss Test Lab](BOSS_TEST_LAB.md) |
| Flyer / electrical spark | [Scene](../scenes/enemies/green_zone_flyer.tscn), [motion and discharge](../scripts/enemies/hovering_hazard_3d.gd) |
| Spikes / water / kill areas | [Spike scene](../scenes/hazards/pixel_spike_row.tscn), [spike collision](../scripts/hazards/pixel_spike_row_3d.gd), [lethal contact](../scripts/hazards/hazard_3d.gd), [Arrival water](../scenes/levels/arrival_shoreline.tscn), [Level 2 pools](../scenes/levels/overgrown_coastal_ascent_interior.tscn) |
| Projectiles / cover | [Shared projectile collision](../scripts/projectiles/handgun_projectile_3d.gd), [crate scene](../scenes/props/breakable_crate.tscn), [crate behavior](../scripts/props/breakable_crate_3d.gd) |

Actor profiles and attacks live in `resources/combat`. The handgun uses
`resources/weapons/first_handgun.tres` and the defaults in
`scripts/weapons/firearm_definition.gd`. Item definitions live in `resources/items`;
loot pools live in `resources/loot/chest_pools.json`. Runtime HP and inventory
quantities belong to each actor, separately from these shared definitions.

Generate the matchup report from the actual resources:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/report_combat_balance.gd
```

The output is `build/reports/combat_balance.md`. It reports current resource
values, including the boss's 300-HP placeholder; it does not resolve the TBD or
catalog every hazard and scripted status effect. Use it to compare damage and hit
counts, then test actual encounters for practical firing opportunities, recovery,
and difficulty. The Firearm Lab isolates those comparisons; campaign play reveals
their effect on pacing and supply use. The [level roadmap](LEVEL_ROADMAP.md)
tracks the next encounters to build.
