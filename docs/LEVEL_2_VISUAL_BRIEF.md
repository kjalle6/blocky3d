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

The current approved implementation is frozen in
`scenes/levels/overgrown_coastal_ascent_interior_snapshot.tscn`. The exterior
`Level 2 WIP` route enters that snapshot, while the directly loadable
`Level 2 Interior WIP` entry continues to use
`scenes/levels/overgrown_coastal_ascent_interior.tscn`. New background and
presentation experiments belong only in the editable Interior WIP until they
are explicitly accepted into a later snapshot.

## Cave background zoning and lighting order

### Global background zoning

The editable Interior WIP currently proves that every cave layer can remain
fixed in world Y: jumping and climbing move the camera past the art instead of
dragging the cave with the player. That behavior is accepted and must not be
changed. The vertically repeated distant-rock composition is only a coverage
proof, however; using the recognizable full-screen art through the entire
climb reads as scrolling wallpaper and is not the target presentation.

The target composition is spatially zoned. Enclosed lower tunnels, shafts, and
any later route that descends from the upper floor use the clean pale blue-grey
base without the full distant composition. The complete layered cave parallax
belongs to the upper floor where the water chambers open up. This rule follows
authored world regions rather than player progress: descending returns to the
base treatment, and climbing back up restores the full upper-floor treatment.
The base may remain underneath as continuous fallback coverage, but it is the
visible treatment only in the lower and descending regions; the detailed upper
composition owns the visible background upstairs.

The transition at the top of the climb must read as the cave naturally opening
into the larger water cavern. Foreground cave walls and the turn onto the upper
floor mask an overlapping handoff between treatments; there must be no hard
screen-wide seam, visible pop, or camera-height-only switch.

### Localized machine-gap water vistas

Each localized water vista stays authored to its shaft on both axes; it is a
fixed view through an opening, not part of the global background handoff.
Uniform source rows extend its ceiling to the distant cave roof and its deep
water below the kill plane, so fixed art never exposes a hard edge. The lake
crop sits 2.0 m lower than its source alignment. The pack's foreground cave
frame is omitted because the level's own rock shell remains the foreground and
collision source of truth.

### Lighting order

Build and approve the background zoning at the current lighting first. Only
then add a restrained lower-cave colour grade that blends back to the current
upper-floor brightness during the sustained climb. The grade follows authored
world regions, reverses on descent, leaves UI unchanged, and must not pulse
during ordinary jumps. Its exact lower darkness remains a hands-on tuning
value. Keep this Level 2-specific until another production level proves a
shared system is useful.

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
| Background zoning | A restrained solid cave base below; the full layered cave composition revealed on the upper water floor; descending naturally returns to the base | Repeated vertical wallpaper, a hard regional pop, a camera-height-only switch, or lighting used to hide a broken transition |
| Machine-gap vista | A fixed lake view visible only through its authored opening, with the level shell remaining in front | A collision surface, global scrolling layer, or exposed top/bottom art edge |

## Current approval boundary

Everything through the first machine encounter is visually approved: the lower
recap, the three detached ascent platforms with Wall Jump on P3, the shaft fed
by P3, the wall-spike patches biasing the top exit left, Dash and its checkpoint
in the upper-left alcove, the 13.28 m Dash-required crossing back right, and the
first machine shaft.

A checkpoint sits on the ledge before the first machine, so a fall retries that
encounter rather than the Dash crossing before it.

Hands-on review accepts the first machine as a deliberately isolated, readable
introduction. A second matching 14.08 m shaft is now authored after a full
12.8 m reveal runway. Its width is divided into thirds: one machine sits in each
outer third, each nudged 0.32 m toward the empty middle to give both ledges more
breathing room. Both begin at the same height, with the left machine rising
while the right falls. This second beat is pending hands-on review; nothing
after its landing is approved.

## Dash crossing width

The editable Interior WIP now uses a 13.28 m row of 17 spikes. Its original
64.0 m left edge stays fixed and all four added spikes extend the hazard to the
right. This is beyond the 11.79 m Double Jump envelope while retaining roughly
4 m of the Double Jump plus Dash envelope, so the beat now requires the ability
it just gave the player without demanding its absolute limit.

The selected width follows the earlier reach audit. At the authored
`spike_height` of 0.76 m:

| extra spikes | row width | vs the 11.79 m reach |
| --- | --- | --- |
| +1 | 11.00 m | still clearable |
| +2 | 11.76 m | still clearable, by 3 cm |
| +3 | 12.52 m | clears |
| +4 | 13.28 m | clears with the same 1.5 m margin the machine gap uses |

Only the lethal row grows; the solid cave floor beneath it remains part of the
interior construction. The validator locks both the 17 visible spikes and the
original left edge, plus the movement-envelope margins, so the crossing cannot
silently drift back under Double Jump reach or grow toward the pickup alcove.
The post-crossing checkpoint moves right to 80.64 m so its trigger and respawn
space remain clear of the new final spike. The frozen snapshot intentionally
remains at 10.24 m until a later explicit promotion.

## Upper-floor machine sequence

The first machine shaft is built. The corridor breaks for 14.08 m, open far
above and below, and one machine hovers in the gap on a slow vertical bob.
Falling in is a long drop past the kill plane. There is no artificial roof or
off-screen spike lid over the chamber.

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

## Next presentation pass

Gameplay stops at the paired-machine landing. Complete and review the
background-then-lighting sequence under **Cave background zoning and lighting
order** before extending the route or promoting a new snapshot.

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
