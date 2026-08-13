# Gameplay-aware set dressing

Set dressing is authored presentation, not random clutter. Automation should
make the available art and the level's empty/readability-critical regions easy
to see; it must not make final artistic decisions without review.

Project visual rule: platform undersides stay clean. Do not hang roots, vines,
props, debris, or other dressing below floating terrain. The terrain silhouette
is the underside language; decoration belongs on a readable support surface or
in a deliberately authored background layer.

## Evidence from the current Arrival route

The real-input traversal writes `build/diagnostics/arrival_route_trace.json`.
The current approved route completes in 1,460 physics frames. Its two longest
attention beats are the open-air dip (117 frames) and blind forward descent
(96 frames), so those screens need the clearest silhouettes. The trace records
landing position, crossing duration, and Double Jump use for every authored
beat. It deliberately remains a legality and attention map rather than a
difficulty judge.

`tools/capture_arrival_shoreline_slice.gd` captures the approved visual beats.
`tools/build_image_review_sheet.ps1` combines selected captures into a single
contact sheet, while `tools/build_asset_contact_sheet.ps1` does the same for
asset families. Together they expose repetition and empty compositions without
requiring scenery to be placed first.

The current route sheet shows a clear shift in density:

- Shoreline and the biome seam have a strong landmark and coherent material
  story.
- Green Threshold and Thorn Garden establish a garden vocabulary through trees,
  hedges, gates, stones, and a bench.
- The open-air Double Jump rise becomes mostly grass tufts on isolated rectangles.
  It needs more depth and environmental continuity, but its platform tops,
  enemy lanes, landing zones, and concealed-spike reveal must remain clean.

## Source palette audit

The complete searchable library contains useful coherent Green Zone families:

- 20 Green Zone bushes and hedges;
- 15 Green Zone grass tufts;
- 6 Green Zone stones;
- 9 Green Zone fence/gate pieces;
- 4 benches, 2 fountains, 4 whole trees, 6 loose leaves, and a small set of
  skate/urban props;
- a secondary nature family with 40 grasses, 24 bushes, 72 trees, and 8 roots.

The native Green Zone pack is the default because its palette, outline weight,
and pixel density already match the terrain. Secondary nature assets are
audition material: green bushes and grasses may work after scale/palette review;
most pink, autumn, winter, palm, dead-tree, or differently outlined variants do
not belong in Arrival merely because they are available.

## Small automation plan

### 1. Curated dressing catalog

Create typed `DressingAssetDefinition` resources rather than scanning arbitrary
PNGs at runtime. Each approved prop records:

- texture and source/license identity;
- native pixel dimensions and intended `pixel_size`;
- bottom contact/pivot inset;
- visual footprint in world metres;
- allowed depth band: rear, gameplay-behind, or foreground;
- tags such as `ground_cover`, `landmark`, `garden`, `wild`, `stone`, `edge`,
  `cluster_member`, and `seam_cover`;
- whether mirroring and limited scale variants are permitted;
- minimum clearances from hazards, enemies, player landings, and platform edges.

Only reviewed definitions enter the catalog. The 5,549-file source mirror stays
searchable but is never treated as an approved prop pool.

### 2. Scene-authored dressing zones

Add optional `DressingZone3D` markers to a level. A zone declares its visual
intent and density, plus explicit exclusion regions. Useful initial types are:

- `landmark`: one dominant tree, fountain, gate, rock mass, or bench grouping;
- `ground_cluster`: one medium prop with two or three smaller relatives;
- `edge_accent`: a low stone, grass, or bush visually anchored to a top edge;
- `rear_mass`: larger foliage behind gameplay that fills negative space;
- `quiet`: deliberately sparse recovery or teaching space.

Zones never infer themselves from platform geometry. The level designer places
them after gameplay is approved so the visual rhythm remains intentional.

### 3. Gameplay exclusion map

Build a read-only map from live scene contracts and the traversal trace:

- expand every hazard and enemy patrol range by a readability margin;
- protect launch and landing points recorded by the tester;
- protect pickups, checkpoints, goals, and camera-framing lessons;
- reserve the player's running-height silhouette above walkable terrain;
- forbid large props inside the blind-descent reveal window;
- allow only low rear-layer accents near precise jumps.

Candidate placement fails closed when its visible footprint overlaps protected
space. This automates safety, not taste.

### 4. Deterministic preview generation

Given a fixed seed, generate two or three candidate arrangements inside one
authored zone. Use weighted clusters and minimum/maximum spacing rather than
uniform random scatter. Snap bottom contact to the support surface, preserve
native pixel scale by default, and assign the declared depth band automatically.
Candidates are preview-only until one is explicitly accepted and baked into the
scene as ordinary named nodes.

### 5. Visual validation

For each candidate:

- capture the route's approved beats in paired views: a clean game frame for
  composition, then a diagnostic frame with F11 inspection, F10 grid, F7
  hitboxes, player-feet coordinates, and cursor coordinates enabled;
- rebuild both views into one review sheet before accepting any candidate;
- assert every sprite is grounded within one art pixel;
- assert scenery has no collision unless explicitly declared;
- assert props use an approved dressing definition and depth band;
- reject repeated landmarks within one or two adjacent camera frames;
- flag, rather than automatically reject, excessive occupied screen area;
- rerun the real-input traversal to prove dressing did not change gameplay.

The tester judges only route legality, timing, and repeatability. It does not
approve visual taste. Clean captures, diagnostic captures, full-route contact
sheets, and hands-on player review are separate required evidence.

## First implementation slice

Prove the workflow only on the accepted open-air rise, not the entire level:

1. Curate roughly twelve native Green Zone definitions: several bushes/hedges,
   grasses, three stone sizes, the small tree, and one larger rear tree.
2. Mark the rise as three authored zones: a sparse takeoff cluster, a wild
   mid-rise rear mass, and a grounded landing landmark.
3. Protect all four launch/landing pairs, both enemy lanes, the spike basin, and
   the concealed landing reveal.
4. Generate three deterministic previews and compare them on one contact sheet.
5. Accept and bake one arrangement only after hands-on visual review.

Do not begin with fountains, skate ramps, garbage cans, large exotic trees, or
cross-zone props. They may become strong local storytelling later, but adding
them now would invent a new place rather than enrich the established open-air
Green Zone.
