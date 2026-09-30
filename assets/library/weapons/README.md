# Weapon asset index

Original pack folders stay intact so matching character bodies, grips, weapons,
projectiles and effects can be found together. Standalone production effects
belong under the project's `assets/art/vfx`.

| Family | Contents |
| --- | --- |
| [guns_pack_1](guns_pack_1) | `1 Characters`, `2 Guns`, `3 Hands`, `4 Shoot_effects`, `5 Bullets`. |
| [guns_pack_2](guns_pack_2) | A separate second collection with the same layout. These are additional assets, not a replacement for pack 1. |
| [beginner weapons](<beginner weapons>) | `1 Characters` has body/attack animations; `2 Weapons` has matching melee weapons. |
| [gun_constructor](gun_constructor) | Guns, bullets, firing effects and construction parts in numbered folders. |
| [bombs](bombs) | Bomb sprites, animation sheets and `3 Effects`, grouped by effect size. |
| [weapon icons](<weapon icons>) | Melee equipment icons. Firearm/ammo icons are also under `../icons/firearm_icons` and `../icons/resource_icons`. |

The older project-only `guns` folder is a mixed collection: 95 same-path files
match pack 1, but its 20 gun sheets and 10 bullet sheets match pack 2. Preserve
existing references; it is not an interchangeable copy of either complete pack.

Character animation lookup: [characters index](../characters/README.md).
Explosion, muzzle flash and other effect lookup: [VFX index](../vfx/README.md).
