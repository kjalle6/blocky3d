# Game vision

## North star

Build a compact, demanding 2.5D precision platformer with the immediate retry
energy and authored challenge of *Super Meat Boy*. The current visual language
is crisp pixel art staged in a 3D world: familiar side-scroller play first,
with the option for authored routes to bend through depth later. Effects,
lighting, UI, and audio should support that style rather than compete with it.

## What we already know

- Movement should feel fast, exact, and fair.
- Levels should communicate an intended challenge instead of being defeated by
  accidental shortcuts.
- Unlocks and upgrades introduce new abilities, then later levels test
  combinations of those abilities.
- Death and retry should be fast enough that failure remains part of the rhythm.
- Enemy damage needs a short, readable hit beat before the fast reset. Until
  its final effect is chosen, a silent instant respawn is considered unfinished
  feedback rather than the intended experience.
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

The game uses path-relative 2.5D movement inside a 3D world. Each local section
plays with side-scroller precision. A later level may turn toward or away from
the former camera position, curve around a structure, or travel vertically,
but the player never has to aim movement into ambiguous screen depth. Level 1
is deliberately flat and orthographic so movement, collision, and encounter
readability can be judged without camera novelty.

This is a precision platformer, not a rage game. Rage-platformer conventions may
inspire occasional reactive obstacles or playful surprises, but frustration is
not the design objective. Those ideas are seasoning inside a readable, fair
platforming adventure.

## Decisions still to make deliberately

- Exact ability roster and upgrade rules
- Level structure, scoring, collectibles, and progression map
- Checkpoint frequency and whether individual challenges are room-based

These decisions should be settled with one production-quality vertical slice,
not by inheriting assumptions from the migration prototype.
