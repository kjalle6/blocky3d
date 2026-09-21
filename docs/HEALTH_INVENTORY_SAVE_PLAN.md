# Health, inventory, and saves: implementation plan

Status: first implementation pass is in place. Phases 0–5 have runtime code and
focused checks; visual/audio acceptance and integrated balancing remain open.
Phase 6 has lab-only chest/drop fixtures and collection receipts; production
supplies await review. The compact left HUD and centered HP numbers are accepted.
Tab inventory, Q/E assignment, smaller supply chests, and matching asset-based
menu frames now have a playable visual pass; final presentation awaits review.
Healing icons/tiers are selected: packet 25 HP, open kit 50 HP, medical bag 75 HP.
Phase 7 remains playtesting and tuning. See [current behavior and controls](SAVE_SYSTEM.md).

Verification, 2026-09-21: all 52 validators have passing results. The full suite
passed 50; the two failures were resolved and rerun individually (editable object
counts and the fresh developer destination's assumed ability kit). Focused
health/save checks also passed after the final edge-case fixes. Live MCP review
covered enemy-bar visibility, Q-slot healing and its audio event, inventory,
pause/load/death screens, and a cold application restart restoring 75 HP and
three medicines. Resolved objects and authored values remain identical in all
nine registered sections. User acceptance of feel, sound and presentation is
still pending; no full Level 2 traversal bot was added.
[Combat balance](COMBAT_BALANCE.md) owns design decisions and balance targets;
this document owns implementation order, dependencies, and completion checks.
Update phase status as work lands, without turning either document into a chat log.

## Scope and starting rules

- Player starts at 100 maximum HP. Ordinary bat/skater attacks deal 25 damage:
  survive three separate hits; the fourth kills without healing.
- Bat patrols and skaters start at 50 HP; knife damage is 25 and stomp damage 50.
  Handgun damage will be chosen by playing; gunner values remain open.
- Test without general invulnerability after damage. Hits interrupt attacks on
  both sides; enemy windup and recovery must remain readable. Confirm nonlethal
  hits with visual and audio feedback.
- Traversal hazards remain instant death, including indestructible flyers,
  spikes, and pits. Movement, existing contact fixes, and authored routes stay
  intact.
- Use the accepted compact player bar plus HP numbers, and thin unframed enemy
  strips that appear only after damage. Support higher maximum HP later. Boss
  presentation will use a named wider bar when the boss is implemented.
- Basic healing restores 25 HP instantly, with a brief player indicator and
  sound. Preserve all movement; briefly lock attacks for that feedback duration.
- Start with no consumable supplies and no healing carry cap. Support multiple
  item types and two always-visible quick-use slots on Q and E, chosen for this
  prototype. Slots reference inventory stacks, not a two-item carry limit.
- Placeable autosave points save without healing. Separate manual slots are
  available through pause while safely grounded and out of combat. Autosaves
  never overwrite manual saves. Loading restores the saved HP and consumables
  exactly; quitting does not silently replace that snapshot.
- Death offers Continue from last save, Load Save, and Quit. Continue targets
  the newest valid manual or automatic save and identifies it to the player.
- Ordinary enemies reset on retry. An undefeated boss will restart at full HP;
  completed bosses and permanent upgrades persist through ordinary retries.
  Loading an older manual save restores all progression to that snapshot:
  earlier unlocks remain, later unlocks and completed bosses roll back.
- Explore healing/ammo drops and loot chests after the core loop works. Supply
  rates are not decided. Stronger healing belongs in later progression; crafting,
  shops, status effects, and the boss itself are later work.

## Integration map

The following table records the pre-implementation integration points and the
changes assigned to them. The implemented ownership and behavior are documented
in [SAVE_SYSTEM.md](SAVE_SYSTEM.md); descriptions below are not runtime status.

| Responsibility | Current implementation | Planned change |
| --- | --- | --- |
| Player damage and actions | `scripts/player/player_character.gd` immediately kills on `receive_enemy_hit`; owns knife/stomp resolution and attack cancellation. | Add per-player health, numerical damage, interruption, and a shared attack gate for hurt/healing. Keep movement calculations intact. |
| Enemy damage | `scripts/enemies/stompable_enemy_3d.gd`, `scripts/enemies/handgun_enemy_3d.gd` currently defeat on successful attacks. | Add health and nonlethal hurt/recovery; defeat and rewards happen only at zero HP. |
| Firearms | `scripts/weapons/firearm_definition.gd`, `resources/weapons/first_handgun.tres`, projectile and hurtbox scripts. | Carry authored damage and attack identity through the full projectile path, including friendly fire. |
| Combat feedback | `scripts/presentation/combat_feedback_3d.gd` handles audio, flashes, and short time-scale pauses; enemy flash is currently tied to defeat. | Present ordinary hits separately from defeat; add healing feedback without slowing or stopping movement. |
| HUD | `scripts/ui/weapon_status_hud.gd`, `scenes/ui/weapon_status_hud.tscn`. | Compose health, weapon, and consumable displays; keep presentation separate from owned state. |
| Run lifecycle | `scripts/level/level_session_3d.gd` owns session-local checkpoints/weapons and automatically resets after death. | Capture/restore run state and request the death menu; separate new run, reload, and developer reset. |
| Scene changes and menus | `scripts/app/game_root.gd`, `scenes/app/game_root.tscn`; Escape currently returns to level selection. | Add pause/save/load/death flows and carry full player state across section/level transitions. |
| Disk persistence | `scripts/progression/progression_store.gd` owns `user://campaign_progress.json`; `game_progress.gd` version 1 stores only completed levels and abilities. | Keep one disk owner, add validated save slots and migration without losing existing progress. |
| Placeable save markers | `scripts/level/level_checkpoint_3d.gd` and designer catalog/layout code. | Preserve stable grounded activation and placement; wire persistent saving before renaming the visible object. |
| Chest art and behavior | `scenes/level/pixel_chest_goal.tscn` uses `PixelGoal3D` and completes a level. | Reuse suitable art for a separate loot-chest actor; do not change existing goal behavior. |

## Implementation sequence

### Phase 0: preserve content and define state ownership

Deliverables:

- Inspect current Git changes and resolved layouts before editing structural
  dependencies. Preserve the user-authored Level 1 enemy, Level 2 spikes, Level 3
  save marker, all layout JSON/recovery drafts, and the saved audio mix.
- Introduce a small shared health component/state with current HP, maximum HP,
  damage/heal operations, and health-change/death signals. Authored settings are
  Godot resources; runtime HP is never stored on those shared resources.
- Define damage context: amount, source, attack kind, and a stable identity for
  one attack. Return whether damage was accepted so feedback/rewards do not
  infer a hit merely from overlap. Hazards retain a separate lethal path.
- Define a player run-state model for HP/max HP, weapon ownership/selection,
  abilities, inventory, and quick-slot assignments. Decide its owner before
  adding scene-local copies; it must survive ordinary scene handoffs.
- Define item IDs and reward-source IDs, plus the save snapshot fields needed
  below. Separate new-game initialization, scene transfer, reload, and lab reset.
- Add shared tuning resources for player, bat, skater, knife, and stomp. Keep
  unapproved gun values visibly provisional in lab fixtures until reviewed.

Completion check: two actors using the same authored resource have independent
HP; damage/healing signals fire once; state can round-trip without touching disk.
No gameplay geometry, audio selection, or user layout has been lost.

### Phase 1: numerical combat and interruptions

Depends on Phase 0.

- Replace immediate defeat on ordinary damage with health reduction on the
  player, bat, skater, and existing gunner. Thread damage through firearm
  definition, projectile, hurtbox, and receiving actor; retain friendly fire.
- Preserve one hit per target per knife animation and one damage application
  per enemy attack. Preserve stomp bounce even if a target survives; the recent
  solid-body-top fix must still prevent standing on an enemy.
- Interrupt pending attacks when the actor takes a nonlethal hit. Cancel future
  damage/spawns from that attack, then enter a readable recovery before a fresh
  windup. Already-fired bullets remain live until normal impact/expiry/reset.
- Add no global invulnerability timer in this first pass. Keep hurt duration and
  enemy recovery independently tunable. Decide paired-bullet damage grouping
  before accepting gunner survivability results.
- Clear hurt/attack state and delayed callbacks on reload, death, or transition.
  Do not let weapon switching or buffered input bypass attack locks.

Completion check: player HP follows 100/75/50/25/0; bat/skater die to two knife
hits or one stomp. Rejected/repeated overlap produces no extra damage. Interrupted
attacks cannot land late. Test overlapping attackers, paired shots, interrupted
gunners, friendly fire, and surviving-stomp fixtures. All hazards still kill at
full or upgraded HP.

### Phase 2: health HUD and readable hit feedback

Depends on Phase 1. This is the first visual combat review.

- Promote only the chosen Cyberpunk GUI bar pieces and matching pixel font into
  production art. Use the accepted compact bar with current/maximum numbers;
  fill uses the real maximum, and ordinary damage never changes bar width.
- Expose a configurable capacity/width presentation for future HP upgrades;
  do not invent an upgrade economy or a fixed pixels-per-HP rule yet.
- Add the thin enemy strip, hidden initially and revealed by accepted damage.
  Hide on reset and avoid an empty-bar flash for an immediately lethal first hit.
- Trigger existing impact flash/audio on confirmed nonlethal hits as well as
  appropriate defeat feedback. Keep death, hurt, and healing visually distinct;
  avoid duplicated audio or time-scale effects on one event.
- Bind and unbind HUD listeners on scene changes. Keep HUD/crosshair behavior
  correct while paused, dead, transitioning, or using developer tools.

Completion check: review captures and live combat in the Firearm Lab at the
1920x1080 baseline, including damaged enemies, reset, and a test maximum above
100. User review owns readability and feel; validator success is not approval.

### Phase 3: inventory, instant healing, and quick-use HUD

Depends on Phases 0-2. Resolve the quick-slot and healing-use decisions below
before committing the final controls.

- Add item definitions with stable ID, display name, icon, and healing amount.
  Implement inventory quantities and quick-slot references as player state.
  A shared item in two slots still has one supply; do not impose a carry cap.
- Create the basic 25-HP item; keep fresh-game inventory empty. Add explicit
  developer supply controls for testing, isolated from campaign state.
- Apply healing and consumption together on successful use. Show a short player
  effect and play the selected healing sound; use a short authored feedback
  duration for the attack lock, not a long audio tail or global time-scale pause.
- Keep running, jumping, wall sliding/jumping, and dashing available throughout.
  Resolve active attacks, repeated presses, full HP, empty slots, and dead-player
  use according to the selected rules. Healing cannot reverse a lethal hazard.
- Build the always-visible quick-use bar and a minimal inventory view for
  inspecting supplies and assigning item types. Reuse the owned UI art and
  review the layout with the existing weapon display. Resolve the current R
  restart conflict if R becomes an item key; support gamepad access too.
- Use a second item definition in a development fixture to verify multiple
  types and quick assignments without declaring a stronger production heal yet.

Completion check: quantities never duplicate or go negative; a stack larger than
two is retained; basic healing restores 25 up to the maximum. Movement remains
normal during use, and both knife and gun respect the brief attack lock. Review
the indicator, sound, HUD, and input feel live.

### Phase 4: persistent snapshots and safe restoration

Depends on the state model and Phase 3 inventory. Settle older-save progression
policy before writing production migration/merge behavior.

- Extend the existing persistence owner with separate manual and autosave slots,
  stable slot IDs, schema versioning, validated metadata, and an index that can
  be rebuilt from valid slot files. Inventory/HUD/actors do not write files.
- Store campaign/level ID plus section ID, safe position/facing, save-point ID
  where applicable, current/max HP, owned/equipped weapons, abilities, inventory,
  quick slots, progression flags, and collected/opened reward state. Later ammo
  becomes owned state when its rules exist. Never serialize live node references.
- Capture logical encounter/intro/gate completion where needed so loading a safe
  point does not rerun a completed cutscene or reopen a one-way handoff. Serialize
  those explicit states rather than trying to save the entire live scene tree.
- Resolve level/section IDs through the project's known scene catalog. A level
  ID alone cannot distinguish the Level 2 approach from its cave interior.
- Preserve version-1 completed levels/abilities during migration and keep the
  original file recoverable. Legacy saves have no HP/location/items to restore;
  use an explicit migration policy rather than pretending those values existed.
  Reject unsupported/corrupt data without silently writing an empty replacement.
- Write to a temporary file, validate/close it, then replace the selected slot
  safely. Failed or interrupted writes retain the prior valid save. Update the
  newest-save index only after success; autosave writes cannot target manual slots.
- Restore in a controlled order: validate data and destination; build/apply the
  saved layout; reset ordinary actors/projectiles; reconcile permanent and reward
  state; apply player state/position; bind HUD/camera; then release gameplay.
  Do not apply fresh-run defaults after restoration or resave merely because a
  save was loaded.
- Carry live HP/items/loadout through ordinary scene transitions without healing
  or clearing supplies. Persistent saving still follows explicit save triggers.
- Validate manual-save safety against the reconstructed world, not just current
  floor contact: reset enemies, moving supports, hazards, and scripted handoffs
  must not make the restored position unsafe. Never silently heal to fix a save.
- Keep labs, developer fresh runs, previews, and designer tests isolated from
  campaign saves. Use a separate test namespace for persistent QA.

Completion check: save at 75 HP with one heal, change both, die/reload, and obtain
exactly 75 HP/one heal. Repeat after fully closing/relaunching the game. Verify
manual-slot protection, multiple slots, interrupted writes, invalid data,
migration, section identity, scene transfers, and no duplicate saved rewards.

### Phase 5: autosave points, pause/load UI, and death menu

Depends on Phase 4. Ship the usable recovery loop together.

- Wire stable grounded marker activation to persistent autosaving. Preserve
  existing authored and designer-added placements/IDs and their ordering behavior.
  Keep internal checkpoint identifiers where compatibility requires them; change
  visible wording to Autosave point only when saving actually works.
- Define reactivation after reload/backtracking and suppress per-frame saves.
  Loading on a trigger must not immediately overwrite another snapshot. Display
  completion only after a successful write and report failure without discarding
  earlier saves.
- Add a pause menu with Resume, Save, Load, and Quit access. Manual saving checks
  the pre-pause gameplay state: pausing does not turn an active fight into a safe
  moment. Disable Save with a clear reason when the player is unsafe.
- Add a shared slot browser with type, location, timestamp, HP/max HP, and healing
  supplies. Make manual overwrite an explicit player choice. Handle empty,
  incompatible, and unreadable slots without selecting them as Continue targets.
- Replace campaign auto-reset after death with Continue from last save, Load
  Save, and Quit. Preserve the brief death presentation, cancel the old delayed
  reset, and allow immediate navigation once the menu is shown. Keep Continue
  focused and identify its target. No menu countdown forces a reload.
- Make Continue/Load available after restarting the application. Define the
  initial new-game save and legacy/no-save fallback before enabling this flow.
- Coordinate pause ownership, cursor/crosshair, UI focus, gameplay input, audio,
  and outstanding feedback timers. Keep developer lab reset useful without
  invoking campaign save menus or writing campaign data.

Completion check: a low-HP autosave cannot erase a healthy manual backup; dying
allows choosing either, or quitting without changing either. Test keyboard,
mouse, and gamepad navigation, pause during healing/hurt, no-save startup,
save failure, trigger reentry, and exact restoration after a cold launch.

### Phase 6: healing rewards, loot chests, and later supply progression

Depends on Phases 3-5. Confirm reward behavior before placing production rewards.

- Build a reusable item reward/pickup path and a separate loot-chest actor using
  suitable owned chest art. Existing chest goals keep completing levels. Register
  approved reward objects in the designer so placement remains user-controlled.
- Prototype healing drops from enemy defeat and healing chest contents in the
  lab. Rewards happen once on defeat/opening, never on every nonlethal hit.
  Confirm drop chance/quantity, collection interaction, and chest contents before
  adding them to authored levels; avoid cluttering traversal space.
- Persist stable reward IDs, opened chests, and claimed rewards. Define unclaimed
  drops at save time and rewards from enemies that respawn on reload. If random
  rewards are used, handle their saved outcomes consistently rather than allowing
  an accidental reward reroll/duplication through loading.
- Use the same item definitions for later stronger healing tiers. Design their
  amounts and introduction points from actual stockpiles and encounter pacing.
- Treat ammo drops as the next supply extension: first choose ammo ownership,
  consumption, gun-acquisition supply, HUD, and reload/save behavior. Do not add
  empty ammo pickups before ammunition has a use, or make progression require
  a gun when a saved player can have no ammunition.

Completion check: collect/open, save, reload, and verify both inventory and the
reward source agree. Reloading before collection restores the earlier state.
Ordinary enemy reset does not duplicate an already-banked reward. Existing goal
chests and the first guaranteed handgun drop still behave correctly.

### Phase 7: integrated balancing and campaign review

Depends on the completed core phases and whichever reward extensions are ready.

- Generate a balance report from authored resources: HP, damage, attack cadence,
  hits to defeat, player survivability, and immunity. Keep a single source for
  implemented numbers instead of manually copying them into multiple documents.
- Use Firearm Lab tuning to choose handgun damage, gunner durability/damage,
  paired-shot treatment, hurt/recovery timing, and healing feedback duration.
  Compare knife risk, stomp positioning, and gun reach in actual encounters.
- Play the authored early levels with no starting supplies and the agreed reward
  setup. Review overlapping attackers, repeated interruptions, low-HP saves,
  healthy manual backups, and how unlimited healing accumulates across a section.
- Preserve lethal platforming, accepted wall-jump geometry, movement, and authored
  encounters. Any route/encounter redesign is a separate review, not a side effect
  of tuning health. Full Level 2 traversal remains a hands-on playtest.
- Close the first pass with a useful save/load loop, clear combat feedback,
  reviewed HUD/healing controls, and documented provisional versus accepted values.
  Only then expand gun enemies and design the boss's pattern, HP, and named bar.

## Decisions to settle at the relevant phase

These do not block independent health/contact work. Suggestions here are not
new accepted rules.

| Decision | Needed by | Treatment in the plan |
| --- | --- | --- |
| Hurt duration, knockback, simultaneous attacks, paired gun bullets | Phase 1 gunner review | Tune in the lab; no general invulnerability in the starting test. Keep distinct attacks distinct and reject repeated processing of one hit. |
| Healing during an active attack, full HP, repeated-use cadence | Phase 3 | Recommend no consumption at full HP. Agree how healing cancels or waits for an existing attack and how rapid item presses behave; keep movement available. |
| Quick-use slots and controls | Phase 3 | Settled for the prototype: two direct-use slots on Q/E. Gamepad mapping and final presentation still need review. |
| Loading an older manual save versus permanent progress earned later | Phase 4 | Settled: restore all progression to the saved snapshot, including maximum HP, weapons, abilities and completed bosses. Keep unlocks earned before it, remove those earned after it. |
| Manual slot count and rotating autosaves | Phases 4-5 | Separate protected manual slots are settled. Recommend several rotating autosaves; count/rotation are still open. |
| New game, migrated saves, and autosave reactivation | Phases 4-5 | Recommend an initial safe-entry snapshot at 100 HP with no consumables for a fresh game. Define legacy continuation and trigger reentry without inventing old HP/item history. |
| Quit destination and production restart control | Phase 5 | Decide main menu versus closing the application for Quit, and how R behaves outside developer tests. Neither action silently saves over a snapshot. |
| Rewards and ammunition | Phase 6 | Decide fixed versus random rewards, quantities, collection behavior, and ammo rules before campaign placement. No free starting healing supply. |

## Validation and preservation workflow

Use [AGENTS.md](../AGENTS.md) and [Godot MCP](GODOT_MCP.md) throughout:

- Before structural script/scene/catalog edits, run the layout inspector and
  read its resolved report. Several enemy/checkpoint scripts participate in
  layout fingerprints. Review compatibility changes explicitly; never discard
  layouts or blindly rewrite fingerprints to silence a failure.
- Extend focused behavioral checks for health, attack interruption, healing,
  snapshot restoration, migration, and slot isolation. Update older one-hit
  assertions deliberately while retaining contact, movement, and audio coverage.
- Run focused validators through the supervised standard Godot runner. Use
  `run_validation_suite.ps1` for a broad pass when the integrated changes reach
  progression, transitions, designer behavior, and combat. Do not manually loop
  the entire validator set or repeat a successful suite for reassurance.
- Use MCP for ordinary editor inspection and live tests, starting with
  `game_start(scene_path="main")`. Check runtime logs after testing/disconnects.
  Reuse the editor; do not close it merely to run an unrelated focused validator.
- Exercise production saving in an isolated test profile as well as lab gameplay;
  lab-only tests cannot prove campaign persistence. Preserve the user's normal
  saves and unsaved editor work.
- Inspect rendered HUD and hear actual healing feedback with the user. These
  require live review in addition to automated contracts. Do not restore the
  retired scripted full-Level-2 traversal bot.

Commands for the implementation phases, not required for this documentation:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/inspect_level_layout.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_ground_combat_contacts.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_validation_suite.ps1
```

The existing contact, melee/combat audio, handgun/drop, progression, developer,
layout, movement, and transition checks remain relevant. Add only focused checks
that protect actual new behavior. Keep permanent player/enemy state, authored
tuning, and UI responsibility separate so later bosses and healing tiers can use
the same implemented foundations.
