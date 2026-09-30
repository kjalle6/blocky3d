# Level roadmap

World 1, the Green Zone, teaches the movement kit across three substantial
levels. Arrival / Shoreline and Overgrown Coastal Ascent are complete. Green
Zone Finale is playable in development through the handgun introduction, tank
fight, wall-jump escape and rebuilt upper gunner route. Upper-route encounter
tuning remains in progress; the boss is playable in its separate test lab.

## Next priority: finish the Green Zone boss

**This is the first implementation priority.** Continue from the working
[Boss Test Lab](BOSS_TEST_LAB.md), then finish the encounter in its actual Level 3
arena. Scanner gameplay/UI, further asset expansion, and general polish follow
this milestone unless a concrete blocker needs attention.

1. Build and connect the final arena around the existing attack kit and the
   player's full movement abilities. The enlarged lab is a test fixture, not
   the arena size target. Settle floor/wall access, overhead room, approach,
   retry position, and camera coverage together.
2. Tune missiles, jump/landing AoE, recovery openings, close-range charge/shove,
   and the head-landing smoke escape in that arena. Keep a no-ammo melee victory
   viable, normal mobility intact, and the agreed lack of advance landing warnings.
3. Choose and test boss durability with those openings. **HP remains TBD; 300
   is too low and is only the current lab placeholder.** Keep the combat guide,
   numbers-only spreadsheet, and scanner stat bindings aligned with final tuning.
4. Finish defeat and Level 3 completion flow, including clearing missiles and
   player holds, repeatable retries, and the existing campaign/save behavior.
   Settle presentation/audio needed for this fight; additional phases are not
   assumed requirements.
5. Playtest full fights with and without ammo, both room edges, aerial/wall
   evasion, close pressure and head contact. Verify camera/ground coverage and
   use the visual inspector on the arena and approach. Focused checks support
   this review; player acceptance of difficulty and presentation is still needed.

After the boss, finish the remaining route/supply review and whole-level checks
before marking the finale complete. The scanner data foundation and the asset
organization detour are complete enough to leave parked while the boss is finished.

## Current campaign

| Level | Main arc | Status |
| --- | --- | --- |
| Arrival / Shoreline | Beach arrival, early combat and hazards, Double Jump, forest clearing | Complete |
| Overgrown Coastal Ascent | Dusk approach, cave entry, Wall Jump and Dash, machine chambers, lift departure | Complete |
| Green Zone Finale | Night ravine, underworks descent and return, first handgun, tank fight and escape, later gunners, boss | Traversal, handgun, tank, scaffold climb and upper gunner route implemented; tuning, final boss arena and integration remain |

Campaign play can continue into the unfinished finale. The production level
selector lists the first two levels; developer entries provide direct access to
the finale and its gun encounter.

Phantom Camera is now accepted across all five playable sections, including
the cave and the earlier Level 3 route. The handgun cutscene returns smoothly
to gameplay framing; terrain and authored object placements are preserved.
See [camera authoring](PHANTOM_CAMERA.md).

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
rounds. Its first collection pauses for the finished Cyberpunk GUI showcase with
a separate raised header, illuminated frame, weapon display, and Continue button.
Restoring a save or entering a lab with an owned gun does not repeat the reveal.
A nearby supply chest uses the gun-encounter loot pool.

Remaining work in this section:

1. Finish the boss, its arena, and the level's ending using the priority above.
2. Tune the existing gun-enemy sequence's firing/reload lesson and encounters
   that combine shooting and movement, keeping melee viable.
3. Playtest the full sequence and add the finished finale to the production
   selector.

The route now extends beyond the first handgun chest through an enclosed
14.08 m spike pit (X 30.72–44.8). It uses Level 1's construction: deep ground
sides, a recessed stone bed, wall-to-wall spikes and lethal fill. The bed is recessed to Y -3.68, so only
its top stone lip shows at the bottom of the standing camera view. It is sized
for Double Jump plus Dash. Hands-on playtesting owns its feel; do not add a
scripted traversal runner for this gap.

A short, clear landing leads into the tank clearing. This traversal beat gives
the player a breather and connects the two combat spaces naturally. Frame the
tank and layered crate cover before engagement; its opening fire should not
catch the player during the mandatory crossing. Keep its patrol inside the
clearing, away from the pit. Firing is gated until the player is grounded beyond
X 48.64. The tank initially patrols X 57.6–65.28; the climb and upper route now extend to X 122.88.

The next stretch uses only gun enemies, in this order:

1. **Moving Green Zone tank — implemented first pass.** A slow firing cadence and a clear attack tell give
   the player room to learn. It takes eight handgun shots. Nonlethal hits do not interrupt its movement
   or firing cycle; damage feedback remains visible and audible. Its defeat
   creates a pause to reload before moving on, with the timed reload bonus
   introduced as an optional improvement.
   Cover is two visible layers of destructible wooden crates: the tank
   removes one box per shot, with the surviving upper box falling into the gap.
   The remaining boxes provide a warning before all protection is lost. Leave room to jump, dash, and fight after the cover is gone.
   The breaking shot stops at the crate; the next windup gives time to reposition.
   See [breakable crates](ideas/BREAKABLE_SUPPLY_CRATES.md) for the prototype and
   the separate, later possibility of supply drops.
2. **Moving dual-gun enemy.** Use the same enemy type as the first handgun
   encounter, with movement enabled for these later placements. It takes the
   approaching-enemy role previously suggested for a skater. The original
   scripted handgun-acquisition encounter stays stationary.
3. **Stationary elevated gunner with cover.** Introduce firing angles and
   choosing when to leave cover, while the gunner holds its elevated position.

The moving dual-gun and elevated gunner encounters now have a compact first pass;
the [upper-route notes below](#upper-gunner-route) describe the layout and remaining review.
The tank uses Green Zone enemy 6's idle, walk, attack, death and projectile art,
plus the pack's tank shot and movement recordings. Tank and crate cover are
available in the level designer. [Combat balance](COMBAT_BALANCE.md) records
current values and remaining tuning decisions. Bat enemies and skaters are not part
of this new stretch. Melee and movement remain valid player options.

#### Tank exit: wall jumping under fire

The first pass is implemented. Killing the tank is optional: defeating it earns
ammunition and makes the climb safe; leaving it alive means escaping while it
moves beneath the shaft and shoots upward. It keeps firing until the wall-jump
area leaves the camera view. The moving dual-gun encounter follows along the upper route.

The left wall-jump face is an open steel scaffold, not a masonry block. Its
bright foreground uprights and girders have matching collision; the darker rear
legs and diagonal braces leave the interior and tank entrance open. This is also
a reusable **Wall-jump scaffold** in the level designer, with width, height and
underpass controls.

Current layout values:

- Shaft faces at X 68.48 and 72.96: a 4.48 m gap.
- Solid right-hand ground rises to Y 25.6; the left scaffold's open underpass
  still reaches Y 3.84. There is only one scaffold.
- The scaffold roof is higher again at Y 35.84. A narrow supported service
  bracket at Y 30.72 splits the optional extension into two reachable wall-kick
  and aerial-jump steps. Its reward stays above the ordinary exit's camera frame.
- Two left-facing spike patches on the right wall span Y 8.96–11.52 and
  Y 17.92–20.48. Clean wall sections above, between and below them leave room
  to time the crossing; the final lip is clear.
- A supply chest at X 65.28 on the left scaffold roof uses **Better supplies**.
  It remains editable in the designer and uses ordinary chest/save behavior.
- Tank firing position at X 70.72. The approach is short enough to give the
  slow tank a useful firing lane without changing its movement speed.
- Solid upper ground shelters the player; its original exit floor reaches X 104.96,
  with the new upper gunner route continuing to X 122.88.
  Passing the climb's former X 75.52 exit no longer ends tank fire on its own.
- The spare far crate pile now sits on the upper ledge. The opening dash pit,
  two main cover piles and authored chest remain in place.

A Phantom Camera rail frames the tank and climber during the exposed ascent,
with a continuous approach and upper-exit reveal. That lower-route camera feel
is accepted. Continuing above it enables Phantom's upward follow for the roof
reward and jumps above it, returning to the rail on descent or along the raised
right-hand exit; see
[camera authoring and checks](PHANTOM_CAMERA.md).
The forest backdrop extends above its original coverage. Engagement persists
inside the authored clearing/climb region even when camera framing changes.
An already-engaged tank can continue firing from below the camera while the
player climbs the shaft or explores its roof; it cannot acquire the player off
screen. This placed tank's shell range is 48 m, covering the visible roof and
jumps above it, with its existing
9 m/s speed and cadence. In the climb phase the tank advances to
the firing position instead of stopping four units from the player. Actual
hazards and unsupported ground still stop it.

The barrel aims upward during the tell, locks its direction for the firing
animation and releases a straight-moving shell. The source barrel art is posed
separately while the tracks and brain remain upright. Horizontal clearing fire,
shell cadence, damage, speed, interruption immunity and psychic punishment
retain their existing values. Solid upper ground blocks shots from below.
The last part of the shaft/scaffold leaving the camera cancels unfired attacks
and sends the tank back; solid ground still blocks shots at the upper exit.
Returning to the clearing can restart the fight without healing it.

Defeat grants **30 reserve handgun rounds** once, with the existing ammo pickup
effect. Eight accurate shots give a net gain of 22 rounds. The reward is editable
per tank placement and does not refill the loaded magazine. Defeat and reward
are saved together: loading after the kill keeps the tank defeated without a
second reward; loading before it restores the earlier tank and inventory.

Focused checks cover real scaffold contact and open gaps, tank clearance,
under-shaft movement, lethal wall spikes, long upward hits, upper shelter,
camera-based disengagement, reward
claims, save restoration and designer placement. The fullscreen MCP view has
been inspected. Hands-on testing still owns the climb rhythm and final visual
acceptance; no automated traversal runner is used for this section.

#### Upper gunner route

The oversized first layout was replaced with a compact route ending at X 122.88.
The existing climb's wall, spike patches, roof reward and tank encounter stay in
place. The scaffold uses the owned
Bridge Constructor pack's native riveted posts, braces and deck tiles; its
wall-jump collision, underpass and height remain unchanged.

The first pass follows the reviewed actual-assets concept: a moving dual-gun
enemy on the approach, a small rock shoulder, a supported bridge ledge, then a
stationary gunner at the front of the high ground. The ground uses native Green
Zone grass caps, stone faces, varied rock tails and soil tiles. Three solid
Bridge Constructor deck pieces form the ledge; separate braces connect it to
the right wall. The elevated gunner stands on grass behind a small exposed rock;
the solid ledge blocks low shots. A level-pool supply chest sits beyond it.

- Approach floor Y 25.6; shoulder X 99.84–104.96, top Y 29.44.
  The original ground omits its 40 covered face tiles beneath the shoulder;
  the shared collision box stays intact. Keep this omission aligned if the
  shoulder footprint changes in the designer.
- Ledge X 106.24–110.08, top Y 32.0; high ground top Y 35.84.
- Enclosed spike pit X 104.96–110.08, stone cap Y 21.92. Spikes cover its width
  beneath the ledge; the floor is lethal rather than a safe lower route.
- The Phantom rail rises through the shoulder and ledge. Upper forest layers
  fade in along the approach and continue behind the raised route.
- Every new tile, bridge part, prop, spike row and enemy is editable/removable
  in the level designer. No new protected set dressing.

Combat rhythm, camera framing and final visuals still need player review. The
short rises fit the existing double jump; no movement tuning or automated
full-route runner was introduced for this build.

The reusable **Patrolling dual-gun enemy** remains available in the designer,
with walking on/off, speed, patrol limits and ammo reward settings. Its walk
animation, pursuit, committed bursts, normal interruptions and saved rewards
remain implemented. `validate_route_gunner.gd` checks that behavior separately
from campaign geometry.

Most ordinary fights can be bypassed. Their rewards make fighting worthwhile;
the tank's ammo and safe climb are the first concrete example. Boss melee
openings remain necessary so these optional rewards do not become a hidden
requirement to finish the level.

#### First boss

The selected boss is **Green Zone bosses, character 2**, currently in the
authoring catalog at `assets/library/enemies/green_zone_bosses/2`. The inspected
72-pixel sprite sheets show launcher sequences in `Attack1.png` through
`Attack3.png`, plus thruster-assisted lift-off poses in `Attack4.png` and a
separate `Bullet.png`. These support missile and jump/flight attack ideas;
the files alone do not prescribe missile tracking, flight paths, damage values,
or how the launcher sheets should be sequenced.

**Required jump behavior:** when the boss lands from its jump, the impact deals
area-of-effect damage around the landing point. The visual impact effect appears
on landing, when the damage begins, and communicates the damaging footprint.
Do not add advance landing warnings: no landing markers, danger circles,
countdowns, UI prompts, warning audio, pre-impact warning effects, or a separate
warning phase. The player learns the attack through the boss's ordinary movement,
the landing effect, and its consequences. Keep timing and damage bounds consistent
so that learned evasive movement works.

The player landing on the boss is a separate defensive response: no stomp
damage and no bounce. It deploys a dense smoke burst and holds the player on
the ground while retreating 9 m, then counterattacks during another 1.5 seconds
of hold. Smoke follows the player and gradually fades through the punishment,
with a short tail after control returns. It may fully obscure the player during
the stun. A blocked retreat still releases after 2.5 seconds. This does not add an advance
warning to the boss's own landing blast. Knife and bullet hits use its Hurt
sheet without interrupting attack logic.

Close pressure when the boss wants to fire missiles can now trigger a short,
committed body charge. A single hit pushes the player away to create firing
space; it has its own cooldown and allows jumping/dashing out of its path.
The existing head-landing smoke response remains separate. Tuning and visual
acceptance of this close-range response remain part of boss-lab playtesting.

Apply damage at most once per player per landing, including any overlapping
body/impact hit regions belonging to that attack. Radius, vertical reach, damage,
and active duration remain tuning decisions; whether it is a ground shockwave
or a broader blast remains open. Preserve an opportunity to evade with the
existing movement kit and a recovery opportunity for melee after the landing
damage ends.

Source the boss's explosions and other supporting effects from the existing
`assets/library/vfx` catalog, especially `fire` and `effects`; original packs
are under `D:\GodotProjects\blocky3dassets\vfx`. Audition those assets when
choosing missile impacts, exhaust, landing dust, and defeat effects. Use the
[VFX index](../assets/library/vfx/README.md); promote selected effects into
`assets/art/vfx` with their source/license records.

The selected art is now promoted and implemented in the isolated
[Boss Test Lab](BOSS_TEST_LAB.md), available from the development selector.
Its prototype alternates a committed six-rocket ripple with a targeted
jump and landing blast, with independent cooldowns, stationary recovery, and
walking between attacks. The lab now has three times its original interior
width and height. Its encounter camera gives nearby combat a modest wider view
and frames both actors, returning to ordinary player follow farther away. The
finished arena need not use the lab's dimensions. It provides all movement
abilities, reset/refill, attack selection, and a no-ammo mode. Selected effects
are under `assets/art/vfx/boss`; source and license records accompany the assets.

The boss should have clear attack patterns and meaningful vulnerability windows.
**Boss HP is TBD:** the current 300 HP is an inadequate lab placeholder, not an
accepted fight-length target. Choose its replacement with the actual arena and
attack openings; see [Combat balance](COMBAT_BALANCE.md).
Melee remains a viable way to win with no ammunition. Attack tuning, recovery,
the finished arena, and any phase changes still need playtesting. The boss has
not been connected to the Level 3 route. Moving saws are reserved for a later level.

Design and test the boss and arena around the player's full available movement
kit: running, variable-height jumps, Double Jump, horizontal Dash, wall slides,
and Wall Jump. Skilled use of those abilities should provide effective evasive
options. Preserve the existing movement rules rather than weakening abilities
to make the boss threatening.

- Use the current movement tuning to test attack timing, arena width, overhead
  clearance, wall access, landing space, and camera coverage together.
- Respect ability availability during attack sequences: landing restores Dash;
  Wall Jump does not restore Dash or Double Jump, and repeated jumps from the
  same wall require an opposite-wall contact or landing. See the movement
  contracts in [Technical foundation](TECHNICAL_FOUNDATION.md#wall-movement-contract).
- Test the fight against airborne players, wall escapes, and players who have
  already spent their aerial jump or Dash. Keep attack motion and targeting
  consistent enough to learn and evade; do not add a warning phase to the landing
  AoE or rely on unavoidable last-moment tracking.
- Give walls and any platforms a useful movement role while checking whether
  one stationary perch trivializes the entire fight. Legitimate skilled dodging
  is not a defect. Recovery must allow the player to land, approach, and use melee.

## Combat and supplies

Health, hit interruptions, healing, inventory, Q/E quick use, ammunition,
active reloads, manual saves, and autosaves are implemented. Supply chests work
in campaign sections and in the level designer, using level pools or fixed
contents. These systems now need integrated balance testing.

The next tuning questions are:

- Boss durability, attack spacing and melee openings in the final arena.
- How handgun damage and reload timing compare with knife attacks and stomps.
- Gunner durability, overlapping attacks, recovery periods, and interruption loops.
- How much healing and ammo accumulate across a level and between saves.
- General enemy drop rates and where stronger healing items should appear.

[Combat balance](COMBAT_BALANCE.md) owns the targets and provisional values.
[Supply chests](CHEST_LOOT.md) owns loot-pool tuning and authoring, and
[inventory and saves](SAVE_SYSTEM.md) explains recovery behavior.

## Enemy and hazard scanner (queued after the boss)

The scanner concept is documented in [Combat balance](COMBAT_BALANCE.md#enemy-and-hazard-scanner-planned):
quick live overlay, hold-left-click initial scan with full movement and no
attacks, game-provided names, experience-based discovery, later optional
renaming and right-click inspection. The [data catalog and reader](SCANNER_DATA.md)
are implemented with current-stat bindings and separate evidence conditions.
Gameplay/UI, event adapters and knowledge storage are not connected, and the
acquisition point has not been assigned to a level. Resolve the open discovery,
naming and save rules before those integrations; select overlay assets afterward.

The data-preparation detour is complete. Leave scanner gameplay integration
queued while finishing the boss; final arena construction, encounter tuning
and Level 3 integration are the active priority.

## Interface and presentation

The compact health HUD, Q/E slots, paused inventory, options menu, save/load
pages, gun HUD, floating pickup icons, and weapon-unlock showcase are implemented.
Further work includes:

- A visual polish pass on the active-reload bar.
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
