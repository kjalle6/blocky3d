# Health, inventory, and saves: implementation status

The core implementation is complete. Combat health, healing, inventory, save
slots, recovery menus, and campaign supply chests are integrated. Remaining work
centers on balance and presentation in the authored levels.

## Implemented

| Area | Current behavior | Reference |
| --- | --- | --- |
| Combat health | Per-actor HP, once-per-attack damage, interruptions, health displays, lethal hazards | [Combat balance](COMBAT_BALANCE.md) |
| Healing and inventory | Three healing tiers, paused Tab inventory, hover-to-assign Q/E slots, no carry cap | [Inventory and saves](SAVE_SYSTEM.md) |
| Saves | Three manual slots, three rotating autosaves, validated snapshots, migration and backup recovery | [Save system](SAVE_SYSTEM.md#ownership-and-files) |
| Recovery menus | Pause, safe manual saving, load selection, and death recovery | [Controls](SAVE_SYSTEM.md#controls-and-current-behavior) |
| Ammunition | Loaded/reserve counts, reload cancellation, randomized active reload, exact save restoration | [Ammunition](COMBAT_BALANCE.md#ammunition-and-reloading) |
| Rewards | Stable claim IDs, floating pickup icons, level loot pools, designer chest placement and fixed bundles | [Supply chests](CHEST_LOOT.md) |

## State ownership

`HealthState` stores an actor's current HP, while shared combat resources define
starting health and damage. `CombatHit` identifies attacks so one hit cannot be
applied repeatedly to the same target. `PlayerInventory` owns carried quantities
and quick-slot references; `PlayerHandgun3D` owns loaded rounds and reload state.
HUD and menu components read these states rather than storing gameplay values.

`SessionSaveState` captures logical session state. `SaveSnapshot` validates the
payload, and `ProgressionStore` owns disk writes and recovery. Reward claims and
inventory travel together so retries cannot duplicate supplies. Campaign and
development sessions have separate persistence behavior.

## Remaining review

- Compare handgun, knife, and stomp effectiveness in complete encounters.
- Tune gunner durability, attack recovery, hit interruptions, and overlapping
  threats without changing the lethal platforming hazards.
- Review healing feedback, reload timing, and supply accumulation over a level.
- Decide general enemy drops and the progression of stronger healing supplies.
- Add the weapon-unlock showcase and finish the remaining menu presentation.
- Review controller navigation and quick use through hands-on play.
- Build the next Level 3 encounters and derive boss balance from its pattern.

The [level roadmap](LEVEL_ROADMAP.md) tracks that campaign work. Shops, crafting,
status effects, and permanent health upgrades need separate designs when they
become relevant.

## Verification

Focused validators cover health and interruptions, inventory input, ammunition,
reward claims, save migration and corruption, slot rotation, campaign restoration,
and designer chest round trips. The exported-pack probe checks that layouts and
loot data are bundled. Live playtests cover feedback, controls, and pacing.
Use the runner and test-selection guidance in [AGENTS.md](../AGENTS.md).
