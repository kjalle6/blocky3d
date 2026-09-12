# New-chat handoff: accepted level designer and enemy friendly fire

Updated 2026-09-12 in `D:\GodotProjects\blocky3d`.
Read this file and [AGENTS.md](AGENTS.md) before further work.

## Checkpoint and working agreement

The user accepted the block-building designer and enemy friendly fire, then
requested committing the current work and updating the docs. This checkpoint
includes the full designer, asset browsers, Green Zone/Beach catalogs, export
loading support, and friendly fire. Its parent is `9d8df81` (handgun combat and
tunable combat audio). Use `git log -3 --oneline` and `git status --short` for
the exact current commit and any newer user edits; this file belongs to the
accepted checkpoint, not an outstanding trial.

Godot is canonical. Gameplay stays on the X/Y plane; 3D nodes stage pixel-art
layers. Levels 1 and 2 are accepted production content. Level 3, Green Zone
Finale, remains WIP. Do not change routes or encounters merely to satisfy a bot.
The user and Codex design level ideas together; Codex owns camera/section wiring
and scripted sequences, while the user can build and fine-tune supported objects.

No further designer expansion is required to finish this milestone. Future
asset zones, backgrounds, camera tools, scripted triggers, ammo, and the boss
need a new task. Parkour/shooting/cover ideas remain in [docs/ideas](docs/ideas/README.md).

## Designer: current accepted workflow

- Launch the main project in a separate game window. Godot's embedded game view
  previously offset the mouse; a separate window aligned correctly in user testing.
- Menu **7: Level Designer Sandbox**, then **F1 → Level designer**. The sandbox
  has a protected 256-tile grass floor, 128 tiles of vertical camera travel,
  all movement abilities, and no seeded encounters.
- **Build → zone → block** opens the sidebar. Click or drag to paint on the
  32-pixel / 1.28 m grid. The brush persists until right-click, Esc, or Select.
  One stroke is one Undo; unchanged strokes create no history. Solid terrain
  and non-solid scenery occupy separate painting layers.
- The sidebar and **Add objects** browser share search, categories, and zones.
  Sidebar click or browser double-click starts placement. Props/enemies place
  once; Shift-click repeats. Right-click an object offers settings, duplicate,
  remove, selection revert, and general Test/Save/Undo actions.
- Green Zone has 96 tiles (72 solid, 24 scenery), 78 static props, and 5 animated
  props. Beach has six existing sand top/side/fill pieces with sand audio defaults.
  Art is promoted unchanged. Decorative ladders, ramps, stones, and chests do
  not acquire gameplay behavior or cover collision merely by being placed.
- Prepared enemies, spikes, flying hazards, checkpoints, and decorations work
  in all registered game sections/labs. Seven existing Level 3 outdoor objects
  are editable; other authored assemblies remain protected. Legacy rectangular
  platforms still load, move, resize, duplicate, and save; new terrain uses blocks.
- **Test** starts a fresh run from the draft. Esc/F1 returns with edits and undo
  intact. **Save** writes the project layout; it does not commit Git. Closing
  with edits offers Save/Discard/Cancel. See [docs/LEVEL_DESIGNER.md](docs/LEVEL_DESIGNER.md).

## Layout data and preservation

`resources/level_layouts/<section>.json` overrides the structural scene before
runtime initialization. The Godot scene editor shows the base; game/designer
show the resolved layout. Before editing a registered scene or structural
dependency, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Headless -Script res://tools/inspect_level_layout.gd
```

Read `build/level_layouts_resolved.json`, and check local recovery drafts too.
No production layout JSON existed at this checkpoint; future user saves must
be preserved and committed when requested. Never silently drop overrides,
bake them into scenes, or rewrite compatibility fingerprints to bypass review.

Schema 3 stores stable IDs, validated values, and signatures for used catalog
templates only. Unrelated catalog additions and browser-label changes do not
stale a save; changes to used assets or structural dependencies require review.
Saving checks conflicts, verifies a temporary file, keeps a backup, and verifies
replacement. Compatible local recovery drafts are offered for review, not
automatically promoted. Undo retains 80 document actions independently of actors.

The user's local two-gunner sandbox draft was specifically reviewed after the
friendly-fire change affected its structural fingerprint. Its original fingerprint
was reproduced from the exact pre-change enemy source plus all other current
dependencies. Only that recovery fingerprint changed; both enemy records stayed
at x=8.32/21.119999, y=0.55, facing left. The original backup remains beside
`%APPDATA%\Godot\app_userdata\Blocky 3D\level_designer\sandbox.recovery.json`
as `sandbox.before-friendly-fire.*.review.json`. Review candidates/backups are
also under ignored `build/sandbox_recovery*`. These local files are not a project
save or a general migration mechanism. Inspect current files before restoring any
candidate, since the user may have edited the draft since this checkpoint.

Implementation owners: `scripts/developer/level_layout_registry.gd` (sections
and structural dependencies), `level_layout_document.gd` (data/undo),
`level_layout_store.gd` (storage/recovery), `level_layout_resolver.gd` (early
application), `level_layout_objects.gd` (supported values/factories), and
`level_designer.gd` (edit/test lifecycle). `level_object_catalog.gd` discovers
zone JSON; `level_object_library.gd` owns browser organization. Extension rules
are in [resources/level_catalogs/README.md](resources/level_catalogs/README.md).

## Accepted firearm and friendly-fire behavior

Menu **6: Level 3 - Gun encounter** starts at the section transition and plays
the introduction. The fixed enemy drop grants session-local handgun ownership
and auto-equips it. Death/checkpoint respawn preserves ownership; full section
restart clears it and rearms the encounter/drop. `1`/`2` select knife/gun;
wheel/gamepad RB cycle. A switch during an action waits for that action to finish.

Player mouse aiming follows cursor side and permits straight up/down, with a
small facing tolerance near the body. Keyboard/gamepad retain horizontal and
upward-diagonal shots. Grounded retreat uses 65% speed and the upright reversed
walk cycle. Shooting works during the double-jump flip without changing its
movement. Pistol 4_1/4_2 from `guns_pack_1`, the one-arm rig, compact flash,
slim rotated projectiles, and directional dual-gun enemy animation are accepted.
The two downloaded gun packs remain separate because filenames overlap.

Enemy bullets now damage other enemies normally. Before each paired beat, a
gunner checks both prospective barrel paths, waits/re-aims if an ally is first
in either lane, and resumes once clear. Waiting consumes no beat and emits no
flash or gunshot cue. Allies behind the player or cover do not block firing.
Already-released bullets can hit moving enemies and survive their shooter's
defeat. Run/encounter reset and teardown still clear them. Melee and
indestructible hazards retain their existing rules.

`HandgunProjectile3D.cast_shot` queries solid bodies and dedicated enemy hurt
areas separately and uses the nearest result. Ordinary contact/trigger areas
do not absorb shots. Owner and child collision RIDs are excluded at launch;
the default mask is 5. The enemy uses the same query for both prospective
barrels via `aimed_muzzle_world_position`, so checks and real shots agree.
Character/scenery impacts use the existing combat effects and audio banks.

## Audio authority

`resources/audio/movement_mix.tres` is the user's saved authority, including
footstep/jump choices, volumes, ambience, reverb, and combat overrides. No audio
settings changed in the designer/friendly-fire checkpoint. Its SHA256 was
`B58F49B8D14F154E9B156A0B8D40B082CA8A2C966116A0CD0A88E4C3D79A0D39`.
Re-read it before future tuning; filenames can be misleading and some cave
takeoff/landing assignments were deliberately chosen by ear.

F1 → Audio tuning supports category/event selection, file picking, previews,
A/B, Revert, and explicit Save. Designer previews suppress gameplay audio and
changing developer tools preserves the unsaved audio mix. See
[docs/AUDIO_TUNING.md](docs/AUDIO_TUNING.md) and
[docs/FOOTSTEP_AUDIO.md](docs/FOOTSTEP_AUDIO.md). Double-jump audio and other
unwired event slots remain optional/preview-only until deliberately connected.

## Validation and next work

The final implementation suite on 2026-09-12 passed **46/47** in **293.2 s**.
The sole failure is the existing `validate_level_2_interior_playthrough.gd`
stage-10 death near (64.54,29.02), not a new friendly-fire/designer regression.
Summary: `build/friendly_fire_validation_suite.txt`; failure log:
`build/godot_tool_logs/script_headless_20260912_212240_5168.log`.
No native Godot fault occurred. Only documentation changed after this suite.

Designer/layout/browser/catalog contracts, fresh-process reload, and isolated
LayoutSmoke pack loading pass. Browser, context menu, palette, and block-building
captures were reviewed at 720p/1080p. `validate_enemy_friendly_fire.gd` covers
both barrels/directions, blocked/resumed volleys, no false cues, moving skater
and gunner hits, thin cover, source exclusion, shooter death, and reset.
`capture_enemy_friendly_fire.gd` produced reviewed images at
`build/previews/enemy_holding_fire.png` and `enemy_friendly_fire_hit.png`.
The user has now accepted the resulting gameplay; validators alone do not
establish visual or listening approval.

Always launch Godot through `tools/run_godot_tool.ps1`, standard non-.NET,
Compatibility. Use `-Visual` for captures, optional `-Headless` for contracts,
and `tools/run_validation_suite.ps1 -Scope All -Headless` for a full sweep.
Use `-EditorImport` for class-cache changes. Preserve running Godot processes
unless exclusive access is necessary. Do not repeat a suite for documentation
changes. LayoutSmoke export/probe commands are in the designer guide.

There is no pending implementation in this accepted milestone. Continue with
the user's next request. Remaining campaign work includes the safe firing
lesson, ammo policy, further movement/shooting practice, and the Level 3 boss.
Do not promote Level 3 to production or expand the deferred designer scope
without a new design decision.
