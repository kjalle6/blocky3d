# blocky3d

A pixel-art action platformer about fast movement, precise jumps, and fighting
through a cyberpunk world. The journey begins on a quiet shoreline, crosses the
overgrown Green Zone, and gradually introduces the machinery and armed enemies
beyond it. `blocky3d` is the working codename; the final title is undecided.

Running, double jumping, wall jumping, and dashing form the core of the game.
Knife attacks and stomps keep combat close to the platforming, while a handgun
adds ranged combat later in the opening world. The aim is demanding, readable
challenges with room to learn and improve.

## What's playable

The project is in development. The opening world has two complete levels and a
third in progress:

| Level | What to expect | Status |
| --- | --- | --- |
| Arrival / Shoreline | Beach and forest paths, early combat, and the Double Jump introduction | Complete |
| Overgrown Coastal Ascent | A dusk approach and connected cave route that teaches Wall Jump and Dash | Complete |
| Green Zone Finale | Nighttime traversal, the first handgun encounter, destructible cover and a tank fight leading into a wall-jump escape | In progress; later gunners and the boss remain |

Current systems include player and enemy health, carried healing items, a paused
inventory with two quick-use slots, ammunition and active reloads, supply chests,
manual saves, and autosaves. Spikes, pits, and flying hazards remain lethal.
Combat values and supply amounts are still being balanced.

The project also includes a Firearm Review Lab and an in-game level designer
for building terrain and placing enemies, hazards, props, autosave points, and
supply chests.

## Run the project

Use **Godot 4.6.3, standard build**, with the **Compatibility** renderer.
The game plays in 2D; Godot's 3D scene system provides layered pixel-art
presentation. There is no C# dependency.

1. Clone this repository and import `project.godot` in Godot.
2. Let the editor finish importing the assets, then press **F5**.
3. Choose **New campaign**, **Continue**, or **Load save** to play with persistent
   progress. The development selector opens individual levels and labs with
   fresh test states, separate from campaign saves.

The assets needed to run the project are included. The separate
`blocky3dassets` folder holds original downloaded packs and editable source
files used during development; it is not required to play this checkout.

## Controls

Abilities become available as they are learned during the campaign.

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move | A / D or left / right arrows | Left stick |
| Jump / wall jump | Space, W, or up arrow | South button |
| Dash | Shift | East button |
| Attack / shoot | Left mouse or J | West button |
| Aim handgun | Mouse; W / up also aims diagonally upward | Stick up for diagonal aim |
| Switch weapon | 1 / 2 or mouse wheel | Right shoulder |
| Reload | R | North button |
| Use quick items | Q / E | D-pad left / right |
| Inventory | Tab | Available through the pause menu |
| Pause | Escape | Start |

In the inventory, hover an item and press **Q** or **E** to assign it. The game
pauses while the inventory is open. During a reload, press reload again while
the marker is inside the highlighted window to finish early.

Autosave points record health and supplies without healing. Manual saves are
available from the pause menu while safely grounded and out of combat. The
[save guide](docs/SAVE_SYSTEM.md) explains slots, recovery, and how loading an
older save affects progression.

## Development

**F1** shows the development tools, including the level designer, audio tuning,
and restart controls. **F7** shows hitboxes, **F10** shows the world grid, and
**F11** enables free-flight inspection.

| Guide | Contents |
| --- | --- |
| [Game direction](docs/GAME_DIRECTION.md) | Movement, combat, setting, and intended player experience |
| [Level roadmap](docs/LEVEL_ROADMAP.md) | Campaign progress and remaining work |
| [Combat balance](docs/COMBAT_BALANCE.md) | Health, damage, healing, and tuning targets |
| [Inventory and saves](docs/SAVE_SYSTEM.md) | Current controls, save behavior, and recovery |
| [Supply chests](docs/CHEST_LOOT.md) | Loot pools, fixed rewards, and chest authoring |
| [Level designer](docs/LEVEL_DESIGNER.md) | Building, placement, testing, and saving layouts |
| [Audio tuning](docs/AUDIO_TUNING.md) | Assigning and tuning sounds |
| [Phantom Camera trial](docs/PHANTOM_CAMERA.md) | Editing the Level 3 camera rail and testing transitions |
| [Asset sources and credits](docs/ASSET_CREDITS.md) | Art, font, audio, tool licenses, and remaining source questions |
| [Technical foundation](docs/TECHNICAL_FOUNDATION.md) | Runtime architecture, rendering, and asset workflow |
| [Maintenance priorities](docs/MAINTENANCE_PLAN.md) | Small fixes now, improvements alongside features, and release preparation |
| [Godot MCP](docs/GODOT_MCP.md) | Editor automation setup and live playtesting |

Standalone checks run through the project's PowerShell tools:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_validation_suite.ps1
```

For a focused check, use `tools/run_godot_tool.ps1 -Script res://tools/<script>.gd`.
The runner accepts `-GodotExecutable` when Godot is installed at a different
path from the local default. Automation details are in [AGENTS.md](AGENTS.md).
