# Engineering principles

## Build for the real game

- Use one Godot unit as one meter. Do not retain a pixel-to-world conversion
  layer from the Pygame reference.
- Prefer composed scenes and focused components over inheritance-heavy entity
  trees or a single controller that owns the whole game.
- Store authored tuning and content metadata in typed custom `Resource` classes.
- Keep simulation, presentation, UI, audio, save data, and progression separate.
- Use signals for meaningful domain events, not as a substitute for clear
  ownership.
- Add automated validation with each real system: movement envelopes, required
  scene nodes, resource integrity, checkpoint/reset behavior, and level exits.

## Scene boundaries

`GameRoot` owns two stable top-level containers:

- `World`: the active 3D game world
- `Interface`: menus, HUD, transitions, and accessibility UI

Gameplay code does not accumulate directly on `GameRoot`. Future services must
earn their lifetime and scope rather than becoming a collection of globals.

## Player and level work

The first gameplay milestone is a vertical slice, not eleven blockouts. It must
prove the movement model, orthographic camera, reset loop, player attack, one
enemy family, art pipeline, and an authored 2.5D level. Only after that slice
feels production-worthy should its systems become the template for additional
levels.

## Asset pipeline

- Keep editable source assets separate from imported runtime assets.
- Keep the complete downloaded packs outside the repository. Import only a
  named, reproducible runtime subset and record its source path and hash.
- Use consistent real-world scale, pivots, collision conventions, and naming.
- Build collision intentionally; do not default to render-mesh collision for
  precision gameplay.
- Establish animation, material, texture, audio-loudness, and performance
  budgets before asset production expands.
