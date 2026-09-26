# Phantom Camera trial

Phantom Camera **0.11.0.3** is installed and enabled. The Level 3 gun-encounter
section uses it for the clearing, tank climb and upper exit. The lower route's
camera feel is accepted. Earlier sections still use the existing camera.

## Editing the composition

Open `scenes/dev/green_zone_finale_shooter_area_wip.tscn` in Godot.

- `CameraDirection/CameraRail` is the editable `Path3D`. Its control points and
  handles describe the camera's world-space route. Keep Z at 24 and avoid loops
  or intersecting segments: Path mode follows the closest point to its target.
- `CameraDirection/RouteCamera` is the actual `PhantomCamera3D`. Its **Follow
  Offset** sets the amount of space ahead/above the player. **Follow Damping
  Value** controls horizontal and vertical response separately.
- Open the **Phantom Camera** bottom panel for its viewfinder. Selecting the
  rail exposes Godot's curve handles. The camera resource keeps an orthographic
  view with a fixed size of 12.9375; changing size changes our pixel-art scale.
- Much of our terrain, characters and backgrounds is generated at runtime.
  The editor viewfinder therefore has incomplete scenery. Use F5 and the Level 3
  gun encounter for the actual visual judgement. The in-game level designer
  continues to own terrain and object placement, not this camera rail.

The rail begins revealing the climb during the approach, stays low enough to
show the tank while the player wall-jumps, then rises toward the upper route.
There is no region priority switch at the former X=62.72 or X=75.52 boundaries.
Following the rail backward also reverses that composition continuously.

The solid right-hand ground rises to Y 25.6; the single left scaffold continues
to a chest at Y 35.84. `GameplayCamera` exposes **Upper exploration** settings:
reaching Y 9 near the first wall spikes changes Phantom to Simple follow, retaining its damping
state. This follows the roof, jumps above it and sideways departures. Descending
to Y 7 returns to the rail; the gap between those heights prevents flickering
between modes during wall jumps. Walking beyond X 80.64 at or below Y 26.8 also
returns to the rail along the raised exit. Spawn/load resolves the mode immediately.
The upper offset is (4, -1, 24), leaving room to see upcoming wall spikes as
well as landing surfaces. The rooftop reward stays out of sight from the
ordinary exit. The already-engaged tank keeps firing from below while any of
the shaft or scaffold is visible, even from the upper ground or chest roof.
The tank itself does not need to remain on screen.

## Integration

`scripts/camera/phantom_pixel_camera_3d.gd` extends the existing camera API.
Phantom computes path following and damping. The adapter quantizes only the
physical camera's output, preserving Phantom's continuous internal position.
The host updates manually from the camera's -100 process priority, before the
background's -90 update. The host remains in Idle mode in the editor so its
viewfinder works.

Spawn/load uses Phantom's teleport function to clear damping velocity.
Inspection can leave the rail and returns to it on exit. Pausing or disabling
the camera does not leave an autonomous host moving it in the background.
The existing handgun introduction temporarily requests Simple follow for its
animated marker, look-ahead and zoom, then returns to Path follow. Both modes
use the same Phantom instance and damping state; no priority tween is involved.

Authored layout objects and revisions are compared before refreshing structural
fingerprints. The taller climb intentionally raises the roof chest and the
parent of the exit crate pile; existing authored placements remain intact.
Six visible textures had Godot's automatic 3D
compression detection disabled after opening the scene triggered it; their
original lossless, non-mipmapped pixel-art settings are preserved.

## Tests and findings

Run through `tools/run_godot_tool.ps1`:

| Check | Coverage |
| --- | --- |
| `-Visual -Script res://tools/probe_phantom_camera_modes.gd` | Real orthographic viewport; Simple, Group, Path, Framed, damping at 30/60/144 FPS, priority blend interruption and teleport behavior |
| `-Script res://tools/validate_phantom_camera.gd` | Forward/backward and optional upper-climb trajectories at 30/60/144 FPS, no boundary jump, output pixel alignment, player/tank visibility, roof/ground save snaps, inspection, cinematic ownership and session reload |
| `-Script res://tools/validate_green_zone_shooter_intro.gd` | Reaction close-up, enemy pan, shot-driven return, checkpoint resume and restart |
| `-Script res://tools/validate_tank_climb.gd` | Scaffold and solid ground contacts, both lethal wall spikes, service bracket/roof reach, chest saves, pursuit, long upward hits from below the camera, no off-screen acquisition, shelter, disengagement and rewards |
| `-Script res://tools/inspect_level_layout.gd` | All registered layouts resolve without losing authored records |

The mode probe writes `build/phantom_camera_modes.json`. The route validator
writes `build/phantom_camera_validation.json`. These are local test artifacts.
Live MCP review also covers fullscreen compositions and the designer's
edit/test/return lifecycle. Automated checks do not establish camera feel.

Observed addon behavior worth retaining:

- Damping converged consistently across the three tested frame rates.
- Path mode clamps to the rail's endpoints and supports deterministic snaps.
- Group follows the targets' bounding-box midpoint; it is useful for shared
  compositions but does not itself understand a safe landing or foreground wall.
- The tested 3D Framed setup initially teleported to Z=0 when the target was
  inside its dead zone, then recentered after a large XY movement. It is not a
  drop-in replacement for this game's side-view framing.
- Teleport moves the camera immediately but **does not cancel an in-progress
  priority tween** in this release; the next host update can resume that tween.
  The trial avoids that case. Future multiple-camera transitions must handle
  it explicitly before being used across death/load or interrupted cutscenes.

## Source and updates

- Upstream: <https://github.com/ramokz/phantom-camera>
- Release: <https://github.com/ramokz/phantom-camera/releases/tag/v0.11.0.3>
- Documentation: <https://phantom-camera.dev>
- Copyright 2022 Marcus Skov; [MIT license](../addons/phantom_camera/LICENSE).
- Downloaded release source archive SHA-256:
  `237fab51bc0eefba1c9b32efbf64f8f2e6c56ad758215ce4505d402e516f58d0`.

The vendored addon is unchanged from upstream. Its automatic updater prompt is
disabled to keep the tested version pinned. Review upgrades deliberately and
rerun the focused checks above. No Mono/.NET runtime is required.
