# Asset sources and credits

This index connects the game's assets to their source records and supplied
licenses. `assets/art` contains curated production art. `assets/audio` contains
both selected sounds and comparison candidates; the saved
[audio mix](../resources/audio/movement_mix.tres) records current assignments.
The full `assets/library` is an authoring and audition catalog.

The only current export preset, `LayoutSmoke`, excludes the catalog but includes
other project resources. It is a validation preset, not a release asset list.
Before distributing a build, check its actual dependencies and include the
required notices. Some source questions remain listed below.

## Art and font

| Production family | Source and evidence | Supplied license record |
| --- | --- | --- |
| Green Zone characters, enemies, weapons, projectiles, effects, terrain, scenery, backgrounds, and shoreline | Craftpix packs; [asset manifest](../assets/art/green_zone/asset_manifest.json), [catalog manifest](../assets/art/green_zone/catalog/manifest.json), and [layout promotions](../assets/art/green_zone/layout_export_promotions.json) record paths, hashes, and transformations | [Pack license files](../assets/art/green_zone/licenses) |
| Cave terrain and rocks | Craftpix Dumb Zone tiles and Rocks collection; [source manifest](../assets/art/interiors/rock_underworks/source_manifest.json) records exact matches to the catalog | Each manifest entry links its pack license; [retained cave license reference](../assets/art/interiors/rock_underworks/licenses/source_license.txt) |
| Expanded designer terrain and scenery | Remaining Craftpix terrain packs, nature/trees/rocks/clouds, bridges, doors, graffiti, signs and vehicles; [world scenery manifest](../assets/art/world_scenery/manifest.json) records unchanged images, source hashes and per-file supplied license paths | Supplied license files are copied beside the promoted packs; cave entrance source notes retain the separate Pixie Haus attribution |
| Cave backgrounds | Craftpix Pixel Cave Game Parallax Backgrounds; [source archive and layer mapping](../assets/art/interiors/rock_underworks/background/SOURCE.txt) | License reference in the source record |
| Cave lift and slide dust | Craftpix Piratebay Zone, Industrial Zone, Doors and Portals, and Pixel Effects; [lift sources](../assets/art/interiors/rock_underworks/props/cave_lift/SOURCE.txt), [dust source](../assets/art/interiors/rock_underworks/effects/SOURCE.txt), and the cave manifest above | Individual catalog license paths in the cave manifest |
| Health HUD, inventory, options, weapon showcase, and pixel font | Craftpix Cyberpunk GUI; [health/font manifest](../assets/art/ui/health/source_manifest.json), [inventory manifest](../assets/art/ui/inventory/source_manifest.json), [options manifest](../assets/art/ui/options/source_manifest.json), [weapon showcase manifest](../assets/art/ui/weapon_unlock/source_manifest.json) | [Cyberpunk GUI license](../assets/art/ui/weapon_unlock/License.txt) |
| Healing icons | Craftpix Radioactive Icons; [health manifest](../assets/art/ui/health/source_manifest.json) | [Radioactive Icons license](../assets/library/icons/radioactive_icons/License.txt) |
| Handgun ammo icon | Craftpix Resource Icons, `Icon1_02.png`; [source manifest](../assets/art/ui/items/source_manifest.json) | [Resource Icons license](../assets/library/icons/resource_icons/License.txt) |
| Shared spike and ability symbols | Four local SVG files in [shared art](../assets/art/shared); no separate source/authorship record | Unresolved; see follow-up list |

Most Craftpix pack license files contain a link to the publisher's license
page rather than the full terms. The records preserve what the packs supplied;
they do not grant rights beyond those terms.

## Audio

| Family | Creator / source | Evidence and recorded license |
| --- | --- | --- |
| Combat sounds from the flattened local collection | Craftpix audio packs 1, 3, 4, 5, and 7 | All 15 files matched original ZIP entries by SHA-256. [Combat manifest](../assets/audio/combat/source_manifest.json) and [archive evidence](../assets/audio/source_archive_matches.json) retain file hashes, archive hashes, member names, and each pack's license reference. |
| Tank shot, moving tracks, psychic pulse, and provisional crate break | Craftpix packs 5, 2, and 7 | [Tank audio manifest](../assets/audio/combat/tank_source_manifest.json) records unchanged copies, exact ZIP matches and supplied license references. `Crate_open_1.wav` is the temporary break cue; `Punch_with_electricity.wav` is the provisional psychic pulse. |
| Knife impact and alternative flesh slice | Mixedupmoviestuff, “Knife Stab.wav”; NeoSpica, “Slicing through flesh” | Individual Freesound pages and CC0 1.0 declarations are retained in the combat manifest. |
| Healing cue and handgun reload | Craftpix packs 6 and 4 respectively | Exact ZIP matches in the archive evidence; [healing source record](../assets/audio/items/source_manifest.json). |
| Grass and sand footsteps / jumps, plus comparison candidates | NOX Sound Essentials Series (recorded CC0), Dryoma Footsteps sounds (recorded CC BY 4.0), Craftpix pack 7, and one Antons candidate with license pending | [Credits and source pages](../assets/audio/footsteps/CREDITS.txt), [file hashes](../assets/audio/footsteps/sources.json), and [trimmed run derivation](../assets/audio/footsteps/tight_run/SOURCE.txt). Craftpix's footstep also has an exact archive match. |
| Cave ambience | NOX SOUND Nature Essentials | [Original filename, hash, and source path](../assets/audio/ambience/SOURCE.txt); a pack-specific license record remains to be retained. |
| Water splash | Embedded metadata identifies Fesliyan Studios; exact source page and license unresolved | [Source file, hash, and metadata evidence](../assets/audio/water/SOURCE.txt). |
| Tuned `.res` audio | Derived from source recordings through the audio tool | Files retain `source_file` and `source_sha256` metadata; tuning is stored in the [audio mix](../resources/audio/movement_mix.tres). Source credits still apply. See the [audio guide](AUDIO_TUNING.md). |

The archive audit resolved every combat entry previously marked as an unknown
collection. It used the seven original Craftpix audio ZIPs under
`D:/GodotProjects/blocky3dassets/audio`; 18 unchanged project recordings matched
entries in six of those archives. The audit changed metadata only.

## Bundled tools

Phantom Camera 0.11.0.3 is vendored unchanged under
[`addons/phantom_camera`](../addons/phantom_camera), with its
[MIT license](../addons/phantom_camera/LICENSE), copyright 2022 Marcus Skov.
Keep the notice with redistributed copies. The [camera guide](PHANTOM_CAMERA.md)
records its source release, integration and checks.

The vendored [Godot MCP Toolkit](../addons/godot_mcp_toolkit) has an
[MIT license](../addons/godot_mcp_toolkit/LICENSE), copyright 2026 NPGameDev.
Keep its notice with redistributed copies. The project's integration and
separately installed server are described in [Godot MCP setup](GODOT_MCP.md).
The addon has a runtime autoload, so its export inclusion needs review with the
release preset. Its license does not define a license for this game's own code
or art.

## Bounded source follow-ups

- **Antons grass step:** recover the download page and license for
  `assets/audio/footsteps/grass_walk_01.wav` from the original download record.
  The local folder and hash are known; no license has been established.
- **Water splash:** recover the Fesliyan Studios source page/download terms for
  `heavy-water-splash.mp3`. The embedded attribution alone does not establish
  the license.
- **NOX cave ambience:** retain the Nature Essentials pack's license alongside
  its existing source record; do not infer it solely from another NOX pack.
- **Shared SVGs:** confirm project authorship or record their original source
  for `spike.svg`, `dash.svg`, `double_jump.svg`, and `wall_jump.svg`.

These entries can stay open during development. Resolve any included asset
before release, or make a separate, reviewed replacement choice. Current
sounds and visuals remain intact.

## Adding or promoting an asset

The tank's five promoted enemy-6 sheets have their own
[source and hash record](../assets/art/green_zone/enemies/tank/source_manifest.json),
using the existing Green Zone enemies license record. The upward firing pose
reuses a cropped barrel from the idle sheet and masks the horizontal barrel at
runtime; the source images remain unchanged. The wall-jump scaffold assembles
the Bridge Constructor pack's `Bridge_tile_111`, `112`, `133`, `145`, `146`,
and `147` as native-size sprites. Posts, splice plates and deck edges use atlas
crops; the PNGs stay unchanged. Their paths, hashes and supplied license are in
the world scenery manifest above. Collision shapes remain project-authored.

1. Keep the original download, editable source, and supplied license in
   `blocky3dassets`. Record its publisher/creator, source page when known, and
   pack name. Missing information belongs in the follow-up list.
2. Use [the visual library sync tool](../tools/sync_visual_asset_library.ps1)
   for searchable catalog files. Its [library manifest](../assets/library/library_manifest.json)
   records source paths and hashes. Original archives remain outside the repo.
3. Promote selected files into `assets/art` or `assets/audio`, recording their
   destination, source path, SHA-256, license record, and any transformations in
   the relevant family manifest. Existing art tools include
   [Green Zone preparation](../tools/prepare_green_zone_assets.ps1),
   [catalog preparation](../tools/prepare_green_zone_catalog.py),
   [beach blocks](../tools/prepare_beach_block_catalog.py), and
   [handgun double-jump assembly](../tools/prepare_player_handgun_double_jump.ps1).
4. Review the asset in game and update this index if it introduces a new source
   family. Save audio choices through the audio tool; preserve source metadata
   for tuned copies. Rendering and collision guidance stays in the
   [asset pipeline](TECHNICAL_FOUNDATION.md#asset-pipeline).
