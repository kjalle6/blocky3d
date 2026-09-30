# Searchable source library

Use the [asset guide](../ASSET_GUIDE.md) for a map by purpose, or the focused
[character](characters/README.md), [weapon](weapons/README.md), and
[VFX](vfx/README.md) indexes for mixed-pack contents.

This directory mirrors the runtime-ready visual files from
`D:\GodotProjects\blocky3dassets`. It is a searchable source-art catalog for
Codex, Godot's filesystem browser, and other project tools.

Files here remain unmodified and generally preserve their source-pack organization.
Standalone effects from mixed packs are grouped under `vfx`; per-pack
`SOURCE.txt` files record their original ZIP member and catalog destination.
Approved, transformed, or permanently referenced game assets belong under
`assets/art`. Copy selected production files there before using them in a
scene, so the actual runtime dependency set remains explicit.

Refresh the mirror with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_visual_asset_library.ps1
```

The synchronizer includes PNG, SVG, TTF, OTF, and text/license files. It omits
audio, `_inbox`, DCC/source documents, archives, and operating-system metadata.
Existing catalog files that no longer have a matching external path are retained
and indexed with `source_status: library_only`; this includes legacy folder
names and project-authored cave entrance art. Synchronization does not delete
or rename those files.

The [September 30 intake report](../../outputs/asset_intake_2026-09-30/report.md)
lists the new pack locations, duplicate archive matches, and verification.
