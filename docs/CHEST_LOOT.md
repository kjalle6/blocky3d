# Supply chests and loot pools

Place **Add objects → Supplies → Supply chest** in the level designer. It
snaps to existing ground, opens on contact during play, and grants its complete
bundle immediately. The accepted item-icon/+quantity popups play one after
another above the player. Editing previews never collect rewards.

Select a chest and open **Settings → Contents**:

- **Automatic · this level** uses the level's pool, including its other sections.
- A named pool overrides the level default; **Better supplies** supports
  deliberately richer or later rewards.
- **Fixed contents** exposes counts for 25/50/75-HP medicine and handgun rounds.
  Zero omits an item; at least one count must be positive. This mode supports
  guaranteed tutorial supplies.

Move, duplicate, delete, Undo, Test and Save work like other designer objects.
Duplicating creates a distinct chest identity. Moving a chest keeps its identity.
The old **Decorative chest opening** remains scenery; goal chests remain exits.
Weapons and ability unlocks retain their deliberately authored rewards.

## First balance pass

The editable source is
[`resources/loot/chest_pools.json`](../resources/loot/chest_pools.json).
Each opening draws one weighted item type, then may draw a second, different
type. Quantities use inclusive integer ranges. If only one type is eligible,
there is only one reward. Handgun ammo is eligible only when the player owns
the handgun; fixed authoring intentionally allows exact bundles.

| Pool / automatic level | Item weights and quantities | Second type chance |
| --- | --- | --- |
| Shoreline / Level 1 | Basic medicine: weight 100, 1–2; ammo: 60, 12–24 | 25% |
| Green Zone / Level 2, outdoors and cave | Basic: 80, 1–2; 50-HP kit: 20, 1; ammo: 60, 12–30 | 25% |
| Gun encounter / both Level 3 sections | Basic: 60, 1–2; 50-HP kit: 25, 1; ammo: 100, 18–36 | 35% |
| Better supplies / explicit override only | 50-HP kit: 65, 1–2; 75-HP bag: 35, 1; ammo: 80, 24–48 | 50% |

Weights are relative among eligible items, not percentages. These are starting
values for playtesting; supply accumulation and encounter balance remain tunable.
Fresh campaigns still start without medicine. The 75-HP bag is available for
authoring but is absent from the automatic early-level pools.

Three movable sample placements use automatic pools:

- Level 1: threshold landing, X 58.88.
- Level 2 outdoors: cave approach, X 31.36.
- Level 3 gun encounter: beyond the first shooter, X 30.72.

The Firearm Lab chest remains fixed at one basic medicine and 30 handgun rounds.
The guaranteed first handgun still supplies 30 rounds in total (12 loaded,
18 reserve). General enemy loot/drop chances are not introduced by this pass.

## Saves and repeatability

New campaigns receive a persisted positive loot seed. A local RNG combines it
with the section, stable chest ID and selected pool. Reopening after loading an
earlier save repeats the roll for that saved weapon eligibility; it does not
depend on global RNG, timing, deaths, or unrelated chest openings. Old saves
without the optional version-2 `loot_seed` use the stable fallback 1.

Claim flags and inventory are restored together. Claimed chests remain open
after loading; ordinary enemy/world resets cannot grant their contents again.
Loading an older manual save also restores its campaign seed and progression.
Pool edits are balance changes and can change future unopened rewards.

## Verification

`tools/validate_chest_loot.gd` covers weighted draws, quantities, weapon gating,
stable outcomes, designer preview/placement/settings/Undo/disk round trips,
actual contact collection and full campaign snapshot reconstruction.
`validate_save_snapshots.gd` covers seed persistence, legacy fallback and invalid
seed rejection. The existing pack probe includes a supply chest and checks that
the pool JSON ships in exported builds.

Current verification: all 56 validators have passing results (53 in the full
suite, then three corrected HUD expectations rerun separately). The standalone
exported-pack probe passed. Live MCP captures confirmed ground placement,
automatic/fixed controls, and the Level 2 contact pickup with medicine popups;
runtime logs contained no errors.
