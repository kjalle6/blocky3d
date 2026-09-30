# Scanner data

The [scanner catalog](../resources/scanner/catalog.json) is the structured source
for building scanner entries. It contains identities, stat bindings and separate
discoverable facts. The [reader](../scripts/scanner/scanner_catalog.gd) resolves
numbers from existing game definitions or a supplied live actor. Combat profiles
and actor settings continue to own HP, damage, armor, cooldowns and movement.

This is a data foundation. The scan overlay, targeting, combat-event adapters,
player knowledge storage, naming and save integration are not connected yet.
The foundation is ready for later integration; **finish the Green Zone boss
first**, following the [roadmap priority](LEVEL_ROADMAP.md#next-priority-finish-the-green-zone-boss).
Keep boss stat bindings current as its fight is tuned without starting scanner
gameplay/UI as part of that work.
The agreed interaction and open design decisions remain in
[Combat balance](COMBAT_BALANCE.md#enemy-and-hazard-scanner-planned).

## Reference files

| File | Purpose |
| --- | --- |
| [catalog.json](../resources/scanner/catalog.json) | Editable identity, fact, evidence and stat-source definitions |
| [scanner_catalog.gd](../scripts/scanner/scanner_catalog.gd) | Read definitions, resolve stats, match confirmed experiences, return learned facts |
| `build/reports/scanner_catalog.json` | Generated developer snapshot with resolved numbers and fact definitions |
| [Combat stats spreadsheet](../outputs/01a0ee28-cea0-7d82-b0a7-f548e4c665b0/Combat_Stats.xlsx) | Human comparison tables; not a runtime data source |

Generate a fresh snapshot and check the catalog with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_scanner_catalog.gd
```

The report is disposable and may become stale after tuning. The game must read
the catalog and current actor values, never that report or the Excel file.

## Stable entry IDs

| ID | Game reference name | Kind |
| --- | --- | --- |
| `bat_patrol` | Bat patrol | Enemy |
| `skater` | Skater | Enemy |
| `gunner_stationary` | Dual-gun enemy | Enemy |
| `gunner_route` | Moving route gunner | Enemy |
| `gunner_guard` | Elevated guard | Enemy |
| `green_zone_tank` | Green Zone tank | Enemy |
| `green_zone_launcher` | Green Zone launcher | Boss |
| `flyer_vertical` | Flying machine | Hazard |
| `flyer_patrol` | Patrolling flying machine | Hazard |
| `spikes_ground` | Ground spikes | Hazard |
| `spikes_wall` | Wall spikes | Hazard |
| `spike_pit` | Spike pit | Hazard |
| `shore_water` | Shore water | Hazard |
| `machine_pool` | Machine-pool water | Hazard |
| `pit_void` | Pit / void | Hazard |
| `moving_saw` | Moving saw | Planned; values TBD |

These IDs identify definitions. They do not decide whether future names and
knowledge are shared across a type, a variant or an individual. Assign scanner
IDs explicitly in the future target adapter; actor script alone cannot
distinguish bat/skater, gunner variants or different lethal contact regions.
Personal aliases must be stored separately from IDs and canonical names.

## Reading values

```gdscript
const CATALOG = preload("res://scripts/scanner/scanner_catalog.gd")
var catalog = CATALOG.new()

# Developer reference using authored defaults.
var defaults = catalog.resolve_stats("green_zone_tank")

# Actual encountered tank, including placement/runtime overrides.
var actual = catalog.resolve_stats("green_zone_tank", tank)
# actual.values.shell_range = {"value": 48.0, "unit": "m"} for the shaft tank.
```

Every result exposes `values`, `errors` and `origin`. Check `errors` before use.
A missing property or wrong actor script is an error, not zero or a fallback
to an unrelated default. The reader does not alter or free a supplied target.
Default scene instances stay outside the live tree and are freed after reading.

Bindings have one of three sources:

| Source | Fields | Reads |
| --- | --- | --- |
| `actor` | `property`, `unit` | Dotted actor/resource property, such as `combat.maximum_hp` |
| `scene` | `path`, `node`, `property`, `unit` | Separate resource composition, such as rocket flight defaults |
| `script_constant` | `path`, `constant`, `transform`, `unit` | Named constant; optional `count` for the six launcher tubes |

Authored defaults do not apply saved layout JSON, call `_ready`, or simulate an
encounter. Pass the actual actor for placement-specific values. A stationary
guard can have a configured patrol speed while `mobile` is false; these are
configuration values, not a measurement of current velocity. Separate projectile
scene bindings are prototype defaults, not measurements of a fired projectile.

Boss `maximum_hp` retains `balance_status: "TBD"`, `target_value: null` and
`current_role: "inadequate_lab_placeholder"`. Its current value comes directly
from the boss profile; no second 300-HP constant is stored here. Lethal hazards
have qualitative death facts and no invented HP/damage number. A planned saw
has no runtime stats or unlockable entry.

## Evidence and player knowledge

Facts have stable IDs, short labels/values and an evidence condition. Shared
weapon facts use `fact_sets`; actor-specific attacks and effects stay separate.
Numbers live under `stats` and are excluded from the learned view while exact
number discovery is undecided.

```gdscript
# This event is an adapter contract, not an event the current combat code emits.
var event = {
    "entry_id": "green_zone_launcher",
    "event": "attack_received",
    "attack": "missile",
    "confirmed": true,
    "after_scan": true,
}
var newly_confirmed = catalog.qualifying_fact_ids("green_zone_launcher", event)
# ["missile"] only; no armor, landing, charge or smoke facts.

var first_scan = catalog.learned_entry("green_zone_launcher", [], true)
# Identity and an empty facts array.
var learned = catalog.learned_entry("green_zone_launcher", ["missile"], true)
# Identity and the confirmed missile fact; no raw stats or source metadata.
```

Future combat adapters must verify source/target, attack identity, actual
connection/outcome and that the scan preceded the event. `confirmed` is supplied
by that trusted game logic; the catalog is a matcher, not proof of an event.
Misses, cover obstruction, cancelled attacks and out-of-range attempts must not
be translated into `ineffective`. A Hurt animation is not an interruption event.
Flyers need a new confirmed ineffective-contact result because they do not
currently participate in normal damage-target contracts.

| Event | Required additional fields |
| --- | --- |
| `weapon_result` | `weapon`: knife/handgun/stomp; `outcome`: effective/reduced/ineffective |
| `attack_received` | `attack`, matched to this entry's specific attack |
| `effect_experienced` | `attack` and `effect`, such as smoke escape and ground hold |
| `lethal_contact` | `attack`, keeping flyer body, electrical spark, water and fall separate |
| `attack_interrupted_by_hit` | Actual pending attack interrupted by the player's confirmed hit |
| `attack_continued_after_hit` | Actual pending attack continued through the player's confirmed hit |

All matched events also require the exact `entry_id`, `confirmed: true` and
`after_scan: true`. Callers own the future knowledge record and must pass only
that record's known fact IDs. No storage, alias ownership or cross-entry merging
happens inside this reader.

Behavior observation and identifying paired firing beats have
`discovery_status: "pending_policy"`; matching and presentation both leave them
locked. Their candidate conditions are recorded for later design. Exact number
reveals, rename timing, observation-only discoveries, knowledge scope and death/
save persistence remain TBD. In particular, lethal-hazard knowledge must not be
silently lost or retained by an invented save policy. Lab records must remain
separate from campaign records when storage is implemented.

## Updating the catalog

Change gameplay values in their existing profile or actor definition. Update
bindings when property names change. Add an entry and separate attack/effect
facts when adding a scannable enemy or hazard, then run the focused check above.
Keep the human combat document/spreadsheet aligned, but do not copy their
numbers into scanner definitions. The JSON export filter is registered in
`export_presets.cfg`; actual scanner integration will also need an exported-game
check once the feature is connected.
