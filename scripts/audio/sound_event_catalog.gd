extends RefCounted
## Register future events here; the panel and empty defaults follow automatically.
## A gameplay description marks events whose owners are already connected.
const BANK := preload("res://scripts/audio/sound_event_bank.gd")
const CATEGORIES := {
	"movement": "Footsteps & jumps", "abilities": "Abilities", "combat": "Combat",
	"pickups": "Pickups & progress", "world": "World objects", "ambience": "Ambience",
	"interface": "Interface", "music": "Music",
}
const EVENTS := [
	{"id": "combat/heal", "title": "Healing item", "gameplay": "Connected · short cue on successful healing; prototype recording."},
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
	{"id": "combat/bullet_character", "title": "Bullet · character impact", "gameplay": "Connected · plays where a bullet hits the player or an enemy."},
	{"id": "combat/stomp", "title": "Enemy stomp", "gameplay": "Connected · plays on the confirmed enemy stomp and bounce."},
	{"id": "combat/enemy_defeat", "title": "Enemy defeat", "gameplay": "Connected · When a ground enemy or gunner is defeated."},
	{"id": "combat/enemy_attack", "title": "Enemy melee attack", "gameplay": "Connected · When a ground enemy starts its melee attack."},
	{"id": "combat/enemy_notice", "title": "Enemy notice / warning", "gameplay": "Connected · When a ground enemy starts pursuit or a gunner warns/aims."},
	{"id": "combat/player_hit", "title": "Player hit", "gameplay": "Connected · When the player takes damage and survives."},
	{"id": "combat/player_death", "title": "Player death", "gameplay": "Connected · Once when the player dies, including lethal hazards; replaces the hit cue on fatal damage."},
	{"id": "combat/player_respawn", "title": "Player respawn", "gameplay": "Connected · After returning from death."},
	{"id": "combat/weapon_switch", "title": "Weapon switch", "gameplay": "Connected · When the equipped weapon changes."},
	{"id": "pickups/double_jump", "title": "Double jump · unlock", "gameplay": "Connected · When Double Jump is first collected."},
	{"id": "pickups/wall_jump", "title": "Wall jump · unlock", "gameplay": "Connected · When Wall Jump is first collected."},
	{"id": "pickups/dash", "title": "Dash · unlock", "gameplay": "Connected · When Dash is first collected."},
	{"id": "pickups/handgun", "title": "Handgun · collect", "gameplay": "Connected · When the dropped handgun is actually collected, once per acquisition."},
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
