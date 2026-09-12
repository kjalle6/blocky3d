# Saved level layouts

The in-game designer saves one readable JSON file per registered scene section
here. These files override the structural scene when the game loads. Include
them in commits and exports alongside the relevant scenes.

Schema 3 stores added objects as known catalog template IDs plus validated
properties and signatures for the templates actually used. Adding an unrelated
terrain/prop pack does not invalidate a layout. Changing an asset it uses still
requires review, as does changing its structural base. Older schema 1/2 files
remain readable when their structural fingerprint matches.

Platforms, individual tiles, enemies, hazards, checkpoints, and decorations all use
the same save path; never put arbitrary scene or script paths into a layout.

Godot's ordinary scene editor shows the structural base. Before changing a
registered section, inspect the resolved layout with
`tools/inspect_level_layout.gd` through the normal Godot runner. Never silently
discard a saved override to make a scene or validator appear unchanged.

Files ending in `.bak` are local previous-save backups; `.tmp` and `.lock`
directories are temporary save coordination. Compatible unsaved recovery drafts
live under `user://level_designer`, separate from production layouts.

At the accepted 2026-09-12 checkpoint this directory contains no production
layout JSON. Temporary fixture saves used for validation were removed. Preserve
any newer user-created section saves; they are authored content, not build
artifacts. The user's local sandbox recovery remains separate from Git.

The structural fingerprint includes supported enemy scripts, so even a shared
combat change can require review of a draft or saved layout. Read both the
resolved project layouts and current local recovery before such changes. Keep
the original file, establish why the base changed, and validate unchanged
records before any specific recovery; never blanket-update fingerprints.

See [the designer guide](../../docs/LEVEL_DESIGNER.md) for edit/test/save behavior
and [the current handoff](../../NEW_CHAT_README.md) for checkpoint evidence.
