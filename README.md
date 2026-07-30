# Blocky 3D

A Godot 4.6 precision platformer built as 2.5D: side-scroller controls and
pixel-art readability inside a 3D world that can support authored route turns
later.

The Pygame project at `C:\Users\kappe\Code\platformertwo` remains a design
reference for level intent, encounter order, power-ups, music, and tone. Its
code and physics are not dependencies.

The current main scene is the fresh Level 1 vertical slice. It reproduces the
approved Unreal prototype's six-platform route, orthographic camera, layered
green-zone art, biker and weapon animation, solid/telegraphed patrol enemy,
stomp and melee rules, chest goal, and fast full-run reset. Superseded Godot
blockouts have been removed; their history remains available through Git.

Start with:

- [`docs/GAME_VISION.md`](docs/GAME_VISION.md)
- [`docs/ENGINEERING_PRINCIPLES.md`](docs/ENGINEERING_PRINCIPLES.md)

## Assets

The complete downloaded packs stay outside this repository at
`D:\GodotProjects\blocky3dassets`. Refresh the curated Level 1 runtime subset
with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prepare_level1_assets.ps1
```

## Validate

```powershell
godot --headless --path . --script res://tools/validate_project.gd
godot --headless --path . --script res://tools/validate_movement_runtime.gd
godot --headless --path . --script res://tools/validate_level1_runtime.gd
godot --headless --path . --script res://tools/validate_level1_playthrough.gd
```

Graphical review captures are generated with:

```powershell
godot --path . --script res://tools/capture_level1.gd
```
