# Health, inventory and saved games

Use **New campaign** on the title screen to start the persistent game. **Continue**
loads the newest valid manual or automatic snapshot; **Load save** lists individual
slots. The existing development level selector and labs still start fresh and do
not write campaign snapshots. A campaign can continue into the existing Level 3
WIP without promoting that level into the production selector.

## Controls and current behavior

- Health and the two Q/E item readouts sit in a compact group at the top left.
  Width scales with maximum HP (110 HP is 10% wider than 100); height and text
  size stay fixed, with the HP numbers centered inside the whole bar.
  They are passive displays: use Q/E to heal and the Tab inventory to assign
  items. Developer tools expand with F1 on the right; the startup audio audition
  text stays hidden until an audition control is used.
- In the Firearm Review Lab, F1 opens **Health Bar Preview**: choose 100, 110,
  120, 150, 200, or 300 maximum HP, then Full, Half, or Low (25%) health.
  Size changes refill lab health; F1's Reset lab refills it while retaining the selected
  maximum. Leaving the lab discards the selection. These controls do not write
  progression or saves.
- R / gamepad Y reloads the handgun from its inventory reserve. The bottom-left
  gun HUD shows actual loaded/reserve rounds and reload progress, and hides for
  the knife. The provisional magazine holds 12 rounds; reload takes 1.5 seconds.
  The lab starts with 12 loaded and 30 reserve; its chest adds one medicine and
  30 reserve rounds. Ammo cannot be assigned to Q/E. Save snapshots and section
  transitions preserve loaded rounds and the reserve stack exactly. Pre-ammo
  saves that already owned the handgun receive 30 total rounds on migration;
  subsequent snapshots record the exact amount. Saves wait for reload to finish.
- Tab opens/closes the inventory over the paused, dimmed game. Hover an item
  and press Q/E, or right-click for Assign to Q/E; no selection click is needed.
  Keyboard/controller focus also selects the target. This changes its quick-slot reference and
  never consumes an item. Escape closes it; if opened through pause, it returns
  to pause. Empty inventories remain usable, and additional item types add
  scrollable rows without a carrying limit. Hover shows the item's healing and
  carried quantity. One grid shows five columns and six rows in a fixed compact
  window; mouse wheel and the grey draggable handle scroll extra rows together.
  The handle is inactive when all carried item types already fit.
  Item and empty-cell backgrounds light up on hover, as do the Close/Sort/X
  controls, scroll control and menu options. Hovering an empty cell clears the
  assignment target, so Q/E cannot accidentally assign the previous item.
  Sort orders the displayed stacks by name, quantity or healing strength and
  preserves the selection, quantities and Q/E references.
- Escape opens the compact vertical **Options** pause menu: Resume, Inventory,
  Save Game, Load Save, Settings, Main Menu and Quit Game. The red X also resumes.
  Settings is a disabled placeholder. Disabled Save Game explains its restriction
  on hover; returning from inventory/load/confirmation keeps the game paused.
  Inventory, pause, save/load, and recovery windows use pieces from the owned
  Cyberpunk GUI pack. Q/E consume directly during play,
  without opening a menu. Gamepad prototype:
  D-pad left/right use those same two slots; Start opens/closes pause. Menu focus
  supports directional navigation and confirm/cancel. Controller feel awaits
  hands-on review.
- Basic medicine restores 25 HP immediately. It does not spend an item at full
  HP. Healing cancels the active attack and locks attacks/repeated use for 0.25
  seconds, while movement remains available. This feedback timing/sound is a
  prototype for review. Both slots can reference one shared stack; there is no
  gameplay carrying cap.
- Healing icons: medicine packet = 25 HP, open medical kit = 50 HP, medical
  bag with a cross = 75 HP. All three are available in the Firearm Lab for
  assignment review; the stronger items' campaign availability remains later
  work. The existing `large_heal_test` ID is preserved for saved-item compatibility.
- Supply chests are now 1.28 m wide and 0.88 m tall, with their trigger sized
  to match. Successful chest, pickup, or drop collection queues floating item
  icons and +quantities above the player. At 1.15x playback speed, entries appear
  about 0.57 seconds apart and pop in, rise and fade over 1.09 seconds each. Inventory updates
  immediately and movement continues. Animation and queue timing pause with the
  inventory; duplicate claims never repeat them. Death, reset and scene changes
  clear the sequence. No separate loot-selection menu is opened.
- Manual Save is available while standing still on static ground, with no active
  attack, hurt/heal feedback, transition or inspection mode. Wait two seconds
  after combat; active ground-enemy pursuit, nearby live enemies, their reset
  positions, projectiles and flyer paths prevent a manual save. Pursuit blocks
  saving even beyond the proximity radius. Pause does not advance this timer.
- The designer's **Autosave point** retains its existing `checkpoint` ID and
  placement geometry. Stable grounded activation saves without healing. Walking
  across a point is allowed. It activates once per loaded section; a point under
  a restored player is already activated, so loading does not immediately save.
  New campaign and section entrances also save once safely grounded and back in
  control. A failed write reports an error rather than retrying every frame.
- There are three manual and three rotating automatic slots in this prototype.
  Manual replacement asks in the game before overwriting. Autosaving cannot
  target a manual slot. Slot counts and final UI presentation remain tunable.
- Campaign death shows Continue, Load Save, Quit to main menu and Quit game.
  No countdown forces a reload. Escape opens pause; R reloads the handgun.
  Developer restart lives in the F1 tools. Quitting never writes a snapshot.

## What loads

All loads restore the selected current HP, inventory quantities, quick assignments,
equipped weapon, section and saved position. Ordinary enemies reset to full health
and projectiles disappear. Scene transitions carry current HP/items/loadout.

An explicitly selected save rolls back all progression to that snapshot. Manual
saves also do this through Continue: unlocks earned before the save are present;
later abilities, weapons, maximum-HP upgrades and completed bosses are absent.
Continue from an autosave preserves later permanent unlocks from the active
profile, matching the ordinary-retry policy, while restoring the saved current HP
and consumables exactly. It does not rewrite the selected snapshot.

Reward claims and logical world flags travel with inventory. Already claimed
rewards cannot be farmed from an ordinary enemy reset. Loading before collecting
a reward restores both the earlier inventory and its unclaimed source. An
unclaimed enemy drop is recreated by defeating the reset enemy again. Supply
chests use reproducible level pools seeded by campaign and stable chest identity;
the seed is preserved with progression. Old saves use a stable fallback.
See [chest loot](CHEST_LOOT.md) for authoring and eligibility.
The completed shooter intro is a logical world flag;
the Level 2 slide is a transition scene, so cave saves do not rerun it.

The Firearm Lab supplies five basic medicines and three 50-HP test medical kits,
a chest at X 6.4 and a basic medicine drop from the shooter. These are review
fixtures; that chest remains fixed at one basic medicine and 30 handgun rounds.
Fresh campaigns start with no consumables. Designer supply chests and three
movable campaign examples now use level pools. The 50-HP kit enters Level 2's
pool; the 75-HP bag is reserved for explicit authoring. General enemy drop rates,
crafting and shops remain open. Existing goal chests still complete levels.

## Ownership and files

`HealthState` owns per-actor HP; `CombatHit` identifies one attack and rejects repeat
damage to the same health state. `resources/combat` and weapon definitions own
tuning. `PlayerInventory` owns quantities and quick references. The HUD only reads
those states. `SessionSaveState` captures/restores logical section state;
`ProgressionStore` is the sole disk owner; `SaveSnapshot` validates external data.

The normal profile contains `user://campaign_progress.json` and
`user://campaign_progress_saves/{manual,auto}_{1,2,3}.json`. These are outside the
project. Standalone validators use the runner's isolated profile and their own
test paths. Slots have schema version 1; permanent progress is now version 2.

Version-1 level/ability progress is read without losing those unlocks. Its exact
original file is retained as `.v1.bak`. When no snapshots exist, Continue resumes
legacy progression at the first unfinished production level's entrance (or the
last available production level), with 100 HP and no consumables: old files did
not contain location, HP or inventory. New campaign preserves manual slots and
archives the old active profile before starting fresh.

Writes use a flushed, closed and validated `.tmp`, rotate the prior file to
`.bak`, then promote the new file. Reads can recover valid backups; corrupt and
unsupported data never silently become an empty replacement. Unknown section,
invalid item/weapon IDs, invalid counts, dead saved HP and nonfinite positions
are rejected before replacing a running session. Save metadata is derived from
slot files rather than depending on a separate fragile index.
Loading a validated snapshot can repair an unreadable active progression file;
the unreadable original is archived separately before replacement.

## Review and verification

### Visual direction

The user selected the assembled layouts in the
[Cyberpunk GUI pack](https://craftpix.net/freebies/free-gui-for-cyberpunk-pixel-art/)
as the visual target. Use those compositions, pixel typography, title strips,
inset grids, red X controls and colored action buttons. The earlier wide,
generic inventory/menu composition is superseded; keep its gameplay and save
logic while replacing its presentation.

- Inventory follows the user's exact cropped reference: one compact five-column,
  six-row window, closely fitted title, red Close and gold Sort against the
  bottom frame, and a grey side handle. There is no split inventory or persistent
  details panel. Hover tooltips and the context menu provide item details and
  Q/E assignment. Empty cells are presentation, never a carrying limit.
- Pause follows the pack's vertical Options layout, with the original flat frame,
  grey buttons, white action icons, red X and subtle borderless hover/focus lighting.
  Its title is centered on the full window, independent of the red X.
  Existing campaign actions remain in place; Settings is reserved for later.
  Confirmation and save/load pages share the same frame, title treatment, grey
  buttons and subtle focus lighting. Save cards separate HP, location and date/
  supplies into three lines. Their X returns to the prior menu just like Escape;
  the death screen has no dismiss button.
- Game over should use the pack's wired panel composition with Continue from
  last save, Load save and Quit. The reference's stars and level-rating rules
  are not game features.
- Settings and tutorial tips should follow their corresponding reference
  panels when implemented. Wall-jump guidance should explain the useful slow
  wall slide before kicking away, as discussed during Level 2 testing.
- Crafting can use the shown inventory-plus-recipe layout once crafting is
  designed. Character equipment, skill trees, vehicle upgrades and gun
  construction are reference examples, not approved feature commitments.

The compact inventory and subtle hover treatment have user acceptance. Options
and its confirmation/save/load pages now share their reference-based layout,
ready for visual review. The title/development selector and the final wired
Game Over composition remain separate presentation work.

Use MCP to review HUD, healing feedback, pause/inventory and save/death menus.
Focused contracts cover health/interruption, reward claims, migration/rotation/
corruption and real campaign save restoration. Run the normal validation suite
after changes that reach those systems. Full Level 2 route acceptance stays a
hands-on test.

`tools/validate_inventory_ui.gd` covers paused movement, assignment without
consumption, 75-HP item use after resuming, returning to pause, empty inventory,
pickup order/quantities, stagger and pause timing, expiry and session cleanup.
It also covers fixed window size during
overflow, handle synchronization and context assignment without consumption.
MCP verified wheel movement in both directions and dragging to the final row
using temporary overflow cells, which were removed after testing.
It and `tools/validate_item_rewards.gd`
passed after this presentation pass. MCP playtesting also verified actual Tab
and Q/E input routing, the smaller chest and its floating pickup icons; visual acceptance
remains a user review.

Generate the current numerical matchup report from the actual resources:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/report_combat_balance.gd
```

Output: `build/reports/combat_balance.md`. Gun damage, gunner durability, paired
shot grouping, interruption timing and healing presentation remain provisional.
