# Visual QA workflow

One inspector provides a second look at the rendered game. The primary agent
implements scoped fixes; the inspector verifies them. These are stages, not
three permanent agents or installed slash commands.

The project agent definition is
[visual_inspector](../.codex/agents/visual_inspector.toml). It inherits the
session's model and tools. Its no-edit boundary is an instruction, not a
technical restriction on all MCP tools. Use the same prompt and this guide
when a client only exposes general subagent delegation.

Example requests:

- "Inspect Level 3 upper gunners for misplaced cover and wrong tiles. Report only."
- "Fix VQA-01 using the smallest change that addresses the finding."
- "Have the visual inspector verify VQA-01 and the adjacent landing."

## Before taking control

1. Receive the area/route, inspect or verify stage, changed files, relevant
   references, and explicit Godot-control handoff from the primary. Do not
   spawn other agents. Read [AGENTS.md](../AGENTS.md), [visual rules](VISUAL_RULES.md),
   and [Godot MCP](GODOT_MCP.md). Choose a short route if none was specified.
2. Record Git status, active edited scene, whether a playtest is running, and
   the starting game scene/mode where available. Preserve dirty work and unsaved
   editor scenes. Do not save, reload, or discard an edited scene to inspect it.
3. Reuse the editor. If it is closed, have the primary open it with the approved
   runner. Start the main game through MCP using `scene_path="main"` and reuse
   an existing suitable playtest with `if_running="return"`. Use the development
   selector's fresh runs, which avoid campaign progression writes. Do not operate
   a user's active campaign run; return that limitation to the primary.

## Inspect

1. Load the selected development entry and confirm the live scene. Check current
   runtime nodes and applied layout state: the base `.tscn` alone may omit layout
   overrides or runtime-generated pieces. References and route coordinates below
   are orientation aids; recheck them against the current run.
2. Inspect the approach, object, and nearby exit at normal gameplay camera scale,
   with inspection overlays off. View actual full-resolution screenshots, not
   only returned file paths. Move through the area with short input sequences
   and explicit releases. Observe relevant idle, attack, and movement states.
3. Use [the checklist](VISUAL_RULES.md#checklist). Capture a clean normal view
   before any diagnostic overlay. Save evidence through `runtime_screenshot`
   with disk/both mode; it writes under `user://screenshots/`. Return the actual
   absolute paths. Evidence images and a requested report are the only allowed
   new artifacts; do not build an export or capture pipeline for an ordinary pass.
4. Investigate suspicious objects with targeted runtime/editor reads: scene/node
   path, texture or atlas region, visible bounds/padding, transforms and parents,
   collision, sprite scale/filter, depth/order, material, and animation as relevant.
   Activate only needed MCP tool groups. Use `execute_code` only for read-only
   queries or an explicitly scoped existing development navigation control.
5. F7 collision and F10 grid overlays, pause, and F11 free flight can help diagnosis.
   F11 changes collision, camera constraints, and session abilities: turn it off
   and return to safe ground for ordinary gameplay evidence. Reload the fresh
   development entry when genuine unlock state matters. Label free-flight,
   paused, zoomed, or overlay captures; they do not prove route reachability,
   combat fairness, pacing, or normal framing. Never change the camera resource
   to get a better-looking report. Editor-only viewpoint changes are fine if they
   do not dirty a scene. Do not toggle persistent node visibility/properties.
6. Compare with the applicable rule or explicitly approved reference. Investigate
   a visible mismatch before asserting its cause. For example, report a measured
   world-space gap separately from screenshot pixels; account for sprite padding,
   parent transforms, viewport scaling, and projection before converting units.
7. Finish the bounded route. No minimum finding count. If tools disconnect, inspect
   logs and report partial coverage rather than silently substituting source-only
   analysis. Do not install tooling, alter the project, or run validators to make
   an inspection pass succeed.

## Report and return control

Start with coverage: scene/entry, route stops visited and missed, ordinary-play
versus diagnostic-only observations, reference status, and runtime log result.
For each finding supply:

- Stable ID (`VQA-01`), severity, and confidence. High: materially misleading
  hazards/cover or hidden necessary gameplay; medium: clear local defect; low:
  minor visible seam/contact/artifact with limited impact.
- Scene, identifiable runtime/editor node and source path; otherwise give a
  reproducible location without guessing a node name.
- Screenshot path and where to look, reproduction steps/viewpoint, observed
  behavior, and the rule/reference or gameplay cue that makes it likely unintended.
- Relevant measured properties, distinguishing confirmed cause from hypothesis.
- Smallest suggested fix and how to verify it. Do not implement it during inspection.

Keep unresolved checks separate and concise. "No evidenced issues in the inspected
area" is valid; "the level is visually approved" is not. Mention existing known
issues only when reproduced, and avoid duplicate reports for the same cause.

Release all inputs, restore temporary diagnostic toggles, and read runtime logs
after the pass or unexpected disconnect. Stop a playtest you started unless the
primary requested it remain available for user review; preserve a pre-existing
playtest. Restore the prior editor tab when safe. Report remaining scene/mode,
any unreverted temporary state, Git status changes, and hand Godot control back.
Never revert an unexpected file change automatically.

## Fix and verify

The primary evaluates the evidence and fixes only issues within the user's
authorized scope. A report-only audit ends with the report. Layout fixes retain
the required resolved-layout inspection and override/recovery protections in
AGENTS.md. Finish edits before handing Godot back to the inspector.

For verification, repeat the same location, gameplay state, camera scale, and
relevant movement. Capture the result and check nearby contact, collision cues,
and approach/exit for regressions. Mark each ID resolved, still present, or
unverified with evidence. Passing focused validators complements this pass;
player acceptance remains separate.

## Initial repeatable routes

These routes are authored from current scenes and documentation. They are
inspection recipes, not completed audit results or new automated playthroughs.

### Level 3 first cover

- Entry: development selector **Level 3 - Gun encounter**, defined by
  `resources/dev/green_zone_finale_wip.tres`, entry ID `gun_encounter`.
- Scene: `scenes/dev/green_zone_finale_shooter_area_wip.tscn`.
- Stops: `SpawnPoint` -> `ShooterEncounterStaging/PlayerNoticeAnchor` ->
  `Props/ShooterCover` and `ShooterEncounterStaging/PlayerCoverAnchor` ->
  `ShooterEncounterStaging/ShooterEnemyAnchor` -> gun drop/landing.
- Focus: rock contact, visible versus effective cover, enemy silhouette and tell,
  shot clearance, pickup placement, and adjacent terrain seams. Observe the intro
  normally when testing its framing; skipping it does not verify that sequence.
- Intent: [Game direction / Firearms](GAME_DIRECTION.md#firearms).

### Level 3 upper gunners

- Same entry/scene; inspect the route from the tank climb's upper exit through
  `UpperRoute/MovingGunner`, the shoulder, supported ledge,
  `UpperRoute/UpperGunner`, and the supply chest beyond it.
- The [roadmap](LEVEL_ROADMAP.md#upper-gunner-route) describes the current shoulder
  at X 99.84-104.96, ledge at X 106.24-110.08, and route ending at X 122.88.
  Discover actual runtime terrain/cover/chest nodes, including layout additions.
- Stable layout IDs in `resources/level_layouts/green_zone_shooter_area.json`:
  `object_upper_route_shoulder_*`, `object_upper_route_deck_0` through `_2`,
  `object_upper_route_brace_0`, `object_upper_route_low_rock`,
  `upper_route_guard`, and `object_upper_route_reward`. The layout overrides the
  upper gunner's base-scene position; inspect the live result before measuring.
- Focus: covered face-tile seams, grass/stone edges, bridge support and contact,
  spike-pit readability, the elevated gunner's cover and firing lane, chest contact,
  camera rise, and background coverage. If F11 is used to reach the area, record
  that the climb was skipped and re-enter ordinary play before assessing framing.

### Firearm Review Lab

- Entry: **Firearm Review Lab**, `resources/dev/animation_lab.tres`.
- Scene: `scenes/dev/animation_lab.tscn`.
- Stops: spawn -> isolated shooter and cover rock -> wall/landing surfaces ->
  return past the cover. Inspect both facing directions and relevant aim/attack
  states, with test controls hidden for clean captures.
- Focus: foot/hand/gun contact, sprite layering and scale, cover/shot clearance,
  and visual state transitions. A lab pass does not verify campaign composition.
