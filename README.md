# Blocky 3D

A Godot 4.6 precision platformer built as 2.5D: side-scroller controls and
pixel-art readability inside a 3D world that can support authored route turns
later.

The Pygame project at `C:\Users\kappe\Code\platformertwo` remains a design
reference for level intent, encounter order, power-ups, music, and tone. Its
code and physics are not dependencies.

The current build contains the production-quality Level 1 vertical slice and
Level 2's longer gaps-and-spikes course. A temporary level selector opens at
launch. Both levels share the approved orthographic camera, layered green-zone
art, biker and weapon animation, solid/telegraphed patrol enemy, stomp and
melee rules, chest goal, and fast retry loop. Level 2 adds fair foot-contact
spikes and earned, grounded checkpoints without placing safety floors beneath
its raised routes.

Start with:

- [`docs/GAME_VISION.md`](docs/GAME_VISION.md)
- [`docs/ENGINEERING_PRINCIPLES.md`](docs/ENGINEERING_PRINCIPLES.md)
- [`docs/LEVEL_02.md`](docs/LEVEL_02.md)

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
godot --headless --path . --script res://tools/validate_level2_runtime.gd
godot --headless --path . --script res://tools/validate_level2_playthrough.gd
```

Graphical review captures are generated with:

```powershell
godot --path . --script res://tools/capture_level1.gd
godot --path . --script res://tools/capture_level2.gd
```
