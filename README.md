# Working title: TBD

`blocky3d` is the internal codename for a Godot 4.6 pixel-art precision
platformer. The public title is still undecided. The game combines fast,
expressive side-scroller movement with light combat and a larger cyberpunk
setting that begins on a beach and in the natural Green Zone.

The game is 2D and stays 2D. The implementation uses Godot 3D nodes to stage
pixel art on layered depth planes, which is an internal presentation choice, not
a claim that the finished game is a 3D platformer. Gameplay never leaves its
single flat plane.

Godot is the canonical implementation. The Python game and Unreal prototype
remain read-only design references.

## Current state

- Arrival / Shoreline is the first completed production campaign level. Its
  route runs from the animated shoreline through Green Threshold, Thorn Garden,
  and an open-air Double Jump rise to a safe tire-swing-tree clearing. The
  completion trigger and fade are final Level 1 behavior rather than a temporary
  construction boundary
- Six earlier Green Zone prototype levels remain in a separate regression
  catalog to validate Fundamentals, Gaps & Spikes, Double Jump, Wall Jump,
  Dash, and full-kit movement
- World 1 is being re-authored as approximately three substantial levels:
  Arrival / Shoreline, Overgrown Coastal Ascent, and Green Zone Finale
- The production selector currently exposes Arrival / Shoreline. Development
  entries expose Animation Lab, the enclosed-terrain construction proof, the
  Level 2 cave approach, and the authored Level 2 interior opening
- A reusable profile-driven pixel-background rig provides native-scale,
  seam-safe horizontal coverage, authored coastal-to-green transitions, and
  stable framing during vertical camera travel. Dormant scene-authored vertical
  regions and height-aware opacity controls are available when an approved
  upward route actually needs them
- The intended finale adds moving saws, a limited firearm lesson, and a simple
  first boss while keeping melee viable
- Typed world catalog and world-grouped mouse or `W`/`S` + `Enter` level
  selector
- Development-only Animation Lab with a full-speed runway, test geometry,
  immediate ability toggles, and no campaign/save effects
- Development mode starts every level from its fresh level-defined entry state,
  then retains session abilities through death and `R`
- Development review tools expose independent F7 collision/hitbox overlays, an
  F10 world grid with live player-feet and cursor coordinates, and an F11
  god/noclip/free-flight inspection mode that grants the loaded level's
  available abilities for the current session
- Arrival has a curated, typed Green Zone dressing palette and paired clean /
  diagnostic capture workflow. Its accepted landmarks include the biome-seam
  outcrop, garden gates and hedges, the non-colliding skate half-pipe at the
  aerial takeoff, and the tire-swing-tree finish clearing
- 1920x1080 presentation baseline
- The first Overgrown Coastal Ascent interior slice is authored: a familiar
  combat-and-spike recap leads through a Double Jump rise into a Wall Jump
  shaft, a forced left turn for Dash, and an immediate Dash-only return. The
  next milestone is one visually reviewed two-route chamber introducing an
  indestructible flying electrical hazard: jump and air-Dash above it or time a
  ground Dash beneath it

The living design and authoring documents are:

- [`docs/GAME_DIRECTION.md`](docs/GAME_DIRECTION.md) — what the game is
- [`docs/LEVEL_ROADMAP.md`](docs/LEVEL_ROADMAP.md) — the eleven legacy ideas,
  revised campaign spine, and next level
- [`docs/TECHNICAL_FOUNDATION.md`](docs/TECHNICAL_FOUNDATION.md) — architecture,
  gameplay contracts, asset pipeline, and validation
- [`docs/SET_DRESSING_WORKFLOW.md`](docs/SET_DRESSING_WORKFLOW.md) — curated
  scenery, gameplay exclusions, visual review, and accepted-placement rules

## Controls

- Move: `A` / `D`, arrow keys, left stick
- Jump: `Space`, `W`, up arrow, gamepad south button
- Dash: `Shift`, gamepad east button
- Attack: left mouse, `J`, gamepad west button
- Restart current run: `R`
- Return to level selector: `Escape`
- Menu: click, `W` / `S` + `Enter`, or number shortcut

## Legacy references

- Python level blueprint:
  `C:\Users\kappe\Code\platformertwo\platformersecond`
- Archived Unreal prototype: `D:\UnrealProjects\Blocky3D`

These paths are not runtime dependencies. Legacy coordinates, physics values,
and architecture are not copied blindly.

## Assets

The complete downloaded packs stay outside this repository at
`D:\GodotProjects\blocky3dassets`. Mirror all runtime-ready visual files into
the project's searchable source-art catalog with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_visual_asset_library.ps1
```

Refresh the curated green-zone production set with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prepare_green_zone_assets.ps1
```

## Validate

Use the guarded runner rather than launching Godot directly. It preserves the
running editor/game by default and uses the standard non-.NET Godot 4.6.3 build
with the normal Compatibility renderer. Do not use `--headless`. Pass
`-CloseRunningGodot` only when a particular automation run genuinely requires
exclusive access.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_project.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_arrival_shoreline_slice.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_arrival_shoreline_slice_playthrough.gd
```

Pass any other `res://tools/validate_*.gd` script through the same runner.

The runner's `-EditorImport` mode uses Godot's dedicated `--import` command and
waits on the real editor executable, not only its console launcher. Every mode
uses the real process exit code, a per-run log, and an exclusive automation
lock. Do not substitute `--editor --quit`; it can exit while import workers are
still active. The complete source-art catalog under `assets/library` is
available in Godot for searching and auditioning; only selected production
files are referenced from scenes and promoted into `assets/art`. Bulk asset
activity is not treated as the proven cause or cure for the outstanding native
automation crash.

Generate graphical review captures with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_level1.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_animation_lab.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_arrival_shoreline_slice.gd
```

The runner gives automation its own writable Windows profile at
`build/godot_automation_profile`. Godot's editor cache and `user://` therefore
stay inside the ignored build directory during validators and captures instead
of touching the interactive editor profile or the player's campaign save. The
runner checks both its Roaming and Local profile roots before every launch. It
uses the standard build because this project contains no C# and the Mono build
repeatedly crashed inside CoreCLR. Use
`res://tools/validate_automation_environment.gd` to verify the isolated profile
and non-.NET engine contracts.

Pass any other `res://tools/capture_*.gd` script through the same runner.
