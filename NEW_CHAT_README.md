# New-chat handoff - Level 3 WIP player handgun milestone

Updated 2026-09-05 in `D:\GodotProjects\blocky3d`.
Read this file and `AGENTS.md` before further work.

## Project and current milestone

Godot is canonical. Gameplay is 2D on X/Y, with pixel-art layers staged in 3D.
Levels 1 and 2 are production levels. Level 3, Green Zone Finale, remains WIP.
The user accepted the current pistol, mouse-facing controls, and slower upright
backpedal, then requested this milestone be committed on `main`.
The previous checkpoint was `8d58a51 Add Level 3 WIP physical gun drop`.
Use `git log -3 --oneline` and `git status --short` for the current boundary.

## Accepted player firearm behavior

- Collecting the fixed shooter drop grants session-local handgun ownership and
  auto-equips it. Death/checkpoint reset preserves ownership; a full section
  restart clears ownership and rearms the shooter/drop.
- `1` selects knife, `2` handgun, wheel or gamepad RB cycles; switching during
  an action is deferred. The contextual two-slot HUD appears after acquisition.
- Mouse movement enables crosshair aiming. Cursor side controls visual/gun
  facing, with a 0.13-world-unit horizontal tolerance to prevent vertical-aim
  flicker. Each facing permits straight up/down, so targets on either side can
  be aimed at. Movement/knife facing stays separate from gun facing.
- Keyboard/gamepad retain horizontal and upward-diagonal fire. Mouse aiming
  uses the normal attack input. Arm, gun, flash, projectile, and crosshair share
  the muzzle direction. Ordinary cover and explicit enemy hurtboxes stop shots.
- Grounded retreat while mouse-aiming uses 65% running speed and Biker Walk1
  played backward. Animation advances by distance travelled. Forward and
  airborne movement retain their existing speeds, as do dash and wall jumps.
- The firing arm sits behind the torso so the shirt hides its rotating root.
- Flash uses a 4x8 region from frames 0, 2, and 4 of the original source streak
  over 75 ms, rather than drawing the entire 48-pixel streak beside the bullet.
- Ammo is deliberately not implemented; no counter, reserve, or drop policy.

## Assets and important files

The local source packs are separate because their filenames overlap:
`D:\GodotProjects\blocky3dassets\weapons\guns_pack_1` and `guns_pack_2`.
The player and pickup use pack-1 pistol `2 Guns/4_1.png` and `4_2.png`.
Body1 idle/run/jump/walk and grip `3.png`/`4.png` provide the one-handed rig.
The player's existing index-2 bullets/effects are retained. Enemy art and its
pack-2 bullet remain independent. All runtime assets are promoted into
`assets/art/green_zone` by `tools/prepare_green_zone_assets.ps1`.

Primary implementation: `scripts/player/player_character.gd`,
`scripts/presentation/pixel_player_visual_3d.gd`,
`scripts/weapons/player_handgun_3d.gd`, `scripts/ui/weapon_status_hud.gd`,
`scripts/level/level_session_3d.gd`, and `resources/weapons/first_handgun.tres`.
The visual script also creates dormant gun layers for older knife-only cutscene
puppets; this fixes missing-node errors without changing Level 2 choreography.

## Next work and limitations

Next is the short safe firing lesson after acquisition. Then explicitly design
ammo appearance/drop/reset policy, combine the learned kit, and build the boss.
Do not treat Level 3 as complete. Dedicated firearm bodies currently cover
idle/run/jump/backpedal; other action states hide the firearm.

The full suite previously exposed a repeatable Level 2 traversal failure:
`validate_level_2_interior_playthrough.gd`, stage 10, player death near
(64.54, 29.02) in the flyer section. It occurred in both headless and visible
runs. That route was not changed here. Record the final commit validation
result below; do not describe a failing suite as passing.

## Validation and preservation

Always use `tools/run_godot_tool.ps1`; never launch Godot directly. Use `-Visual`
for `tools/capture_player_handgun_review.gd`. Captures include aiming in both
facing directions and retreat with assertions for speed, pose, and shot origin.
Use `tools/validate_player_handgun.gd` for ownership, switching, aim/crosshair,
facing tolerance, reset, and projectile checks. Use the suite for broad changes.
Current preview images are ignored under `build/previews`.
Preserve dirty work, ask before route changes, and make controlled visual
changes. Validator success does not substitute for user visual acceptance.

Final milestone validation (2026-09-05): full headless suite 34/36 passed.
`validate_green_zone_section_transition.gd` failed its intro timing assertion
headless, then passed with the normal visible renderer. The Level 2 stage-10
flyer traversal failure repeated. Handgun, movement, pixel-art, slide intro,
and matched-transition checks passed. Visual captures and user acceptance
cover mouse aiming, retreat speed, and the upright backpedal. `git diff --check`
passed. Superseded two-hand sprites/import files are preserved locally under
`build/previews/superseded_handgun_rig_20260905`, outside production assets.
