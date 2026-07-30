# Level 2 — Gaps & Spikes

Level 2 carries the approved Unreal prototype's route into the Godot game while
using the production Level 1 movement, combat, camera, enemy, art, and reset
systems. It introduces no new player ability.

## Authored course

- 22 platforms across a 131-metre side-scrolling route
- Five visible spike rows with deliberately inset, foot-level damage shapes
- Six patrol enemies using the shared melee, stomp, ledge, and reset rules
- Four invisible route checkpoints
- No hidden ground or safety floor beneath raised platforming sections

The course progresses through opening stairs, separated ground islands, a
precision staircase, a two-row spike run, three narrow rising blocks, and a
final climb to the chest.

## Checkpoint contract

A checkpoint is earned only after the player remains grounded inside its
trigger. Airborne overlap while falling past it does not count. Death returns
the player to the latest earned checkpoint and resets enemies and feedback;
manual restart clears all checkpoint progress and returns to the entrance.

## Validation

`validate_level2_runtime.gd` checks authored counts, traversal geometry, spike
collision fairness, checkpoint earning, death respawn, spike death, and manual
restart. `validate_level2_playthrough.gd` completes the entire production route
using only normal movement, jump, attack, and air-control inputs.
