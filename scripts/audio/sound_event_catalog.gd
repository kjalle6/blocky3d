extends RefCounted
## Register future events here; the panel and empty defaults follow automatically.
## A gameplay description marks events whose owners are already connected.
const BANK := preload("res://scripts/audio/sound_event_bank.gd")
const CATEGORIES := {
	"movement": "Footsteps & jumps", "abilities": "Abilities", "combat": "Combat", "boss": "Boss · S.T.O.M.P.",
	"pickups": "Pickups & progress", "world": "World objects", "ambience": "Ambience",
	"interface": "Interface", "music": "Music",
}
const EVENTS := [
	{"id": "combat/tank_psychic", "title": "Tank · psychic pulse", "gameplay": "Connected · once when landing on the brain triggers its damaging freeze; independent of shell firing."},
	{"id": "combat/tank_shot", "title": "Tank · shot", "gameplay": "Connected · on the tank's actual shell release."},
	{"id": "world/tank_tracks", "title": "Tank · moving tracks", "loop": true, "gameplay": "Connected · while a nearby living tank moves; stops when paused or defeated."},
	{"id": "world/crate_break", "title": "Crate cover · break", "gameplay": "Connected · once when an individual destructible box breaks; prototype crate recording."},
	{"id": "boss/footstep", "title": "Mechanical footstep", "gameplay": "Connected · on the boss's planted walk frames while it is on screen."},
	{"id": "boss/charge", "title": "Body charge", "gameplay": "Connected · once when the close-range charge commits, before its rush."},
	{"id": "boss/shove_contact", "title": "Shove contact", "gameplay": "Connected · only when a charge or salvo shove actually knocks the player back."},
	{"id": "boss/landing", "title": "Landing impact", "gameplay": "Connected · on the boss's physical floor contact after a jump or chase leap; no advance warning."},
	{"id": "boss/launcher_swivel", "title": "Launcher swivel", "gameplay": "Connected · when the launcher turns to aim a salvo, including the entry beat's aim."},
	{"id": "boss/rocket_launch", "title": "Rocket launch", "gameplay": "Connected · once per rocket as it leaves its tube; six in a salvo."},
	{"id": "boss/rocket_flight", "title": "Rocket flight", "loop": true, "gameplay": "Connected · while each rocket is actually flying; stops on impact or expiry."},
	{"id": "boss/rocket_explosion", "title": "Rocket explosion", "gameplay": "Connected · where a rocket hits the player or scenery."},
	{"id": "boss/jump_thruster", "title": "Jump thruster", "gameplay": "Connected · at the boss's actual take-off for a jump or chase leap."},
	{"id": "boss/smoke_vent", "title": "Smoke vent", "gameplay": "Connected · when a head landing triggers the smoke escape."},
	{"id": "boss/firebomb_launch", "title": "Firebomb launch", "gameplay": "Connected · once per lob when the canisters leave the pod."},
	{"id": "boss/firebomb_burst", "title": "Firebomb burst", "gameplay": "Connected · where each canister bursts into a burning patch."},
	{"id": "boss/flyer_flight", "title": "Flying-machine flight", "loop": true, "gameplay": "Connected · while a nearby phase-two flying machine is active; replaces the generic hover."},
	{"id": "boss/flyer_destroyed", "title": "Flying-machine destruction", "gameplay": "Connected · when the player shoots down a flying machine; silent when the boss's defeat clears them."},
	{"id": "boss/phase_two", "title": "Phase-two activation", "gameplay": "Connected · once when the boss first falls to half health."},
	{"id": "boss/defeat", "title": "Boss defeat", "gameplay": "Connected · once on the live kill; a restored defeat stays silent."},
	{"id": "boss/reveal", "title": "Reveal stinger", "gameplay": "Connected · when the entry cutscene's name reveal starts; a skipped cutscene stays silent."},
	{"id": "boss/warhead_drop", "title": "Warhead drop", "gameplay": "Connected · where the warhead lands after the boss's defeat."},
	{"id": "boss/warhead_pickup", "title": "Warhead pickup", "gameplay": "Connected · when the player picks up the warhead."},
	{"id": "boss/blast_door", "title": "Blast door blown", "gameplay": "Connected · when the planted charge blows the exit door; a restored open door stays silent."},
	{"id": "boss/fire_burning", "title": "Fire patch · burning", "loop": true, "gameplay": "Connected · while a nearby firebomb fire is burning."},
	{"id": "boss/fire_smothered", "title": "Fire patch · smothered", "gameplay": "Connected · when a landing puts a fire out; burning out on its own stays silent."},
	{"id": "combat/heal", "title": "Healing · medicine", "gameplay": "Connected · when Medicine heals; also the fallback for any healing item whose own slot is empty."},
	{"id": "combat/heal_kit", "title": "Healing · medical kit", "gameplay": "Connected · when a Medical kit heals; falls back to Medicine while empty."},
	{"id": "combat/heal_bag", "title": "Healing · medical bag", "gameplay": "Connected · when a Medical bag heals; falls back to Medicine while empty."},
	{"id": "abilities/double_jump", "title": "Double jump", "gameplay": "Connected · On the second jump."},
	{"id": "abilities/dash_ground", "title": "Dash · grounded", "gameplay": "Connected · When a grounded dash starts."},
	{"id": "abilities/dash_air", "title": "Dash · airborne", "gameplay": "Connected · When an airborne dash starts."},
	{"id": "abilities/wall_jump", "title": "Wall jump", "gameplay": "Connected · When a wall jump starts."},
	{"id": "abilities/wall_slide", "title": "Wall slide", "loop": true, "gameplay": "Connected · While the player slides down a wall."},
	{"id": "abilities/dash_ready", "title": "Dash ready again", "gameplay": "Connected · When a spent dash becomes available again."},
	{"id": "combat/player_gunshot", "title": "Player handgun · shot", "gameplay": "Connected · plays when the player fires, including during jumps."},
	{"id": "combat/out_of_ammo", "title": "Player handgun · out of ammo", "gameplay": "Connected · empty trigger clicks share the gunshot cooldown; silent during reloads and blocked attacks."},
	{"id": "combat/enemy_gunshot", "title": "Enemy handguns · paired shot", "gameplay": "Connected · one sound for each simultaneous two-gun shot."},
	{"id": "combat/knife_swing", "title": "Knife · swing", "gameplay": "Connected · one sound when a knife swing starts, including misses."},
	{"id": "combat/knife_hit", "title": "Knife · hit", "gameplay": "Connected · one impact when a swing hits a live enemy, even if it catches several."},
	{"id": "combat/bullet_scenery", "title": "Bullet · scenery impact", "gameplay": "Connected · plays where a bullet hits cover or scenery."},
	{"id": "combat/bullet_machine", "title": "Bullet · machine impact", "gameplay": "Connected · where a bullet hits armour: the boss, its flying machines or the tank."},
	{"id": "combat/bullet_dirt", "title": "Bullet · dirt and grass impact", "gameplay": "Connected · where a bullet hits grass or sand ground; falls back to the scenery impact while empty."},
	{"id": "combat/bullet_metal", "title": "Bullet · metal impact", "gameplay": "Connected · where a bullet hits scaffolds, the lift or other steel; falls back to the scenery impact while empty."},
	{"id": "combat/bullet_wood", "title": "Bullet · wood impact", "gameplay": "Connected · where a bullet hits a wooden crate; falls back to the scenery impact while empty."},
	{"id": "combat/bullet_character", "title": "Bullet · character impact", "gameplay": "Connected · plays where a bullet hits the player or an enemy."},
	{"id": "combat/knife_metal_hit", "title": "Knife · metal hit", "gameplay": "Connected · one impact when a swing hits the boss or the tank, instead of the flesh hit."},
	{"id": "combat/reload_start", "title": "Player handgun · reload start", "gameplay": "Connected · when a reload begins."},
	{"id": "combat/reload_finish", "title": "Player handgun · reload finish", "gameplay": "Connected · when a reload completes normally; an active reload plays its own cue instead."},
	{"id": "combat/active_reload", "title": "Player handgun · active reload", "gameplay": "Connected · when a press inside the highlighted window finishes the reload early."},
	{"id": "combat/enemy_defeat", "title": "Enemy defeat", "gameplay": "Connected · When a ground enemy or gunner is defeated."},
	{"id": "combat/enemy_attack", "title": "Enemy melee attack", "gameplay": "Connected · When a ground enemy starts its melee attack."},
	{"id": "combat/enemy_notice", "title": "Enemy notice / warning", "gameplay": "Connected · When a ground enemy starts pursuit or a gunner warns/aims."},
	{"id": "combat/player_hit", "title": "Player hit", "gameplay": "Connected · When the player takes damage and survives."},
	{"id": "combat/player_death", "title": "Player death", "gameplay": "Connected · Once when the player dies, including lethal hazards; replaces the hit cue on fatal damage."},
	{"id": "combat/weapon_switch", "title": "Weapon switch", "gameplay": "Connected · When the equipped weapon changes."},
	{"id": "pickups/double_jump", "title": "Double jump · unlock", "gameplay": "Connected · When Double Jump is first collected."},
	{"id": "pickups/wall_jump", "title": "Wall jump · unlock", "gameplay": "Connected · When Wall Jump is first collected."},
	{"id": "pickups/dash", "title": "Dash · unlock", "gameplay": "Connected · When Dash is first collected."},
	{"id": "pickups/handgun", "title": "Handgun · collect", "gameplay": "Connected · When the dropped handgun is actually collected, once per acquisition."},
	{"id": "pickups/ammo", "title": "Ammo received", "gameplay": "Connected · when handgun rounds arrive outside a chest, such as a defeated gunner's or tank's reward."},
	{"id": "pickups/checkpoint", "title": "Autosave point", "gameplay": "Connected · When an autosave point activates."},
	{"id": "pickups/level_complete", "title": "Level complete", "gameplay": "Connected · When a level is completed, including its exit transition."},
	{"id": "world/chest_open", "title": "Chest · open", "gameplay": "Connected · Once when a supply chest opens, regardless of its item count. Restoring an already opened chest stays silent."},
	{"id": "world/gun_drop", "title": "Dropped handgun · bounce / settle", "gameplay": "Connected · When the dropped handgun finishes its bounce and settles."},
	{"id": "world/enemy_step", "title": "Patrol enemy · footstep", "gameplay": "Connected · On nearby patrol enemies walking animation contacts."},
	{"id": "world/skater_roll", "title": "Skater · wheels", "loop": true, "gameplay": "Connected · While a nearby skater moves on the ground."},
	{"id": "world/flyer_hover", "title": "Flying hazard · hover", "loop": true, "gameplay": "Connected · While a nearby flying hazard is active."},
	{"id": "world/flyer_spark", "title": "Flying hazard · discharge", "gameplay": "Connected · When a nearby flying hazard starts its discharge."},
	{"id": "world/lift_start", "title": "Lift · start", "gameplay": "Connected · When a nearby lift begins moving."},
	{"id": "world/lift_motor", "title": "Lift · motor", "loop": true, "gameplay": "Connected · While a nearby lift is moving."},
	{"id": "world/lift_stop", "title": "Lift · stop", "gameplay": "Connected · When a nearby lift stops moving."},
	{"id": "world/lift_step", "title": "Lift deck · footstep", "gameplay": "Connected · On player footfalls on the lift deck."},
	{"id": "world/lift_land", "title": "Lift deck · landing", "gameplay": "Connected · When the player lands on the lift deck."},
	{"id": "world/cave_slide", "title": "Cave intro · sliding", "loop": true, "gameplay": "Connected · During the cave entrance slide."},
	{"id": "world/cave_slide_exit", "title": "Cave intro · exit contact", "gameplay": "Connected · At the natural end of the cave slide; silent when skipped."},
	{"id": "world/cave_splash", "title": "Cave water · splash", "gameplay": "Connected · When the player dies in cave water."},
	{"id": "ambience/cave", "title": "Cave · existing room ambience", "room": "cave"},
	{"id": "ambience/underground", "title": "Underground · existing room ambience", "room": "underground"},
	{"id": "ambience/beach", "title": "Level 1 · beach surf", "loop": true, "gameplay": "Connected · In the shoreline area of Level 1."},
	{"id": "ambience/forest", "title": "Level 1 · forest", "loop": true, "gameplay": "Connected · In the forest section of Level 1, after the shoreline."},
	{"id": "ambience/level_2_forest", "title": "Level 2 · forest", "loop": true, "gameplay": "Connected · In Level 2 outdoors; separate from the Level 1 forest."},
	{"id": "ambience/level_3_outdoors", "title": "Level 3 · outdoors", "loop": true, "gameplay": "Connected · In Level 3 outdoors; stops inside underground rooms."},
	{"id": "interface/focus", "title": "Selection / focus", "gameplay": "Connected · When hovering or focusing a menu button."},
	{"id": "interface/confirm", "title": "Confirm", "gameplay": "Connected · When activating a menu button."},
	{"id": "interface/back", "title": "Back / close", "gameplay": "Connected · When closing, cancelling or returning from a menu."},
	{"id": "interface/unavailable", "title": "Unavailable choice", "gameplay": "Connected · When attempting a disabled menu button."},
	{"id": "music/menu", "title": "Menu", "loop": true, "gameplay": "Connected · While the main menu/development selector is open."},
	{"id": "music/level_1", "title": "Level 1", "loop": true, "gameplay": "Connected · While playing Level 1."},
	{"id": "music/level_2", "title": "Level 2", "loop": true, "gameplay": "Connected · While playing Level 2, including its cave."},
	{"id": "music/level_3", "title": "Level 3", "loop": true, "gameplay": "Connected · While playing Level 3."},
	{"id": "music/completion", "title": "Completion phrase", "gameplay": "Connected · Once when completing a level."},
]

static func entries_for(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in EVENTS:
		if str(entry.id).get_slice("/", 0) == category:
			result.append(entry)
	return result

static func definition(event_id: String) -> Dictionary:
	for entry in EVENTS:
		if entry.id == event_id:
			return entry
	return {}

static func default_banks() -> Dictionary:
	var banks := {}
	for entry in EVENTS:
		if entry.has("room"):
			continue
		var bank := BANK.new()
		bank.looping = entry.get("loop", false)
		bank.volume_db = -18.0
		bank.use_room_reverb = not str(entry.id).get_slice("/", 0) in ["ambience", "interface", "music"]
		banks[entry.id] = bank
	return banks
