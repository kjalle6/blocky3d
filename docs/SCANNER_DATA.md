# Scanner data

**Shelved (13 October 2026).** The user no longer wants the scanner. It might
return in some other form, but that is unlikely. Nothing is planned or queued
for it, and no other work waits on it.

The catalog, reader and `validate_scanner_catalog` stay in the repository,
unconnected to gameplay. Combat changes no longer need to keep the catalog in
step: some facts are already out of date (the stomp facts predate the
removal of stomp kills). If a combat change breaks the validator, ask the user whether
to remove the scanner code rather than updating the catalog. The last agreed
design is kept below under [Shelved design](#shelved-design).

The [scanner catalog](../resources/scanner/catalog.json) is the structured source
for building scanner entries. It contains identities, stat bindings and separate
discoverable facts. The [reader](../scripts/scanner/scanner_catalog.gd) resolves
numbers from existing game definitions or a supplied live actor. Combat profiles
and actor settings continue to own HP, damage, armor, cooldowns and movement.

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
| `green_zone_launcher` | S.T.O.M.P. | Boss |
| `flyer_vertical` | Flying machine | Hazard |
| `flyer_patrol` | Patrolling flying machine | Hazard |
| `flyer_shootable` | Shootable flying machine | Hazard |
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
`current_role: "provisional_playtest_value"`. Its current value comes directly
from the boss profile; no second HP constant is stored here. Lethal hazards
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

This applies only if the scanner returns. Change gameplay values in their existing profile or actor definition. Update
bindings when property names change. Add an entry and separate attack/effect
facts when adding a scannable enemy or hazard, then run the focused check above.
Keep the human combat document/spreadsheet aligned, but do not copy their
numbers into scanner definitions. The JSON export filter is registered in
`export_presets.cfg`; actual scanner integration will also need an exported-game
check once the feature is connected.

## Shelved design

Moved here from Combat balance when the scanner was shelved on 13 October 2026.
It is the last agreed design, kept for reference only; its combat facts reflect
that date and are not maintained.

A cyberpunk eye implant, glasses, or similar device would let the player
identify enemies and hazards, learn about them through experience, and later
give them personal names. The device's final form and overlay artwork were
never chosen. The combat values and effects in [Combat balance](COMBAT_BALANCE.md)
remained the underlying rules; scanning would only change what the player knows.

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
it does not establish bullet effectiveness.

Keep **unknown**, **confirmed effective**, **reduced damage**, and **confirmed
ineffective** distinct. A missed swing, obstructed bullet, out-of-range attempt,
or attack cancelled before impact cannot prove resistance. A visible Hurt
animation alone cannot prove that the enemy's attack was interrupted: the
S.T.O.M.P. can display Hurt while continuing to fire.

The following maps existing combat rules to proposed discovery evidence. Actor
names are the current reference names, not final device-screen copy. Each row
contains separate facts to unlock, not a bundle awarded by any one interaction.
Numerical baselines stay in the tables and actor descriptions above.

| Enemy or hazard | Existing rules the entry could record | Experience needed for the corresponding fact |
| --- | --- | --- |
| Bat patrol / skater | Knife and bullet effectiveness; attack damage; head-landing damage to the player; hit interruption | A confirmed connection with each tested attack; receiving its attack; a head landing; interrupting an attack through a hit |
| Stationary / moving / elevated dual-gun enemy | Weapon effectiveness; gunfire damage; paired bullets form one damaging beat; hit interruption; applicable movement and burst behavior | The corresponding weapon hit, received firing beat, interrupted attack or observed behavior; one bullet observation must not reveal every burst pattern or variant |
| Green Zone tank | Reduced knife damage, full bullet damage; attacks continue through nonlethal hits; head contact causes psychic damage and a freeze while the tank retreats | Test the relevant weapon or head contact; experience the pulse/freeze; observe a pending attack continue through a confirmed hit |
| S.T.O.M.P. (Green Zone boss) | Reduced knife damage, full bullet damage; head contact causes smoke, grounded hold, retreat and counterattack; landing AoE; charge/firing shove; missile damage | Separate confirmed weapon tests, descending head contact, landing-blast contact, charge/shove contact and rocket hits; smoke itself is not the source of rocket damage |
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

Left undecided when the scanner was shelved:

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
