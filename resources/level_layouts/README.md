# Saved level layouts

The in-game designer saves one readable JSON file per registered scene section
here. These files override the structural scene when the game loads. Include
them in commits and exports alongside the relevant scenes.

Schema 3 stores added objects as known catalog template IDs plus validated
properties and signatures for the templates actually used. Adding an unrelated
terrain/prop pack does not invalidate a layout. Changing an asset it uses still
requires review, as does changing its structural base. Older schema 1/2 files
remain readable when their structural fingerprint matches.

Platforms, individual tiles, enemies, hazards, checkpoints, and decorations all use
the same save path; never put arbitrary scene or script paths into a layout.

Godot's ordinary scene editor shows the structural base. Before changing a
registered section, inspect the resolved layout with
`tools/inspect_level_layout.gd` through the normal Godot runner. Never silently
discard a saved override to make a scene or validator appear unchanged.

Files ending in `.bak` are local previous-save backups; `.tmp` and `.lock`
directories are temporary save coordination. Compatible unsaved recovery drafts
live under `user://level_designer`, separate from production layouts.

Current section saves contain user-authored additions:

- `arrival_shoreline.json`: an additional skater enemy in Level 1;
- `overgrown_coastal_ascent_interior.json`: an additional spike row in Level 2;
- `green_zone_finale_outdoors.json`: an additional checkpoint in Level 3 WIP.

Preserve these saves as authored content, not build artifacts. Include them
when committing or exporting the current levels. The user's local sandbox
recovery remains separate from Git.

The structural fingerprint includes supported enemy scripts, so even a shared
combat change can require review of a draft or saved layout. Read both the
resolved project layouts and current local recovery before such changes. Keep
the original file, establish why the base changed, and validate unchanged
records before any specific recovery; never blanket-update fingerprints.

See [the designer guide](../../docs/LEVEL_DESIGNER.md) for edit/test/save behavior.

## Local recovery reference

The interactive Windows profile keeps drafts at
`%APPDATA%\Godot\app_userdata\Blocky 3D\level_designer`; automation has its own
profile under ignored `build/godot_automation_profile`.

On 2026-09-12 the friendly-fire change required a specific review of the user's
two-gunner sandbox draft. Its old fingerprint was reproduced from the exact
pre-change enemy source and other current dependencies. Only the recovery
fingerprint changed; the two records stayed at x=8.32/21.119999, y=0.55,
facing left. The original backup is beside `sandbox.recovery.json`, named
`sandbox.before-friendly-fire.*.review.json`. Reviewed candidates and backups
also remain under ignored `build/sandbox_recovery*`.

These are local recovery artifacts, not project saves or a general migration.
Inspect current draft/save contents before restoring anything: the user may
have made newer edits since that review.

The 2026-09-21 ground-combat change also reviewed the current sandbox recovery
against the exact previous enemy-script bytes. Both gunner records, now at
x=6.360001/19.159999 and y=0.55 facing left, validated unchanged against the new
base. Only its fingerprint was updated. The original is preserved as
`sandbox.before-ground-combat.20260921T001106945.review.json`; the review and
original source snapshots are under ignored `build/ground_combat_review`.
