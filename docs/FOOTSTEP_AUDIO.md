# Player footstep audio

**Live tuning:** F1 -> Audio tuning now exposes the sound banks in game, with
paused previews, A/B, recording selection, and explicit Save defaults. See
[AUDIO_TUNING.md](AUDIO_TUNING.md). Saved `movement_mix.tres` settings override
the initial values documented below; consult that resource for current tuning.

The current system separates animation contact, supporting surface, recording
selection, and audio playback. Source recordings are preserved at original
pitch. The earlier `tight_run` trims remain on disk but are not referenced by
the current sound banks.

The user accepted NOX Walk Mono 07/06/04 for both grass running and walking
on 2026-09-06 after in-game listening. Keep the current randomized mix,
original pitch, and each gait's animation-driven timing. Later saved tuning
sets grass running to -16 dB and walking to -17 dB (2026-09-12 snapshot).
This supersedes the earlier grass candidates. Sand uses the accepted NOX
Footsteps_Sand_Walk_01/02 for both gaits, at original pitch and a saved -19 dB. Both
recordings are copied unchanged. Sand's `foot_indices` binds 01 to the left
animation foot and 02 to the right. A fresh stride starts with left/01, then
right/02; pauses and gait changes preserve the foot-to-recording association.
This replaces the random 01/06 mix. Gravel 006 and Dirt 004 remain in a separate
comparison bank and are excluded from the paired playback.
The user accepted this fixed left/right pairing after in-game listening on
2026-09-06, for both running and walking on sand.

Current saved volume snapshot (2026-09-12):

| Surface | Running | Walking | Takeoff | Landing |
| --- | --- | --- | --- | --- |
| Grass | -16 dB | -17 dB | -18 dB | -24 dB |
| Sand | -19 dB | -19 dB | -22 dB | -26 dB |

These saved values supersede the earlier -10/-13/-16 dB listening trials.
The resource remains authoritative if the user tunes it again. No mix change
was made for the designer/friendly-fire checkpoint.

Designer-added solid blocks expose their supporting surface in Settings;
Beach blocks default to sand and Green Zone terrain to grass. The same
contact-event and surface-detection path plays their footsteps and jumps during
Test/normal play. Frozen placement/edit previews suppress movement audio.

## Choosing footsteps for future surfaces

User direction (2026-09-06): cave and subsequent surfaces should use a
complementary left/right recording pair, following the accepted sand approach.
Audition the two sounds together in alternating foot-contact order at walking
and running cadence, judging their rhythm, tone, and relative loudness as a pair.
Bind each chosen recording to its animation foot through `foot_indices`.
The accepted grass 07/06/04 random mix remains the exception. This direction
concerns footsteps; the accepted grass takeoff and landing pools remain separate.

## Event path

1. `PixelPlayerVisual3D` advances the same stride cursor used to display the
   running legs. Run and knife run-attack share the cursor; grounded idle pauses
   it. Backpedal has a reverse walk cursor driven by movement speed.
2. `resources/audio/markers/player_run.tres` and `player_backpedal.tres` define
   contact frames and foot names. The marker track enumerates crossings on an
   unwrapped cursor, including cycle wraps and skipped display frames. It emits
   one event ID per crossing, with gait, source frame, foot, and event age.
3. `player_footsteps.gd` rejects duplicate IDs, airborne/inactive contacts,
   animation without actual horizontal progress, teleports, and events older
   than 0.10s. Old contacts are dropped instead of bursting after a hitch.
4. `footstep_surface_resolver.gd` raycasts down 0.8 world units from the player's
   collision center on the terrain collision layer, excluding the player.
   Collider `footstep_surface` metadata overrides the surface ID on platform
   or interior-terrain styles. These audio IDs do not affect physics materials.
   Arrival's low opening collider is sand throughout; grass starts on the rise.
5. A bank under `resources/audio` supplies recordings, labels, and volume for
   surface/gait. Grass run and walk both use the accepted NOX Walk Mono 07/06/04 mix;
   sand defaults to the NOX Sand Walk 01-left / 02-right pairing. Grass random
   selection avoids the preceding clip in that gait's bank. The recordings do
   not change either gait's contact rate, playback pitch, or volume.
   Cave is a recognized ID with no approved bank yet, so it remains silent.
6. Each footfall uses a free AudioStreamPlayer from a four-voice pool. Previous
   recordings are not replaced by a new surface, gait, or audition selection.
   Tails finish through stopping, jumping, and dashing. Death/reset/inspection
   stops them. If all voices are occupied, a new event is dropped and reported,
   rather than cutting a recording or building an audio queue.

Running cadence trial (2026-09-06): two contacts per six frames at 10 fps,
about 3.3 steps per second / 0.30 seconds between contacts. The user found the
previous 12 fps / four steps per second too busy. The body animation and contact
markers slow together, including the legs during running knife attacks; weapon
swing timing, movement speed, and backpedal cadence retain their existing values.
The tuning panel derives its running preview interval from the animation rate.
Natural recording tails can still overlap. Listening and the appearance of the
slower leg motion at the existing movement speed await user review.

Validation: the footstep and audio-tuning checks passed after the cadence change.
The rendered in-game diagnostics probe measured alternating contacts at
0.283-0.300 seconds (within one physics tick of 0.30s). It also retained the
accepted grass recordings and correct surface selection. This verifies timing,
not subjective approval of the slower leg animation.

## Grass and sand takeoff and landing

The `JumpAudio` child of the player uses `player_jump_audio.gd`. The shared
movement mix selects a separate takeoff/landing bank for each supporting surface.
Grass uses `grass_jump_start.tres` / `grass_jump_land.tres`, each with all ten
NOX Grass Jump recordings (01-10). The user accepted both grass mixes after
in-game listening on 2026-09-06.

Sand uses `sand_jump_start.tres` / `sand_jump_land.tres`, each with all five
available NOX Sand Jump recordings (01-05). This follows the same approach as
grass; the sand mixes are awaiting in-game listening approval.

Recordings are copied unchanged with SHA256 provenance in
`assets/audio/footsteps/sources.json`. Selection is random, with no consecutive
repeat within each surface/action pool. Pitch stays at 1.0; volume is -10 dB
for grass and -16 dB for the current sand jump loudness trial.

`PlayerCharacter.ground_jump_started` fires when a ground jump is executed,
before movement leaves the supporting surface. Coyote jumps use the last floor
within the existing coyote window. Walking off a ledge does not play takeoff.
Double jumps and wall jumps have separate actions and do not emit this signal.

`PlayerCharacter.landed` fires on the air-to-floor transition after
`move_and_slide`, carrying the incoming vertical speed. The audio component
samples the destination surface independently of the takeoff surface. It plays
for grass and sand touchdowns after at least 0.05s airborne and 1.5 units/s
downward impact, including falls off ledges. A grass-to-sand jump uses grass
takeoff and sand landing; the reverse uses sand takeoff and grass landing.
Tiny snap changes are silent. Cave has no jump bank yet and remains silent.

Initial spawn settling stays silent until the player has had floor support.
`movement_reset` clears that support history on repositioning and inspection
changes. Death/reset stops the sounds; ordinary contacts use four independent
voices so takeoff, landing, and the existing footstep tails can finish.

`tools/validate_player_jump_audio.gd` checks real stationary jumps, held input,
grass-to-sand and sand-to-grass jumps, ledge falls, coyote takeoff, air abilities,
respawn/inspection silence, independent tails, all ten variants per grass bank,
and all five variants per sand bank.
The scoped visible validator passed after adding the sand banks, including
stationary sand jumps and both directions across the grass/sand boundary.

Validation after adding grass jump audio (2026-09-06): the scoped visible
jump validator passed. The full headless suite passed 37/38 in 209.2s, including
footsteps, jump audio, movement, air abilities, and player handgun checks. The
only failure repeated the existing Level 2 traversal stage-10 death near
(64.54, 29.02); log `build/godot_tool_logs/script_headless_20260906_052156_15916.log`.
That full-route Level 2 bot was retired at the user's request on 2026-09-15;
this historical failure is no longer an outstanding test issue.

## Audition and diagnosis

- F5: grass running MIX / Walk Mono 07 / 06 / 04.
- F4: grass walking MIX / 07 / 06 / 04 (gun backpedal).
- F6: sand PAIR / NOX Sand Walk 01 / NOX Sand Walk 02 / Gravel 006 / Dirt 004.
- F9: marker count, played/suppressed count, active voices, and the last eight
  events with foot/frame, surface/collider, gait, selected clip, and spacing.

Walking audition uses F4 because F8 stops the project when launched from the
Godot editor. The game does not bind F8.

`tools/validate_player_footsteps.gd` checks marker crossings, reverse playback,
short stops, knife attack cadence, random selection, independent voices,
suppression rules, and real Arrival surface boundaries. Run through the Godot
runner, or use `tools/run_validation_suite.ps1` for the full suite.

`tools/probe_footstep_diagnostics.gd` drives a real grass run, checks alternating
feet and measured event spacing, and captures the F9 panel. It needs the runner's
`-Visual` switch. Technical checks do not establish that the sound mix feels good.

## Source-frame review (2026-09-06)

`tools/capture_player_foot_contacts.gd` renders enlarged poses in playback order,
with current contact markers highlighted. Run with `-Visual -Width 1440 -Height
1080`; output is `build/previews/player_foot_contacts.png`.

The knife run, knife run-attack, and handgun run share the same lower-foot
positions. Current run markers 1/4 show a supporting foot beneath the body;
backpedal markers 3/0 show the wide planted stance in reverse playback order.
This supports keeping the current markers for now. These coarse six-frame
sprites do not establish an exact physical impact instant, or prove perceived
audio synchronization during play.

The NOX run samples also differ in their attack envelopes. In 5ms RMS windows,
Run 08 first reaches half its own peak RMS at approximately 95ms; Run 10 at
25ms and Run 11 at 10ms. All three have lower-level signal by about 5ms, so
this is a difference in buildup, not a silent lead-in to trim automatically.
Walking 04/06/07 reaches the same relative threshold at 20/10/25ms.
These measurements are a diagnostic clue, not a listening verdict. No markers,
recordings, sample offsets, or gameplay timing were changed by that review.
The subsequent audition used the walking mix for running too, and the user
accepted it for both gaits. The run recordings remain available on disk.

## Accepted cave and underground jumps (2026-09-06)

The saved project mix now contains all four jump banks: Cave has three takeoff
recordings and eight landings; Underground has three takeoffs and five landings.
The user chose them in the tuning panel and confirmed completion by listening.
Cave's DirtyGround Jump Land 03 in takeoff and Jump Start 03 in landing are
intentional corrections for swapped source names. Do not normalize those
assignments from their filenames. Keep the user-saved levels in movement_mix.tres.
Dash, double-jump, and wall-jump audio remain unwired; combat audio is now live.
See [AUDIO_TUNING.md](AUDIO_TUNING.md) for current event support. No further
audio implementation order is fixed by this earlier listening milestone.
