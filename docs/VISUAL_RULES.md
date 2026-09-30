# Visual inspection rules

This is a QA checklist grounded in the project's existing direction, not a new
art direction or blanket approval of the current build. Apply it through
[the visual QA procedure](VISUAL_QA.md).

## Sources and approval

- [Game direction](GAME_DIRECTION.md#art-sound-and-interface) establishes crisp
  pixel art, coherent local palettes, clear gameplay silhouettes, natural ground
  contact, and a readable distinction between solid and decorative props.
- [Technical foundation](TECHNICAL_FOUNDATION.md#pixel-art-invariants) owns the
  rendering and scale contracts and their exceptions. Its asset workflow also
  requires nearest filtering and deliberate use of art from different packs.
- [Level 2 visual brief](LEVEL_2_VISUAL_BRIEF.md) records that level's accepted
  route and composition. It is not a reference for redesigning other levels.
- [Level roadmap](LEVEL_ROADMAP.md) records area-specific intent and remaining
  review. WIP descriptions, concepts, generated mockups, old screenshots, and
  passing validators do not establish visual approval. Use an image as an
  approved reference only when its approval and scope are documented or supplied
  by the user. Otherwise label it contextual or unapproved.

## Checklist

| Check | Look for and investigate |
| --- | --- |
| Pixel scale and filtering | Blurred edges, inconsistent source-pixel size, or scenery jitter during camera movement. Authored scenery uses `PixelPlatform3D.TILE_PIXEL_SIZE` (0.04 m), including effective parent transforms. Actors, pickups, and the goal chest have deliberate scale exceptions; do not normalize them to scenery. |
| Tiles and seams | Wrong cap, edge, corner, fill, or slope piece; exposed rectangular tile faces through grass; doubled surfaces, gaps, and abrupt texture joins. Identify the actual texture/atlas region and adjacent intended use before claiming a wrong tile. Follow the foundation's terrain rules: no rotated corners creating false notches, and no end caps inside continuous terrain. |
| Ground contact and placement | Floating feet, cover, chests or props; clipping into floors; unsupported-looking pieces; sprite padding/pivot mismatch. Check visible texture bounds and inherited transforms, not origins alone. |
| Cover and collision cues | Does the cover visibly protect the actor where bullets actually stop? Does apparent ground support the player? Does apparently open space block movement or fire? Check relevant collision shapes/layers/masks and ordinary gameplay; decorative art need not itself be solid. |
| Layering and occlusion | Foreground hiding enemies, pickups, hazards, or landing edges; unstable sorting as the camera moves. This is a 3D scene with 2D gameplay: inspect world depth, `render_priority`, transparency/depth settings, and parents. Terrain priority is 0; bedded props use negative and props on top positive priority. Overlapping props require deliberate ordering. Do not assume `z_index` controls Sprite3D. |
| Local art consistency | Palette, outlines, pixel density, silhouettes, or effects visibly conflicting with documented local treatment. A different source pack alone is not a defect. Support stylistic findings with a rule or approved comparison. |
| Camera and motion | Cropped necessary threats/landing targets, backdrop gaps, layer drift, sorting pops, and obstructed routes at normal gameplay framing. Capture motion or multiple positions for temporal claims. Intentional offscreen threats and authored reveals must be checked against encounter intent. |
| Effects and interface | Overlays, lighting, particles, or 3D effects hiding needed gameplay cues or violating the local pixel-art treatment. Intentional soft UI glows and authored grading are not automatically filtering defects. |

Ask what a player can reasonably read: where to stand, what hurts, where to go,
what can be interacted with, and where shots can pass. A report must identify
the misleading cue and its consequence, not merely say an area feels wrong.

Bosses use their large encounter health bar only. The small overhead health bar
belongs to regular enemies; check the boss after damage as well as at full health.

Do not report personal preferences, speculative redesigns, or a quota of issues.
Keep uncertain causes separate from visible observations. A suspected defect
without enough evidence is an unresolved check, not a confirmed finding.
