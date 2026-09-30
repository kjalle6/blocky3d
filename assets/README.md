# Asset collection

Start with the [asset guide](ASSET_GUIDE.md) to find art by role, locate
animations/effects bundled in other packs, and distinguish source art from
production files. It also records the older paths kept for compatibility.

Complete downloaded packs and editable sources remain outside the repository
at:

`D:\GodotProjects\blocky3dassets`

Runtime-ready visual files are mirrored beneath `assets/library` so Codex,
Godot's filesystem browser, and other tools can search and audit the complete
owned collection during level authoring. Run
`tools/sync_visual_asset_library.ps1` to refresh it. Files remain unmodified
and retain their source-pack structure where practical. Standalone effects are
grouped under `vfx`, with their original pack/member paths recorded in
`SOURCE.txt`. Selected production files are promoted into `assets/art`.

The drone pack's additional Biker, Punk, and Cyborg animation sheets are also
grouped with the character animations at
`assets/library/characters/animations/{1,2,3}/Drone_interaction.png`.
`Drone_pack_source.txt` and `Drone_pack_license.txt` in that animations folder
record their original drone-pack locations and supplied license note.

The [September 30 asset intake](../outputs/asset_intake_2026-09-30/report.md)
indexes 29 added packs and six verified duplicate downloads. It includes
street tilesets, enemy and boss families, police vehicles, traders and other
NPCs, graffiti, and equipment icons. Implant icons are in
`icons/implant_icons_1` and `icons/implant_icons_2`; glasses and headphones are
in `equipment/headphones_and_glasses`. These paths exist in both the external
collection and `assets/library`.

Approved and transformed production art belongs beneath `assets/art`. The
opening-world pixel set is curated beneath `assets/art/green_zone`; its
manifest records source-relative paths and hashes, and supplied license notes
are stored beside it.

Before promoting a library asset into production:

1. confirm its source and license;
2. choose a clear runtime role;
3. normalize pixel filtering, scale, pivot, and transparent padding;
4. place any approved derivative beneath `assets/art`;
5. keep gameplay collision independently authored;
6. update the manifest and license notes.

The canonical asset and visual rules are in
[`docs/TECHNICAL_FOUNDATION.md`](../docs/TECHNICAL_FOUNDATION.md) and
[`docs/GAME_DIRECTION.md`](../docs/GAME_DIRECTION.md).
