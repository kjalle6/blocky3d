# Game vision

## North star

Build a compact, demanding 3D precision platformer with the immediate retry
energy and authored challenge of *Super Meat Boy*. The finished game uses
purpose-built 3D characters, environments, animation, effects, lighting, UI,
and audio. Primitive geometry is acceptable for deliberate blockouts, never as
a disguised final asset pipeline.

## What we already know

- Movement should feel fast, exact, and fair.
- Levels should communicate an intended challenge instead of being defeated by
  accidental shortcuts.
- Unlocks and upgrades introduce new abilities, then later levels test
  combinations of those abilities.
- Death and retry should be fast enough that failure remains part of the rhythm.
- The Pygame project at `C:\Users\kappe\Code\platformertwo` is a design reference:
  it shows level ideas, encounter order, power-up placement, music, and tone.
  Its code, pixel dimensions, physics constants, and architecture are not
  constraints on this project.
- Concepts corresponding to the former Levels 9 and 10 should be re-authored at
  a scale that takes advantage of 3D space rather than preserving their old
  2D footprint.

## Quality target

Every obstacle should be readable before it is demanding. Every ability should
have a clear purpose, reliable input behavior, and level geometry designed
around its real movement envelope. Difficulty should come from execution and
decision-making, not ambiguous collision, camera surprises, or inconsistent
timing.

## Movement and camera direction

The game uses path-relative 2.5D movement inside a fully 3D world. Each local
section plays with side-scroller precision, but its authored traversal path may
turn toward or away from the former camera position, curve around structures,
or travel vertically through the environment. The camera turns with the route
so depth aiming is never required from the player.

This is a precision platformer, not a rage game. Rage-platformer conventions may
inspire occasional reactive obstacles or playful surprises, but frustration is
not the design objective. Those ideas are seasoning inside a readable, fair
platforming adventure.

## Decisions still to make deliberately

- Character and world art direction
- Exact ability roster and upgrade rules
- Level structure, scoring, collectibles, and progression map
- Checkpoint frequency and whether individual challenges are room-based

These decisions should be settled with one production-quality vertical slice,
not by inheriting assumptions from the migration prototype.
