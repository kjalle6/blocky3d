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

- Arrival / Shoreline is the first production campaign level. Its reviewed
  shoreline now leads into the first production passes of Green Threshold and
  Thorn Garden. The current Canopy Ascent geometry is a technically traversable
  composition draft, not approved content; its replacement is the active
  milestone
- Six earlier Green Zone prototype levels remain in a separate regression
  catalog to validate Fundamentals, Gaps & Spikes, Double Jump, Wall Jump,
  Dash, and full-kit movement
- World 1 is being re-authored as approximately three substantial levels:
  Arrival / Shoreline, Overgrown Coastal Ascent, and Green Zone Finale
- The production selector currently exposes Arrival / Shoreline; Animation Lab
  remains the only development-tool entry
- A reusable profile-driven pixel-background rig provides native-scale,
  seam-safe horizontal coverage, authored coastal-to-green transitions, and
  stable framing during vertical camera travel. Canopy Ascent will extend this
  with scene-authored vertical camera regions and height-aware layered parallax
- The intended finale adds moving saws, a limited firearm lesson, and a simple
  first boss while keeping melee viable
- Typed world catalog and world-grouped mouse or `W`/`S` + `Enter` level
  selector
- Development-only Animation Lab with a full-speed runway, test geometry,
  immediate ability toggles, and no campaign/save effects
- Development mode starts every level from its fresh level-defined entry state,
  then retains session abilities through death and `R`
- 1920x1080 presentation baseline
- Next milestone: rebuild Canopy Ascent as a substantially longer, primarily
  vertical climb through continuous layered tree masses, then review its low,
  middle, and high compositions at normal speed

The three living design documents are:

- [`docs/GAME_DIRECTION.md`](docs/GAME_DIRECTION.md) — what the game is
- [`docs/LEVEL_ROADMAP.md`](docs/LEVEL_ROADMAP.md) — the eleven legacy ideas,
  revised campaign spine, and next level
- [`docs/TECHNICAL_FOUNDATION.md`](docs/TECHNICAL_FOUNDATION.md) — architecture,
  gameplay contracts, asset pipeline, and validation

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
`D:\GodotProjects\blocky3dassets`. Refresh the curated green-zone runtime set
with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prepare_green_zone_assets.ps1
```

## Validate

Use the guarded runner rather than launching Godot directly. It preserves the
running editor/game by default and uses the normal Compatibility renderer. Do
not use `--headless`: Godot 4.6.3 Mono produces native access-violation dialogs
with headless project scripts on this machine, while the same validators pass
normally without that flag. Pass `-CloseRunningGodot` only when a particular
automation run genuinely requires exclusive access.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_project.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_arrival_shoreline_slice.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_arrival_shoreline_slice_playthrough.gd
```

Pass any other `res://tools/validate_*.gd` script through the same runner.

Generate graphical review captures with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_level1.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_animation_lab.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_arrival_shoreline_slice.gd
```

Pass any other `res://tools/capture_*.gd` script through the same runner.
