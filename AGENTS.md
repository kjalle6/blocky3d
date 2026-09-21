# Godot automation

Use the standard non-.NET Godot 4.6.3 build with Compatibility. This project
contains no C#. Native access violations have occurred with both Mono and
standard builds; their shared cause remains unproven. MCP does not establish
that those crashes are fixed.

## Editor and playtests

- Use Godot MCP for normal editor inspection, editing, game start/stop, input,
  and screenshots. Start the main game with `game_start(scene_path="main")`;
  the editor's F5/F6 lifecycle owns these playtests. Inspect runtime logs after
  testing and after an unexpected disconnect; a started process is not proof
  of a successful playtest.
- Reuse the open project editor. If it needs opening, use
  `tools/run_godot_tool.ps1 -Editor`. This retains real-process supervision and
  logging, uses the normal Windows profile, and does not hold the standalone
  automation lock. See `docs/GODOT_MCP.md` for connection details.
- Keep GUI launches visible to the user. In a restricted command environment,
  request desktop/GUI permission for the runner invocation. A zero
  `MainWindowHandle` does not prove that no window exists; user confirmation
  is authoritative.
- Preserve running Godot processes by default. For exclusive access, the user
  has authorized `-CloseRunningGodot` without another permission question.
  It closes Godot processes gracefully first, forcibly if necessary. Preserve
  unsaved scene edits before using it. Do not close the editor just to run an
  unrelated focused validator.
- Live screenshots and input tests complement focused validators; they do not
  establish user acceptance of visual or audio choices.

## Standalone automation

- Use `tools/run_godot_tool.ps1` for validators, imports, exports, dedicated
  capture scripts, and standalone game/pack probes. Do not launch a Godot
  executable directly for these jobs or switch the runner to Mono.
- These modes keep an isolated, writable profile and saves, per-run logs,
  `Start-Process -Wait` supervision of the real non-console executable, and an
  exclusive lock between standalone runs. The editor and its MCP playtests
  use the normal profile and do not take that lock. Avoid simultaneous project
  mutations or imports; the lock does not coordinate editor edits.
- Preserve the runner's `SCRIPT ERROR` failure check: Godot can exit 0 after a
  failed assertion. The console launcher alone also cannot reliably report a
  delayed native crash.
- `-Headless` is opt-in for contract checks. It was an early repeatable native
  crash trigger, so drop it first if faults recur. It does not speed up
  simulation-bound validators and cannot verify rendered appearance.
- Use `-Visual` for dedicated graphical capture scripts and rendered probes.
  Use MCP screenshots for ordinary live review. Do not combine `-Headless`
  with interactive, import, or visual modes.
- After renaming a `class_name` script or its file, refresh the class cache
  through `-EditorImport`; use `-CloseRunningGodot` if an open editor holds the
  old registry. Import must use dedicated `--import`, never `--editor --quit`,
  which can exit with import workers unfinished.
- The full `assets/library` catalog stays visible for search and auditioning.
  Promote selected production assets into `assets/art`; catalog availability
  does not make every pack a runtime dependency. Asset volume and concurrent
  processes are not proven causes of the unresolved native crashes.

Canonical examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_validation_suite.ps1
powershell -ExecutionPolicy Bypass -File .\tools\run_validation_suite.ps1 -Scope All -Headless
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_project.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_arrival_shoreline_slice.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -EditorImport -CloseRunningGodot
```

## Running the validators

Use `tools/run_validation_suite.ps1` rather than looping over `validate_*.gd`
by hand. It runs every validator and reports a single pass or fail rather than a wall
of output. On 2026-09-15 the user requested removal of the scripted Level 2
full-route playthrough: maintaining its automated input sequence was not useful.
Do not restore that bot or carry its old stage-10 death as an outstanding bug.
Keep focused movement, ability, Level 2 structure, and transition checks;
hands-on playtesting owns the complete Level 2 route.

The suite contains 56 validators, including focused inventory UI, ammunition,
and campaign/designer chest loot checks.
All 54 then-existing validators passed in the 2026-09-21 windowed run
(426.7 seconds), before moving the independent shaft-containment stress test
out of the suite at the user's request. Its removal does not need another full
run. The new inventory UI check and existing item reward check passed separately
after the inventory presentation work. Timing and test count are checkpoint
observations, not limits.

`tools/probe_shaft_containment.gd` is opt-in only. It repeats four ten-second
jump/dash attempts against the Level 2 machine shaft to check for an escape;
it is not a cave playthrough. Run it only when changes to that shaft or movement
rules could allow an escape. Do not include it in routine suites or combat work.
For isolated enemy behavior changes, prefer the relevant focused combat checks
and an MCP playtest; sharing an enemy script across levels is not by itself a
reason to run unrelated cave, audio, background, and authoring checks.

It still takes a `-Scope` switch even though only `All` exists today. The six
prototype levels used to be a separate scope worth skipping, at roughly 60% of
a full run; they are deleted, and the switch is kept because a slow set will
almost certainly reappear.

`tools/probe_level_2_background_jump_drift.gd` is deliberately outside the
suite. It drives one real jump and samples after `frame_post_draw`, so it needs
a rendering context: run it with `-Visual`. Headless it cannot work, and it now
says so and exits rather than hanging on the automation lock.

`tools/probe_level_2_wall_jump_camera_focus.gd` is outside the suite for the
same reason. It drives repeated real wall jumps and measures rendered player,
camera, and ceiling motion; run it with `-Visual`, never headless.

Run the suite when a change could plausibly reach what it covers, not as
reassurance. Two full passes in a row, the second confirming what the first
already proved, is wasted time whether or not it opens windows.

## Layout export checks

The runner also owns `-ExportPack` (with `-ExportPreset LayoutSmoke`) and
`-MainPack` probes. Keep both on the same supervised standard engine and
exclusive lock. Pack paths stay inside `build`; MainPack probes use a separate
working directory so missing resources cannot fall back to the source checkout.
`LayoutSmoke` is a validation preset, not a release configuration. Commands and
fixture cleanup rules are in `docs/LEVEL_DESIGNER.md`.

Before changing registered scene sections or structural layout dependencies,
run `tools/inspect_level_layout.gd` through the runner and read the resolved
layout report. Preserve project layout JSON and local recovery drafts. Do not
rewrite fingerprints or discard user overrides merely to make validation pass.

## Project documentation and handoffs

Start with `README.md` and the relevant task guide. Keep durable project
decisions in those documents and planned campaign work in `docs/LEVEL_ROADMAP.md`.
There is no standing handoff file. Only create a handoff when the user requests
one for a chat transition; write a fresh, task-specific snapshot of current
Git state, remaining work, constraints, validation, and next actions. Link to
existing docs instead of copying their history. Do not accumulate a new
permanent conversation log under the name of a handoff.
