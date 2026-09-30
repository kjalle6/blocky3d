# Asset intake — 2026-09-30

35 incoming ZIPs: 29 new packs and 6 exact duplicate downloads.
1975 catalog files added, including 1885 PNGs. Library entries: 5554 → 7529.

The source collection is `D:/GodotProjects/blocky3dassets`; searchable visual copies are under `assets/library` in the project. Original ZIPs and PSD files stay in the source collection. These are catalog additions; no gameplay scenes were changed.

## New packs

| Download | Organized folder | PNG sheets in ZIP (excluding Apple metadata) |
| --- | --- | ---: |
| craftpix-net-101350-drone-32x32-pixel-art-icons.zip | `icons/drone_icons` | 40 |
| craftpix-net-153816-cyberpunk-market-street-pixel-art.zip | `tilesets/market_street` | 141 |
| craftpix-net-255422-enemies-chinese-street-pixel-art.zip | `enemies/chinese_street_enemies` | 31 |
| craftpix-net-278498-bar-street-tileset-pixel-art-pack.zip | `tilesets/bar_street` | 164 |
| craftpix-net-283889-cyberpunk-pixel-bar-cafe-npc-asset-pack.zip | `npcs/bar_cafe` | 42 |
| craftpix-net-355913-bosses-chinese-street-pixel-art.zip | `enemies/chinese_street_bosses` | 34 |
| craftpix-net-360771-medicine-and-thematic-things-pixel-art-32x32-icon-pack.zip | `icons/medicine_icons` | 41 |
| craftpix-net-384116-bar-street-bosses-pixel-art.zip | `enemies/bar_street_bosses` | 37 |
| craftpix-net-386974-bar-street-enemies-pixel-art.zip | `enemies/bar_street_enemies` | 33 |
| craftpix-net-446105-business-enemies-pixel-art.zip | `enemies/business_enemies` | 31 |
| craftpix-net-477421-cyberpunk-gadgets-pixel-art-32x32-icon-pack.zip | `icons/gadget_icons` | 41 |
| craftpix-net-507212-homeless-character-pixel-art-pack.zip | `npcs/homeless` | 36 |
| craftpix-net-516420-trader-cyberpunk-pixel-art-pack.zip | `npcs/traders` | 30 |
| craftpix-net-527764-pixel-art-enemy-character-pack.zip | `enemies/cyberpunk_enemies` | 34 |
| craftpix-net-541373-lab-bosses-pixel-art.zip | `enemies/lab_bosses` | 30 |
| craftpix-net-550902-police-cyberpunk-characters-pixel-art.zip | `enemies/police` | 32 |
| craftpix-net-588685-cyberpunk-firearm-pixel-art-32x32-icons.zip | `icons/firearm_icons` | 40 |
| craftpix-net-613851-graffiti-constructor-pixel-art-pack-2.zip | `environment/urban/graffiti_2` | 337 |
| craftpix-net-615713-cyber-implant-32x32-icons-pixel-art.zip | `icons/implant_icons_1` | 41 |
| craftpix-net-622073-business-center-tileset-pixel-art.zip | `tilesets/business_center` | 123 |
| craftpix-net-667785-lab-enemies-pixel-art.zip | `enemies/lab_enemies` | 35 |
| craftpix-net-687978-police-transport-pixel-art-assets.zip | `vehicles/police_transport` | 34 |
| craftpix-net-713504-various-bosses-pixel-art-pack.zip | `enemies/various_bosses` | 29 |
| craftpix-net-716407-chinese-street-tileset-pixel-art.zip | `tilesets/chinese_street` | 133 |
| craftpix-net-805026-implants-for-cyberpunk-32x32-pixel-icons.zip | `icons/implant_icons_2` | 40 |
| craftpix-net-834374-jewelry-32x32-pixel-art-icons.zip | `icons/jewelry_icons` | 40 |
| craftpix-net-856137-headphones-and-glasses-pixel-icon-set.zip | `equipment/headphones_and_glasses` | 40 |
| craftpix-net-995156-ghetto-tileset-pixel-art.zip | `tilesets/ghetto_zone` | 174 |
| craftpix-net-999713-cyberpunk-pixel-art-bosses-pack.zip | `enemies/cyberpunk_bosses` | 28 |

## Duplicate downloads

These inbox copies are byte-identical to the retained ZIPs below; no unique archive content is discarded.

| Inbox ZIP | Retained source archive |
| --- | --- |
| craftpix-net-184808-free-cyberpunk-resource-pixel-art-32x32-icons.zip | `icons/resource_icons/craftpix-net-184808-free-cyberpunk-resource-pixel-art-32x32-icons.zip` |
| craftpix-net-796772-free-extra-animations-for-cyberpunk-characters.zip | `characters/animations/craftpix-net-796772-free-extra-animations-for-cyberpunk-characters.zip` |
| craftpix-net-823313-residential-area-enemies-pixel-art-pack (1).zip | `enemies/residential_area_enemies/craftpix-net-823313-residential-area-enemies-pixel-art-pack.zip` |
| craftpix-net-823313-residential-area-enemies-pixel-art-pack.zip | `enemies/residential_area_enemies/craftpix-net-823313-residential-area-enemies-pixel-art-pack.zip` |
| craftpix-net-894350-trees-and-bushes-pixel-art-for-platformer.zip | `environment/vegetation/nature/craftpix-net-894350-trees-and-bushes-pixel-art-for-platformer.zip` |
| craftpix-net-920510-free-graffiti-constructor-pixel-art.zip | `environment/urban/graffiti/craftpix-net-920510-free-graffiti-constructor-pixel-art.zip` |

## Effects and source details

- Seven identical explosion sheets share `vfx/shared_combat/Explosion.png`.
- The electric attack effect is catalogued at `vfx/shared_combat/Electric_attack.png`; it also matches the existing bombs pack effect. Its original source remains intact.
- Four flame sheets and one dust sheet are under `vfx/bar_street_bosses`.
- Per-pack `SOURCE.txt` files map relocated effects to their original ZIP members and preserve hashes and license references.
- Both implant icon packs are distinct and retained as `icons/implant_icons_1` and `icons/implant_icons_2`.
- The bar/café NPC ZIP omitted a license file; this source follow-up is resolved. The owner supplied the [official product page](https://craftpix.net/product/cyberpunk-pixel-bar-cafe-npc-asset-pack/), and [Craftpix's premium/paid product terms](https://craftpix.net/file-licenses/) were checked on September 30, 2026. Both links are retained in the pack's source note.
- Apple `__MACOSX` metadata was not extracted; it remains preserved inside the original ZIPs.
- Shared palettes and pack-specific repeated files remain with their packs where that context is useful.

## Verification

All retained ZIPs, archive members, organized files, mirror files, and preexisting manifest entries verified by SHA256.

Inbox cleanup: complete; 29 original ZIPs filed with their packs, six duplicate inbox copies removed, inbox empty.

Detailed member-to-destination evidence is in [audit.json](audit.json).
