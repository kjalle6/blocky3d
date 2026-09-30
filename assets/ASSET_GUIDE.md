# Finding and using assets

Start here when choosing art or sound. Search the collection by its role before
assuming a character, effect, pose, or UI piece is missing. Many Craftpix packs
include supporting assets outside the folder suggested by the pack name.

## The three locations

| Location | Purpose |
| --- | --- |
| `D:/GodotProjects/blocky3dassets` | Original downloads, complete packs, editable PSD/vector sources, audio, and `_inbox`. |
| [library](library) | Searchable visual catalog in the project. Same relative paths as the source collection, plus preserved older paths and project-authored catalog art. |
| [art](art) and [audio](audio) | Selected production assets already used by the game or prepared for use. Start here when changing an existing feature. |

The level designer's registered objects are in
[resources/level_catalogs](../resources/level_catalogs). A PNG appearing in the
library does not give it collision, damage, an animation definition, or a
designer entry. Catalog preparation tools can make production changes; use
them only for the selected scope.

## Where to look first

Paths in this table are beneath `assets/library` and the external source root.

| Need | Look here |
| --- | --- |
| Player bodies, movement, hurt, melee and interaction poses | [characters](library/characters/README.md). Also check gun, melee, drone, and door packs through that index. |
| Ordinary enemies and bosses | [enemies](library/enemies). Families include Green Zone, factory, power station, seaport, residential, bar street, business, Chinese street, lab, police, and general cyberpunk sets. Boss packs have `_bosses` in their names. |
| Civilians, traders, bar/cafe staff, customers and animals | [npcs](library/npcs): `human_npcs`, `traders`, `bar_cafe`, `homeless`, `animal_npcs`. |
| Terrain, walls, platforms and matching scenery | [tilesets](library/tilesets). Start with the area's pack: `1 Tiles`, then `3 Objects` and `4 Animated objects` where present. |
| Matching zone backgrounds | Each tileset's `2 Background` or `3 Background`; then [backgrounds](library/backgrounds) for separate parallax collections. |
| Rocks, plants, trees and clouds | [environment/rocks](library/environment/rocks), [environment/vegetation](library/environment/vegetation), [environment/sky](library/environment/sky). |
| Bridges, doors, lifts, portals and cave entrances | [environment/structures](library/environment/structures). Door packs also contain player entry/rappelling poses. |
| Graffiti, signs, billboards and lights | [environment/urban](library/environment/urban), including both graffiti constructors and `city_visuals`. |
| Drones, trucks and police transport | [vehicles](library/vehicles). Drone **icons** are separately under `icons/drone_icons`. |
| Guns, grips, bullets and melee weapons | [weapons](library/weapons/README.md). Keep character/grip/weapon sheet choices tied to their source pack. |
| Smoke, explosions, blood, sparks, fire, water, muzzle flashes and overlays | [vfx index](library/vfx/README.md), including effect sheets bundled inside weapon packs. |
| Inventory, health, buttons, cursors, frames, bars and numbers | [gui/cyberpunk gui](<library/gui/cyberpunk gui>); production selections are under [art/ui](art/ui). |
| Scanner, implants, gadgets and eyewear candidates | [icons/implant_icons_1](library/icons/implant_icons_1), [icons/implant_icons_2](library/icons/implant_icons_2), [icons/gadget_icons](library/icons/gadget_icons), [equipment/headphones_and_glasses](library/equipment/headphones_and_glasses). These are item icons; assess them before using one as an overlay. |
| Medicine, supplies, skills, weapons and other item symbols | [icons](library/icons), plus [equipment/clothes](library/equipment/clothes) and [weapons/weapon icons](<library/weapons/weapon icons>). `resource_icons` also contains ammo/weapon icons. |
| Fonts and text styling | [fonts](library/fonts), plus the GUI pack's `10 Font`. |
| Game audio already assigned | [assets/audio](audio), [audio resources](../resources/audio), and [audio tuning guide](../docs/AUDIO_TUNING.md). |
| Original music and sound candidates | External `audio/Music`, `audio/Sounds`, and `audio/Prepared_Firearms`. Audio is deliberately outside the visual mirror. |

## Terrain and background families

The tileset collection contains bar street, beach, business center, Chinese
street, desert, dump, exclusion zone, factory, ghetto, Green Zone, industrial,
market street, pirate bay, power station, and seaport sets. The original dump
pack is stored as `dumb_zone`; search either name, but keep the actual path.

Separate background packs include desert, forest, forests and trees, mountain,
stone, horizontal nature, horizontal 2D, parallax, scrolling city, night city
street, cave parallax, pixel caves, 1-bit caves, and war backgrounds. Some
background packs are stylistically different from the current pixel-art game;
folder membership alone does not establish a visual match.

## Existing production groups

| Feature | Production location |
| --- | --- |
| Current player, early enemies, terrain and handheld weapons | [art/green_zone](art/green_zone), with source manifests and category subfolders. |
| Launcher boss from the test lab | [art/green_zone/bosses/launcher](art/green_zone/bosses/launcher). Source: `enemies/green_zone_bosses/2`. |
| Boss smoke and impact effects | [art/vfx/boss](art/vfx/boss). Reuse source effects through the VFX index. |
| Cave presentation | [art/interiors/rock_underworks](art/interiors/rock_underworks). |
| Designer scenery and expanded terrain | [art/world_scenery](art/world_scenery) and its manifest. |
| HUD, inventory, options and weapon unlock presentation | [art/ui](art/ui). |
| Shared gameplay symbols | [art/shared](art/shared). |

Some older production effects are still beside their original feature. Preserve
those working paths; put newly selected standalone effects under `art/vfx`.

## Paths that should stay stable

- `library/weapons/guns` is an older **mixed** collection: 95 same-path files
  match `guns_pack_1`, while its 20 gun sheets and 10 bullet sheets match
  `guns_pack_2`. It is not an interchangeable alias for either complete pack.
  Use the separate packs for new source lookups; preserve existing `guns` paths.
- `library/npcs/industrial_npcs` is the older catalog path for `npcs/human_npcs`.
  The canonical source pack is the townspeople collection, despite the old name.
- `library/environment/structures/cave_entrances` contains project-authored
  catalog files without a matching external source folder. Its `SOURCE.txt`
  preserves the separate source information.
- Pack numbering, spaces, and supplied spellings are meaningful file paths.
  Use friendly descriptions in indexes instead of mass-renaming source files.

`library_manifest.json` records exact paths and hashes. Records marked
`source_status: library_only` remain available at their existing paths even
when the external collection no longer has a matching path. Synchronization
retains both those files and their manifest entries.

## Working from the collection

1. Find the relevant family here, then inspect the actual sheet at native scale.
2. Check the existing feature's production manifest before replacing an asset.
3. For a new selection, copy only the needed art into the appropriate production
   folder and retain its source path, hash, and supplied license/source note.
4. Author the gameplay behavior separately and verify the result in game.

To find named sheets quickly:

```powershell
rg --files assets/library -g '*.png' | rg -i 'smoke|explosion|flame'
rg --files assets/library -g '*.png' | rg -i 'hurt|sneer|rappell|drone_interaction'
```

Refresh visual source copies with `tools/sync_visual_asset_library.ps1`.
Original ZIPs, PSD/vector sources, and audio remain outside the project mirror.
Use [asset sources and credits](../docs/ASSET_CREDITS.md) for provenance and
the [intake inventory](../outputs/asset_intake_2026-09-30/report.md) for the
September 30 additions.
