# Maintenance priorities

The aim is to make further game work easier and reduce specific sources of
mistakes. Movement tuning, health, inventory, and handgun behavior already have
separate owners, and the project has automated validators. The earlier cleanup
pass is complete. **Finishing the Green Zone boss is now the first priority**;
maintenance should support that work or resolve a concrete blocker. Follow the
[boss completion checklist](LEVEL_ROADMAP.md#next-priority-finish-the-green-zone-boss).

## Wall-jump camera review - 13 October 2026

This is a bounded review of the Level 2 pickup approach and the later wall-jump
areas, not a complete campaign bug sweep. Findings and checks:

- **VQA-01, Level 2 approach/floor:** walking across P3 raised the camera despite
  constant player height. After a missed jump, its rising rail also left the
  grounded player below the screen. Replaced this part with bounded player
  follow, retaining shaft centring and the upper-cave hold. The regression
  failed before the fix and now passes, including floor recovery, boundary
  backtracking/reload agreement and fast falls at 30/60/144 FPS.
- **VQA-02, tank climb:** an ordinary fall from the upper ledge hid the player
  below the screen before landing. Reduced vertical damping from 0.35 to 0.16
  seconds; the previously failing terminal-fall check now passes along with
  the existing climb, transition and introduction-camera checks.
- **Comparison:** the Level 3 underworks approach, wall kick and fallback kept
  the player visible. No corresponding camera bug was reproduced there.
- **Open review, boss high deck:** the player was close to the top edge while
  grounded around `(10.08, 33.83)`. Grounded framing and a short deck fall were
  visible, but jumps above that deck and the full descent were not covered.
  Check those during boss encounter review before deciding whether the arena
  camera needs more headroom. This is an unverified concern, not a confirmed
  bug; the encounter framing remains unchanged.

The camera settings and repeatable checks are in
[Phantom Camera](PHANTOM_CAMERA.md#earlier-routes). All resolved authored layout
objects and revisions were compared unchanged before updating their structural
fingerprints. Independent MCP verification passed for P3 walking/reversal,
missed-jump landing and retreat, the lower boundary, real initial wall kicks,
an upper-alcove jump, and the matched tank ledge fall. The upper alcove was
reached with diagnostic flight before returning to ordinary controls; a full
continuous cave ascent and complete boss encounter were not tested. Fresh
runtime/editor errors were empty. The user subsequently accepted the improved
camera feel and approved committing these changes.

Validation: the focused campaign-camera, tank-camera and layout checks all
passed. The rendered wall-jump probe drove seven jumps, with 53 visible samples,
zero horizontal camera movement and zero measured ceiling drift. Evidence
captures under the normal Godot `user://screenshots/` directory use the prefixes
`wj_inspect_`, `wj_compare_` and `wj_verify_`; the safe-floor recovery and matched
tank fall are the key before/after comparisons.

Fifteen reviewed textures had automatic 3D detection
disabled after the editor changed their import settings; their original
lossless, non-mipmapped pixel-art settings are retained.

## Open tank verification follow-up

The 2026-09-30 checkpoint still has two failing focused checks:

- `validate_tank_psychic`: the tank does not satisfy the expected retreat during
  the player's psychic freeze.
- `validate_tank_pursuit`: the tank does not satisfy the initial advance through
  the cover route.

Both checks load the current saved Level 3 layout. That layout places the tank
at `(60.92, 3.61)`, while the structural scene starts it at `(63.36, 0.45)`;
the tests still assume the older grounded setup. The exact cause remains
unconfirmed. Inspect the resolved encounter in-game before deciding whether
the behavior or the test setup needs changing. Preserve the authored placement
and overrides. These open checks do not establish a defect in the new boss.
Run both through the suite's `-Name` option when this follow-up is addressed.

## Completed foundations

The September 30 asset organization pass added the [asset guide](../assets/ASSET_GUIDE.md)
and character/weapon/VFX indexes, refreshed missing source files, and retained
older catalog paths. Existing art and audio were not moved or overwritten.
The visual sync now keeps library-only files indexed. The numbers-only combat
spreadsheet is also prepared. Scanner data was prepared too; the scanner itself
was shelved on 13 October 2026.

### September 21 cleanup

Completed 2026-09-21. The [credits index](ASSET_CREDITS.md) links source evidence
and the remaining bounded follow-ups. All 15 previously unattributed combat
sounds now have exact archive matches. Player cleanup passed the health/combat,
ground-contact, save-lifecycle, and handgun checks, plus an MCP lab smoke test
for movement, jumping, knife attacks, shooting, and reload. Gameplay tuning and
the saved audio mix are unchanged.

#### 1. Asset credits and source gaps

- [x] Create a central asset/credits index for art, fonts, audio, and bundled
  third-party code used by the game or its tools. Link the existing manifests
  and license files, and distinguish shipped assets from the audition library.
- [x] Investigate the older combat sounds whose original collection was marked
  unknown in [the audio manifest](../assets/audio/combat/source_manifest.json).
  Start with the local source packs, archives, and download records. Record
  confirmed matches and the evidence; leave unresolved sources clearly marked.
- [x] Add a short source-to-runtime workflow linking the existing import tools
  and manifests. Keep detailed rendering guidance in the
  [technical foundation](TECHNICAL_FOUNDATION.md#asset-pipeline).

**Done when:** each production asset family has a discoverable source/license
record or an explicit unresolved entry. Unknown audio has a bounded follow-up
list. If local evidence runs out, move on with that list rather than repeatedly
searching or guessing. This first pass documents the sounds currently in use;
any replacement would be a separate audio choice.

#### 2. Small player-code cleanup

- [x] Give the repeated `0.55` feet offset in
  [player_character.gd](../scripts/player/player_character.gd) one named source,
  preserving the existing collision measurements and stomp behavior.
- [x] Trace calls to `receive_enemy_hit` and resolve its fallback `25` damage.
  The ground-enemy and projectile callers already supply a `CombatHit`; check
  the remaining callers and test fixtures before removing the fallback or
  making its intended default explicit. Damage continues to belong to the
  attacking source.
- [x] Review initialization of required player nodes/resources and add useful
  diagnostics where missing setup would otherwise produce an unclear error.
  Optional references retain appropriate guards. The earlier review did not
  establish a live null-reference crash, so this is targeted setup validation.

**Done when:** the duplicated measurements and ambiguous fallback have clear
ownership, missing required setup is reported clearly, and normal play behaves
the same. Use the existing ground-contact and health-combat validators, plus
the relevant player-scene checks and an MCP smoke test. Add a regression case
only for a concrete gap the existing checks do not cover.

These two bounded tasks are complete. Remaining asset source questions stay in
the credits index; they do not displace the active boss milestone.

## Alongside new features

| When | Useful improvement | Completion check |
| --- | --- | --- |
| Another weapon or more loadout behavior is needed | Extract weapon ownership/selection and, if helpful, melee action state from the player controller. Keep firing, damage, and movement order explicit. | Existing switching, knife/stomp, shooting, reload, interruption, and save behavior still work in focused checks and play. |
| Developer controls need substantial changes | Move inspection/free-flight behavior behind a focused helper if it simplifies the controller. | Entering and leaving inspection restores collision, camera policy, and session abilities correctly; campaign saves remain isolated. |
| A bug or a new rule exposes an untested case | Extend the existing validator or add a small isolated test for health, inventory, loot, or save validation. | The test exercises the specific behavior and fails when that behavior is broken. |

Extract one responsibility at a time when it removes duplication or makes a
feature easier to implement. Movement and abilities share jump, wall-contact,
Dash, and attack timing; keep them together until there is a concrete reason to
change that boundary. The player's line count is an observation, not a target.
Health, inventory, and handgun components already exist and can be reused.

## Later, when sharing builds becomes routine

- [ ] Add selected automated checks on GitHub. First make the engine path and
  runner setup portable, pin the standard Godot version, import cleanly, and
  retain isolated saves and script-error detection. Begin with a small reliable
  set of data/logic checks; measure runtime before expanding it. MCP and hands-on
  playtesting continue to cover visual quality and game feel.
- [ ] Before distributing a release, finish the shipped-asset source review,
  resolve outstanding attribution entries or choose documented replacements,
  and assemble credits/notices from the central index. Verify the export
  contains its runtime dependencies and appropriate notices.

The current local suite remains useful throughout. Test selection and Godot
execution details stay in [AGENTS.md](../AGENTS.md); this plan adds no replacement
test framework or full-route bot.

## Low priority without new evidence

A full controller rewrite, a universal ability/component framework, exporting
every numeric threshold, or adding null checks to every node access would create
considerable work without an established benefit. Reconsider a specific item
when a feature, reproducible bug, or maintenance difficulty makes the need clear.

Gameplay priorities remain in the [level roadmap](LEVEL_ROADMAP.md). This plan
tracks the maintenance tasks above; update their status as they are completed.
