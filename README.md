# Blocky 3D

Clean production foundation for a 3D precision platformer in Godot 4.6.

The migration prototype has been intentionally removed. The Pygame project is a
design reference only; no Pygame code, exported level coordinates, generated
primitive levels, or compatibility architecture remains in this project.

Start with:

- [`docs/GAME_VISION.md`](docs/GAME_VISION.md)
- [`docs/ENGINEERING_PRINCIPLES.md`](docs/ENGINEERING_PRINCIPLES.md)

The current main scene contains the classic Level 1 blockout: running, jumping,
progressively wider gaps, visible spike strips, stompable patrol enemies,
optional raised platforms, a finish flag, and fast full-run reset. Its generated
blockout geometry is deliberately disposable and is not part of the final asset
pipeline. The original turning movement lab remains available as a regression
scene under `scenes/lab/`.

## Validate

```powershell
godot --headless --path . --script res://tools/validate_project.gd
godot --headless --path . --script res://tools/validate_movement_runtime.gd
godot --headless --path . --script res://tools/validate_level1_runtime.gd
godot --headless --path . --script res://tools/validate_level1_playthrough.gd
```
