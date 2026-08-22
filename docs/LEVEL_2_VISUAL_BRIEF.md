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
                                                            -> evasive flyer chamber
                                                               over: jump + air Dash
                                                               under: timed ground Dash
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
| Evasive flyer chamber | One generous first encounter with a hovering Green Zone enemy and two readable clearance routes | A combat arena, an unavoidable damage gate, or geometry that only pretends to offer a choice |

## Current approval boundary

The lower recap and the three detached ascent platforms are approved. P3 is the
pickup platform; a one-tile gap separates it from the shaft wall, and there is
no fourth landing. The shaft rises to a true left/right junction. Build and
review in this order:

1. remove unapproved spikes from beneath the ascent;
2. keep exactly three unsupported platforms and place Wall Jump on P3;
3. build only the coherent shaft fed by P3;
4. stop for visual and hands-on review;
5. use short wall-spike patches to test Wall Jump and bias the top exit left;
6. place Dash and its checkpoint in the connected upper-left alcove;
7. gate the upper-right route with one readable spike run that requires Dash.

## Next approved beat

Extend the current upper-right landing into one wide, tall tunnel chamber that
introduces Green Zone enemy 5, the hovering machine with the electrical spark
animation. It is an evasive traversal hazard, not another melee target:

- the player may jump and air-Dash through clear space above it;
- the player may remain grounded and use a timed ground Dash through clear
  space below it;
- its body and active electrical contact are lethal;
- Dash never grants contact invulnerability;
- melee attacks and stomps cannot damage or defeat it;
- a slow, readable hover or vertical bob may create the timing window, but the
  first encounter stays generous enough to teach the rule rather than test
  mastery.

Build and review only this first chamber before extending the route again. Both
paths must be visibly real in the clean capture and physically real in hands-on
play; an invisible speed gate or misleading clearance is not acceptable.

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
