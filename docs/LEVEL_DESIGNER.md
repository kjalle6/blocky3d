# Level designer

Accepted first version and browser/block-building follow-ups: 2026-09-12.
Scripted sequences, camera editing, and background selection remain deferred.

Open **Level Designer Sandbox** from level select (shortcut **7**), then press
**F1** and choose **Level designer…**. The sandbox starts empty apart from its
protected grass foundation. Run the main project in a separate game window.
The embedded game view previously offset cursor targeting; the separate window
aligned correctly during user testing.

## First experiment

1. Click **Build**. Choose a **zone**, then a block from the side panel.
   **Open full browser…** shows the same choices as larger picture cards.
2. Click in the level to place one block, or drag to build a row or follow a
   shape. The brush stays active for the next stroke; **right-click or Esc**
   finishes. Each stroke is one Undo. Select another block to change pieces.
   **Add objects…** offers props, enemies, hazards, and autosave points. Those place
   once and become selected; Shift-click keeps placing them. Grounded objects
   snap to nearby floors, while flying machines stay in the air.
3. Choose **Test** to play a fresh attempt. **Esc** returns to editing with your
   layout and undo history intact. **R** restarts while testing.
4. Choose **Save** to keep the layout for future launches. No coordinates need
   to be sent to Codex, and saving does not make a Git commit.

**Revert** returns to the last successful save and can itself be undone. Closing
with changes offers Save, Discard, or Cancel. Closing starts a fresh normal run
from the saved layout; it does not resume an old fight.

## Controls

| Action | Control |
| --- | --- |
| Quick add | Click a picture card in the side panel's **Add** tab |
| Add from the large browser | **Add objects…**, then double-click a card or use **Place in level** |
| Build with blocks | **Build**, choose a zone and block, then click or drag |
| Finish building | Right-click, Esc, or **Select / move** |
| Repeat props/enemies | Shift-click while their preview is following the mouse |
| Select | Click an object or choose it under the side panel's **In level** tab |
| Object actions | Right-click an object in the level |
| Select a group | Shift-click objects |
| Select something underneath | Click again to cycle overlapping objects |
| Move | Drag a selected object or its coloured axis handle |
| Resize | Drag a square edge handle, or enter dimensions in the inspector |
| Pan / zoom | Middle mouse drag / mouse wheel |
| Frame selection | **F** or **Frame selection**; with nothing selected, frames the start |
| Nudge | Arrow keys while the level canvas has focus |
| Cancel a drag | **Esc**, right-click, or move focus to another window |
| Undo / redo | **Ctrl+Z** / **Ctrl+Y** or **Ctrl+Shift+Z** |
| Duplicate / remove | **Ctrl+D** / **Delete** for added objects and permitted independent platforms |
| Save | **Ctrl+S**, after finishing a text field, or **Save** |
| Return from testing | **Esc**, **F1**, or **Return to editor** |

The **Side panel** button collapses the panel. Its **Add** tab offers the same
catalog with search, a zone dropdown, and categories; one click begins placement.
It starts with Green Zone blocks. **Build** brings this panel back even if it was
collapsed. The full-browser button carries over the current filters.
**Settings** opens when you select an
object in the level. **In level** keeps the existing placed-object list and
protected-object toggle, and stays open while selecting a group from the list.

Single-clicking a card in the full browser shows its details. Double-clicking
starts placement. It does not place an object until you click in the level.

Position snapping offers a
tile, half tile, pixel, or no snapping. Platform sizes always stay whole tiles.
Selecting an existing object does not move or snap it.

The camera used for editing is independent of the gameplay camera. Panning,
zooming, selection, and undo history are not saved into the level.

Right-click an object for **Edit settings**, **Frame selection**, **Duplicate**,
**Revert to last save**, and **Remove**, plus Undo/Redo/Test/Save shortcuts.
Right-clicking a member of your selected group keeps the group selected.
Right-clicking empty space offers **Add objects**, **Build with blocks**, and general level actions.
During a drag, right-click cancels the drag instead of opening the menu.

The menu's **Revert to last save** restores only the selected object or group,
leaving other edits intact, and can be undone. It is disabled for objects that
have never been saved; remove those or undo their creation instead. The toolbar's
**Revert** still restores the whole layout. Unavailable actions stay greyed out;
the menu does not bypass protected objects.

## The object browser

The same browser is available in the sandbox, Levels 1 and 2 (including the
cave), both Level 3 sections, and the existing developer labs. Each section has
its own saved additions. Original scenery and scripted assemblies remain
protected unless explicitly registered for editing.

| Category | Prepared objects |
| --- | --- |
| Blocks | Green Zone tops, edges, corners, slopes, fill and scenery pieces; Beach sand pieces |
| Enemies | Patrol enemy, skater, stationary dual-gun enemy |
| Hazards | Spike row, flying electrical machine |
| Autosaves | Additional grounded autosave point (campaign); respawn point in developer tests |
| Supplies | Supply chest: automatic level pool, chosen pool, or fixed item counts |
| Decorations | The original four quick choices plus all 78 Green Zone props |
| Animated scenery | Card, money, skateboard, fountain, and chest opening |

Use **Zone → Green Zone** in either browser to browse that collection. Zones
organize the assets, not where you may use them: Green Zone pieces are available
in any supported level. Future packs will get their own zone choices. This pass
includes the complete terrain and prop collection, with background selection
left for later.

### Building with blocks

There is one building workflow. The **Blocks** category puts the zone's pieces
together: Green Zone has 72 solid blocks and 24 clearly labelled scenery blocks.
Beach has six existing sand pieces: left/middle/right tops and sides/fill.
Sand blocks use the sand footstep surface automatically.

Click a block, then click or drag in the level to paint on the 32-pixel grid.
A drag fills the cells along your stroke using that selected piece. The brush
stays active between strokes, including when clicking a cell already occupied
by the same block. One stroke is one Undo action; an unchanged stroke adds no
history. Painting over an aligned block replaces it. Solid terrain and scenery
use separate layers, so a scenery stroke will not erase walkable ground.

Tiles retain their original size and artwork. Solid pieces have collision shaped
to their outer outline, including the diagonal slopes; small indentations inside
that outline are simplified. **Scenery blocks** have no collision. Blocks can be
moved, duplicated, removed, and flipped in Settings. Solid tiles also expose
their footstep surface. Painting always uses the tile grid; changing the movement
snap setting only affects moving a selection afterward.

Existing larger platforms still load, move, resize, duplicate, and save as
before. They appear with blocks in the placed-object filter. Creating a new
rectangle is no longer a separate tool or browser choice; new structures are
built from individual blocks.

The catalog also includes benches, bushes, fences, fountains, grass tufts,
leaves, stones, trees, bins, boxes, ladders, ramps, and skateboards. These props
are scenery: a ladder picture does not introduce climbing, and a ramp picture
does not create a rideable ramp. Animated scenery freezes during editing and
plays during Test/normal play. Decorative chest opening is scenery only.
Choose **Supplies → Supply chest** for rewards: its Settings panel selects
the automatic level pool, a named pool, or fixed medicine/ammo counts. It stays
closed in editing, opens on player contact in Test/play, and saves its claim
alongside inventory. See [chest loot](CHEST_LOOT.md) for pools and sample
placements. The other four scenery animations loop.

Each section supports up to 4,096 added objects in total, with up to 512 of those
being props, platforms, enemies, or other non-tile objects. A single tile stroke
can affect up to 512 cells.

Enemies include their existing animations, collision, attacks, and reset
behaviour. The flying machine keeps its existing bob/discharge timing; only
placement is exposed. Decorations are scenery without movement or bullet
collision. A decorative stone is not a cover object.

Enemy gunfire can damage other enemies. A gunner holds a paired shot when a
teammate blocks either barrel's firing line, then continues when it clears.
Already-fired bullets can still hit enemies that move into their path, and
defeating the shooter does not remove those bullets. Restarting/respawning
clears them. This makes positioning matter when testing mixed enemy groups;
melee attacks keep their existing rules.

Added checkpoints activate through stable grounded contact. They remember a
respawn spot without advancing the original campaign checkpoint numbering,
so later authored checkpoints still work. Their marked areas are visible in
the designer and invisible during normal play.

These same placeable markers now appear as **Autosave points**. Existing
placements and layout IDs are preserved. In a campaign, activation saves without
healing and never overwrites separate manual slots. Death offers Continue from
last save, Load Save, and Quit; loading restores saved HP and supplies exactly.
Developer level selections and designer tests still use a session-local respawn
spot, keeping authoring tests separate from campaign snapshots.
See [save-system guide](SAVE_SYSTEM.md) for the implemented behavior.
See [Combat balance](COMBAT_BALANCE.md#autosave-points-and-recovery).

You can duplicate/remove added objects and move mixed groups. Placement previews
never enter the saved layout and cannot hurt the player or trigger encounters.
The catalog contains approved reusable objects, not arbitrary files or scripts.

## Existing enemies, spikes, and checkpoints

The existing objects already registered for adjustment are in **Level 3 WIP**
(menu shortcut **5**). Use the object list and Frame selection to find:

- Double Jump Island and Dash Island 01.
- Opening Patrol, Dash Landing Patrol, and Runup Patrol.
- Final Landing Spikes and Opening Checkpoint.

Walking enemies expose their starting position, speed, initial direction, and
left/right patrol limits. Each side can turn automatically at walls/edges or
use a fixed distance from its start. Round handles set fixed limits visually.
Moving an enemy also moves its patrol range. Walls and ledges still matter;
the displayed range does not guarantee a walkable route.

Checkpoints expose their activation width/height and ground position; their
purpose and order are fixed. Basic support warnings help identify a floating
enemy or checkpoint, but always test a changed route.

Scripted triggers and encounters are still assembled with Codex. The separate
populated fixture is for automated checks, not the user's sandbox.

Show protected objects to see what remains with Codex: the foundation, connected
terrain, lift, cave, camera regions, and scripted transitions/encounters. The gun
encounter shortcut keeps its existing behaviour; its original encounter stays
protected while you can place additional objects in that section.

## Saving and recovery

Saved files live in `resources/level_layouts`, one per supported scene section.
The game combines the original scene with these saved changes before terrain,
enemies, and checkpoints initialize. Testing uses the same loader with the draft.
Defeated enemies and current patrol positions never become layout edits.

The ordinary Godot scene editor shows the structural base; the game and designer
show the effective saved layout. Codex must inspect that layout before continuing
work on a registered section.

A save validates the complete layout, checks for other writers and changed base
files, verifies a temporary file, keeps a `.bak` of the previous save, replaces
the saved file, and verifies the result. A rejected save keeps the working draft.
Only the development checkout can save; packaged games load layouts with the
designer disabled.

Completed edits also get a local recovery copy. After an interrupted session,
the tool offers to restore a compatible draft for review. It is never promoted
to the project save automatically. This is useful when Godot/F8 stops the game.

If another window or Codex changes a layout/base while you are editing, saving
stops with an explanation. **Reload saved** keeps a review copy before replacing
your working view and clearing history. If the saved layout itself no longer
matches its base, have Codex reconcile the two. There is no silent force-save or
automatic merging. Review/recovery copies are in `user://level_designer`; the
audio panel's unsaved mix is preserved when changing tools.

## Authoring and validation notes for Codex

- Section IDs and paths: `scripts/developer/level_layout_registry.gd`.
- Catalog: `scripts/developer/level_object_catalog.gd`, plus discovered zone JSON
  files in `resources/level_catalogs`. Each added object saves a known template
  ID and validated properties; schema 3 does not load paths supplied by layouts.
  It records signatures for only the templates used by that layout, including
  production image hashes. Adding unrelated terrain/prop entries does not
  invalidate existing layouts; changing a used asset requires review. Schema 1
  and 2 remain readable when their structural fingerprint still matches.
- `level_object_library.gd` owns browser organization and new-placement defaults.
  Its unified Blocks category hides the two legacy platform creation entries,
  while the saved catalog and runtime factories remain unchanged. UI changes
  therefore do not invalidate the structural fingerprints of existing layouts.
  `tools/prepare_beach_block_catalog.py` exposes six existing production sand
  images in `resources/level_catalogs/beach.json`; no image bytes are changed.
- `tools/prepare_green_zone_catalog.py` promotes 179 original images unchanged
  into `assets/art/green_zone/catalog`, writes their source/hash manifest, and
  generates `resources/level_catalogs/green_zone.json`. It needs Pillow. The
  source catalog remains excluded from exports. See `resources/level_catalogs/README.md`.
- Object IDs/kinds/removal permissions are metadata on placed scene instances.
  Keep IDs stable; do not reuse IDs for unrelated objects or put them on prefabs.
- `level_layout_objects.gd` owns supported properties, bounds, validation, and
  application. Shared styles stay immutable; surface choices use object metadata.
- `level_layout_document.gd` stores values and produces versioned diffs with
  expected base values. `level_layout_store.gd` owns verified storage/recovery.
- `level_layout_resolver.gd` applies the complete validated document before
  children initialize. Main loading preflights before replacing the old level;
  LevelSession's early entry also covers direct scene/validator loads.
- The editor uses a frozen source snapshot to preserve a draft if files change.
  Fresh testing and saving check the current structural fingerprint. Reload
  explicitly refreshes scene dependencies.
- Preview mode suppresses processing, collision interactions, game UI/audio and
  relevant startup signal connections. Do not assume a paused tree blocks signals.
- Undo holds document snapshots, not disposable runtime nodes, and retains up to
  80 completed actions. Rebuilds replace generated platform/spike children;
  painting a different template replaces that tile instance while keeping its ID.

Inspect all effective layouts through the runner:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Headless -Script res://tools/inspect_level_layout.gd
```

Read `build/level_layouts_resolved.json` before changing a registered section.
Focused contracts are `validate_level_layout.gd`, `validate_level_designer.gd`,
`validate_green_zone_catalog.gd`, and `validate_level_object_browser.gd` (typed placement/save/reload, real
combat/checkpoints/hazards, and frozen previews in every registered section).
Use `capture_level_designer.gd` with `-Visual` for the real interface at 1080p
and 720p. `capture_green_zone_catalog.gd` captures the zone browsers and a
temporary tile-building example, leaving the sandbox empty. The regular
validation suite includes all four contracts. The accepted checkpoint passed
46/47 checks in 293.2 s; the sole failure was the Level 2 route bot, retired
at the user's request on 2026-09-15. See README for current validation status.
`validate_enemy_friendly_fire.gd` separately covers
placed-enemy firing discipline, damage, live bullets after defeat, and reset.
The user accepted both the designer and friendly-fire gameplay.

The `LayoutSmoke` export preset includes layout JSON and curated production
resources while excluding the source-art catalog. It is a validation preset,
not a distributable release setup. Pack exports and pack reloads also go through
the supervised standard-engine runner. MainPack runs use an isolated directory
so missing pack assets cannot fall back to the source checkout:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Headless -Script res://tools/prepare_level_layout_probe.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Headless -Script res://tools/probe_level_layout_reload.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -ExportPack build/level_designer_smoke.pck -ExportPreset LayoutSmoke
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Headless -MainPack build/level_designer_smoke.pck -Script res://tools/probe_level_layout_reload.gd
```

The preparation script refuses to overwrite an existing fixture save. Remove
only its generated `resources/level_layouts/designer_fixture.json` after the
reload/export checks, before running the normal suite. Keep the user's sandbox
and Level 3 JSON files intact.
