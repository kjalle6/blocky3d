# Working title: TBD

`blocky3d` is the internal codename for a Godot 4.6 pixel-art precision
platformer. The public title is still undecided. The game combines fast,
expressive side-scroller movement with light combat and a larger cyberpunk
setting that begins on a beach and in the natural Green Zone.

The game is 2D and stays 2D. The implementation uses Godot 3D nodes to stage
pixel art on layered depth planes, which is an internal presentation choice, not
a claim that the finished game is a 3D platformer. Gameplay never leaves its
single flat plane.

Godot is the canonical implementation. The Python game and Unreal prototype
remain read-only design references.

## Current state

- Arrival / Shoreline is the first completed production campaign level. Its
  route runs from the animated shoreline through Green Threshold, Thorn Garden,
  and an open-air Double Jump rise to a safe tire-swing-tree clearing. The
  clearing now carries the player through a matched run-out/run-in transition
  into Level 2, recording Level 1 completion without interrupting the journey
  with a completion overlay
- Overgrown Coastal Ascent is the second completed production campaign level.
  Two patrols guard its dusk approach; a cave threshold leads through a short
  slide cutscene into the enclosed route, which teaches Wall Jump and Dash
  before two hovering-machine chambers, a Dash-required exit gauntlet, and a
  construction-lift departure
- Green Zone Finale now has a development-only Level 3 WIP. It begins on the
  same construction lift at its upper landing, then opens across one continuous
  ravine: a Double Jump island, two Dash-required crossings, and a spike-side
  final landing lead into safe continuation ground. One familiar ground patrol
  and a paired vertical-flyer gap followed by another patrol recap the existing
  enemy language against the accepted dark-blue night forest treatment. One
  more ground enemy free-roams from the spike strip's far edge to the final
  ledge, while a faster flyer sweeps the entire joined platform over those
  spikes with only a slight vertical sway. That mixed recap leads
  into a plausible but deliberately unreachable 20.48 m gap. A committed jump
  carries the player safely about 25.6 m into a short rock-underworks pocket,
  while the first three lower-floor tiles are cut away beneath the takeoff so
  a straight step into the gap still falls to the kill plane. The forest
  ends at a fixed underground boundary at Y -3.78, where a subdued
  blue-grey cave backdrop rises into view during the open fall. One patrol, a
  5.12 m spike strip, and a long hazard-free 5.12 m two-wall Wall Jump shaft
  merge back into the extended Green Zone shelf from underneath. A same-level
  fade handoff then enters the sealed shooter section, where the approved
  mutual-surprise introduction runs the player to real cover before the live
  three-beat shooter encounter. Killing that enemy with the existing knife now
  produces one deterministic physical gun drop. Collecting it gives the player
  a session-local two-slot knife/handgun loadout, auto-equips the pack-1 pistol,
  and enables mouse aiming within a 180-degree forward arc (accepted handgun milestone). Keyboard/gamepad retain
  horizontal/upward-diagonal fire. Select weapons with `1`, `2`, the
  mouse wheel, or gamepad RB for switching. Ammo, the safe firing lesson, boss,
  ending, and production promotion remain deliberately open
- The six earlier Green Zone prototype levels are deleted. Their movement
  contracts moved to permanent homes first: the Animation Lab for the ability
  kit, Arrival for camera stability, and the Level 2 interior for progression
  and background coverage
- World 1 is being re-authored as approximately three substantial levels:
  Arrival / Shoreline, Overgrown Coastal Ascent, and Green Zone Finale
- The World 1 production selector exposes Arrival / Shoreline and Overgrown
  Coastal Ascent. Its cave interior is a same-level Level 2 section, and focused
  tools load that section under the production Level 2 identity. Development
  entries retain Animation Lab, the reusable Level Design Lab, and Level 3 WIP;
  the lab keeps the current cave-terrain and lift proofs as starting fixtures
- A reusable profile-driven pixel-background rig provides native-scale,
  seam-safe horizontal coverage, authored coastal-to-green transitions, and
  stable framing during vertical camera travel. Level 2 actively uses authored
  cave regions for a reversible lower/upper blend, plus independent horizontal
  shaft focus while its vertical camera follows the climb. Height-aware opacity
  controls remain available as a separate opt-in extension
- The intended finale starts by recapping the current movement and enemy
  language with one ground patrol followed by two flyers and another patrol,
  then proves the full traversal kit through the surprise descent and Wall Jump
  return. One new armed Green Zone humanoid then introduces ranged attacks;
  defeating that enemy guarantees the now-collectible first gun. A combined
  movement-and-shooting stretch will lead to the simple first boss while melee
  remains viable. Moving saws were cut from this level and remain available for
  a later campaign fit
- Typed world catalog and world-grouped mouse or `W`/`S` + `Enter` level
  selector
- Development-only Animation Lab with a full-speed runway, test geometry,
  immediate ability toggles, and no campaign/save effects
- Development mode starts every level from its fresh level-defined entry state,
  then retains session abilities through death and `R`
- Development review tools expose independent F7 collision/hitbox overlays, an
  F10 world grid with live player-feet and cursor coordinates, and an F11
  god/noclip/free-flight inspection mode that grants the loaded level's
  available abilities for the current session
- Arrival has a curated, typed Green Zone dressing palette and paired clean /
  diagnostic capture workflow. Its accepted landmarks include the biome-seam
  outcrop, garden gates and hedges, the non-colliding skate half-pipe at the
  aerial takeoff, and the tire-swing-tree finish clearing
- 1920x1080 presentation baseline
- Overgrown Coastal Ascent's full interior is authored and accepted: the
  familiar recap, Double Jump rise, Wall Jump shaft, left-turn Dash pickup,
  Dash-only return, machine chambers, final enemy-and-spike run, and lift ending
  share one coherent cave. Its five-layer lower/upper blend, regional grade,
  water vistas, upper ceiling, focused shaft camera, and fixed lift framing are
  part of that accepted presentation

The living design and authoring documents are:

- [`docs/GAME_DIRECTION.md`](docs/GAME_DIRECTION.md) — what the game is
- [`docs/LEVEL_ROADMAP.md`](docs/LEVEL_ROADMAP.md) — the eleven legacy ideas,
  revised campaign spine, and next level
- [`docs/LEVEL_2_VISUAL_BRIEF.md`](docs/LEVEL_2_VISUAL_BRIEF.md) — the completed
  Level 2 route and accepted visual contracts
- [`docs/TECHNICAL_FOUNDATION.md`](docs/TECHNICAL_FOUNDATION.md) — architecture,
  gameplay contracts, asset pipeline, and validation
- [`docs/SET_DRESSING_WORKFLOW.md`](docs/SET_DRESSING_WORKFLOW.md) — curated
  scenery, gameplay exclusions, visual review, and accepted-placement rules

## Controls

- Move: `A` / `D`, arrow keys, left stick
- Jump: `Space`, `W`, up arrow, gamepad south button
- Dash: `Shift`, gamepad east button
- Attack: left mouse, `J`, gamepad west button
- Restart current run: `R`
- Return to level selector: `Escape`
- Menu: click, `W` / `S` + `Enter`, or number shortcut

## Legacy references

- Python level blueprint:
  `C:\Users\kappe\Code\platformertwo\platformersecond`
- Archived Unreal prototype: `D:\UnrealProjects\Blocky3D`

These paths are not runtime dependencies. Legacy coordinates, physics values,
and architecture are not copied blindly.

## Assets

The complete downloaded packs stay outside this repository at
`D:\GodotProjects\blocky3dassets`. Mirror all runtime-ready visual files into
the project's searchable source-art catalog with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_visual_asset_library.ps1
```

Refresh the curated green-zone production set with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prepare_green_zone_assets.ps1
```

## Validate

Use the guarded runner rather than launching Godot directly. It preserves the
running editor/game by default and uses the standard non-.NET Godot 4.6.3 build
with the normal Compatibility renderer. Do not use `--headless`. Pass
`-CloseRunningGodot` only when a particular automation run genuinely requires
exclusive access.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_project.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_arrival_shoreline_slice.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Script res://tools/validate_arrival_shoreline_slice_playthrough.gd
```

Pass any other `res://tools/validate_*.gd` script through the same runner.

The runner's `-EditorImport` mode uses Godot's dedicated `--import` command and
waits on the real editor executable, not only its console launcher. Every mode
uses the real process exit code, a per-run log, and an exclusive automation
lock. Do not substitute `--editor --quit`; it can exit while import workers are
still active. The complete source-art catalog under `assets/library` is
available in Godot for searching and auditioning; only selected production
files are referenced from scenes and promoted into `assets/art`. Bulk asset
activity is not treated as the proven cause or cure for the outstanding native
automation crash.

Generate graphical review captures with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_level1.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_animation_lab.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_arrival_shoreline_slice.gd
```

The runner gives automation its own writable Windows profile at
`build/godot_automation_profile`. Godot's editor cache and `user://` therefore
stay inside the ignored build directory during validators and captures instead
of touching the interactive editor profile or the player's campaign save. The
runner checks both its Roaming and Local profile roots before every launch. It
uses the standard build because this project contains no C# and the Mono build
repeatedly crashed inside CoreCLR. Use
`res://tools/validate_automation_environment.gd` to verify the isolated profile
and non-.NET engine contracts.

Pass any other `res://tools/capture_*.gd` script through the same runner.
