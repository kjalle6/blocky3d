# Game direction

The game is a demanding pixel-art action platformer set in a cyberpunk world.
Fast, expressive movement drives the experience: read the route, carry momentum,
combine abilities, and use combat to make space for the next jump.

The journey begins on a beach and in the overgrown Green Zone. Machinery,
industrial spaces, and armed enemies gradually reveal the larger setting. The
protagonist and interface bring that cyberpunk identity into the opening areas.
The final title and detailed fiction remain undecided; `blocky3d` is the working
codename.

## Movement and challenge

Running, jumping, Double Jump, Wall Jump, and Dash form the opening movement kit.
Players learn abilities inside the levels and then combine them in longer
sequences. Skilled play should preserve momentum and make familiar routes feel
faster and more fluid.

Gameplay stays on one side-scrolling plane. Routes can climb, descend, and double
back. The camera follows and frames those routes, while layered pixel art gives
the world depth.

Challenge comes from execution, timing, and reading the route. Geometry, enemy
poses, and hazard placement should make the result of an action understandable.
Slow wall slides, for example, give the player time to choose when to kick away;
future Wall Jump guidance should explain that use as well as the jump itself.

The intended difficulty is hard without tedious repetition. Death should teach
something useful, and saves should keep retries close to the challenge. A
surprise can work when it is readable in retrospect and enjoyable to master.
Repeated resource farming should not become the price of another attempt.

## Combat

Combat supports traversal. Knife attacks reward approaching an enemy, stomps
reward getting above it, and gunfire gives the player reach while moving.
Encounters should resolve briskly enough to preserve the pace of a level.

The current starting balance is:

- The player has 100 HP and can survive three ordinary 25-damage hits; the
  fourth kills without healing.
- Bat patrols and skaters have 50 HP: two knife hits or one stomp defeat them.
  Their behavior and timing distinguish them, with equal damage for now.
- Ground-enemy body contact is solid and harmless. Damage comes from the
  attack's visible impact, and ordinary enemies and the player can have attacks
  interrupted by hits. The tank keeps moving and firing through damage.
- Ordinary damage uses attack recovery and interruptions without a general
  invulnerability period. Overlapping threats and repeated hits need playtesting.
- Spikes, pits, and flying enemies are lethal hazards. Flyers are indestructible.

Successful hits need visible and audible feedback even when the target survives.
An ordinary enemy's small health strip appears after it first takes damage.
Bosses are intended to have a larger named bar and clearly readable openings.

[Combat balance](COMBAT_BALANCE.md) records the tuning targets, provisional
weapon values, and encounter questions still to test.

## Firearms

The first handgun comes from defeating an armed enemy in Level 3 with the
existing movement and melee kit. The encounter uses a natural rock as real
projectile cover. The defeated enemy drops a guaranteed weapon pickup that
settles safely and auto-equips on collection. The first collection pauses for
a weapon-unlock showcase: a separate raised heading connects to a metal display
through exposed supports and cables. Recessed cyan and magenta strips cast a soft
glow over the frame and Continue button; a blue line drifts behind the gun above
a faint grid.
A short scan reveal and subtle idle motion bring the display to life. The
player continues by button, Enter/Space, Escape, or gamepad confirm/Start.
The collection sound uses its existing audio-tool bank and finishes during
the reveal. Loading an owned weapon from a save does not replay the showcase.

Mouse aim follows the cursor independently of travel direction, including
retreating fire and shooting during Double Jump. Knife and handgun remain
separately selectable. Enemy bullets can hit other enemies; gunners wait when
a teammate blocks a shot, while released bullets remain dangerous.

The handgun uses loaded rounds and a reserve ammo pool. Reloading transfers
rounds from that pool without discarding what remains in the magazine. A timed
second reload press can finish early; its timing window changes each reload.
The gun HUD shows the weapon and ammunition counts, and hides when the knife is
equipped.

The next campaign stretch introduces shooting through gun enemies: a moving,
slow-firing tank with enough health to encourage reloading, a moving dual-gun
enemy, and a stationary elevated gunner behind cover. An enclosed spike pit
requiring Dash provides a traversal beat between acquiring the handgun and
entering the tank clearing. The tank keeps its firing cycle when hit and destroys
layered crate cover, encouraging the player to reposition. The first boss follows
the remaining encounter sequence. Melee should remain viable throughout, so
running out of ammo cannot make a required encounter impossible.

Most ordinary enemies can be bypassed, with supplies rewarding players who
choose to fight. The tank exit makes that choice immediate: its defeat
earns ammunition and a safe wall-jump climb, while a surviving tank moves below
the climber and fires upward until the player reaches the sheltered upper route.
The [level roadmap](LEVEL_ROADMAP.md#tank-exit-wall-jumping-under-fire)
records the scaffold climb, shelter and encounter boundaries.

## Healing, inventory, and supplies

The player begins without healing items and can carry as many as they find.
Medicine, medical kits, and medical bags restore 25, 50, and 75 HP respectively.
Stronger supplies become available through progression and authored rewards.

Healing is immediate, with a short sound and player indicator. Movement remains
available while attacks pause briefly. An item is not consumed at full health.
The Tab inventory pauses the game; hovering an item and pressing Q or E assigns
it to one of two quick-use slots. Those keys use the assigned items during play.

Supply chests give their contents immediately, then show item icons and quantities
in sequence above the player. Level-specific loot pools vary item types and
amounts; fixed contents support deliberate rewards. Ammo enters random chest
pools once the player owns the handgun. See [chest loot](CHEST_LOOT.md).

General enemy drops, status-effect items, shops, and crafting are possible
extensions. Their availability and balance remain to be designed.

## Saves and recovery

Placeable autosave points record progress on grounded contact without restoring
health. Separate manual slots let the player keep backups from safe positions
outside combat. Death offers Continue, Load Save, and quit options, and the
player can leave the game and resume later.

Loading restores the saved health, inventory, location, and reward claims.
Explicitly choosing an older save also restores progression to that snapshot:
unlocks earned before it remain, while later unlocks are rolled back. Continue
from an autosave can retain later permanent unlocks from the active profile.
The [save guide](SAVE_SYSTEM.md) describes that distinction and the current
three-manual-slot, three-autosave setup.

## Campaign

World 1 introduces the game through three substantial levels:

1. **Arrival / Shoreline** teaches running, jumping, early combat, and Double
   Jump, then carries the player directly into the next level.
2. **Overgrown Coastal Ascent** moves from a dusk approach into connected caves,
   introduces Wall Jump and Dash, and ends with a construction-lift departure.
3. **Green Zone Finale** combines the movement kit in a night forest and
   underworks route before introducing the handgun and, later, a first boss.

The first two levels are complete. The finale has its traversal and first
shooter encounter in place. The [roadmap](LEVEL_ROADMAP.md) tracks the remaining
campaign work and future ideas.

## Art, sound, and interface

Crisp pixel art, layered backgrounds, and coherent local palettes define the
presentation. Gameplay silhouettes stay clear against scenery, especially
during fast movement. Props should meet their surfaces naturally and make it
clear whether they are solid or decorative.

The Cyberpunk GUI pack supplies the compact framed inventory and menus. The
health bar starts small, with centered numbers and Q/E items beneath it, leaving
room for future maximum-health upgrades. More elaborate settings, tutorial,
and game-over screens can extend that same visual style.

Movement and combat already have sound hooks and an in-game tuning tool. Music,
broader sound selection, richer impact effects, and accessibility options remain
part of later presentation work.

## Still to decide

- Final title, protagonist identity, and story.
- The first boss's appearance, attacks, and vulnerability windows.
- Worlds and level order after the Green Zone.
- How permanent upgrades, additional weapons, and stronger supplies are earned.
- Whether crafting, status effects, or a wider economy suit the game.
- Accessibility, rebinding, and difficulty-assist options.
