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
	{"id": "abilities/double_jump", "title": "Double jump"},
	{"id": "abilities/dash_ground", "title": "Dash · grounded"},
	{"id": "abilities/dash_air", "title": "Dash · airborne"},
	{"id": "abilities/wall_jump", "title": "Wall jump"},
	{"id": "abilities/wall_slide", "title": "Wall slide", "loop": true},
	{"id": "abilities/dash_ready", "title": "Dash ready again"},
	{"id": "combat/player_gunshot", "title": "Player handgun · shot", "gameplay": "Connected · plays when the player fires, including during jumps."},
	{"id": "combat/enemy_gunshot", "title": "Enemy handguns · paired shot", "gameplay": "Connected · one sound for each simultaneous two-gun shot."},
	{"id": "combat/knife_swing", "title": "Knife · swing", "gameplay": "Connected · one sound when a knife swing starts, including misses."},
	{"id": "combat/knife_hit", "title": "Knife · hit", "gameplay": "Connected · one impact when a swing hits a live enemy, even if it catches several."},
	{"id": "combat/bullet_scenery", "title": "Bullet · scenery impact", "gameplay": "Connected · plays where a bullet hits cover or scenery."},
	{"id": "combat/bullet_character", "title": "Bullet · character impact", "gameplay": "Connected · plays where a bullet hits the player or an enemy."},
	{"id": "combat/stomp", "title": "Enemy stomp", "gameplay": "Connected · plays on the confirmed enemy stomp and bounce."},
	{"id": "combat/enemy_defeat", "title": "Enemy defeat"},
	{"id": "combat/enemy_attack", "title": "Enemy melee attack"},
	{"id": "combat/enemy_notice", "title": "Enemy notice / warning"},
	{"id": "combat/player_death", "title": "Player hit / death"},
	{"id": "combat/player_respawn", "title": "Player respawn"},
	{"id": "combat/weapon_switch", "title": "Weapon switch"},
	{"id": "pickups/double_jump", "title": "Double jump · unlock"},
	{"id": "pickups/wall_jump", "title": "Wall jump · unlock"},
	{"id": "pickups/dash", "title": "Dash · unlock"},
	{"id": "pickups/handgun", "title": "Handgun · collect"},
	{"id": "pickups/checkpoint", "title": "Checkpoint"},
	{"id": "pickups/level_complete", "title": "Level complete"},
	{"id": "world/gun_drop", "title": "Dropped handgun · bounce / settle"},
	{"id": "world/enemy_step", "title": "Patrol enemy · footstep"},
	{"id": "world/skater_roll", "title": "Skater · wheels", "loop": true},
	{"id": "world/flyer_hover", "title": "Flying hazard · hover", "loop": true},
	{"id": "world/flyer_spark", "title": "Flying hazard · discharge"},
	{"id": "world/lift_start", "title": "Lift · start"},
	{"id": "world/lift_motor", "title": "Lift · motor", "loop": true},
	{"id": "world/lift_stop", "title": "Lift · stop"},
	{"id": "world/lift_step", "title": "Lift deck · footstep"},
	{"id": "world/lift_land", "title": "Lift deck · landing"},
	{"id": "world/cave_slide", "title": "Cave intro · sliding", "loop": true},
	{"id": "world/cave_slide_exit", "title": "Cave intro · exit contact"},
	{"id": "world/cave_splash", "title": "Cave water · splash"},
	{"id": "ambience/cave", "title": "Cave · existing room ambience", "room": "cave"},
	{"id": "ambience/underground", "title": "Underground · existing room ambience", "room": "underground"},
	{"id": "ambience/beach", "title": "Beach · surf", "loop": true},
	{"id": "ambience/forest", "title": "Forest · night", "loop": true},
	{"id": "ambience/level_3_outdoors", "title": "Level 3 · outdoors", "loop": true},
	{"id": "interface/focus", "title": "Selection / focus"},
	{"id": "interface/confirm", "title": "Confirm"},
	{"id": "interface/back", "title": "Back / close"},
	{"id": "interface/unavailable", "title": "Unavailable choice"},
	{"id": "music/menu", "title": "Menu", "loop": true},
	{"id": "music/level_1", "title": "Level 1", "loop": true},
	{"id": "music/level_2", "title": "Level 2", "loop": true},
	{"id": "music/level_3", "title": "Level 3", "loop": true},
	{"id": "music/completion", "title": "Completion phrase"},
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
