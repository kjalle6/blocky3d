# Blocky 3D

Clean production foundation for a 3D precision platformer in Godot 4.6.

The migration prototype has been intentionally removed. The Pygame project is a
design reference only; no Pygame code, exported level coordinates, generated
primitive levels, or compatibility architecture remains in this project.

Start with:

- [`docs/GAME_VISION.md`](docs/GAME_VISION.md)
- [`docs/ENGINEERING_PRINCIPLES.md`](docs/ENGINEERING_PRINCIPLES.md)

The current main scene contains the first disposable movement lab. It tests
path-relative 2.5D movement, a route that turns through 3D space, an authored
side-view camera, jumping, gaps, hazards, and fast reset. It is not Level 1 and
its blockout geometry is not part of the final asset pipeline.

## Validate

```powershell
godot --headless --path . --script res://tools/validate_project.gd
```
