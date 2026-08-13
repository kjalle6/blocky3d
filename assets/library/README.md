# Searchable source library

This directory mirrors the runtime-ready visual files from
`D:\GodotProjects\blocky3dassets`. It is a searchable source-art catalog for
Codex, Godot's filesystem browser, and other project tools.

Files here remain unmodified and preserve their source-pack organization.
Approved, transformed, or permanently referenced game assets belong under
`assets/art`. Copy selected production files there before using them in a
scene, so the actual runtime dependency set remains explicit.

Refresh the mirror with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_visual_asset_library.ps1
```

The synchronizer includes PNG, SVG, TTF, OTF, and text/license files. It omits
audio, `_inbox`, DCC/source documents, archives, and operating-system metadata.
