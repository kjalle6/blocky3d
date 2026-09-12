> Current checkpoint (2026-09-12): the user requested committing the current
> firearm visuals, double-jump shooting, Level 3 menu shortcut, expanded audio
> tool, gunfire/impact audio, and saved tuning. The NEXT task is the in-game
> level editor in docs/DEVELOPER_LEVEL_EDITOR_PLAN.md, linked from the roadmap.
> It is planned only. Prove move/test/save/reload for a platform, walking enemy,
> and ordinary trigger first, then expand patrol controls and platform building.
> The user and Codex design levels together; Codex builds camera/level wiring,
> the user fine-tunes visually, and ALL scripted sequences stay with Codex.
> Latest saved audio overrides supersede the initial picks below: player Shot_2
> at -12 dB; enemy Shot_2 at -15 dB; scenery Hammer_1 at -24 dB and pitch 1.65;
> character Blood_1/2/3 random at -17 dB. The promoted Hammer recording and all
> current movement/ambience settings in movement_mix.tres belong in this checkpoint.
> The full suite passed 41/42 before these final user audio tweaks; its only
> failure is the existing Level 2 stage-10 traversal death at (64.54,29.02).
> A fresh validate_sound_event_tuning.gd pass checks loading/persistence after
> the user's saved tweaks, without modifying the saved mix.
>
> First gun-audio listening pass (2026-09-12): four Combat banks are connected.
> Player: Shot_1 at -12 dB, with Shot_2/Blaster alternatives. Enemy paired beat:
> Shot_2 at -15 dB, with Shot_3/4 alternatives. Scenery impact: Bump at -12 dB,
> with Hammer_1 alternative. Character impacts: Blood_1/2/3 random at -17 dB.
> Gun/scenery banks start fixed; all choices are available under F1 -> Audio
> tuning -> Combat. The user explicitly asked for initial picks they can tune.
> The session could inspect audio timing/waveforms but could not hear playback;
> these are trial selections, not an accepted final mix. Source WAVs are copied
> unchanged into assets/audio/combat with source paths/hashes in its manifest.
> Gunshot cues follow real releases, including double jumps; each simultaneous
> enemy two-gun beat emits one cue. Projectile collisions select character or
> scenery impacts. Misses/expiry are silent. Twenty-four pooled spatial voices
> let tails overlap; live events cannot loop. Reset/exit clears voices and tails.
> Initial defaults are resources/audio/combat/*.tres, merged before explicit
> saved event overrides; resources/audio/movement_mix.tres is byte-for-byte
> unchanged. All earlier movement/ambience choices and dirty work are preserved.
> validate_combat_audio.gd passes. capture_combat_audio.gd captures four tuning
> pages and actual mixer output; player/enemy sample peaks are -14.1/-17.7 dB.
> See docs/AUDIO_TUNING.md. Full headless suite: 41/42 passed in 235.7s;
> only the existing Level 2 stage-10 traversal death at (64.54,29.02) remains.
>
> Future idea archive: docs/ideas/README.md. The first note records the user's
> parkour + shooting + cover concept, including double-jump firing angles and
> wall-jump routes up behind enemies. A possible fit is tall vertical levels
> with a choice of approach, not every shootout. Saved for much later.
>
> Level 3 shortcut and two-gun firing refinement (2026-09-12): the menu now has
> LEVEL 3 - GUN ENCOUNTER directly below LEVEL 3 WIP, also reachable with key 6.
> It starts the shooter-area scene at its normal entrance, just before the
> introduction. The same Level 3 identity and assumed movement abilities are
> retained; the intro, enemy, checkpoint, and gun pickup run normally. R restarts
> this section. The original Level 3 button still starts the traversal section.
> LevelDefinition.developer_entry_points stores typed LevelEntryPoint resources;
> GameRoot's existing developer loader accepts an optional entry_id. The tool
> fixture uses that same loader. No extra campaign level or duplicate scene.
> The enemy now releases one round from each gun's source-art flash root:
> forward front/rear (30,26)/(18,25), down (28,36)/(19,35), up (26,14)/(17,14).
> The old artificial pair spacing around a shared barrel is removed. Both guns
> still fire simultaneously, with the same continuous direction, speed, damage,
> beat count, and intervals. Projectile size was not changed in this pass.
> Each 0.18s beat is flash 0-.04s, recoil .04-.11s, then return to aim. Guns stay
> raised between beats; the final beat holds aim for .12s into the existing
> recovery period before relaxing. No additional delay or firing audio.
> Focused project/menu and firing checks pass. Full headless suite: 40/41 passed
> in 231.6s; only the existing Level 2 stage-10 traversal death at (64.54,29.02)
> remains. Graphical review: build/previews/enemy_handgun_aim contains the
> menu, all directional poses, and full twin/triple firing sequences.
> The user accepted this firing refinement, the preceding directional aiming,
> and double-jump shooting. Nothing has been committed.
>
> Enemy directional aiming (2026-09-12): target height now selects the source
> sheet's forward 0/1/2, downward 3/4/5, or upward 6/7/8 aim/flash/recoil group,
> mirrored for either facing. The threshold is 22.5 degrees from horizontal.
> Telegraphs track the target; each released shot holds its pose through recoil
> and the next shot can select a new angle. Actual projectile aim remains exact.
> The visual owns per-pose barrel registration: source forward (30, 26), down
> (28, 36), up (26, 14); the obsolete fixed Muzzle marker is removed. Paired
> lanes retain 0.18 spacing, and firing counts/cadence/speed/damage are unchanged.
> Focused lab checks cover both facings, shallow/steep targets, all pose markers,
> barrel origins, continuous trajectories, recoil stability, and cover/damage.
> Level 3 shooter-intro and handgun-drop checks pass. The capture tool
> tools/capture_enemy_handgun_aim.gd produces
> real-renderer directional pose/shot captures under build/previews/enemy_handgun_aim.
> Rendered poses were reviewed; final in-game feel remains with the user.
>
> Double-jump handgun accepted (2026-09-12): mouse aiming and the gun remain active
> throughout the six-frame somersault. Per-frame shoulder registration follows
> the original flip while the firing arm aims independently in world space.
> player_handgun_double_jump.png is a deterministic derivative: the tucked
> firing-arm silhouette is removed from source frames 0-3; matching one-arm
> Jump1 recovery frames supply 4/5. Original knife art is retained. The recipe
> is tools/prepare_player_handgun_double_jump.ps1, also called by the main art
> preparation tool; both sources and the transform are in asset_manifest.json.
> Handgun input now releases after movement, pose, and aim resolve in the SAME
> physics tick, so jump + fire uses the current barrel instead of the preceding
> frame's shoulder. Knife contact timing and dash cancellation are preserved.
> The 0.28s cooldown, aerial jump limit, movement speed, and normal time scale
> remain as before. Bullet time / jump chains are future ideas, not implemented.
> Focused checks cover firing on all six frames, simultaneous jump/fire,
> keyboard up-aim, both cursor sides/heights, and return to the normal jump pose.
> tools/capture_double_jump_handgun.gd records real jump input, then fixed-step
> shots on flip frames 0/4, from both sides. The user says double-jump shooting
> feels good; the remaining issue they reported was enemy directional aiming.
> Full headless suite after this change: 40/41 passed in 232.6s; only the known
> Level 2 stage-10 traversal failure remains. The art recipe reproduces the
> production texture byte-for-byte; the user's saved audio mix is unchanged.
> The user liked the preceding firing pass; enemy projectiles may be a little
> large, but that adjustment was deferred while adding double-jump shooting.
>
> Firearm presentation trial (2026-09-12): the player handgun now fires on the
> accepted input tick, independently of the knife's 0.13s contact delay / 0.34s
> swing. Its own 0.28s cooldown also governs deferred switching; early clicks
> are not queued, holding fire stays semi-automatic, and dash still cancels.
> Player bullet speed is 28 (was 13), using pack-2 Bullets/2.png: a slim yellow
> streak. Both projectile owners rotate their source sprite to actual travel;
> the gun component no longer overrides the projectile sprite after launch.
> Player flash is pack-2 Shoot_effects/6_1.png, six complete native frames over
> 0.10s, tinted to the bullets' yellow and anchored at the barrel in all poses.
> Pistol 4_1/4_2, the accepted arm rig, mouse facing, and backpedal are retained.
> The enemy uses only the forward flash/recoil frames 1/2 after telegraph 0;
> a frame marker releases both projectiles. It no longer drifts into the
> separate down/up source poses. The clip owns its 0.18s completion; obsolete
> inspector timing/frame exports are removed. Enemy speed, targeting, dual-shot
> counts, intervals, and recovery tuning remain as before. No shooting audio
> was added. The saved movement audio mix and the earlier tool work are intact.
> The enemy muzzle marker is registered to forward flash source (30, 26):
> local (0.24, 0.33), replacing (0.72, 0.42), which spawned rounds ahead of the
> barrel. Its two projectile lanes retain their existing 0.18 spacing.
> Visual acceptance remains with the user; these changes are not committed.
> tools/capture_player_handgun_review.gd now also captures fixed-time shot and
> volley sequences, in addition to the live input / aiming / retreat review.
> Validation: full headless suite 40/41, with only the same Level 2 stage-10
> traversal death at (64.54, 29.02). After the final muzzle registration change,
> validate_animation_lab.gd and validate_green_zone_shooter_intro.gd both passed.
> The lab covers shot markers, volley counts, cover/damage, and muzzle origin;
> validate_player_handgun.gd covers immediate/repeated input, cooldown, deferred
> switching, dash cancellation, fast thin-cover collision, and both owners'
> directional sprites. Graphical captures were reviewed with the real renderer.
>
> Audio tool expansion (2026-09-12): F1 -> Audio tuning now has categories for
> Footsteps & jumps, Abilities, Combat, Pickups & progress, World objects,
> Ambience, Interface, and Music. Fifty new event banks start empty; fixed/random
> selection, one-shot/loop previews, pitch/variation, volume, reverb routing,
> A/B/Revert/Save are available. New slots are explicitly PREVIEW ONLY until
> gameplay owners are connected. The user requested the tool without adding
> production audio because gun firing/projectile visuals still need work.
> No gameplay audio hooks or gun/projectile visuals were changed. Existing Cave
> and Underground ambience also have direct entries in the Ambience category.
> resources/audio/movement_mix.tres remains authoritative, including the user's
> newer grass tweaks. It was not rewritten by this tool expansion.
> Full suite: 40/41 passed; only the same Level 2 stage-10 traversal failure.
> Focused event-tool checks passed, and the panel's graphical captures were reviewed.
> See docs/AUDIO_TUNING.md and tools/validate_sound_event_tuning.gd.
>
> Audio milestone accepted (2026-09-06): the user is happy with the saved
> footsteps, ground takeoff/landing, room ambience/reverb, and slower run cadence.
> resources/audio/movement_mix.tres is authoritative; all four surfaces now
> have selected jump banks. Cave uses 3 takeoffs / 8 landings; Underground
> uses 3 takeoffs / 5 landings. Cave's DirtyGround Jump Land 03 in takeoff and
> Jump Start 03 in landing are intentional: the user identified swapped source
> names by ear. Preserve those assignments. Latest full suite passed 39/40;
> only the known Level 2 stage-10 traversal failure remains. Beach water audio
> and the skater's close-contact presentation were also accepted in this session.
> Next audio pass: dash, double jump, and wall jump, then combat and UI/music.
> Earlier trial/awaiting-review notes below describe the development history;
> this acceptance and the saved mix supersede them.
>
> Level 3 underground audio (2026-09-06): F1 -> Audio tuning now offers
> Underground · Level 3, with separate footstep/jump banks, ambience, and reverb.
> Initial reverb trial 24% amount / 70% room size / 60% damping; recordings empty
> for the user to choose. Both Cave and Underground have Choose ambience… for
> WAV/OGG/MP3 and Remove ambience, with volume/on-off, A/B, Revert, and Save.
> New selected ambience assets are promoted into assets/audio/tuned on Save.
> Older cave saves retain their drip track; intentional empty slots stay empty.
> UndergroundAudioRegion in green_zone_finale_wip.tscn covers X 107.52–171.52,
> Y -29.44–-1.28; player position selects it through descent/shaft/respawns.
> Surface and shooter area remain outdoors. DeepRockShell's footstep_surface
> is underground. No geometry or movement changes. Each room has independent
> gameplay/preview reverb buses; the shared ambience player follows the chosen
> recording and fades changes. See docs/AUDIO_TUNING.md and
> tools/validate_audio_environments.gd. Final sound selection awaits the user.
>
> Running cadence trial (2026-09-06): lowered run animation 12 -> 10 fps,
> giving a foot contact every 0.30s (about 3.3/sec) instead of 0.25s (4/sec).
> Applies to all surfaces and running attack legs; movement speed, backpedal,
> weapon swing timing, and audio pitch remain unchanged. The tuning preview
> follows the animation rate. User found the old running rhythm too fast;
> slower sound/leg motion now awaits their in-game review.
>
> Cave reverb (2026-09-06): the audio panel now has Amount / Room size / Damping
> and an enable checkbox. Cave defaults to that preview space; "Listen in cave"
> also auditions any other surface's recordings with the same effect. Initial
> trial: 16% amount, 50% room size, 65% damping; dry contact preserved.
> Settings participate in A/B / Revert / Save defaults. Existing saved bank
> selections and user-tuned volumes remain authoritative in movement_mix.tres.
> Actual gameplay uses room metadata audio_environment=cave on the Level 2
> interior and Level Design Lab, independently of floor material. Separate
> CaveSFX/CavePreview buses prevent preview echo leakage; no Master-bus reverb.
> User has begun saving Cave footstep/reverb experiments through the panel;
> read movement_mix.tres for their current choices. These were preserved.
> Cave ambience is now installed: Nature_Essentials_NOX_SOUND/
> Ambiance_Cave_Drips_Loop_Stereo.wav, copied unchanged into assets/audio/ambience.
> Full 30-second stereo loop, initial -6 dB, separate Ambience bus without added
> reverb. The panel's Cave drip ambience checkbox/volume use A/B / Revert / Save.
> One game-root player follows the cave room or the panel's listening space;
> works while paused and persists through respawns and preview bank changes.
> Outdoor previews / room exit fade it out over 0.4s.
> See docs/AUDIO_TUNING.md for details and validation; balance awaits user review.

> Cursor/editor note: user confirmed the offset occurred in Godot's embedded
> game view and that standalone alignment works. They disabled Game Embed Mode
> in Editor Settings; do not add game-side cursor offsets to compensate.

> Audio tuning panel (2026-09-06): F1 -> Audio tuning opens a paused listening
> panel for grass, sand, and cave footsteps/takeoff/landing. Volume, pool
> checkboxes, left/right assignment, recording picker, repeat previews, A/B,
> Revert, and Save defaults are implemented. Try in game / F1 / Esc resumes.
> Explicit Save writes resources/audio/movement_mix.tres; this becomes the
> authoritative mix, including on future launches. Unsaved edits are session-only.
> Original bank files remain initial defaults/validator fixtures. Newly chosen
> external audio is promoted on Save to assets/audio/tuned as self-contained
> AudioStream resources with source provenance. Cave starts empty with a foot
> pair; no cave recordings were chosen on the user's behalf.
> See docs/AUDIO_TUNING.md and tools/validate_audio_tuning.gd. The panel is
> functionally checked and captured; the user likes the workflow.

> Water audio audition: Arrival plays heavy-water-splash.mp3 once on water
> death, at original pitch and -10 dB, skipping 0.30s of quiet lead-in.
> Full splash playback, with no fade-out. Arrival water deaths respawn after
> 1.7s, skipping the silent end wait; other deaths keep the quick reset.
> Source unchanged; provenance is in
> assets/audio/water/SOURCE.txt. Awaiting the user's in-game listening review.

> Level 1 now has a skater at the ThornGardenExit half-pipe, roaming the
> whole platform with natural ledge turns and a short rolling attack.
> It uses Green Zone enemy 3's original animations and
> the shared stompable patrol behavior (new pixel_skater_enemy.tscn).
> Player rig and skater art now shift 11 source pixels toward their facing
> direction to align the off-center source torsos with body collisions.
> Skater damage range is 0.8; tools/probe_skater_body_contact.gd checks
> close hits and distant misses from both sides (run with -Visual).

> Accepted grass footsteps (2026-09-06): randomized NOX Walk Mono 07/06/04 for BOTH
> running and gun backpedalling, with no consecutive repeats within each gait.
> Each gait keeps its animation-driven cadence; clips play at normal speed.
> Original pitch, -10 dB; no pitch or volume randomization.
> Accepted sand footsteps (2026-09-06): NOX Footsteps_Sand_Walk_01 on the left and 02
> with the right-foot marker for both gaits, at original pitch and -13 dB.
> A fresh stride starts left/01, then right/02. Foot identity drives selection;
> stops and gait changes keep the association. This replaces the 01/06 mix.
> F6 cycles PAIR / Sand Walk 01 / Sand Walk 02 / Gravel 006 / Dirt 004.
> Sand loudness: the user accepted running at -13 dB (also used for F6 comparisons).
> Takeoff and landing were still too loud, so their current trial is -16 dB,
> another 3 dB below the first reduction. Footsteps remain at -13 dB.
> This is a volume-only adjustment; no filtering or source edits were applied.
> In-game audition: F5 cycles grass Run MIX/07/06/04; F4 cycles grass Walk
> MIX/07/06/04 (gun backpedal). Selections survive respawns/level changes.
> Walking audition moved from F8 because Godot uses F8 to stop editor-launched games.
> Both gaits now use original recordings (tight_run trims are no longer used).
> Four independent playback voices let step tails finish across stops, jumps,
> surface changes, and audition switches. Death/reset stops them.

> Accepted grass jump audio (2026-09-06): all ten NOX Grass Jump Start clips and all
> ten Grass Jump Land clips, in separate random pools with no consecutive
> repeats per pool. Original recordings, pitch 1.0, -10 dB, no extra processing.
> Player ground-jump and physical-touchdown signals trigger these contacts.
> Takeoff samples the departure surface (last support for coyote jumps);
> landing samples the destination, including falls off ledges. Cave has no
> jump-contact bank yet. Double/wall jumps do not play ground push-off audio.
> Spawn/reset/inspection settling and tiny floor-snap contacts stay silent.
> scripts/presentation/player_jump_audio.gd uses its own four playback voices;
> resources/audio/grass_jump_start.tres and grass_jump_land.tres hold the pools.
> tools/validate_player_jump_audio.gd covers real movement and bank selection.
> The user accepted these takeoff and landing mixes after in-game listening.

> Sand jump audition (2026-09-06): all five NOX Sand Jump Start clips and all
> five Sand Jump Land clips, in separate pools with no consecutive repeats.
> Uses the same physical takeoff/touchdown events as grass: original recordings,
> pitch 1.0, with the sand jump loudness trial at -16 dB and no extra processing.
> resources/audio/sand_jump_start.tres and sand_jump_land.tres hold the pools.
> Each contact chooses its own surface bank, including grass-to-sand jumps
> and the reverse. Awaiting the user's in-game listening review.

> Footstep markers are authored resources under resources/audio/markers,
> with foot identity and frame crossings (run/run-attack 1/4; backpedal 0/3).
> The stride clock pauses through grounded stops and continues through knife
> swings. Duplicate, stale, stationary, and airborne contacts cannot play.
> Sound banks live under resources/audio; scripts/audio holds marker, bank,
> and surface resolver code. Metadata overrides platform/interior style IDs.
> Cave is recognized but has no chosen bank and remains silent.
> F9 shows foot/frame, surface/gait, actual sample, event spacing, active
> voices, and suppressed events. F5/F4 still allow MIX or fixed auditions.
> tools/validate_player_footsteps.gd covers these contracts; the broader
> marker/state change also needs the normal validation suite.

> Accepted footsteps: grass uses the NOX Walk Mono 07/06/04 mix above;
> sand uses the accepted NOX Sand Walk 01-left / 02-right pairing for both gaits.
> Gravel 006 remains available as an F6 comparison.
> Arrival's entire low beach/green transition uses sand. Grass begins on the
> raised GreenRiseCollision platform (x = 14.08, top y = 0.64).

> Footstep selection going forward (user direction, 2026-09-06): choose
> complementary left/right recording pairs for cave and subsequent surfaces.
> Audition each pair together at walking/running cadence and bind each sound
> to its foot using the bank's foot_indices, as on sand. Grass keeps its
> accepted 07/06/04 random mix. See docs/FOOTSTEP_AUDIO.md.

> Earlier grass choices (Footstep_alt_4, Dirt 004, Anton Grass Walk 01, and
> NOX Run 08/10/11) are superseded. Source files remain available for reference.
> Clips/provenance/credits are in assets/audio/footsteps.

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
