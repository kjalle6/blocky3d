# Level 2 visual brief

This guide describes the route and visual composition of Overgrown Coastal Ascent.

The accepted production build spans
`scenes/levels/overgrown_coastal_ascent.tscn` and
`scenes/levels/overgrown_coastal_ascent_interior.tscn`, with
`resources/campaign/level_02.tres` providing its stable campaign identity. The
exterior cave threshold uses a direct same-level `target_scene` handoff into the
interior, preserving the two authored spaces without inventing a second level
identity. Focused validators, captures, and probes load the interior scene
directly under `resources/campaign/level_02.tres`, preserving that production
Level 2 identity without a separate developer selector entry.

## Editing the level

Both Level 2 sections now support prepared additions through the in-game
designer. Their original connected terrain, camera regions, and scripted
sequence assemblies remain protected; this does not reopen the accepted route
or add cave-painting tools. Inspect resolved layout data before further scene
work. The cave entrance texture was promoted unchanged from the source catalog
to production art for isolated export loading.

## Approved route

Read this as a side view, from left to right:

```text
DUSK APPROACH
[run-up] -> [patrol] -------- [patrol] -> [cave mouth]
                                                |
                                                v
                                    [slide cutscene + run-in]
                                                |
                                                v
LOWER CAVE
[enemy + spikes] -> [P1] -> [P2] -> [P3 + Wall Jump]
                                                      | shaft |
                                   [Dash alcove]  <-  | climb |
                                                      |
                     [Dash-required spike return]  -> upper cave
                                                      |
                           [single machine shaft] -> [paired machines]
                                                      |
                           [enemy] -> [Dash spikes] -> [enemy] -> [lift]
```

The accepted route and human-tested timing own this shape. Coordinates, tile
counts, and camera regions serve it; they do not reinterpret it.

## Approach, threshold, and arrival

The exterior is a short combat bridge, not a second tutorial opening. Its two
patrols may roam the full usable ground from the opening tree line to the cave,
so the approach feels alive and lets the player carry momentum toward the
entrance.

The cave is an authored threshold between two scenes of the same level. Its
direct `target_scene` handoff preserves the active Level 2 identity and run
state. The player disappears into the mouth, the screen fades to black, and a
short downhill slide supplies the spatial story for the wall-climbing route
that follows. The slide has no
visible artificial top edge or underside. Dust at the player's feet supports
contact without hiding it, and the arrival terrain masks the ramp so it reads as
part of the cave rather than a placed playground slide. The cutscene lands on
the interior floor and becomes a short automatic run-in before returning input.

## Cave background zoning and grade

Level 2 uses five global layers: three smoky-grey crystal-cave layers below and
two pale water-cave layers above. Background zoning is authored as world
volumes, not keyed to irreversible progress. The lower layers consume the
inverse of the `upper` region weight, so descending naturally restores the
lower composition and climbing restores the upper one. Checkpoint respawn,
death, restart, and direct loads therefore reproduce the same result.

The broad handoff begins during the final shaft climb with a 7.0 m blend margin
and exponent 1.0. Lower detail fades as the pale upper composition, regional
grade, and ceiling arrive. The shaft walls mask the busiest part of the blend.

Global layers are screen-locked vertically. Lower distant and crystal layers
use restrained 0.08 and 0.14 horizontal parallax; the upper distant layer uses
0.22. This preserves depth without making rapid wall jumps drag the entire cave
around the player.

`CaveRegionGrade` follows the same upper-zone influence. The lower cave uses
brightness 0.74, saturation 0.88, and contrast 1.04, returning to 1.0 above.
Every sprite remains unshaded, so this authored grade and the art carry the
lighting transition. There is no free-standing amber or cyan spill.

## Upper ceiling, vistas, and camera

The upper zone shares one rocky ceiling laid out across five mirrored,
world-anchored panels. It is camera-stable on Y, follows the same blend as the
background and grade, and contains no water or collision. The foreground cave
shell remains the single source of visible structure and collision.

Localized water vistas retain authored world X and lock to the camera on Y.
They contribute only lake, rocks, and deep-water fill through their openings;
foreground terrain masks their edges. A uniform source row extends water below
the kill plane and the lake crop sits 2.0 m below its source alignment.

The Wall Jump shaft focuses horizontal camera framing at its 58.88 m centre
while continuing to follow the climb vertically. This holds one composition
during rapid left-right kicks. Normal look-ahead resumes smoothly after the
upper-left exit. The upper floor clamps at a 28.0 m vertical offset, so ordinary
jumps do not move the whole cave shell.

The lift owns a still tighter fixed region. The camera remains motionless while
the deck rises, letting the machinery, not the background, sell departure.

## Visual contracts

| Beat | Must read as | Must not become |
| --- | --- | --- |
| Dusk approach | A short living bridge with two roaming patrols and a clear destination | A fresh tutorial start or cramped enemy pens |
| Cave threshold | A natural entrance into another authored space | A visible terrain seam or sky leaking behind the cave |
| Slide and arrival | A brief uncontrolled descent that lands with momentum inside the cave | A freestanding playground slide, visible underside, pillar, or exposed level edge |
| Recap tunnel | A familiar enemy-and-spike beat before the new lessons | Hazards leaking into the ascent without a reason |
| P1-P3 ascent | Three unsupported platforms rising toward the shaft | Stairs, pillars, or platforms fused into terrain |
| Shaft base | Wall Jump on P3, followed by one clear commitment jump to the right wall | A fourth pickup landing or unrelated room |
| Wall Jump shaft | Two continuous readable walls and a stable camera composition | Detached fragments or left-right camera sway |
| Dash alcove | A connected upper-left reward reached after the climb | A floating chamber or giant empty turnback room |
| Dash return | One legible rightward spike strip whose width proves Dash is required | A Double-Jump-clearable gap or disconnected destination |
| Single machine | A full-height corridor break with one slow hazard and readable upper/lower choices | A fake gap, artificial lid, or machine that closes both lanes |
| Paired machines | The same learned rule, escalated with opposite-phase hazards | New rules introduced without a reveal runway |
| Exit gauntlet | Two enemies bracketing one Dash-required strip | An empty victory corridor or surprise with no retry boundary |
| Cave lift | A substantial cave-built mechanism and deliberate departure | A random door, decorative prop, or trigger that steals control on approach |

## Traversal measurements

The first Dash return uses a 13.28 m row of 17 spikes. The original 64.0 m left
edge stays fixed and all four added spikes extend right. That exceeds the 11.79
m Double Jump envelope while leaving a fair margin inside the 17.29 m Double
Jump-plus-Dash envelope. Only the lethal row grows; the solid cave floor below
remains part of the terrain shell. The following checkpoint sits at 80.64 m,
clear of the last spike.

Both hovering-machine breaks are 14.08 m wide: outside Double Jump reach but
inside the full movement envelope. The first machine is deliberately slow and
alone. Its lethal body and hanging discharge never close the upper and lower
routes simultaneously. After a 12.8 m reveal runway, the paired chamber puts
one machine in each outer third and starts them half a bob cycle apart. Hands-on
review accepts both encounters.

## Exit and completion timing

The final spike strip requires Dash and has one enemy on each side. A checkpoint
before the run preserves the encounter boundary.

Approaching the lift does nothing. Departure arms only while the player is
fully supported by the deck and standing still; movement resets the timer. One
continuous second of stillness starts ascent from the player's chosen deck
position. The completion goal fires at 62 percent lift progress, and the level
uses a one-second fade so the player sees the lift rise before full black hides
the physical ceiling.

## Required review loop

For every later Level 2 presentation edit:

1. Run `tools/build_level_2_visual_review.ps1`.
2. Open `build/previews/level_2_interior_opening/level_2_visual_review_sheet.png`.
3. Compare clean overviews and local frames to this brief.
4. Use diagnostic frames only to explain contact, scale, gaps, and camera state.
5. List visible contradictions before editing.
6. Change one route beat, rebuild the sheet, and compare again.
7. Launch the windowed game for hands-on review.
8. Update structural and playthrough automation only after acceptance.

The sheet and this brief do not make taste automatic. They make it difficult to
hide arbitrary decisions behind a green validator.
