# Level roadmap

World 1, the Green Zone, teaches the movement kit across three substantial
levels. Arrival / Shoreline and Overgrown Coastal Ascent are complete. Green
Zone Finale is playable in development through its first handgun encounter;
its remaining combat sequence and boss are the next campaign work.

## Current campaign

| Level | Main arc | Status |
| --- | --- | --- |
| Arrival / Shoreline | Beach arrival, early combat and hazards, Double Jump, forest clearing | Complete |
| Overgrown Coastal Ascent | Dusk approach, cave entry, Wall Jump and Dash, machine chambers, lift departure | Complete |
| Green Zone Finale | Night ravine, underworks descent and return, first handgun, shooting practice, boss | Traversal and handgun encounter implemented; practice and boss remain |

Campaign play can continue into the unfinished finale. The production level
selector lists the first two levels; developer entries provide direct access to
the finale and its gun encounter.

### Level 1: Arrival / Shoreline

The shoreline leads through Green Threshold and Thorn Garden into an open-air
Double Jump rise. Ground enemies, gaps, and spikes establish the basic combat
and platforming language. A skate half-pipe marks the aerial takeoff, and a
tire-swing-tree clearing ends the route.

The first Thorn Garden gap is an enclosed spike pit: its ground walls extend
downward around a stone bed, with lethal coverage across the entire bottom.
The original takeoff and landing heights and jump gap are preserved.

The second Thorn Garden spike pit and the long spike bed after the skate ramp
also have stone floors beneath their existing spikes. The tall ground beside
the second pit extends downward; the floating platforms above the long pit
retain their original shapes and positions.

The gap just before the skate park also has a recessed spike bed. All four lower
spike beds share the same depth and stone surface, with spikes covering each pit
from wall to wall.

The finish records completion and carries the player directly into Level 2
through a matched exit and entrance. A supply chest on the threshold landing
uses the Shoreline loot pool. The route is complete; ongoing combat and supply
balancing should be assessed in the context of that route.

### Level 2: Overgrown Coastal Ascent

A dusk approach leads through a short cave-slide sequence into one connected
interior. The route recaps familiar movement, teaches Wall Jump, turns toward
the Dash pickup, then combines the abilities through hovering-machine chambers
and an enemy-and-spike exit gauntlet. A construction lift carries the player
out toward Level 3.

The cave's lower and upper backgrounds, regional lighting, water vistas, shaft
camera, and lift framing are in place. The
[Level 2 visual brief](LEVEL_2_VISUAL_BRIEF.md) contains the detailed route and
presentation reference. The cave-approach supply chest uses the Green Zone pool,
which introduces the 50-HP medical kit.

Future tutorial text should explain that a slow wall slide lets the player wait
for clearance before kicking away. The upper wall-jump spike pair currently
uses that timing intentionally.

### Level 3: Green Zone Finale

The player arrives on the construction lift at night. A ravine tests Double
Jump and Dash among familiar enemies, followed by a surprise descent into the
underworks and a long, hazard-free Wall Jump return to the surface.

The sparse surface stretch deliberately suggests a reachable jump before the
fall. Its isolated chest rewards exploration of the apparently empty area;
the bare surroundings are intentional.

A section transition leads into the first armed encounter. The player and
shooter notice each other, the opening volley sends the player to real cover,
and control returns for a fight using the existing movement and melee kit.
Defeating the shooter drops the first handgun, which auto-equips with 30 total
rounds. A nearby supply chest uses the gun-encounter loot pool.

Remaining work in this section:

1. Add the distinct weapon-unlock presentation, showing the acquired handgun
   and its name.
2. Teach firing and reloading in a short safe situation.
3. Build encounters that combine shooting, movement, melee, and familiar hazards.
4. Design and build the first boss and the level's ending.
5. Playtest the full sequence and add the finished finale to the production
   selector.

The boss should have clear attack patterns and meaningful vulnerability windows.
Melee remains a viable way to win with no ammunition. The golf-cart/driver art
is a candidate for a movement set piece and possible second form; the boss
choice and behavior are still open. Moving saws are reserved for a later level.

## Combat and supplies

Health, hit interruptions, healing, inventory, Q/E quick use, ammunition,
active reloads, manual saves, and autosaves are implemented. Supply chests work
in campaign sections and in the level designer, using level pools or fixed
contents. These systems now need integrated balance testing.

The next tuning questions are:

- How handgun damage and reload timing compare with knife attacks and stomps.
- Gunner durability, overlapping attacks, recovery periods, and interruption loops.
- How much healing and ammo accumulate across a level and between saves.
- General enemy drop rates and where stronger healing items should appear.
- Boss durability once its actual attack pattern and melee openings exist.

[Combat balance](COMBAT_BALANCE.md) owns the targets and provisional values.
[Supply chests](CHEST_LOOT.md) owns loot-pool tuning and authoring, and
[inventory and saves](SAVE_SYSTEM.md) explains recovery behavior.

## Interface and presentation

The compact health HUD, Q/E slots, paused inventory, options menu, save/load
pages, gun HUD, and floating pickup icons are implemented. Further work includes:

- The weapon-unlock showcase and a visual polish pass on the active-reload bar.
- Settings behind the current placeholder option.
- Consistent title/level selection and the final game-over composition.
- Tutorial tips, including wall-slide timing and firearm controls.
- Further audio selection and controller/accessibility review.

The Cyberpunk GUI pack provides the visual basis. Crafting, equipment, skill
systems, and a wider economy remain future design choices.

## Later ideas

Possible mechanics for later worlds include moving saws, reactive spikes,
dropping floors, timed platforms, and longer sequences built around the full
movement kit. The [idea notebook](ideas/README.md) holds other exploratory work.

Dash refresh on wall contact is a possible later upgrade. Current routes assume
Dash refreshes on the ground, so changing that rule would alter their reach and
needs to be treated as an ability decision.

World order after the Green Zone, further weapons, upgrades, shops, crafting,
and status-effect items remain open.

## Review before completing a level

A finished level should teach its new mechanics in context, develop them through
readable challenges, and end before repetition becomes padding. Review the full
route at normal speed, including combat, supply availability, saves, deaths, and
recovery. Scenery and camera framing should support clear decisions while moving.

Focused validators check movement, collision, persistence, and transitions.
Hands-on playtesting establishes pacing, difficulty, and visual quality.
New abilities also need a working Firearm Review Lab toggle and focused checks
alongside their campaign introduction.

## Issue to reproduce

An intermittent flash of the death animation at respawn was reported earlier.
The rendered probe did not reproduce it. It remains a low-priority visual issue
for a live reproduction; earlier timing guesses have not established its cause.
