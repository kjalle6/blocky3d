# Main menu background preview

**Approved by the user on 13 October 2026.** Preserve the current artwork and
motion as the baseline for logo and menu integration.

Neon Junction is the approved main-menu background for **Neon Pixel Riot Protocol:
Retro Rebel**. It follows the selected city direction and Protocol Override logo
concept. The technical project name and current game entry scene are unchanged.
F5 now opens the [Protocol Override title and menu](MAIN_MENU.md), which embeds
this approved background. The isolated F6 preview remains available below.

## Run the study

Open `scenes/dev/neon_junction_background_preview.tscn` and run that scene with F6.
For agent playtests, use Godot MCP with that scene path. Space toggles still/motion,
B compares the original sky with the night treatment, S toggles smoke animation,
H toggles preview help,
and Esc closes the preview. The isolated scene contains no
menu actions and does not load or write campaign progress.

The city stays fixed. A separate three-car metro passes behind the bridge railings
and foreground structures. The current timing is an eight-second crossing in a
27-second cycle; the preview begins two seconds into that cycle. Seven signs animate independently. Still mode removes the train and holds all
signs steadily lit. It also removes the aircraft lights. The animation clock
pauses when hidden.

The user requested the left coffee/bowl sign become a classic strip-club sign.
The current plate has a magenta pole-dancer pictogram in that sign. Only its
210 by 415 pixel region at (90,295) was composited from the fal revision; all
pixels outside that region retain the first clean city plate.

## Neon sign timing

The lady sign loses power approximately every 17.8 seconds: a short blackout,
four uneven rapid restart flashes, then a return to steady full brightness.
The first fault begins 3.5 seconds into the preview. Four deeper signs now blink
at staggered intervals: NYVO, ZUIX, the magenta KORU frame/title and the small
distant cross. The existing cyan face and PIXL dips remain.

Local cyan/magenta masks dim the painted neon while holding surrounding
architecture stable; these are not separate unlit/glow assets or dynamic scene
lighting. The shared animation clock pauses when hidden, and still mode returns
every sign to steady light. The approved capture includes this final sign timing
and the accepted broader steam sources.

## Aircraft and alley steam - build 04

The user liked build02 and requested around **24 aircraft**: imagine a child
growing up in this city, never having seen real stars, believing the moving
aircraft lights are what stars look like. The current pass retains the twelve
brighter aircraft and adds twelve smaller, slower distant lights. Independent
strobes and opposing motion keep the field varied, with mostly cool whites,
some red lights and a few warmer points. Brighter lanes move at 4-17 source
pixels per second, distant lanes at 2.2-5.6. Tower occlusion, the darker navy sky
and purple horizon haze are retained. B compares against the original sky.

The user approved the twenty-four aircraft. Build04 keeps them unchanged and
replaces the subtle flow inside painted smoke with full rising alley steam.
Each plume has eight overlapping shader billows with moving outlines, expanding
volume and dissolving edges. Wind visibly carries both plumes to the right,
with matching drift in the inner texture. The smoke silhouette is independent
of the cleanup patch, fixing the visible cutoff at the upper edge. After the user liked this motion, the billows were
widened and thickened to approach the original amount of smoke.

The latest live tuning broadens the source itself toward the right, so steam
emerges from a larger area behind the foreground structures. Initial billow
radius is 52 source pixels; horizontal source spans are 95 upper and 135 lower.
The accepted wind and rolling motion remain. The approved capture includes
this source width; the earlier build04 video is retained as a historical study.

One fal Nano Banana2.1 Edit job reconstructed the walls behind the old smoke.
Only two bounded smoke regions sample this clean plate; the approved city,
sky, signs and original PNG remain intact. Foreground masks keep pipes,
signs, bridge structures and railings in front. Pixel-quantized smoke shades
retain the blue-violet alley light. The actual fal charge is not confirmed.

S restores the original painted smoke for comparison. Space restores it
along with disabling the other motion. The native shader uses a bounded
eight-billow stream per plume and the existing shared animation clock.

## Assets and implementation

- `assets/art/ui/main_menu/neon_junction/city_plate.png`: 2752 by 1536 opaque PNG.
- `assets/art/ui/main_menu/neon_junction/city_no_steam.png`: 2752 by 1536 cleaned plate, sampled only behind steam.
- `assets/art/ui/main_menu/neon_junction/metro.png`: 1956 by 215 transparent PNG.
- `scripts/ui/neon_junction_background.gd`: fixed composition, train, occlusion and sky silhouette.
- `shaders/neon_junction_signs.gdshader`: sky grade, aircraft lights, smoke flow and seven local colour-selective neon animations.
- `shaders/neon_junction_steam.gdshaderinc`: bounded native billows and smoke-region masks.
- `scripts/ui/neon_junction_background_preview.gd`: development-only controls.

All layers share the same transform and nearest texture filtering. Cover scaling
fills the viewport with centered cropping. The signs currently dim selected colours
in the painted plate: they are not separate unlit/glow artwork or scene lighting.
Foreground cutouts reuse the plate pixels. No parallax, video texture, character,
rain, music or interface audio is added; smoke uses native shader billows over locally cleaned artwork.

The reusable background component does not own the logo, title transition,
input focus or menu actions. The separate Protocol Override front end now owns
those behaviors; see [the main-menu guide](MAIN_MENU.md). This component and its
development comparison controls retain the approved source hashes.

## Provenance and review

Source artwork, intermediate takes, exact prompts, model/request IDs, file hashes,
and review notes are retained in the existing workspace under
`workspace/2026-10-12_blocky3d/main-menu/build-01/`. The workspace root is
`D:\GodotTools\mr-mak-workspace`; the game remains in its original folder.
`build-record.json` is the complete source record. Four fal jobs were used:
Nano Banana 2.1 Edit for city cleanup, train reconstruction and the sign revision;
Bria Guided Remove Background for the train's alpha cutout. Retain the originals
when refining or replacing these production copies.

`assets/art/ui/main_menu/neon_junction/SOURCE.json` also keeps the generation
prompts, model/request IDs, production hashes and scoped review with the game.
The visual inspector confirmed the corrected rail masks, isolated face-sign
flicker and revised club sign in sampled 1920 by 1080 frames. The guarded visual
capture completed all 240 frames without script errors. These checks do not
establish approval of the final artwork or timing.

Review the finished capture under **Main menu -> Neon Junction**. The approved
media, acceptance statement and source hashes are in
`workspace/2026-10-12_blocky3d/main-menu/approved-background/approved-record.json`.
Earlier builds remain available below it. The user approved the background's
artwork and motion, including the aircraft, broad steam sources, rightward wind,
train and seven signs. The logo entrance and menu have their own review record;
the user subsequently approved that complete presentation on 13 October 2026.
See [the main-menu guide](MAIN_MENU.md) for its accepted scope.

Use the live Godot preview and targeted screenshots for intermediate tuning.
At the user's request, render videos only for the first iteration and the
finished version; do not make a new video for each adjustment. The final
background capture is saved with the approval record.

When a milestone needs a deterministic ten-second 1280 by 720 capture, use the guarded runner:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_godot_tool.ps1 -Visual -Script res://tools/capture_neon_junction_background.gd
```

The script writes 240 PNG frames at a sampled 24 fps timeline to
`build/neon_junction_capture`. This is an opt-in rendered capture, not a validator,
performance benchmark or proof of continuous real-time frame rate. Do not use
headless mode. Follow AGENTS.md for editor/standalone coordination.
