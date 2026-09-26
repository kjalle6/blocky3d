# Breakable supply crates

Status: Destructible cover is implemented for the Level 3 tank encounter.
Loot-bearing supply crates remain a later extension.

## Tank encounter: temporary cover

Use visibly layered wooden crates as temporary cover in the moving tank's
clearing. This develops the earlier lesson that solid scenery blocks bullets:
wood protects the player, but the tank can destroy it and force a change of
position. Keep the original handgun-acquisition encounter's rock cover intact.

Current first prototype:

- Two visible layers along the shot path, with a small separation so their
  depth reads clearly in the side view. Each pile contains three independent
  boxes, with an offset upper box supported by a lower one.
- Each tank shot breaks exactly one box with flying splinters and a provisional
  crate impact recording. Other boxes survive, and an unsupported upper box
  falls into the gap. Further shots remove individual boxes in the line of fire.
- The breaking shot is absorbed by that box. It does not pass through into
  the next layer or the player. Debris is cosmetic and cannot trap or damage
  the player.
- The tank's next visible windup leaves time to jump or dash away. Keep the
  surrounding ground open, with room to move past the tank or retreat to
  another temporary cover position. The encounter must remain beatable after
  all crates are gone, including with melee and no ammo.
- Breakable wood blocks player shots too, encouraging the player to
  leave cover or jump for an angle. Each box takes two handgun or knife hits
  (50 HP). Decorative boxes remain scenery.
- Start with empty cover crates to establish the combat behavior. Releasing
  supplies can be added later using the rules below.

The actor uses the existing wooden crate art with its empty margins cropped
at display time. The shared projectile stops at its first solid hit, and the
gunner's ally check distinguishes enemies from cover. Level-designer placement
is available under Supplies as **Breakable wooden crate**. Destruction uses
stable world flags, so loading a snapshot restores the cover state from that
save; loading an earlier save can bring the boxes back. No items drop yet.

The tank takes normal damage without hit interruption: incoming hits do not
cancel shots, restart its cadence, or stop its movement. Tune the firing interval
and initial tell so it has a practical opportunity to threaten cover while
leaving time to reposition. Impact feedback must remain clear without forcing
the tank into a hurt animation. See the tank rules in
[combat balance](../COMBAT_BALANCE.md).

The approach crosses an enclosed spike pit requiring Dash, followed by a clear
landing before the tank engages. The [level roadmap](../LEVEL_ROADMAP.md) owns
the transition layout; the pit separates the earlier gunfight from this clearing
without placing the player under tank fire during a mandatory jump.

## Later: supply crates

Some supply crates could break when attacked and release ammunition, healing,
or other loot. This could make exploration and occasional practice shots more
rewarding. Existing crate scenery is decorative; damage, destruction, and
reward behavior would need to be added.

Reuse suitable art from the owned packs and consider the existing level-based
loot pools and fixed rewards. The existing pickup icons and quantity feedback
could present their contents. Keep these distinct from ordinary supply chests
that open on contact.

Questions for a later prototype:

- How do breakable crates stand out clearly from decorative boxes?
- What extra impact/dust detail and final sound make breaking them satisfying?
- How do their rewards fit alongside chest supplies and future enemy drops?
- Persist any future claimed contents with the destruction flag to prevent farming.
