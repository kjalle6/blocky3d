# Zone asset catalogs

All installed terrain packs and the world-building prop collections are available
through the shared Build/sidebar/full-browser workflow. Additional zones extend
these catalogs without requiring another browser. See
[the designer guide](../../docs/LEVEL_DESIGNER.md).

`level_object_catalog.gd` discovers the JSON files in this directory. Entries
appear in both designer browsers; each declares its zone and existing category.
Catalogs are available in every registered level, not restricted to that zone's
campaign scenes. Stable template IDs are stored in layout saves.

`level_object_library.gd` maps these entries to the user-facing **Blocks**
category. The underlying category names in JSON remain compatible; browser
organization does not change saved runtime definitions. Legacy rectangular
platform templates remain loadable/editable but are hidden from new placement.
`authored_scenery.json` likewise keeps exact original scenery appearances for
editing and duplication, without repeating their scale/depth variants in Add.
`resources/level_scenery.json` registers those original Sprite3D nodes by stable
section/path. The export preset includes this registration map explicitly.
Beach exposes the six existing production sand top/side/fill images through
`tools/prepare_beach_block_catalog.py`. Its `surface: sand` field supplies the
new-placement default, which is then saved in the block's validated properties.

Green Zone contains 96 tiles, 78 static props, and 5 animated props. Backgrounds
are deliberately excluded. Run `tools/prepare_green_zone_catalog.py` with Python
and Pillow to regenerate the metadata and promote byte-for-byte images from
`assets/library/tilesets/green_zone` to `assets/art/green_zone/catalog`.
The generator refuses to overwrite a production image with different bytes.
`assets/art/green_zone/catalog/manifest.json` records source/output hashes.

`world_scenery.json` adds 2,129 entries from the other terrain zones and the
environment/vehicle collections. Regenerate with Python + Pillow using
`tools/prepare_world_scenery_catalog.py`. Original images and supplied licenses
are retained under `assets/art/world_scenery`, with source paths and SHA-256
hashes in its manifest. Marketing previews, overview atlases, duplicate graffiti
copies and enlarged duplicates are omitted. Screen backgrounds, character
combat sheets and GUI assets continue to use their own systems. The browsers
page results so the full collection does not create thousands of UI controls.

To add another terrain/prop zone, prepare another JSON catalog using the same
entry types and a new stable ID prefix. Promote its approved runtime images
into `assets/art`, preserving source art. Do not reference `assets/library` from
production catalog entries; exports deliberately exclude that source archive.
The export preset includes zone JSON files explicitly.

- Tiles use `kind: tile`, a native 32x32 image, grid anchor, `solid`, and a
  collision polygon in image pixels for solid pieces. The Green Zone generator
  derives a convex outer outline from opaque pixels; it preserves slopes but
  simplifies concavities. Tile artwork is not cropped or rescaled.
- Props use `kind: decoration` and a ground or air anchor. Static props crop
  transparent image margins when placed. They have no gameplay collision.
- Animated props additionally declare frame count, frame width/stride, FPS,
  loop behaviour, and a shared `frame_region` crop. Check frame boundaries
  visually: Green Zone's chest has seven 32px cells in a 222px-wide sheet,
  with two transparent columns missing from the final cell.
- Use descriptions that explain placement and any meaningful limitations.
  New game behaviour needs an explicitly supported object kind and its own
  validation; dropping an image into a catalog does not create that behaviour.

Schema 3 layout saves include signatures only for used templates, excluding
display names, descriptions, categories, and zone labels. Unrelated entries can
be added without invalidating saved levels. Changes to a used template's runtime
definition/image or structural scene/scripts require review. Do not silently
rewrite a user's layout fingerprint or asset signatures to bypass that review.

Run the appropriate catalog, layout, and integration checks through the Godot
runner, including a rendered browser/placement review and isolated export
loading when adding runtime dependencies. Keep capture fixtures separate from
the user's saved layouts and empty sandbox.
