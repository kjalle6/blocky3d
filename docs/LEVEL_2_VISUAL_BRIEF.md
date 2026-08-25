# Level 2 opening visual brief

This brief is the visual source of truth for the first interior route. Runtime
validators prove collision and progression only after the route passes this
review. A passing bot never authorizes geometry that contradicts this page.

## Approved route

Read this as a side view, from left to right:

```text
LOWER TUNNEL
[familiar recap: enemy and a small explicit spike beat]
                         -> [P1] -> [P2] -> [P3 + Wall Jump]
                                                         | narrow shaft |
                                                         | climb upward |
                                      [Dash alcove]  <-  | top exit     |
                                      [collect Dash]
                                                         -> Dash across spikes
                                                            -> upper-right tunnel
                                                            -> machine shaft
                                                               a full-height break
                                                               in the corridor
                                                               over: Dash above it
                                                               under: Dash below it
```

The user's drawn plan owns this route. Coordinates, tile counts, and camera
regions serve it; they do not get to reinterpret it.

## Visual contracts

| Beat | Must read as | Must not become |
| --- | --- | --- |
| Recap tunnel | A short familiar run with deliberately placed hazards | Hazards leaking into the ascent without a reason |
| P1-P3 ascent | Three separate unsupported platforms, rising toward the shaft | Stairs, pillars, or a platform merged into adjacent terrain |
| Shaft base | Unsupported P3 is the Wall Jump pickup landing, followed by one clear commitment jump to the right wall | A fourth pickup landing, a platform fused into the wall, or an unrelated room |
| Wall Jump shaft | Two continuous readable walls with enough space to learn the move | Detached wall fragments, dangling blocks, or unrelated rooms |
| Dash alcove | A connected upper-left reward space reached after the climb | A distant floating chamber or giant empty turnback room |
| Dash crossing | One legible rightward gap whose spikes explain why Dash is required | An isolated spike box, one-tile pillar, or disconnected destination |
| Machine shaft | A break in the corridor wide enough that Dash is required, open far above and below, with one hovering machine in it and two readable ways past | A gap a Double Jump can clear, a ceiling over the machine, a floor under it, or geometry that only pretends to offer a choice |

## Current approval boundary

Everything up to and including the machine shaft is visually approved: the lower
recap, the three detached ascent platforms with Wall Jump on P3, the shaft fed
by P3, the wall-spike patches biasing the top exit left, Dash and its checkpoint
in the upper-left alcove, the Dash-only crossing back right, and the machine
shaft that ends the current route.

A checkpoint sits on the ledge before the machine, so a fall retries the machine
rather than the crossing before it.

Hands-on review of the machine is the remaining gate. Nothing beyond it is
approved, and no second machine is authored until the first one has been played.

## Pending change: widen the Dash crossing

The Dash crossing before the machine is still 10.24 m, which sits inside the
11.79 m a Double Jump reaches, so the beat that introduces Dash does not require
it. Hands-on it took about a hundred attempts to clear once, which is the worst
of both outcomes: technically possible, never reliable, and it teaches nothing
while occasionally rewarding a fluke. The timing that works is counterintuitive
- the second jump has to be spent late, near floor level, because double jumping
at the apex puts the player's head into the 33.28 m ceiling and costs the arc.

Approved fix: grow the spike row so Dash is genuinely required. Note that one or
two more spikes is not enough. At the authored spike_height of 0.76 m:

| extra spikes | row width | vs the 11.79 m reach |
| --- | --- | --- |
| +1 | 11.00 m | still clearable |
| +2 | 11.76 m | still clearable, by 3 cm |
| +3 | 12.52 m | clears |
| +4 | 13.28 m | clears with the same 1.5 m margin the machine gap uses |

Take it to roughly 13.3 m so it matches the machine gap's standard, widen the
gap in the floor to match the spike row, and add the same
ideal_double_jump_distance assertion the machine gap already carries so it
cannot drift back under the reach.

## Next approved beat

The machine shaft is built. The corridor breaks for 14.08 m, open far above and
below,
and one machine hovers in the gap on a slow vertical bob. Falling in is a long
drop past the kill plane, and the top of the gap is closed by spikes far above
the camera rather than by a roof, so it cannot be stood on.

Crossings are sized against the reach the player actually has. A Double Jump
carries 11.79 m - two full arcs - so a gap tuned to a single jump does not
require Dash at all. 14.08 m sits clear of that and still leaves a fair landing
margin against the 17.29 m a Double Jump and Dash reach together.

Green Zone enemy 5 is an evasive traversal hazard, not a melee target:

- it cannot be stabbed or stomped, and Dash grants no contact invulnerability;
- its body is always lethal, and its electrical discharge hangs beneath it, so
  the low route is the one that has to be timed;
- the bob must never close both routes at once. When the machine rises the floor
  lane opens; when it drops the ceiling lane opens. The structural validator
  asserts this, so a bad tune fails rather than shipping.

The first machine is deliberately alone and deliberately slow. It teaches the
rule so that later chambers can vary speed, phase, and count without being
unfair - two machines drifting out of step are a timing puzzle only once a
player already knows what "it is rising, go low" means.

Later chambers may combine several machines at different speeds, and may demand
a Double Jump to reach a lane. Build and review one at a time.

## Required review loop

For every geometry pass:

1. Run `tools/build_level_2_visual_review.ps1`.
2. Open `build/previews/level_2_interior_opening/level_2_visual_review_sheet.png`.
3. Compare the clean overview and local clean frames to this brief.
4. Use the paired diagnostic frames only to explain contact, scale, and gaps.
5. List every visible contradiction before deciding what to edit.
6. Change one route beat only, rebuild the sheet, and compare again.
7. Launch the windowed game for hands-on review before extending the route.
8. Update the playthrough bot and structural validator only after acceptance.

The sheet and this brief do not make taste automatic. They make it difficult to
hide arbitrary decisions behind a green validator.
