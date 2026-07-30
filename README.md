# Blocky 3D

Blocky 3D is a Godot 4.6 pixel-art 2.5D precision platformer. It combines fast
side-scroller movement with a 3D world that can support authored turns,
vertical routes, and controlled depth changes without becoming a free-roaming
3D game.

Godot is the canonical implementation. The Python game and Unreal prototype
remain read-only design references.

## Current state

- Level 1: Fundamentals — complete production vertical slice
- Level 2: Gaps & Spikes — complete fundamentals regression course
- Level 3: Double Jump — complete ability-introduction level
- Level 4: Wall Jump — complete vertical-movement introduction
- World 1 is the five-level opening green-zone world; Dash remains planned
- Typed world catalog and world-grouped mouse or `W`/`S` + `Enter` level
  selector
- Development-only Animation Lab with a full-speed runway, test geometry,
  immediate ability toggles, and no campaign/save effects
- Development mode starts progression fresh on every level load while
  retaining unlocks through death and `R` inside that session
- 1920x1080 presentation baseline

The three living design documents are:

- [`docs/GAME_DIRECTION.md`](docs/GAME_DIRECTION.md) — what the game is
- [`docs/LEVEL_ROADMAP.md`](docs/LEVEL_ROADMAP.md) — the eleven legacy ideas,
  revised campaign spine, and next level
- [`docs/TECHNICAL_FOUNDATION.md`](docs/TECHNICAL_FOUNDATION.md) — architecture,
  gameplay contracts, asset pipeline, and validation

## Controls

- Move: `A` / `D`, arrow keys, left stick
- Jump: `Space`, `W`, up arrow, gamepad south button
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

```powershell
godot --headless --path . --script res://tools/validate_project.gd
godot --headless --path . --script res://tools/validate_animation_lab.gd
godot --headless --path . --script res://tools/validate_progression.gd
godot --headless --path . --script res://tools/validate_developer_mode.gd
godot --headless --path . --script res://tools/validate_movement_runtime.gd
godot --headless --path . --script res://tools/validate_camera_pixel_stability.gd
godot --headless --path . --script res://tools/validate_double_jump_runtime.gd
godot --headless --path . --script res://tools/validate_wall_jump_runtime.gd
godot --headless --path . --script res://tools/validate_level1_runtime.gd
godot --headless --path . --script res://tools/validate_level1_playthrough.gd
godot --headless --path . --script res://tools/validate_level2_runtime.gd
godot --headless --path . --script res://tools/validate_level2_playthrough.gd
godot --headless --path . --script res://tools/validate_level3_runtime.gd
godot --headless --path . --script res://tools/validate_level3_playthrough.gd
godot --headless --path . --script res://tools/validate_level4_runtime.gd
godot --headless --path . --script res://tools/validate_level4_playthrough.gd
```

Generate graphical review captures with:

```powershell
godot --path . --script res://tools/capture_level1.gd
godot --path . --script res://tools/capture_level2.gd
godot --path . --script res://tools/capture_level3.gd
godot --path . --script res://tools/capture_level4.gd
godot --path . --script res://tools/capture_animation_lab.gd
```
