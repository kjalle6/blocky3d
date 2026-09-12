# In-game level editor plan

Agreed: 2026-09-12. Status: next development milestone; not implemented.

## Purpose and workflow

Give the user a visual way to build and fine-tune supported level objects
while playing, with permanent saves and an edit/test cycle like the audio tool.

1. The user and Codex develop the level idea and intended routes together.
2. Codex builds the first playable level, including camera framing, checkpoints,
   transitions, encounter wiring, and scripted moments.
3. The user tests and adjusts platform spacing and sizes, enemy placement and
   ordinary patrol ranges, hazards, and supported trigger areas in the game.
4. Codex continues from that saved layout and handles larger structural,
   camera, and scripting changes. The user does not need to transcribe edits.

All scripted behaviour stays with Codex for now. This includes cutscenes,
choreographed encounters, linked transition sequences, and routes requiring
new enemy jumping, climbing, or lift behaviour.

## Planned controls

- Enter an explicit edit mode that freezes gameplay and allows camera movement.
- Select complete platforms, enemies, hazards, and supported ordinary triggers.
  Show a clear selection outline and labelled boxes for invisible areas.
- Drag on the gameplay plane, use optional grid snapping, and enter precise
  positions. Keep visual depth separate from gameplay placement.
- Resize supported platforms and trigger areas using handles or size fields.
- Show category filters, collision bounds, and camera coverage where useful.
- Try in game, return to editing, undo/redo, revert, and save deliberately.
  Show unsaved changes and preserve them while testing.

### Walking-enemy patrols

Expose the authored spawn, starting direction, movement speed, and draggable
left/right patrol limits, with the range drawn in the level. Retain the
enemy's existing wall and ledge behaviour. Endpoint pauses can follow later;
they are additional behaviour, not part of today's walking-enemy controls.

A patrol range does not create navigation across gaps. Advanced routes remain
with Codex. The edit must update the enemy's intended spawn and patrol origin,
so death and restart do not restore its old location.

### Building platforms

Offer a palette of supported terrain styles/blocks. The user chooses a style
and draws or resizes a platform on the grid. Build matching tile faces, edges,
and collision together, with an explicit footstep-surface setting. Expand the
palette as suitable assets and shapes are prepared.

Start with the existing rectangular tiled platforms. Special shoreline shapes,
joined terrain seams, and other custom assemblies require explicit support;
arbitrary sprite scaling is not a platform-building system.

## Foundation and constraints

The project already has grid/collision overlays, cursor-to-gameplay-plane
projection, reusable objects, and a paused tool UI. The remaining work is
selection, editing, persistence, and object-specific refresh/reset handling.

- Keep intended layout data separate from temporary play state. Saves must not
  capture wandering enemies, defeated actors, bullets, or a lift in transit.
- Give editable objects stable identities and define supported properties.
  Preserve scene references, resource ownership, and shared-resource isolation.
- Apply saved edits early enough that generated collision/art and cached spawn
  positions agree with the layout. Rebuild both visuals and physics on resize.
- Choose one authoritative project layout and a save/load path that both normal
  gameplay and Codex's future scene work use. Resolve inherited scenes and
  section identity before promising direct scene-file round trips. Do not
  blindly pack and overwrite the running level. Check for newer disk changes.
- Moving an encounter's ordinary trigger is distinct from editing its scripted
  choreography. Keep unsupported scripted objects locked or clearly excluded.
- Camera coverage can be shown, but substantial route changes still need
  framing review. Do not claim automatic camera composition or route validity.
- Retain pixel/grid rules and distinguish structural validation from human
  judgment about jump difficulty, pacing, and visuals. Existing traversal bots
  may need deliberate updates after the user changes a route.

## Implementation order and first acceptance gate

1. Prove one complete edit/save/load cycle in a small development fixture:
   move an existing platform, walking enemy, and ordinary trigger; test them;
   save; close and reopen the game; confirm the edits remain functional.
   Verify collision alignment, enemy patrol/spawn after death and restart,
   trigger activation, undo/revert, and preservation of unrelated scene data.
2. Expand selection and move/resize support across explicitly supported object
   types, with usable category filters and patrol handles.
3. Add platform creation from the curated terrain palette, including correct
   surfaces, generated edges/collision, and durable new-object identities.
4. Extend support to the existing level sections and review camera coverage and
   linked objects before allowing edits that affect those systems.

Feasibility is established from the current architecture; reliability across
every object type must be demonstrated through implementation and playtesting.
This plan authorizes no automatic level redesign. Parkour/shooting/cover ideas
remain in `docs/ideas` for much later.
