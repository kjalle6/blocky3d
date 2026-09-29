# Combat balance

The opening balance aims for demanding platforming with short, readable fights.
Ordinary combat allows a few recoverable mistakes, while spikes, pits, and flying
hazards remain instantly lethal. Health, healing, ammunition, and save recovery
are implemented; the remaining work is tuning them together in actual levels.

## Starting targets

| Actor or action | Current baseline | What it means |
| --- | --- | --- |
| Player | 100 maximum HP | Survives three ordinary hits; the fourth kills without healing |
| Bat patrol | 50 HP, 25 attack damage | Two knife hits or one stomp to defeat |
| Skater | 50 HP, 25 attack damage | Same toughness as the bat; movement and attack behavior differ |
| Knife | 25 damage | Close-range commitment |
| Stomp | 50 damage | Rewards positioning above an enemy and preserves the bounce |
| Handgun | 25 damage, 0.20 seconds between shots or empty trigger clicks | Provisional; compare its reach and firing opportunities with melee |
| Dual-gun enemy | 50 HP, 25 attack damage | Provisional; each paired firing beat damages a target once |
| Green Zone tank | 200 HP, 25 attack damage | Eight handgun hits or eight knife hits; immune to stomps and nonlethal interruption |
| Individual wooden crate | 50 HP | Two ordinary hits or one tank shell; the breaking shot is absorbed |
| Flyer | Indestructible, lethal on contact | Platforming hazard with no health bar |
| Spikes and pits | Lethal regardless of HP | Platforming challenge remains intact |

The player, bat, skater, knife, and stomp values are the agreed starting balance.
Handgun and gunner values are test values. One stomp is the current choice for
ordinary enemies; revisit it only if playtesting shows a need.

Boss health will follow the encounter's attack pattern and vulnerability windows.
An initial target is three or four well-used openings, with viable melee and no
requirement to arrive with ammunition. Bosses should use the same weapon damage
rules as ordinary enemies unless a readable resistance is deliberately designed.

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
deal normal damage but do not stagger it, knock it back, cancel a pending shot,
or reset its firing timer or movement. Its chosen attack cycle continues under
fire. Use impact sparks, sound, and the health strip to acknowledge damage without
replacing its attack animation with a blocking hurt animation. Defeat still
stops movement and cancels unfired attacks; released projectiles remain live.

Landing on the brain triggers a psychic pulse: 25 damage and a 0.7-second
player freeze, without damaging or interrupting the tank. It retreats at 2 m/s
during the freeze, then resumes its normal movement; the shell firing cycle
continues unchanged. A shell can damage the player during the freeze as a separate hit. Each landing triggers one pulse,
rearming after the player leaves the head area. Purple rings, a tinted player,
a brief label, and a separate audio-tool cue identify the attack. Knife and
handgun hits still deal their normal damage. Repeat pulses restart the same
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
The prototype campaign placements were removed; later encounter positions and
any elevated-guard timing changes will be decided with the rebuilt layout.

Judge the tank's cadence by the time available to recognise breaking crate
cover and move before the next shot. Its interruption immunity does not imply
damage reduction; the other enemies retain their existing interruption rules.

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

Each attack can damage a target once. Separate attacks remain separate damage
opportunities: there is no general invulnerability period after an ordinary hit.
The gunner's two simultaneous bullets share one hit identity per beat, preventing
an accidental double application on one target.

For the current player and ordinary enemies, nonlethal hits interrupt attacks
on both sides. The tank is the exception described above. Pending attack
damage is cancelled, while already-fired projectiles remain live. The current hurt attack
lock is 0.18 seconds. Repeated knife interruptions, simultaneous attacks, and
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
Ordinary enemy health strips appear after the first damage and hide on reset.
Ground contact, stomp detection, attack reach, and projectile hurt regions remain
separate from the artwork and from each other.

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

Actor profiles and attacks live in `resources/combat`. The handgun uses
`resources/weapons/first_handgun.tres` and the defaults in
`scripts/weapons/firearm_definition.gd`. Item definitions live in `resources/items`;
loot pools live in `resources/loot/chest_pools.json`. Runtime HP and inventory
quantities belong to each actor, separately from these shared definitions.

Generate the matchup report from the actual resources:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/report_combat_balance.gd
```

The output is `build/reports/combat_balance.md`. Use it to compare damage and hit
counts, then test actual encounters for practical firing opportunities, recovery,
and difficulty. The Firearm Lab isolates those comparisons; campaign play reveals
their effect on pacing and supply use. The [level roadmap](LEVEL_ROADMAP.md)
tracks the next encounters to build.
