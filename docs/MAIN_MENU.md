# Protocol Override title and main menu

**Main menu approved for now by the user on 13 October 2026.** This baseline
includes the entrance, enlarged logo, steady NEON PIXEL glow, idle title effects,
faceted menu panels, cycling outlines and three-colour neon marks. Preserve this
accepted presentation during subsequent feature and audio work.

The navigation footer is removed and the player-facing version hides Development.
The [Neon Junction background](MAIN_MENU_BACKGROUND.md) remains approved; its
source artwork, shaders and animation are unchanged.

## Open it

Run the project with **F5**. Agents use Godot MCP `game_start(scene_path="main")`.
The entry scene is still `scenes/app/game_root.tscn`; the technical project name
and save identity remain Blocky 3D.

The entrance now takes **4.8 seconds**, giving each phrase time to register:
NEON PIXEL begins powering up at 0.35 seconds, RIOT PROTOCOL arrives at 1.8
seconds and locks by 2.2, and RETRO REBEL stamps in at 3.4 and lands by 3.68.
The full logo then holds before PRESS ANY BUTTON appears at 4.8 seconds.
Individual arrivals stay brisk; the pauses provide room for a possible sound
effect or spoken title. That audio treatment is undecided and no cue is added.
Named timing constants in `protocol_logo.gd` own both the animation and prompt
completion, so later timing adjustments do not leave the input gate out of sync.
An early press skips to the settled title. Release and press again to enter the
menu. The opening gesture is consumed through release so a held key, mouse click
or controller button cannot also start a campaign.

The title moves upward and scales down over 0.38 seconds, revealing the centered
menu. Keyboard arrows or W/S select; Enter or Space confirms. Controller D-pad
and A use Godot's UI actions; Start confirms the focused action. Pointer hover
and clicks share the same focus highlight. Settings is visibly unavailable.
The menu displays no navigation instruction footer. The title retains its
requested PRESS ANY BUTTON prompt.

Continue reads the existing save/legacy-progress availability. New Campaign,
Load Save and Quit use the existing CampaignMenu operations and confirmation
dialogs. Cancelling a title dialog restores focus. Returning from the pause
menu lands directly on the menu without replaying the entrance.

Development remains in the lower-right corner when developer tools are enabled.
It opens the original level selector; Esc returns to the new main menu. Entering
a level hides the front end and stops the background animation clock. The isolated
background F6 preview and its comparison shortcuts remain available separately.

## Entrance effects and comparison

The entrance adds a brief cyberpunk treatment to each phrase. The user confirmed
they like the current entrance and requested further effects specifically while
the title sits onscreen. Preserve this entrance when tuning the idle treatment.

- **NEON PIXEL, 0.35-1.07 seconds:** a cyan/white charge travels across the actual
  glyph faces, with small circuit runners and one brief power interruption.
- **RIOT PROTOCOL, 1.8-2.32 seconds:** two short horizontal signal faults and a
  smaller correction separate cyan and magenta edge channels. They lock back into
  the solid white wordmark; a narrow read head completes the lock.
- **RETRO REBEL, 3.4-4.18 seconds:** the stamp lands, briefly brightens and sends
  out a slanted rectangular pink pressure wave and twelve short fragments.

All transient entrance effects finish before the 4.8-second prompt. NEON PIXEL now
gains a subtle cyan halo as its letters power up. The halo stays at constant strength
through the settled title and main menu, with the solid letter faces and dark outline
drawn above it to retain crisp edges. It does not pulse or follow the idle faults.
The pauses, approved straight
diagonals and settled title/menu geometry remain unchanged. There is no added
entrance sound or vocal.

For the earlier simple entrance, open
`scenes/dev/main_menu_clean_preview.tscn` and press **F6**. It inherits the
player-facing preview with `title_entrance_effects = false`. Both versions use
the same phrase timing, input gate and final lettering. The clean preview also
omits the new prefix halo. F5 plays the effects;
`scenes/dev/main_menu_release_preview.tscn` plays them without Development.
The exported `GameRoot.title_entrance_effects` flag selects the production
treatment; it does not add a player-facing development control.

Effects belong to `ProtocolLogo` in its local artboard coordinates. Entrance
effects derive only from the entrance clock. Skip moves that clock to the
settled time; replay rewinds it. No timers, emitters or queued callbacks survive
a skip or scene exit. Geometry clipping keeps the glyphs sharp without a raster logo,
post-processing dependency or new paid asset. Contiguous glyph cells are batched
into row rectangles; only the diagonal polygons use edge clipping during effects.
The clipper removes duplicate vertices and zero-area shapes before drawing.

## Effects while the title sits onscreen

These effects start only after the entrance is complete and continue through
the title-to-menu move and on the main menu. The user explicitly requested
occasional flicker after the entrance too and approved this treatment with
"looks really good now" before requesting the steady NEON PIXEL glow.

- **RIOT PROTOCOL:** occasional short recoil and cyan/pink electrical flashes.
  The whole word moves together by at most 14 artboard pixels horizontally and
  5 vertically, then returns exactly to rest. There is no camera shake or
  permanent deformation. Two uneven bursts occupy less than one second of a
  23.9-second cycle.
- **RETRO REBEL:** its lettering and border dim together like an unpowered
  neon tube, briefly relight brighter, then settle back to pink. Three different
  sputter patterns are separated by steady stretches in a 19.7-second cycle.
- **NEON PIXEL:** holds a quiet, constant cyan glow after powering up. Buttons, prompt and the
  approved city are unaffected by the title interference.

The logo owns one idle clock. It starts at the settled title, keeps running when
the menu opens, and resets on replay or a return from gameplay. Hidden titles
stop advancing it. The clean comparison disables both entrance and idle effects.
During steady stretches the logo retains its cached draw; redraws happen only
on a lamp-level change or during the short RIOT PROTOCOL burst.

## Menu selection panels

The user approved the NEON PIXEL glow, then requested more distinctive menu
surfaces and outlines switching between the title colours. The panel treatment,
including the three-colour mark refinement, is now approved for the current menu.

Clipped corners, an offset lower shell, shallow inner facets and segmented light
rails replace the plain rectangles. Enabled rows share a slow cyan -> white ->
pink cycle using the exact logo palette: 3.4 seconds holding each colour and a
0.9-second eased transition, for 12.9 seconds total. The selected row has a
brighter frame and fill, a white chevron, small end brackets, a restrained glow
and a travelling highlight along one short rail. These shape and brightness cues
keep focus clear independently of hue. Disabled Settings remains fixed muted slate.
The three diagonal marks at each panel's right end use fixed neon cyan, white and
pink with a soft glow, as requested in the follow-up. Disabled rows retain faint
coloured marks without the glow. These marks do not follow the frame's colour cycle.

The original Cyberpunk pixel font, 32-pixel type size, centered labels, button
spacing and native Button actions are retained. Panel drawing sits behind the
native label on a mouse-ignoring Control. A single title-owned clock updates
presentation at most 30 times per second while the menu is visible and no modal
is open. It resets on presentation and stops advancing when hidden. There are no
new timers, audio cues, raster assets or shader dependencies.

## Player-facing preview and exports

Open `scenes/dev/main_menu_release_preview.tscn` and press **F6** to review the
player-facing version. It inherits the real game root with
`developer_tools_enabled = false`; Development is hidden, disabled and excluded
from keyboard focus. Direct developer-selector and developer-level entry calls
also return without changing the session. Ordinary F5 keeps editor development
access available.

The existing startup gate requires Godot's `editor` feature and rejects
`blocky_export` before enabling developer tools. Exported games therefore disable
them automatically. This pass verifies the preview and runtime guards; it does
not build or certify a standalone release executable. `LayoutSmoke` remains a
validation preset, not a release configuration.

The preview uses the game's normal campaign/save behavior. Its live check only
views the menu; campaign-writing checks run under the isolated validation runner.

## Implementation

- `scripts/ui/protocol_logo.gd`: original code-authored pixel glyphs, outline,
  extrusion, prefix, stamp, deterministic entrance timing and finite native
  charge/glitch/impact effects. No generated raster
  wordmark or paid model call is involved. The prefix and stamp were enlarged at
  the user's request. Generous counters and solid straight N/X/R diagonals replace
  the first pass's cramped holes and oversized staircase strokes.
- `scripts/ui/protocol_menu_button.gd`: faceted dark panels, cycling title-colour
  outlines, distinct focus/disabled states and the existing production Cyberpunk
  pixel font. Native Button labels and interaction remain authoritative.
- `scripts/ui/protocol_title_screen.gd`: 1920 by 1080 artboard, uniform layout
  scaling, input-release gate, availability and modal focus restoration. It embeds
  the approved background component, which retains its own cover scaling.
- `scripts/app/game_root.gd`: boot, level entry, developer selector and menu return.
- `scripts/ui/campaign_menu.gd`: reuses save/new-campaign actions and adds the title
  quit confirmation. Save formats and progression rules are unchanged.

No entrance sound or music was added; audio work remains separate. Existing UI
dialog sounds retain their current behavior. Timing and logo geometry remain
editable in Godot. Preserve the accepted style and hierarchy during later work.

## Verification and review

The entrance and idle effects revision passed the focused `validate_title_screen` check,
including transient draw paths, both effects/clean previews, reset from an active
idle fault, hidden-title clock suspension and clean-mode suspension. The earlier integration also
passed `validate_save_lifecycle` and `validate_developer_mode`; those were not
rerun for this presentation change. The title regression covers held/echoed keyboard input,
mouse and controller opening gestures, modal cancellation and focus, empty-profile
Continue, hidden background suspension, editor developer access, player-preview
access guards and real campaign entry/return under the runner's isolated profile.
Normal-profile live checks do
not start a new campaign or overwrite a save.

The subsequent prefix-glow refinement received a scoped primary live check:
matched 1920x1080 title captures with the glow on and off, the prefix entrance,
the main menu, and a 1280x720 menu render. The halo remains discreet and the
lettering stays readable without clipping. The runtime error query was clear;
the editor buffer retains earlier progress-dialog/task errors, with no newer errors
in the final incremental query. This small drawing-only refinement did not rerun the functional suite
or the independent inspection. The user subsequently approved the glow with
"it looks good i like it".

The menu-panel revision passed the focused title regression in 7.3 seconds,
covering the existing input, modal, campaign and developer-entry contracts.
Its scoped independent native review is recorded separately from earlier title
passes in the work record. It found no concrete panel, layering or readability
defects across the three hues and smaller window; keyboard skipped Settings and
modal cancellation restored focus. The later three-colour mark refinement received
a primary native check at 1920x1080 and 1280x720, with no runtime errors. It did not
rerun the functional suite or independent pass. The user subsequently approved
the complete current menu: "yeah this is good, approved main menu for now".

Native captures, independent visual-review coverage and the work record are in
Workspace -> blocky3d -> Main menu -> Protocol Override. The record separates
the user's visual approval from automated checks and independent inspection. Use live
Godot and targeted screenshots for intermediate tuning; do not render a new video
for each revision.
