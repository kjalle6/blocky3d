# Runtime assets

Complete downloaded packs and editable sources remain outside the repository
at:

`D:\GodotProjects\blocky3dassets`

Runtime-ready visual files are mirrored beneath `assets/library` so Codex,
Godot's filesystem browser, and other tools can search and audit the complete
owned collection during level authoring. Run
`tools/sync_visual_asset_library.ps1` to refresh it. Files remain unmodified
and retain their source-pack structure. Selected production files are promoted
into `assets/art`.

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
