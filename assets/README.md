# Runtime assets

This directory contains only assets imported for the running Godot game.
Complete downloaded packs, editable sources, and unused alternatives remain
outside the repository at:

`D:\GodotProjects\blocky3dassets`

The opening-world pixel set is curated beneath `assets/art/level01` and is
currently shared by Levels 1 and 2. Its manifest records source-relative paths
and hashes; supplied license notes are stored beside it.

Before adding an asset:

1. confirm its source and license;
2. choose a clear runtime role;
3. normalize pixel filtering, scale, pivot, and transparent padding;
4. import only the required files;
5. keep gameplay collision independently authored;
6. update the manifest and license notes.

The canonical asset and visual rules are in
[`docs/TECHNICAL_FOUNDATION.md`](../docs/TECHNICAL_FOUNDATION.md) and
[`docs/GAME_DIRECTION.md`](../docs/GAME_DIRECTION.md).
