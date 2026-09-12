# Audio tuning

Run the main project in a separate Godot game window, press **F1**, then click
**Audio tuning…**. Use the separate window because the embedded game view
previously offset cursor targeting during user testing.
The panel pauses the game. **Try in game**, **F1**, or **Esc** closes it and
resumes play with the selected mix. Changes survive deaths and level changes.
Opening the Level designer closes this panel while retaining its unsaved mix;
designer previews are silent and Test uses the selected settings. The designer
and friendly-fire checkpoint did not change `movement_mix.tres`.

## Gunfire and bullet impacts (2026-09-12)

The user subsequently saved a new mix: player **Shot_2 at -12 dB**, enemy
**Shot_2 at -15 dB**, scenery **Hammer_1 at -24 dB with pitch 1.65**, and
the **Blood_1/2/3 character mix at -17 dB**. These choices are stored in
`resources/audio/movement_mix.tres` and override the original starting banks.
The Hammer recording was promoted into `assets/audio/tuned` by the tool.
Preserve these saved choices; the table below records the original candidates.

The four Combat entries below now play in-game. Start **Level 3 - Gun encounter**
from the menu (key **6**), then use **F1 -> Audio tuning -> Combat** to compare
the choices. Player shots also work throughout double jumps.

| Event | Starting selection | Alternatives in the tool | Volume |
| --- | --- | --- | --- |
| Player handgun · shot | Shot_1, fixed | Shot_2, Blaster | -12 dB |
| Enemy handguns · paired shot | Shot_2, fixed | Shot_3, Shot_4 | -15 dB |
| Bullet · scenery impact | Bump, fixed | Hammer_1 | -12 dB |
| Bullet · character impact | Blood_1 / Blood_2 / Blood_3, random without immediate repeats | Any member can be selected alone | -17 dB |

These are initial candidates for the user to hear and tune. Selection was
based on source names and measured onset/tail characteristics; this session
could not audition playback. Shot_1 and Shot_2 have immediate onsets and shorter
active tails than Shot_3/4. Ten source recordings were copied unchanged from
`D:/GodotProjects/blocky3dassets/audio/Sounds` into `assets/audio/combat`.
`source_manifest.json` there records paths and hashes. The flattened source
folder does not identify the exact original pack for each recording.

For the fixed banks, change the **Fixed recording** dropdown to compare
alternatives. **Random pool** varies enabled recordings. Volume, pitch, pitch
variation, enable/mute, A/B, reverb, Revert, and Save work in-game. Preview
**Loop** and **Repeat** remain audition controls; live shots and impacts always
play once. Preview Repeat waits for a recording to finish; actual rapid shots
overlap using separate voices, preserving their tails.

Each simultaneous enemy two-gun beat plays one balanced sound cue; the six
projectiles in a three-beat volley therefore make three firing cues. Each real
collision has its own impact cue. Character hits include the player's body and
enemy projectile hurtboxes; other collisions use the scenery bank. Flying
bullets, expiry, and misses do not create impact sounds. A gunner holding fire
for a teammate plays no shot cue. Enemy-on-enemy hits use the character bank;
bullets that survive shooter defeat can still produce their eventual impact cue.

`combat_audio_3d.gd` owns a bounded pool of 24 spatial voices per level. Camera
staging depth does not attenuate the mix; left/right placement still follows
the sound position. Room reverb uses the actual source/impact position. Reset
stops combat voices and clears gameplay reverb tails; level exit frees them.
The enemy's `dual_shot_fired` signal and `CombatFeedback3D` connect the events.

The initial banks live in `resources/audio/combat`, merged as fallback defaults
by `movement_audio_mix.gd`. Explicit settings in `movement_mix.tres`, including
empty banks, take precedence. The user's existing saved movement and room mix
was not rewritten. Save from the panel persists later choices as usual.

`tools/validate_combat_audio.gd` checks real shot/impact events, double-jump
shots, paired beats, overlapping tails, live controls, routing, and cleanup.
`tools/capture_combat_audio.gd` records the real output mixer and captures the
four tuning pages under `build/previews/combat_audio`. Initial captured peaks
were approximately -14.1 dB for player shots/cover and -17.7 dB for the enemy
volley/cover, leaving headroom. These checks do not establish listening approval.

## Sound-event tool expansion (2026-09-12)

Choose a **Category**, then a surface/action or named sound event. Categories
are Footsteps & jumps, Abilities, Combat, Pickups & progress, World objects,
Ambience, Interface, and Music. The existing surface controls still work as
before. Ambience also gives direct access to the existing Cave and Underground
recording/reverb controls; these edit the same settings shown alongside footsteps.

The expansion introduced 50 empty event banks, including dash, wall movement,
combat, pickups, lift/skater/flyer sounds, outdoor ambience, menu sounds, and
music. Four gunfire/impact entries are now connected as described above; the
other new events remain **preview-only**. Their pages identify whether they
are connected. Adding and saving a recording to an unconnected entry prepares
it for later integration. Existing Cave/Underground ambience stays connected.

For a new event:

1. **Add recordings…** accepts multiple WAV, OGG, or MP3 files.
2. Choose a **Random pool** (no immediate repeat with multiple enabled clips)
   or **Fixed recording**. An empty pool, no fixed selection, or disabling
   **Enabled in mix** makes the event silent. A row's **Play** button can still
   audition a recording separately from its inclusion in the mix.
3. Set **Volume**, **Pitch**, and optional **Pitch variation ±**. Pitch 1.0 and
   variation 0.0 retain normal playback. Variation is an additive range around
   the chosen pitch, sampled once per play; a loop keeps that pitch until stopped.
4. Choose **Play once** or **Loop until stopped**. **Play event** follows the
   current selection rules. A loop repeats the same recording in the audio mixer;
   pressing Play event again picks a new recording according to the pool.
5. **Repeat** previews one-shots at the selected interval, waiting if a recording
   is still playing. It never layers the same event over its own tail. **Stop**
   ends the preview immediately. Loops continue until stopped, without timer
   restarts. Changing category/event, playback mode, A/B, or closing the panel
   also stops the previous event voice.
6. **Use listening room's reverb** routes the event through the selected Cave
   or Underground preview space. Untick it for dry playback. Ambience, Interface,
   and Music slots start dry. The room's existing ambience can play underneath
   previews, and its shared controls remain available.
7. **A/B**, **Revert all changes**, and **Save defaults** include these event
   settings together with the existing movement and room settings. Save promotes
   imported recordings into the project and persists the choices for later runs.

Implementation: `scripts/audio/sound_event_catalog.gd` is the central event
registry. Each unique `category/event` entry supplies its title and initial loop
mode; new entries automatically appear in the panel and receive an empty bank.
A `gameplay` description identifies a connected event in the panel.
`sound_event_bank.gd` extends the existing recording bank with event selection,
pitch, repeat, enable, loop, and reverb settings. The mix resource stores them in
`event_banks`, separate from the established surface banks. Older saved mixes
load the current fallback defaults for new events and retain all existing choices.

`sound_event_voice.gd` provides explicit play/stop playback for previews and
future gameplay owners. It duplicates stream settings before enabling/disabling
WAV/OGG/MP3 looping, preserving the original asset. It does not subscribe to any
gameplay signals. Future integration must deliberately connect a gameplay owner
and decide event lifetime, positional playback, and voice limits as appropriate.

`tools/validate_sound_event_tuning.gd` checks empty defaults, legacy mix loading,
selection, pitch limits, isolated A/B, file replacement and failure handling,
asset promotion, actual panel controls, paused looping and one-shot playback,
room routing, cleanup, and absence of ability-audio subscriptions. Generated
test tones and saved test mixes stay under `build/sound_event_tuning_test`.
The validator hashes the production mix before/after. Extended graphical
captures are under `build/previews/audio_tuning`.

Validation on 2026-09-12: the full suite passed 40/41 checks in about 230 seconds.
The only failure was the previously known Level 2 traversal stage 10 at
(64.54, 29.02). The new event validator also passed additional Repeat/Stop and
pause-ownership checks. Grass, empty event, loop, and room-ambience layouts were
captured at 1920x1080; the grass, combat, and room-ambience captures were visually
reviewed. This is tool validation, not approval of any new audio selections.

The surface-specific instructions and earlier validation history follow.

The user accepted the saved movement and environment mix on 2026-09-06.
All Grass, Sand, Cave, and Underground footstep/takeoff/landing banks are now
populated. `movement_mix.tres` contains the chosen recordings and final levels;
the initial values and validation history below are reference points.
Cave intentionally uses DirtyGround Jump Land 03 for takeoff and Jump Start 03
for landing: the user identified incorrect source filenames by listening.

1. Choose **Grass**, **Sand**, **Cave**, or **Underground · Level 3**, then
   footsteps, takeoff, or landing.
2. Adjust volume with the slider or the number field. Recordings keep their
   original pitch and timing. Grass has separate run/walk settings; **Use for
   both run & walk** copies the selected bank to the other gait.
3. For a random mix, tick the recordings to include. For a foot pair, choose
   the left and right recording. A pool with one enabled clip repeats it;
   an empty pool or an unassigned foot is silent. **Remove** removes a bank
   entry from the experiment, not the source audio file.
4. **Play** auditions one recording. **Play contact** uses the bank's current
   selection rules. **Repeat** alternates feet at about 3.3 contacts/second for running
   or 2.6 for full-speed backwards walking. Jump previews repeat once per second.
   Actual gameplay still uses animation contacts and physical jump events.
5. **B · Current experiment** switches to **A · Saved defaults** for comparison.
   A is read-only and leaves your B edits intact. The selected A/B mix also
   applies when returning to gameplay. **Revert all changes** restores the
   last saved mix across every surface and action.
6. **Save defaults** saves all current banks into
   `resources/audio/movement_mix.tres`. Future launches use that file, and Git
   can track it alongside the code. Unsaved experiments disappear on quit.
   Saving is available in a project run from the Godot editor/executable;
   exported games allow temporary auditioning but cannot save project defaults.

Opening the panel resets the old F5/F4/F6 single-recording auditions to their
normal mix/pair mode, so those overrides cannot mask a panel change. Those
shortcuts and F9 diagnostics remain available during gameplay.

## Adding recordings

**Add recordings…** opens a multiple-file picker for WAV, OGG, or MP3.
On this machine it starts in the NOX footsteps source directory under
`D:/GodotProjects/blocky3dassets/audio/Sounds`. You can navigate to other packs.
Added recordings immediately become available to audition and use in game.
Cave and Underground start with no selected footsteps and use separate
left/right pairs by default. Saved user choices override those initial banks.

On Save, newly selected recordings are stored as Godot binary AudioStream
resources under `assets/audio/tuned`, with the original source path and SHA256
embedded as metadata. This permits use on the next run or in an export without
depending on the external source folder or waiting for an editor import. WAV
PCM is preserved; OGG/MP3 streams retain their encoded audio. Original files
are never modified, and the full source pack is not added to the project.
Source-pack permissions still apply to any recordings selected for release.

## Cave reverb

Choose **Cave**, or choose **Listen in cave** beside the preview speed to hear
any bank with cave acoustics. The reverb card exposes **Amount**, **Room size**,
and **Damping**. Untick its checkbox to compare against the original sound.
The initial suggestion is 16% amount, 50% room size, and 65% damping; these
are listening starting points, not approved final values. The direct contact
retains its original gain and timing; early reflections start after 18 ms.

Reverb settings are shared across footsteps and jump contacts. They participate
in **A/B**, **Revert all changes**, and **Save defaults**, alongside the selected
recordings. Existing saved mixes without a reverb entry load the new initial
settings without replacing the user's bank selections or volumes.

Actual gameplay chooses acoustics from scene-authored audio regions or the
nearest ancestor's `audio_environment` metadata, independently of floor material.
The Level 2 cave interior and the cave-based Level Design Lab are tagged `cave`.
Outdoor sections remain dry, including stone recordings previewed outdoors.
Future cave sounds can use `movement_audio_mix.gd`'s `bus_for_source()` to share
the same acoustic space. Gun and music audio remain pending.

Each environment has separate gameplay and preview buses (`CaveSFX` /
`CavePreview`, `UndergroundSFX` / `UndergroundPreview`). Opening the panel
mutes all existing gameplay reverb buses while its world is paused;
closing restores the previous mute state. Stopping a preview, changing its
space/bank, switching A/B, or closing the panel clears preview delay buffers.
Leaving a level clears gameplay's tail. The Master bus is unaffected.

The scoped tuning validator also captures the actual processed audio. It checks
that a short contact produces a reverb tail, disabling reverb retains the dry
contact without a tail, and clearing a preview leaves no delayed output. It
checks real footstep/jump routing, cave metadata, shared sliders, A/B, and saved
reverb values. All saves still target the disposable build directory.

## Cave drip ambience

The selected NOX `Ambiance_Cave_Drips_Loop_Stereo.wav` is now installed under
`assets/audio/ambience`, with source provenance beside it. The entire roughly
30-second stereo recording loops at its original pitch. Initial volume is
**-6 dB**; the source itself measures -32.2 dB mean / -18.4 dB peak, so this is
a starting point for listening alongside footsteps, not a final approved mix.

**Cave ambience** appears beneath the reverb controls whenever the panel
uses **Listen in cave**. **Choose ambience…** selects a WAV, OGG, or MP3 from
any folder, and **Remove ambience** empties that environment's slot. The file,
checkbox, and volume participate in A/B, Revert, and Save defaults. Newly chosen
ambience files are promoted on Save just like footsteps. Older saved mixes
keep their original drip recording and tuned volume; an explicitly removed
recording stays empty after reloading.

One `cave_ambience_player.gd` on the game root now follows either environment's
selected recording. It also plays during previews while gameplay is paused. Switching
between footsteps and jumps, stopping contact previews, opening/closing the
panel in the same room, and respawning within that room do not restart it.
Selecting an outdoor preview, disabling ambience, or leaving the room fades it
out over 0.4 seconds. Changing recordings fades the old one out before the new
one fades in. WAV, OGG, and MP3 loop in the mixer at their original pitch.
It uses its own Ambience bus, without the movement reverb, so the recording's
existing stereo space is preserved and future music can be balanced separately.

The scoped tuning validator checks the actual loop boundary, concurrent
contact/ambience playback, controls and saved values, preview continuity,
respawn continuity, and stopping on exit. Until footsteps are selected,
choose any current recording with **Listen in cave** to audition against the bed.

## Level 3 underground

**Underground · Level 3** has independent footsteps, takeoff, landing, ambience,
and reverb. Its initial reverb trial is 24% amount, 70% room size, 60% damping;
ambience and contact recordings start empty for user selection. Use
**Choose ambience…**, then add recordings for the foot pair or jump mix.
**Listen underground** auditions any other bank in that acoustic space too.
Changing Underground settings does not change Cave, and all settings persist
through the existing Save / Revert / A/B workflow.

The Level 3 traversal scene's `UndergroundAudioRegion` covers X 107.52–171.52,
Y -29.44–-1.28: descent, lower encounter, and return shaft below the surface lip.
It follows the player's position directly, so jumps, respawns, and inspection
teleports resolve immediately; no trigger-enter history is required. The
surface and the later shooter scene stay outdoors. `DeepRockShell` carries
`footstep_surface=underground` so its contacts use the new banks. Geometry and
movement are unchanged. Region size/position are editable in the scene.

`tools/validate_audio_environments.gd` checks region boundaries, terrain/contact
routing, independent buses/settings, picker signals for WAV/OGG/MP3, loop
playback, selected-asset persistence, intentional empty slots, and room exit.
Tests save only to `build/audio_environment_test` and hash production defaults.

## Implementation and validation

Accepted checkpoint, 2026-09-12: 46/47 suite checks passed in 293.2 s, including
all audio checks and friendly-fire cue checks. The sole failure is the existing
Level 2 stage-10 traversal death near (64.54,29.02). Older dated validation
results below describe earlier milestones, not the current suite status.


- `scripts/developer/audio_tuning_panel.gd`: developer UI and independent
  preview voices; restores the prior pause state on close or level exit.
- `scripts/audio/movement_audio_mix.gd`: separate saved/working bank copies,
  active A/B lookup, selected-asset promotion, and explicit persistence.
- `scripts/audio/footstep_sound_bank.gd`: fixed foot mapping or random selection
  without immediate repeats when two or more clips are enabled.
- `scripts/audio/movement_audio_settings.gd`: resource holding all configured
  banks. The original bank files provide the initial defaults and test fixtures;
  after a user save, `movement_mix.tres` is the authoritative mix.

Saving stages and reloads a temporary `.tres` in the destination folder before
replacing the defaults. On failure, previous defaults and the experiment are
retained. A failed save after asset promotion may leave an unreferenced asset;
it does not replace the previous mix. No Git commit is made by the panel.

`tools/validate_audio_tuning.gd` saves only into `build/audio_tuning_test`,
checks fresh resource loading, file replacement, failed-save recovery,
selected-asset self-containment, live playback, A/B isolation, empty/single
pools, foot mappings, and preview pause ownership. It hashes the real defaults
before and after to ensure they were not changed.

The original footstep/jump validators use the initial fixture banks so that
legitimate user-saved volume or recording choices do not invalidate timing and
surface tests. `tools/capture_audio_tuning.gd` requires the runner's **-Visual**
switch and captures grass, sand, and cave layouts under
`build/previews/audio_tuning`. Automated checks and captures do not establish
whether a chosen sound mix feels right during play.

Validation on 2026-09-06 after adding reverb: the full headless suite passed
36/39 in 265 seconds. Two test issues were corrected and passed scoped reruns:
the tuning test now compares effect floats approximately, and the Level 3
transition test allows a physics tick before requiring player displacement
after an idle scene swap. No transition gameplay was changed. Tuning rerun:
`build/godot_tool_logs/script_headless_20260906_081026_16392.log`.
The remaining failure repeats the previously recorded Level 2 traversal
stage-10 death at (64.54, 29.02):
`build/godot_tool_logs/script_headless_20260906_080828_25692.log`.
The full suite was not repeated after those test-only fixes. Cave panel layout
was captured and inspected; final reverb strength still needs in-game listening.

After adding the drip ambience, the full headless suite passed 38/39 in
219 seconds. Audio tuning (including ambience), both movement-audio validators,
and level transitions passed. The only failure was the same Level 2 stage-10
traversal death, logged in
`build/godot_tool_logs/script_headless_20260906_082433_24512.log`.
The new ambience controls were captured and inspected at 1920x1080. The saved
production mix remained unchanged; ambience loudness awaits user listening.

After adding Underground and both ambience pickers, the full headless suite
passed 39/40 in 224 seconds. Both audio validators, Level 3 geometry/transition,
and footstep/jump checks passed. The only failure remained Level 2 traversal
stage 10 at (64.54, 29.02), logged in
`build/godot_tool_logs/script_headless_20260906_094409_27644.log`.
Cave and Underground panel layouts were captured and inspected at 1920x1080.
The user's saved mix hash was unchanged; Underground sound selection and
acoustic balance remain for their listening review.

The user subsequently completed the Cave and Underground jump selections and
accepted the mix. No gameplay code changed during that final listening pass.
