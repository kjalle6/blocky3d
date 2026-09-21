# Combat balance

This is the design reference for the first health-and-damage pass. Numerical
health, interruptions, health displays, carried healing, Q/E slots, inventory,
manual saves, autosaves and death/load menus now have a first implementation.
See [current behavior and controls](SAVE_SYSTEM.md). Accepted baseline numbers
are implemented; presentation and provisional gun/healing tuning await playtest.

[Health, inventory, and saves: implementation plan](HEALTH_INVENTORY_SAVE_PLAN.md)
turns these decisions into ordered phases, integration work, and completion checks.

## Accepted targets

| Character or hazard | Health and toughness | Open decisions |
| --- | --- | --- |
| Player | Starts with 100 maximum HP. Survives three ordinary hits; the fourth kills, without healing (25 damage per hit). Allow a higher maximum later. Test without general invulnerability after damage; hits interrupt attacks on both sides. | Special/heavy attack damage, hurt timing/knockback, and how upgrades are earned. |
| Green Zone bat patrol | Start at 50 HP: two knife hits or one stomp from full health. Its attack deals 25 damage. | Player bullet damage; revisit the stomp count after playtesting. |
| Skater | Start at 50 HP: two knife hits or one stomp from full health. Its attack deals 25 damage. | Player bullet damage; revisit the stomp count after playtesting. |
| Dual-gun enemy | Damageable. | HP, knife/stomp/shot counts, and damage per bullet. |
| Green Zone flyer | A platforming hazard: contact is instant death regardless of HP. Indestructible for now; no health bar. | Possible vulnerability to guns later remains an idea, not an approved feature. |
| Boss | Health and damage will follow its attack pattern and vulnerability windows. | Numerical values and matchup targets. |
| Traversal hazards, including spikes and pits | Instant death regardless of remaining HP, preserving the platforming challenge. | None for this pass. |

The two-hit knife targets refer to distinct successful attacks. One animation
must not apply its damage repeatedly while it overlaps the same enemy.

## Display rules

- Player: the accepted Cyberpunk health bar plus numerical current/maximum HP
  using the pack's pixel font. Begin with a compact HUD footprint at 100 HP;
  leave room for a potentially longer bar and larger maximum later. The fill
  uses current HP divided by maximum HP, with no permanent 100-HP ceiling.
  Future capacity increases and the bar's physical length are separate from
  ordinary damage; the HUD must not grow and shrink as current HP changes.
- Ordinary damageable enemies: a thin pixel strip without a frame or numbers.
  Hide it until the first damaging hit, then show remaining health until defeat
  or reset. Reset hides it again. A killing first hit does not need to display
  an empty bar before death.
- Bosses: a wider health bar with the boss's name.
- Consumables: keep quick-use slots visible on screen, with item icons, counts,
  and their assigned inputs. Support more than one healing-item type without
  opening a selection menu. The user chose two direct-use slots on Q/E for the
  prototype. Layout and gamepad controls remain to be reviewed.
- Confirm successful damage with visible impact feedback and a hit sound, even
  when the enemy survives. Healing has its own short indicator on the player
  and sound, distinct from taking damage or damaging an enemy.
- Exact in-game positions, pixel sizes, and any future capacity-to-width mapping
  still need visual review.

The selected source pack is
`D:\GodotProjects\blocky3dassets\gui\cyberpunk gui`. Promote the chosen production
art into `assets/art` when implementing the HUD.

## Accepted first-playtest baseline

These are accepted starting numbers for testing, not final balance:

| Setting | Starting value | Result |
| --- | --- | --- |
| Player starting maximum HP | 100 | Compact initial HUD with future capacity growth supported. |
| Ordinary enemy attack damage to player | 25 | 100, 75, 50, 25, then 0 HP: fourth hit kills without healing. |
| Bat patrol maximum HP | 50 | Two knife hits at 25 damage each. |
| Skater maximum HP | 50 | Two knife hits at 25 damage each. |
| Bat patrol and skater attack damage | 25 each | Behavior and timing distinguish the two enemies, with equal damage for the first pass. |
| Player knife damage | 25 | Matches both accepted two-hit targets. |
| Player stomp damage | 50 | One stomp defeats either enemy from full health. |
| Basic healing item | 25 HP restored instantly | Manual use; offsets one ordinary hit. Brief player indicator/sound and attack lockout, with all movement retained. |
| Starting consumable supplies | 0 items | Acquire supplies during play; no starting healing items. |
| Healing-item carrying capacity | No cap for the first pass | Carry as many as are found or, if crafting is added, crafted. Quick-use slot count does not limit inventory quantity. |

Start with one stomp: getting above an enemy requires positioning, and a single
bounce preserves traversal momentum. A two-stomp alternative remains available
if testing warrants it. Preserve a successful stomp's bounce when the target
survives; health changes must not recreate standing on enemies.

Do not infer player-handgun, special enemy attack, gunner HP, or boss values from
these examples. The 25-damage baseline covers ordinary attacks; classify special
attacks explicitly when their behavior is designed.
The starting enemy HP scale can change while preserving the intended hit counts.

## Difficulty and weapon-role proposal

The accepted difficulty direction is hard, fair platforming and combat, with
quick retries. Avoid tedious repetition and a Soulslike recovery loop. The
first health pass should be tuned around
player mistakes, encounter duration, and recovery opportunities together.
Choosing an HP total alone does not establish the game's difficulty.

The accepted starting survivability is three ordinary hits survived and death
on the fourth, from full health without healing. Keep that target separate from
the instantly lethal traversal hazards.

The following weapon roles and encounter pacing are proposed for review:

- Opening-world combat allows several recoverable mistakes while the existing
  lethal traversal hazards retain their rules. Ordinary fights resolve quickly;
  later difficulty can come from enemy behavior, placement, and combinations.
- Knife: 25 damage rewards approaching an enemy and committing to close combat.
- Stomp: 50 damage rewards positioning above a valid target and preserves flow.
- First handgun: choose damage through hands-on testing; no numerical value is
  agreed. Its benefit is reach and the ability to fire while moving; compare
  actual encounter results as well as damage per hit. The existing
  0.28-second shot interval and 0.34-second knife animation are relevant to that
  comparison, but neither alone measures practical damage output.
- First boss: aim initially for three to four well-used vulnerability windows.
  Derive HP from the attacks that can actually land during those windows once
  the pattern exists. Melee must remain viable, and access to the handgun must
  not allow the player to ignore the pattern. Stomp vulnerability is part of
  the boss's readable design, not an assumed universal weakness.

Stronger attacks can have different damage values once their telegraphs and
recovery opportunities are known. Player and enemy guns need not share damage
just because both use bullets. Avoid unexplained weapon damage changes between
ordinary enemies and bosses; derive boss durability from the actual opportunities
to land the same attacks. Any resistance or immunity needs a readable reason.

Health restoration and autosave-point spacing also determine cumulative
difficulty. Placement remains manually authored; recovery follows the separate
rules below.

## Damage response and impact feedback

Start testing without a general invulnerability window after player damage.
Fairness should first come from readable attacks, a real enemy recovery period,
and the player's movement options. Enemies must not hit and immediately restart
an attack. This is a testing direction, not a claim that all multi-enemy setups
will already be fair without protection.

Ground enemies now stop during their 0.65-second attack recovery, including
recovery from an interrupted swing. The bat starts its windup within its
1.25-unit damage reach; the skater retains its rolling approach. Facing stays
committed through the attack and recovery, so walking against their solid body
does not make them patrol into the player and reverse between swings. After
recovery they turn to follow a player who jumped past, and start a fresh windup
when back within reach. Damage and windup timing are unchanged.

Bats and skaters notice a player within 4 units horizontally and 3.5 vertically
when there is a safe ground route; a nonlethal hit also gets their attention.
Once engaged they pursue at their normal patrol speed, regardless of which way
the player faces. Ledges, active hazards, walls, authored patrol limits, or the
enemy's entire sprite leaving the camera end pursuit. They walk back toward
their original patrol position and resume patrolling; this neither teleports
them nor restores HP. A player returning to a reachable nearby position can
engage them again. They do not jump gaps or navigate around obstacles.
Active pursuit also blocks manual saving beyond the nearby-enemy safety radius.

`tools/validate_ground_enemy_engagement.gd` covers both directions, held player
contact, recovery, crossing behind, and interruptions.
`tools/validate_ground_enemy_pursuit.gd` covers real jump-overs, catching a player
who stops, terrain/hazard limits, partial/full camera visibility, and preserved
HP when disengaging.

Each attack can damage a particular target only once. Keep that contact rule
separate from invulnerability: an overlapping hitbox must not subtract HP on
every frame, but independent attacks are not automatically ignored. Test
overlapping enemies and the gunner's paired bullets explicitly. A single enemy's
cooldown does not prevent another enemy from hitting during the player's hurt
response. Decide whether a paired firing beat counts as one damage opportunity
before tuning the gunner; do not hide an unintended double hit in its HP numbers.

Nonlethal hits interrupt attacks on both sides: an enemy hit can interrupt the
player's attack, and the player's hit can interrupt an ordinary enemy's attack.
Cancel pending attack damage when interrupted, and make the next attack use a
readable windup and recovery. Already-fired projectiles remain independent, as
in the existing firearm contract. Exact hurt duration, movement response, any
knockback, and simultaneous-hit ordering still need testing. Check both repeated
knife interruptions and overlapping enemy attacks for unavoidable stun loops.
Boss reactions will be designed with their individual patterns.

Successful hits need clear recognition beyond an enemy eventually dying. Use
the existing impact flash and accepted hit audio as a starting point, add a
readable brief hurt reaction, and update/reveal the enemy HP strip immediately.
Review the combination on nonlethal hits before adding stronger visual effects.
The feedback must follow confirmed damage; misses must not produce a hit cue.
Preserve the saved audio mix while testing this response.

Flyers, spikes, pits, and other traversal hazards remain instant death. Healing,
ordinary combat interrupts, and any later reconsideration of damage protection
must not let the player absorb a traversal-hazard hit with HP.

## Autosave points and recovery

Accepted behavior:

- Replace the player-facing checkpoint concept with an autosave point. Keep the
  existing placement workflow: the level designer can place, move, and size the
  same grounded trigger areas. Activation automatically saves progress and a
  safe continuation location without healing the player.
- Save location, current HP, inventory, and equipped consumables together as a
  coherent gameplay snapshot when these systems are implemented. The point is
  a real persistent save, not just an in-memory respawn marker.
- Provide separate manual save slots alongside autosaves. Autosaving must never
  overwrite or delete a manual save; the player controls which manual slot to
  create or replace and can preserve an earlier recovery point.
- Allow manual saving from the pause menu while the player is alive, safely
  grounded, and out of combat. Capture that current safe position and current
  HP/inventory, rather than copying the previous autosave. Disable saving during
  a jump, fall, death, or active fight; explain why when it is unavailable.
- Support quitting and continuing later from a saved game. On death, present
  **Continue from last save**, **Load Save**, and **Quit**, instead of immediately
  forcing a reload. Continue uses the most recently written valid save, whether
  manual or automatic; Load Save allows choosing an earlier manual or autosave.
- Loading after death or through Continue restores the selected save's exact HP
  and consumable quantities. There is no separate full-health or percentage-based
  death refill.
  Consumables spent after that save return on retry; supplies spent before
  it remain spent. For example, a snapshot at 75 HP with one healing item always
  resumes at 75 HP with one item.
- Continue from an autosave retains later permanent abilities, weapons,
  maximum-health upgrades and completed bosses through ordinary retries.
- A manual save restores all progression to its snapshot, including via Continue.
  Explicit Load also restores the selected snapshot. Unlocks earned before the
  save remain; those earned later roll back. HP/items always return to saved values.
- Reset ordinary enemies on death. An undefeated boss returns to full health
  for a new attempt; a permanently completed boss stays completed.
- Add healing pickups as carried consumables with manual use, separate from
  autosaves. Picking one up does not immediately heal. Start with no supplies
  and no healing-item carry cap for this pass.

Existing marker locations and authored layout IDs must survive the change.
Internal checkpoint IDs/classes can remain for compatibility; the designer's
display names and gameplay messaging should say Autosave point/Autosave once
persistent snapshot saving is wired. Keep the stable grounded activation rule.
Development labs and designer test runs must not overwrite campaign saves.

Quitting must not silently replace any save's HP and consumable quantities with
a later mid-section state. Keep pickup collection state consistent with the saved
inventory: pickups collected after the save become available again on retry,
while an already-saved pickup
must not duplicate itself. Independently retained permanent upgrades and boss
completion must also prevent duplicate rewards when replaying a section.

The save list should identify manual versus automatic saves and show location,
time saved, HP/maximum HP, and carried healing supplies. Continue should identify
the save it will load. Keep the death menu quick to use, with Continue selected
by default and no automatic countdown that prevents choosing a backup.

Recommended extra protection, pending agreement: rotate a small number of
autosave slots so one low-health activation does not erase every recent
automatic recovery point. Manual saves remain separate regardless of that
choice. Exact slot counts and save-list presentation remain to be reviewed.

The implemented safety checks, migration, three-slot prototype for each save
type, backup behavior and developer isolation are described in
[SAVE_SYSTEM.md](SAVE_SYSTEM.md). Slot count remains a prototype choice.
The designer now calls the existing placeable marker an Autosave point.

## Inventory, healing progression, and quick access

Healing pickups become carried consumables; the player chooses when to use
them. Begin testing with a 25-HP basic item, no starting supplies, and no carrying
cap. The player can keep as many healing items as they find or eventually craft.
The earlier two-item capacity proposal is superseded. Supply availability and
use timing, rather than an initial storage limit, are the first balancing tools.

Healing takes effect immediately, consumes one item on successful use, and plays
a short indicator on the player plus a sound. Walking, jumping, wall movement,
and dashing remain available throughout. Attacking is briefly unavailable for
the duration of that short feedback beat, then resumes. There is no stationary
healing animation or delayed heal that damage can interrupt before it takes
effect. Prototype behavior: 0.25-second feedback/attack lock, cancel an active
attack, reject repeated use during the feedback and leave items unspent at full
HP. These details and the digital healing cue still need user playtest review.

The player will have an inventory, and better healing items become available
as the game progresses. Support multiple item types from the start, even if the
first playable pass introduces only the basic item. More than one healing-item
type should be readily accessible through an always-visible quick-use bar.

Quick-use direction:

- The inventory owns each item type and its quantity. Quick slots reference
  those stacks; equipping the same item must not create a second supply.
- Show the assigned items on screen and let their inputs provide immediate
  access during play. Do not require opening a separate quick-selection menu.
- Use the user-selected two-slot prototype on Q and E. Tab opens the paused
  inventory; select an owned item, then use Q/E or the assignment buttons.
  R reloads the handgun. Developer restart is in the F1 tools.
- Quick-use slots limit readily accessible item types, not owned quantities.
  Q/E are direct-use inputs. Gamepad mapping and visual presentation remain
  subject to review.

The quick-use bar does not introduce a menu pause or slow-motion mode. The full
Tab inventory pauses play and shows carried stacks with two assignment slots.
Its layout awaits visual review; the empty grid cells do not impose an item
capacity or stack limit. Supplies restore from the
selected save on reload. Implement pickup, chest, and drop state alongside
inventory restoration so retries neither require repetitive resource farming
nor duplicate inventory on reload.

The selected icons define three healing tiers: medicine packet 25 HP, open
medical kit 50 HP, and medical bag 75 HP. The latter two are available in the
lab inventory, with campaign availability to follow progression later. Consider
availability, typical stockpiles, and use timing together. These heals coexist
so the player can choose how much to spend on a missing-health gap.
Test accumulated supplies over a level
as well as short encounters before revisiting any capacity rule.

Status-effect consumables are a possible extension of the same inventory and
quick-access system. Regeneration, protection, or temporary attack effects are
examples to review, not selected effects. Their durations, stacking, and effect
on lethal hazards must be explicitly designed; traversal hazards, including
flyers, stay lethal unless that decision is changed.

## Supplies, drops, and chests

Start the player with no consumable supplies. Enemy drops of healing items and
ammunition are a direction to explore, alongside chests that give items, so the
levels do not need to be cluttered with individual pickups. Supply chests now
use level-based weighted pools with quantity ranges, a possible second item
type, weapon-gated ammo and repeatable save/load outcomes. They are placeable
in the designer with pool/fixed overrides. Three movable campaign examples
start this pass; [chest loot](CHEST_LOOT.md) owns their tuning and locations.
General enemy drop chances remain open.

Prefer judging supply availability over whole sections and save intervals.
With no initial carry cap, reward amounts and drop rates directly affect how
much healing can accumulate. Avoid requiring repeated enemy farming to recover
from a bad attempt. Save opened chests and collected reward state consistently
with inventory; reloading must not retain a reward while also restoring its
uncollected source.

## Accepted ammunition and pickup presentation direction

Loaded/reserve ammunition, reloading, inventory ammo, configurable rewards and
exact save restoration are implemented. Ordinary reward icons now pop above the
player in sequence; the separate weapon-unlock presentation remains future work.

- Use concept A: an unframed gun icon and numerical loaded/reserve count in
  the bottom-left. A compact active-reload timing bar appears above the player
  while reloading, with a moving marker and highlighted success zone. Do not add
  "loaded" or "reserve" labels. Hide the entire weapon HUD when using the knife.
  A 12-round magazine is the provisional first-playtest capacity.
- R reloads from the reserve pool, topping up the gun without discarding
  remaining rounds or introducing individual magazine items. Move developer
  restart into the F1 tools. Duration and interruption rules remain provisional.
- The Firearm Lab chest gives one basic medicine and 30 handgun rounds.
  The first Level 3 handgun pickup also grants 30 rounds. Author reward amounts
  per source rather than making 30 the universal ammunition reward.
- Ordinary rewards show their icon and +quantity above the player in sequence,
  with a brief upward movement and fade while gameplay continues. The current
  prototype runs at 1.15x speed: rewards appear about 0.57 seconds apart, and each
  pops in, rises and fades over about 1.09 seconds. The original motion and fade
  proportions are preserved. It follows the player and replaces the old receipt.
  Inventory changes immediately; the animation only reports the granted items.
  Inventory/pause freezes the sequence, and death/reset/scene changes clear it.
- A newly acquired weapon gets a separate paused unlock panel showing the
  weapon, its unlock title, ammunition received, and relevant controls.
- Save and restore ammunition together with inventory and reward claims.

The local character packs and both gun packs have no dedicated reload sprite
sequence. The extra-animation pack's Use.png is a reaching gesture, not a
reload. The user approved trying a simple custom gesture that can finish before
the full reload; the bar and sound carry the remaining timing.

Reloading has a 0.4-second gun/arm pull-in,
downward tilt and return, with a 1.5-second reload bar and the catalog's
Reloading_weapons.wav at -12 dB. These are review values, not settled balance
or accepted sound tuning. Movement continues; firing waits for the bar.
Switching to the knife, taking damage, healing, death or reset cancels the
reload without spending reserve rounds. Inventory/pause suspends its timer and
sound. F1 exposes developer restart controls.

The active-reload prototype allows one second R press per reload. Each reload
randomly places a 0.2-second success window, starting between 0.4 and 1.0 seconds.
The target stays fixed for that reload; the HUD and input check use the same
sampled window. Pressing inside it completes the reload immediately, transfers the
normal amount of reserve ammunition, stops the reload sound and briefly flashes
the overhead bar green. An early or late attempt uses that attempt and leaves
the original 1.5-second completion time unchanged; repeated presses cannot retry
or restart it. Skipping the attempt also gives the ordinary reload. There is no
damage bonus or jam penalty. The bar follows movement and jumps, and disappears
when reloading ends (after a 0.22-second flash on success). The time window is
authored as earliest/latest start and window width beside reload duration in
FirearmDefinition. These are playtest values.

The concept A HUD now reads actual loaded/reserve state in all levels and hides
when the knife is equipped. Each successful shot spends one loaded round.
Reload completion transfers only the amount needed, limited by available reserve;
an empty gun can reload, a full magazine cannot, and cancellation spends nothing.
The lab starts at 12 / 30. The first Level 3 pickup grants 30 total rounds
(12 loaded, 18 reserve), with its amount editable on the pickup. A chest's
additional_items dictionary supports independently authored ammo quantities.
Reserve ammo uses the catalog's Icon1_02.png cartridge art and appears in the
inventory without Q/E assignment. Snapshots preserve both magazine and inventory
reserve; old unlimited-gun saves migrate with one 30-round starting supply.
The aiming reticle remains available. The ordinary 1.5-second duration remains
provisional while testing active reload; it can still be shortened independently.

## Possible later crafting and available art

Later, bought ingredients might be crafted into the same healing item. Shops,
prices, recipes, and crafting are exploratory extensions, not part of the first
health implementation. The owned art supports exploring this direction:

- `D:\GodotProjects\blocky3dassets\gui\cyberpunk gui\1 Frames\Interface windows.png`
  shows inventory slots and recipe-style input/output panels.
- `D:\GodotProjects\blocky3dassets\icons\radioactive_icons\1 Icons\Iconset10.png`
  contains medical-looking supplies among protective equipment and containers.
- `D:\GodotProjects\blocky3dassets\icons\resource_icons\1 Icons\Iconset1.png`
  contains resource/container icons that could support ingredients later.

These are art candidates, not selected pickup assets or finished UI. Choose a
clear healing silhouette and review it at gameplay scale before promotion.

## Where the numbers will live

Use shared Godot resources for authored health and attack values, editable in
the Inspector. The existing player handgun resource is a starting point:
`resources/weapons/first_handgun.tres`. Give enemy types their own health and
attack settings; placed instances use those shared defaults. Keep current HP
on each runtime character, never on a shared resource.

Likewise, shared item definitions can hold an item's ID, name, icon, healing
amount, and any later effect rules. Owned quantities and equipped quick-slot
references belong to the player's runtime/save inventory. Found and crafted
copies should use the same definition and behavior.

Generate the implemented numeric tables and matchup report from those resources
once the system exists. Avoid a second manually maintained copy of live values
in this document. Keep accepted design targets, rationale, and unresolved
choices here. Resource wiring and report generation are not implemented yet.

The report should show maximum HP, damage per successful attack, attack cadence,
and hits required from full health for knife, stomp, and handgun. Include player
survivability against each enemy attack, and distinguish immunity from high HP.

## First implementation and review

Resolve these first-pass decisions before treating the design as complete:

| Decision | What remains open |
| --- | --- |
| Save integration | Implemented safe-ground checks, protected manual slots, rotating autosaves, exact HP/items, stable reward claims and recovery menus. Older manual saves roll back all progression. Review the three-slot prototype and menu presentation. |
| Repeated hits and hurt response | Test without general damage invulnerability, with interruptions on both sides and clear impact feedback. Tune enemy recovery, hurt duration/knockback, simultaneous hits, and paired-bullet damage grouping; test overlapping enemies and stun loops. Traversal hazards stay lethal. |
| Healing use | Instant healing with full movement, a short player indicator/sound, and attacks briefly locked for that feedback duration are settled. Choose duration, behavior during an active attack, repeated-use cadence, full-HP behavior, and the actual visual/audio assets. |
| Inventory and quick use | Two user-selected direct-use slots on Q/E, with no healing carry cap and a paused Tab inventory for assignment. Review the asset-based layout and gamepad mapping. |
| Remaining combat values | Feel out player handgun damage in play; define gunner HP and bullet damage. Flyer contact is settled as instant death, not an ordinary numerical attack. |
| Supply availability | No starting consumable supplies. Explore healing/ammo drops and chest rewards; decide quantities, chances, and persistence. Retry restores the saved supply. Review accumulated healing without adding an unrequested carry cap. |

Boss numbers, stronger healing availability, status effects, shops, and crafting can be
designed after the basic combat and recovery loop has been tested.

Current provisional values: handgun 25 damage, gunner 50 HP/25 damage, paired
bullets from one beat share one damage application per target, hurt attack lock
0.18 seconds, medicine feedback/attack lock 0.25 seconds. The 50-HP medical kit
now enters the Level 2 pool; the 75-HP medical bag is available through explicit
chest overrides and the lab. These are implementation test values,
not accepted final balance.
`tools/report_combat_balance.gd` generates the current matchup report from the
resources; run it through the standard runner.

1. Use the accepted health/damage and save baseline. Define the remaining hurt,
   healing-feedback, and save details; begin without general damage invulnerability
   and review attack recovery and overlapping threats.
2. Add health and damage using the shared settings; preserve lethal hazards,
   indestructible lethal flyers, solid nonlethal ground-enemy bodies, and existing
   contact detection. Keep movement and level geometry unchanged by this work.
3. Add the accepted displays, basic carried healing item, and inventory/quick-use
   foundation that supports multiple consumable types. Verify nonlethal hits and
   interruptions, defeat, instant healing with movement and brief attack lockout,
   item counts/reward persistence, save/continue, loading an earlier manual backup,
   autosave isolation from manual slots, the death menu, and bar visibility with
   focused checks and live MCP playtests in the Firearm Lab.
4. Test the resulting pacing in the authored levels. Tune against the matchup
   targets, then define the gunner and boss values as their encounters develop.

See [game direction](GAME_DIRECTION.md) for the combat role and
[level roadmap](LEVEL_ROADMAP.md#next-health-and-damage) for campaign sequencing.
