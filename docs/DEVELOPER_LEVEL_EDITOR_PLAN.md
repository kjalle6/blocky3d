# In-game level designer: implemented scope and build plan

Accepted checkpoint: `e620abb` (2026-09-12), including the designer, its
block-building/browser follow-ups, and enemy friendly fire. Use Git for any
newer changes.
The first version is complete. The stages below record its original build and
acceptance contract, with the approved expansions here taking precedence.

The current workflow is **Build → zone → block**, with a persistent click/drag
brush until right-click/Esc/Select and one Undo per stroke. Existing rectangular
platforms remain editable/loadable; their creation cards and Draw platform tool
are retired. Green Zone offers 96 tiles, 78 static props, and 5 animated props;
Beach offers six sand pieces. Background selection remains deferred.

Both the picture-card browser and quick sidebar support search, categories,
and zones. Prepared enemies, hazards, checkpoints, and scenery can be added in
every registered game section/lab. Single sidebar clicks and browser double-clicks
start previews. The accepted right-click menu provides object and general actions.
This expands the original v1 scope on individual blocks and prepared additions;
scripted assemblies, camera controls, and arbitrary prefabs remain outside it.

The empty sandbox is menu **7**; seven original Level 3 outdoor objects are
registered for editing under menu **5**. Per-section saved data, frozen previews,
separate fresh testing, document undo, verified saving/conflict checks, backups,
and compatible recovery are implemented. Production layout saves are still
user-authored, and no automated fixture was left in the sandbox.

All four designer/layout/browser/catalog validators, fresh-process reload, and
isolated exported-pack loading pass. UI/placement captures were reviewed at
720p/1080p. The final suite, including friendly fire, passed **46/47** in
293.2 s; the sole failure was the Level 2 route bot, subsequently retired at
the user's request on 2026-09-15. No native fault occurred. Saved audio was
unchanged at that checkpoint. See
[the current user guide](LEVEL_DESIGNER.md) for controls and
[the saved-layout notes](../resources/level_layouts/README.md) for preservation.

Further features are optional future work, not hidden completion requirements.
Enemy friendly fire is a shared combat rule used by placed enemies, not a new
designer setting: gunners wait for clear teammate lanes; released bullets stay live.

## 1. Purpose and working arrangement

Build a dependable tool for the adjustments the user wants to make repeatedly
while playing: object placement, platform spacing and size, simple platform
creation, and walking-enemy patrol limits.

The user and Codex design the level idea together. Codex builds the first
playable version with its camera, transitions, checkpoints, and scripted
encounters. The user fine-tunes supported parts through the designer. Codex
continues from the saved result and handles larger structural changes.

All scripted behaviour stays with Codex. Camera composition, cave construction,
complex terrain joins, and coordinated hazards are also work to do together.
The user expects few, if any, further caves, so a cave-painting tool is a poor
priority for this version.

## 2. First-version scope

The user will be able to:

1. Move supported platforms, enemies, spike rows, and approved ordinary
   trigger/checkpoint assemblies.
2. Resize supported platforms and simple trigger areas.
3. Choose a prepared terrain style and create simple rectangular platforms.
4. Set walking-enemy starting position, direction, speed, and patrol limits.
5. Select several supported objects and move them together.
6. Test the working layout, undo/redo, revert, and save permanently.

Support is explicit per object and section. Select the whole gameplay object,
including its matching visual and collision components. Do not expose every
node, sprite, resource, or arbitrary script property.

### Support boundaries

| Object | First-version controls | Protected parts |
| --- | --- | --- |
| Independent rectangular PixelPlatform3D | Position, whole-tile dimensions, prepared style, footstep surface, supported edge caps | Scripted supports and special shoreline joins are locked unless separately audited. |
| New rectangular platform | Create, resize, move, duplicate, remove | Uses approved assets and parent groups; no arbitrary texture/script import. |
| Walking enemy / skater | Authored spawn, initial direction, speed, left/right patrol limits | Attack settings, animation timing, advanced movement, and scripted encounters stay with Codex. |
| Ordinary spike row | Position and width | Preserve damage inset/height/timing; regenerate the matching art and damage shape together. |
| Existing ordinary checkpoint or unlinked box trigger | Position and supported activation-area size | Trigger purpose, checkpoint ordering, progression, and scripted targets remain fixed. |
| Other enemy or hazard | Position only if a dedicated registration confirms safe reset behaviour | Otherwise visible but locked; additional object support is added when needed. |
| Connected cave/underground terrain | Visible context | Whole terrain grid, its cells, origin, seams, and dimensions remain with Codex. |
| Camera/background/audio regions, route bounds, kill planes | Existing presentation remains in use | No authoring controls or automatic resizing in this version. |
| Cutscene, transition, lift, linked cover, or gun pickup | Visible locked assembly | All scripted relationships and their required support geometry remain protected. |
| Decorative props | Visible context | No assumption that a nearby prop should automatically follow a moved platform. |

Removal or duplication of existing objects is allowed only where registered
as independent. Creating platforms is in scope; creating new enemies,
checkpoints, or arbitrary trigger logic is not required for this first version.

### Explicitly deferred

- Cave cell painting, tunnel excavation, and resizing whole terrain grids.
- Comprehensive route, camera-coverage, encounter, or terrain-seam diagnostics.
- Detailed flyer bob/sweep controls, hazard phase/timing controls, endpoint
  pauses, or advanced enemy navigation.
- Support for every object in every level before the first version is usable.
- Editing scripted sequences, camera choreography, or background/audio zoning.
- General scene/resource editing, arbitrary asset import, and custom-level
  sharing or authoring in exported games.
- Automatic merging of conflicting layouts, a full recovery/history manager,
  and automatic baking of designer data back into scene files.
- A Godot editor preview bridge, direct F6 authoring support, and comprehensive
  embedded-game-view support. The established separate game window comes first.

These are possible later additions only. Do not build their infrastructure
unless a concrete first-version requirement needs it.

## 3. Editing workflow and interface

### Entry and layout

Add **Level designer** to the existing F1 tools menu. Use a visible button
rather than taking another function key. Preserve the existing F7/F10/F11
controls in normal gameplay; F8 remains Godot's stop-game control.

Use **Level Designer Sandbox** (menu shortcut **7**) for hands-on building and
layout experiments. Its scene is `scenes/dev/level_designer_sandbox.tscn`, with
definition `resources/dev/level_designer_sandbox.tres`: a 256-tile-wide grass
floor, 128 tiles of vertical camera travel, and all movement abilities. The
existing F10 grid, F11 free flight, and R reset already work. The foundation
and spawn provide a safe starting point; keep the foundation protected when
registering editable objects. Leave this workspace empty until the user builds
in it. The older cave-based Level Design Lab stays separate.

Keep a small disposable fixture for automated object/save/reset checks, then
enable ordinary objects in Level 3's outdoor traversal as their support passes
validation. Other sections can show **Designer not enabled for this section
yet**. We do not need to expose partially working controls in the shooter
cutscene or the cave to finish v1.

The Editing view shows the intended layout, including the spawn positions of
walking enemies defeated or moved during the previous run. A compact toolbar
contains Select, Move, Build platform, Undo, Redo, Test, Save, Revert, and Close.
A collapsible side panel contains an object list, category filters, properties,
and short status messages. Do not show a raw Godot node tree.

### Selection, drag, numeric edits, and groups

- Hover highlights a candidate; clicking selects it with an outline and name.
- Repeated selection or a small overlapping-object chooser resolves overlaps.
  Invisible triggers remain selectable from the object list.
- Pick using projected authoring bounds. Paused physics and decorative depth
  layers make a physics-only picking system insufficient.
- Drag the object or an axis handle. A movement threshold separates clicks from
  drags. Arrow keys nudge only when the canvas has focus.
- Numeric position/size fields provide exact adjustments. Validate on commit;
  incomplete typing must not move or resize the object.
- Shift-click adds to a selection. A group move preserves each member's offset
  and transforms each complete object exactly once.
- Resize handles keep the opposite edge fixed. For example, raising a platform
  top must not unintentionally lower its bottom.
- Esc cancels an active operation first, then clears selection. Closing the
  designer is explicit. Text fields consume typing and shortcuts.
- One completed drag, resize, or property edit creates one undo command.
  Cancelling an operation produces no history entry or dirty-state change.

### Camera, cursor, and snapping

Use an independent editing camera with middle-button pan, wheel zoom, and a
**Frame selection** button. It must not move the player, grant abilities, or
change the saved gameplay camera. F11 is not the editor camera controller.

Use viewport mouse coordinates, the actual viewport stretch, and projection
to the gameplay plane. The panel must not introduce a pointer offset. Validate
1920x1080 and 1280x720 separate windows and ordinary resizing. Do not claim to
fix the previous embedded-game-view offset as part of this feature.

Offer full-tile, half-tile, and fine/pixel position snapping. Existing platform
art uses 1.28-world-unit tiles and 0.04-world-unit pixels. Platform dimensions
stay whole tiles; actor/trigger movement may be unsnapped. Preserve authored
half-tile offsets. Selecting or opening an object must never snap it by itself.
Snap relevant edges rather than blindly rounding a platform centre.

Keep ordinary layout editing on X/Y. Preserve visual depth, rotation, and
scale. Unsupported transformed parents stay locked. When the edit camera
moves, refresh the required presentation explicitly rather than unpausing
all gameplay to update the background.

## 4. Platform creation and patrol controls

### Platforms

Use prepared grass and sand platform styles already present in the project.
The palette can grow later. Connected rock terrain is not part of this tool's
first palette; changing existing cave rooms remains work for Codex.

Dragging a rectangle previews its footprint and tile dimensions. Confirming
creates a solid platform with a new stable ID, an approved parent, and the
chosen footstep surface. Include duplicate/remove for platforms created by the
user, with exact undo. Register removal of existing platforms individually.

Artwork and collision must come from the same dimensions. Refactor the current
platform builder into a repeatable refresh operation that only replaces its
generated children. Preserve authored children and avoid accumulating duplicate
sprites/shapes on repeated edits. Keep styles shared as immutable assets;
per-platform surface overrides must not alter other platforms using that style.

Support standalone rectangles and the existing complete-edge cap controls.
Do not invent a general auto-joining terrain system. Complex partial-height
joins are a layout/art decision to handle together.

### Walking enemies

Show an authored spawn marker, initial-direction arrow, and left/right patrol
handles. Each side has **Automatic edge/wall turn** or **Fixed limit**. The
current code uses zero distance for automatic behaviour, so distinguish it
from a literal zero-width lane in the UI.

Move the spawn and its fixed limits together. Moving a limit handle changes
that side's distance. Preserve ordinary wall/ledge detection. The drawn range
shows requested patrol bounds, not proof that the entire range is navigable.

Apply edited positions before the enemy caches its spawn. Death, restart, and
fresh load must all use the new spawn and limits. No new jumping, climbing,
attack behaviour, or endpoint-pause system is needed.

## 5. Layout data and permanent saving

### Chosen storage model

Keep existing scene files as the structural base: scripts, connections,
composition, and properties the designer does not own. Store supported edits
in one versioned, readable JSON file per registered scene section under the
proposed resources/level_layouts directory.

The effective layout is **base scene plus saved layout edits**. Saved edits
are authoritative for the properties they override. The game, test fixtures,
and Codex's inspection/authoring workflow must use the same resolver.

This avoids packing a running game into the source scene and accidentally
saving defeated actors or current patrol positions. It also preserves scene
inheritance and avoids overwriting a scene open in the Godot editor on Save.

Tradeoff: Godot's ordinary scene view initially shows the structural base,
not automatically the resolved placements. The game/designer shows the actual
saved layout. Document this clearly; Codex must read the resolved layout
before changing a registered section. No automatic bake or editor bridge is
required for v1.

### Identity and schema

- Each registered section gets a stable section ID and explicit layout path.
  Separate Level 3 sections keep separate layouts and shared progression identity.
- Each opted-in placed object gets a stable ID in scene metadata. Its ID belongs
  to the placed instance, not to a shared enemy prefab or mutable node name.
- Node paths are diagnostic hints. Renames must not apply old edits to another
  object with the same name. Duplicate generates a new ID.
- Store schema version, section ID, revision, structural dependency fingerprint,
  approved object overrides, expected base values, created-platform records,
  and permitted removal records. No terrain-cell schema is required.
- Serialize in stable order with consistent numbers. Reject unknown properties,
  missing/duplicate IDs, incompatible versions, non-finite values, invalid
  sizes, and unapproved prefab/style choices.
- Selection, zoom, undo history, test starts, warnings, and all temporary
  gameplay state are excluded from the production layout.

One-time registration must preserve the original layout. An empty saved
layout must not change geometry, references, or gameplay behaviour.

### Loading before initialization

Use one LevelLayoutResolver to validate and apply the layout to a fresh level
instance before its children initialize. Apply working drafts through that
same path when testing. Validate the complete document before changing nodes;
report failure instead of partially applying it or silently ignoring it.

This must cover the supported normal main-project launch, campaign/developer
entries, section transitions, and relevant validation fixtures. Guard any
unsupported direct scene launch against silently presenting a different layout;
full direct-F6 editor support is deferred, not a prerequisite for v1.

Applying edits only in the parent's ready callback is too late: children have
already generated terrain and cached spawn positions. Preflight before adding
the level to the tree and use a checked early-lifecycle integration where needed.
Verify the actual ordering in the foundation stage.
[Godot node lifecycle](https://docs.godotengine.org/en/4.6/classes/class_node.html#description).

Read saved layout files afresh on document reload. When a base dependency
changes, deliberately refresh it rather than trusting a stale cached scene.
Isolate mutable collision shapes before changing them; modifying a shared
resource must not resize another trigger or a second instance.
[Godot resource sharing](https://docs.godotengine.org/en/4.6/classes/class_resource.html#class-resource-property-resource-local-to-scene).

### Save reliability without a large management UI

1. Complete/cancel the active edit and validate the working document.
2. Acquire a short cooperative section-save lock and recheck the saved
   revision/hash and relevant base fingerprints. A stale document does not save.
3. Write a temporary file beside the destination, flush/close it, then reload,
   parse, and resolve it against a clean base instance. Check the result.
4. Keep the previous valid save as a local backup, replace the destination with
   the verified file, and verify the final result. Preserve the previous file
   if a write/replace fails. Do not delete the original first.
5. Mark the working document saved and release the lock only after success.

The first implementation stage tests the intended Windows file-replacement
and lock behaviour. The available API is not proof of power-loss guarantees.
[Godot file operations](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html#class-diraccess-method-rename).

A conflict offers **Reload saved** or **Keep draft for review**. Keep the user's
work intact and let Codex reconcile it. Do not add automatic merging, complex
history browsing, or a silent force-overwrite path. Two game windows must not
silently overwrite each other's saves; external source edits still require
coordination and a fresh fingerprint check.

Maintain a bounded, debounced local recovery copy of completed edits. Recovery
is a simple offer to restore a compatible draft, not automatic promotion to
production. This matters because Godot/F8 can stop the game without a normal
close handler. A full recovery manager is unnecessary.

Revert returns to the last successful save. Closing or switching away with
unsaved edits offers Save / Discard / Cancel. Never auto-commit or push.

Project saving is supported only in the writable development checkout. Ordinary
exported games must load the saved layouts and required palette assets while
keeping authoring controls disabled. Include the JSON files in exports, but do
not build an exported-game editor or sharing system.
[Godot data paths](https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html#accessing-persistent-user-data-user).

## 6. Editing and testing have separate state

A controller outside the level owns **Closed**, **Editing**, **Testing**, and
**Saving** states, plus the working document, selection, camera, and undo history.
Do not keep undo operations bound to runtime nodes that a test can free.

Editing renders a clean instance of the intended layout in an explicit preview
purpose. It uses real generated terrain/art and authored actor positions, but
suppresses damage, pickups, progression, scripts, and gameplay audio. Audit
initialization as well as processing: pausing alone does not prevent signals
from invoking callbacks.
[Godot pausing behaviour](https://docs.godotengine.org/en/4.6/tutorials/scripting/pausing_games.html#process-modes).

Reuse presentation construction with narrow preview guards for side effects.
If an assembly cannot be previewed safely yet, keep that section disabled.
Do not build a duplicate gameplay simulation or a generic sandbox engine.

**Test** creates a fresh normal attempt from the working document. Returning
to Editing discards that test and restores the editable layout and history.
A defeated or wandering enemy never changes the layout document.

Initially test from the section's normal start. A temporary **Test here** marker
can follow when useful for the first supported section, with basic clearance
and support checks. It must not move the production spawn. Scripted areas keep
approved entry points; the tool does not skip their required setup arbitrarily.

Test abilities, weapons, and checkpoints remain session-local. Death/R behave
normally within the test. No campaign progress is written. Same-level transitions
preserve their normal policy without rebinding source edits to a destination
section. Provide a way back to the original editable section.

Do not enter the designer mid-cutscene, fade, or incomplete death reset. Explain
when the sequence must finish first. Closing the designer starts an ordinary
fresh run from the saved layout after resolving unsaved changes; it does not
promise exact continuation of a frozen fight.

Coordinate pause/input ownership with the audio panel. Only one editor panel
owns the interaction at once. Preserve its existing unsaved audio mix without
saving or reverting it. Clear transient shot/reverb tails when discarding a
test, release held gameplay inputs, and restore cursor/time-scale state.

## 7. Implementation structure and basic checks

Keep data, saving, runtime application, object support, and UI separate, but
avoid creating a general plugin framework.

| Proposed component | Responsibility |
| --- | --- |
| level_layout_document.gd | Base/saved/working data, schema checks, stable IDs, dirty state. |
| level_layout_resolver.gd | Validate and apply saved/draft layouts before initialization. |
| level_layout_store.gd | Fresh loading, save lock/revision checks, verified replacement, simple backup/recovery. |
| Small section/palette registry and object adapters | Approved objects/properties/parents, selection bounds, application and refresh rules. |
| level_designer.gd | Mode controller, document/undo lifetime, test reconstruction, close/conflict flow. |
| level_designer_panel.gd and overlay | Toolbar, object list, properties, palette, handles, patrol bounds, edit camera. |
| Shared developer-tool ownership helper | Coordinate the designer and audio panel without competing pause/input state. |
| Layout inspection, validators, and capture tools | Same resolved data for Codex, persistence/integration checks, real visual evidence. |

An adapter is a small object-specific contract, not a generic resource inspector.
It owns approved properties, bounds, constraints, preview refresh, and allowed
creation/removal. Existing integration points are GameRoot loading/freeing,
LevelSession3D initialization/test policy, the rectangular platform builder,
spike builder, and the relevant actor/trigger handlers.

Use document-level UndoRedo commands containing IDs and before/after values.
A group move is one action. Keep history bounded and compute dirty state against
the saved document content. Test reconstruction must not clear history.
[Godot UndoRedo](https://docs.godotengine.org/en/4.6/classes/class_undoredo.html).

Preserve parent/local transforms correctly. Do not move a whole parent and its
child twice. Keep unsupported scaled/rotated assemblies locked. Do not silently
move nearby props or attach enemies to moved platforms; group selection is explicit.

Validate required links before allowing deletion. Audit registered objects for
NodePath, signal, and known script dependencies rather than claiming automatic
analysis can understand every script. Unsupported scripted assemblies remain locked.

Provide only basic feedback: invalid dimensions/values, forbidden edits, stale
saves, missing required references, and obvious unsupported actor/checkpoint
placements where reliably detectable. Show useful selection/collision outlines.
No comprehensive route solver, camera advisor, or automated encounter critique.
Camera/background changes continue to be reviewed with Codex.

Keep dragging cheap: projected outlines during movement, no disk I/O or full
terrain rebuild per mouse event, then one object refresh at commit. Index
registered objects rather than scanning generated tiles every frame. Profile
against the same scene/camera and check repeated edit/test cycles for accumulating
nodes, signals, audio voices, and history. Keep the UI responsive at the existing
presentation sizes; measure before deciding whether more optimization is needed.

## 8. Build order and acceptance gates

### Stage 1: fixture, registration, and permanent-save proof

Build a small dedicated test fixture with an independent rectangular platform,
walking enemy, spike row, and ordinary checkpoint/trigger. Reuse known production
assets and keep accepted level layouts unchanged. Keep test objects out of the
user's empty sandbox. Register stable IDs and an empty section document.

Implement the document, early resolver, and verified storage for basic movement
first. Audit supported load paths and resource sharing. Test saved and unsaved
drafts, fresh-process loading, base conflicts, competing saves, failed writes,
and backup preservation.

**Gate:** move a platform, enemy, and trigger; test; save; close/reopen the game;
confirm collision, trigger function, and enemy spawn/patrol after death/R.
An empty layout changes nothing. Do not expand the interface until this passes.

### Stage 2: usable selection, movement, undo, and testing

Add the F1 entry, clean authoring preview, independent camera, object list,
selection/grouping, drag/nudge/numeric positions, snapping, Undo/Redo, Test,
Save, Revert, and close flow. Coordinate input/pause with audio tuning.

**Gate:** the user can move the fixture objects through the UI, test, undo,
save, and reopen without supplying coordinates to Codex. Defeating an enemy
in a test does not remove it from the edited layout. No unwanted audio or
progression writes occur while editing.

### Stage 3: simple platform building, resizing, and walking patrols

Add repeatable platform/spike rebuilds, anchored resize controls, the prepared
grass/sand palette, rectangular platform creation, permitted duplicate/remove,
and surface settings. Add walking patrol handles, automatic/fixed limits,
starting direction, and speed. Add approved ordinary trigger sizing.

**Gate:** build a short platform sequence in the empty sandbox, walk/jump on it,
and confirm its surface sound. In the populated fixture, tune a patrol and resize
a spike row/trigger. Undo and save/reload restore exact intended results. A shared
resource never leaks an edit to another object.

### Stage 4: first actual level section and usability finish

Register ordinary Level 3 outdoor traversal objects as each adapter passes.
Keep underground terrain and scripted assemblies locked. Do not register every
other section as a prerequisite. Additional sections are enabled when useful.

Verify normal loads, relevant section transitions, the distinct gun-entry
identity, close/revert behaviour, compatible draft recovery after forced stop,
viewport resizing/cursor alignment, and repeated edit/test cleanup. Write a
short user guide and resolved-layout authoring notes. Check a test export loads
saved data with authoring UI disabled.

**Gate:** the user can fine-tune a real supported section, save it, reopen it
through the normal game, and have Codex continue from the same result. Clearly
identify unsupported objects/sections. Do not label v1 unfinished merely because
a deferred feature remains absent.

These are logical checkpoints, not calendar estimates. Show usable milestones
for hands-on feedback. A successful validator does not establish good controls
or approve the user's route design.

## 9. Required validation

| Area | Evidence required for v1 |
| --- | --- |
| IDs and sections | Root rename harmless, duplicate gets a new ID, edits never apply to another section. |
| Early application | Supported loaders initialize geometry and spawn caches from saved/draft placements. |
| Geometry | Art/collision agree after resize; no selection-time snapping or duplicate generated children. |
| Edit/test separation | Defeated/wandering actors and activated checkpoints never become layout edits. |
| Reset | Death, R, checkpoints, and fresh loading respect edited positions and test progression policy. |
| Saving | Fresh-process reload, stale base/layout detection, competing save, failed write/replace, compatible recovery, previous save preserved. |
| Undo and grouping | Move/resize/create/remove/group actions round-trip across tests; cancel is a no-op. |
| Input and coordinates | Overlapping/invisible objects selectable; no typing/attack leakage; separate-window pan/zoom/resize aligns correctly. |
| Existing systems | Saved movement/audio mix preserved, surface settings work, scripted sequences protected. |
| Resources and performance | No shared-resource mutation leaks or growing node/voice counts across repeated edits/tests. |
| Export | Saved JSON and assets included; ordinary game loads the layout; authoring controls hidden. |

Run scoped tests when their contracts change. Shared loader/session/geometry
changes justify a full validation sweep at integration milestones, not after
every small UI adjustment. See README for current validation status. The user
retired the scripted Level 2 full-route bot on 2026-09-15; retain focused checks
and hands-on route review. Other route-specific tests may need deliberate
revision after a user-approved geometry change;
never alter them automatically merely to make a new layout pass.

All Godot launches use tools/run_godot_tool.ps1. Use -Visual for captures and
tools/run_validation_suite.ps1 for a full sweep. Refresh the generated class
registry through -EditorImport when required. Preserve the user's Godot processes
unless exclusive access is necessary. Check the then-current worktree and saved
audio before implementation; never reset, auto-commit, or overwrite newer work.

## 10. Completion boundary

The first version is complete when the included controls work in the fixture,
the sandbox supports platform-building experiments, and the first registered
real section supports edit/test/undo/save/fresh reload, with correct collisions,
actor resets, and clear locks for unsupported content.

Saving correctness, state separation, reliable undo, and correct gameplay
geometry are essential. Cave painting, broad diagnostics, complex hazard tuning,
universal object support, and additional launch-mode polish are not.

Implementation has passed the early-initialization and Windows replacement
proof, integration checks, and user hands-on acceptance. The first version and
approved follow-ups are complete; only concrete feedback or a new request
should start additional tool work.
