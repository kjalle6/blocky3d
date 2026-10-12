extends Node
## Gameplay connections for optional audio banks; no selected recording is silent.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const LOOP := preload("res://scripts/audio/gameplay_event_loop.gd")
const LIFT := preload("res://scripts/presentation/cave_construction_lift_3d.gd")
const SKATER_PROFILE := preload("res://resources/combat/skater.tres")
const BOSS := preload("res://scripts/enemies/green_zone_boss_3d.gd")
const BOSS_MISSILE := preload("res://scripts/projectiles/boss_missile_3d.gd")
const FIRE_PATCH := preload("res://scripts/hazards/boss_fire_patch_3d.gd")
const PHASE_FLYER := preload("res://scripts/enemies/destructible_flyer_3d.gd")
# Planted feet in the boss's six-frame walk, as for the patrol enemies.
const BOSS_STEP_FRAMES := [0, 3]
const MAX_LOOPS := 16
var session: LevelSession3D
var sound: Node3D
var _actors: Array[Node3D] = []
var _states: Dictionary = {}
var _loops: Dictionary = {}
var _requested: Dictionary = {}
var _dash_ready := false
var _awaiting_respawn := false

func _ready() -> void:
	session = get_parent() as LevelSession3D
	process_physics_priority = 100
	sound = session.combat_feedback.combat_audio if session.combat_feedback != null else null
	if sound == null:
		sound = preload("res://scripts/audio/combat_audio_3d.gd").new()
		add_child(sound)
	var player := session.player
	player.ability_performed.connect(_on_ability)
	player.weapon_equipped.connect(func(_weapon: StringName) -> void: play("combat/weapon_switch", player))
	player.damage_received.connect(func(_position: Vector3) -> void:
		if player.health.current > 0: play("combat/player_hit", player))
	player.death_started.connect(_on_death)
	player.movement_reset.connect(_on_player_reset)
	player.pixel_visual.footstep_contact.connect(_on_player_step)
	player.landed.connect(_on_player_landed)
	session.ability_unlocked.connect(func(id: StringName) -> void: play("pickups/" + str(id), player))
	session.checkpoint_changed.connect(func(_index: int) -> void: play("pickups/checkpoint", player))
	session.run_completed.connect(func() -> void: play("pickups/level_complete", player))
	session.run_reset.connect(_reset_tracking)
	session.save_state.reward_claimed.connect(_on_reward_claimed)
	for node in session.find_children("*", "Node", true, false):
		_bind_actor(node)
	get_tree().node_added.connect(_on_node_added)
	_dash_ready = player.dash_available()

func play(id: String, source: Node3D) -> bool:
	if not is_instance_valid(source): return false
	return play_at(id, source.global_position)

func play_at(id: String, world_position: Vector3) -> bool:
	if session.is_developer_inspection_enabled(): return false
	return sound.play_event(id, world_position)

func _on_reward_claimed(source: Node) -> void:
	if source is ItemReward3D and source.presentation == ItemReward3D.Presentation.CHEST:
		play("world/chest_open", source)

func _on_node_added(node: Node) -> void:
	if session.is_ancestor_of(node): _bind_actor.call_deferred(node)

func _bind_actor(node: Node) -> void:
	if not is_instance_valid(node) or not node is Node3D or not session.is_ancestor_of(node) or node in _actors: return
	if node is HandgunPickup3D:
		node.collected.connect(func(_position: Vector3) -> void: play("pickups/handgun", session.player))
		node.settled.connect(func() -> void: play("world/gun_drop", node))
		_actors.append(node)
	elif node is StompableEnemy3D or node is HandgunEnemy3D:
		node.defeated.connect(func(_position: Vector3) -> void: play("combat/enemy_defeat", node))
		_actors.append(node)
	elif node.get_script() == BOSS:
		node.attack_started.connect(func(attack: StringName) -> void: _on_boss_attack(node, attack))
		node.missile_fired.connect(_on_boss_missile)
		node.landed.connect(func(point: Vector3) -> void: play_at("boss/landing", point))
		node.shoved.connect(func(point: Vector3) -> void: play_at("boss/shove_contact", point))
		node.smoke_vented.connect(func(_point: Vector3) -> void: play("boss/smoke_vent", node))
		node.firebombs_released.connect(func(origin: Vector3) -> void: play_at("boss/firebomb_launch", origin))
		node.phase_changed.connect(func(_phase: int) -> void: play("boss/phase_two", node))
		node.defeated.connect(func(point: Vector3) -> void: play_at("boss/defeat", point))
		_actors.append(node)
	elif node.get_script() == FIRE_PATCH:
		play("boss/firebomb_burst", node)
	elif node.get_script() == PHASE_FLYER:
		# The boss's defeat clears the remaining machines under its own cue.
		node.defeated.connect(func(point: Vector3) -> void:
			if not _boss_defeated(): play_at("boss/flyer_destroyed", point))
		_actors.append(node)
	elif node is HoveringHazard3D or node.get_script() == LIFT:
		_actors.append(node)

func _on_boss_attack(boss: Node3D, attack: StringName) -> void:
	match attack:
		&"missiles": play("boss/launcher_swivel", boss)
		&"jump", &"chase_leap": play("boss/jump_thruster", boss)
		&"space_charge": play("boss/charge", boss)
	# Firebombs sound on release, not when the lob starts.

func _on_boss_missile(missile: Node3D) -> void:
	play("boss/rocket_launch", missile)
	missile.impacted.connect(func(point: Vector3, _normal: Vector3, _collider: Object) -> void:
		play_at("boss/rocket_explosion", point))
	# Rockets free themselves mid-level; never leave a freed one in the typed scan.
	missile.tree_exiting.connect(func() -> void: _actors.erase(missile))
	_actors.append(missile)

func _boss_defeated() -> bool:
	for actor in _actors:
		if is_instance_valid(actor) and actor.get_script() == BOSS and actor.is_defeated(): return true
	return false

func _on_ability(id: StringName) -> void:
	var player := session.player
	if id == PlayerAbility.DASH:
		play("abilities/dash_air" if player.is_dash_airborne() else "abilities/dash_ground", player)
		_dash_ready = false
	else:
		play("abilities/" + str(id), player)

func _on_death(kind: StringName, _position: Vector3) -> void:
	_awaiting_respawn = true
	play("combat/player_death", session.player)
	if kind == PlayerCharacter.DEATH_KIND_WATER and MIX.environment_for(session.player) == &"cave":
		play("world/cave_splash", session.player)
	for loop in _loops.values(): loop.stop()

func _on_player_reset() -> void:
	_dash_ready = session.player.dash_available()
	if _awaiting_respawn:
		_awaiting_respawn = false
		play("combat/player_respawn", session.player)

func _reset_tracking() -> void:
	_states.clear()
	for loop in _loops.values(): loop.stop()

func _physics_process(_delta: float) -> void:
	_requested.clear()
	var player := session.player
	var active := not player.is_dead() and not session.is_developer_inspection_enabled()
	if active:
		if player.dash_available() and not _dash_ready: play("abilities/dash_ready", player)
		_dash_ready = player.dash_available()
		_loop("abilities/wall_slide", player, player.is_wall_sliding())
	for actor: Node3D in _actors.duplicate():
		if not is_instance_valid(actor):
			_actors.erase(actor)
			continue
		var id := actor.get_instance_id()
		var previous: Dictionary = _states.get(id, {})
		var nearby := active and actor.is_visible_in_tree() and actor.global_position.distance_to(player.global_position) < 20.0
		if actor is StompableEnemy3D:
			var attacking: bool = actor.is_attacking()
			var pursuing: bool = actor.is_pursuing()
			if nearby and attacking and not previous.get("attack", false): play("combat/enemy_attack", actor)
			if nearby and pursuing and not previous.get("pursuit", false): play("combat/enemy_notice", actor)
			var moving: bool = actor.is_on_floor() and absf(actor.velocity.x) > 0.1 and not actor.is_defeated()
			var skater: bool = actor.combat == SKATER_PROFILE
			_loop("world/skater_roll", actor, nearby and skater and moving)
			var frame: int = actor.pixel_visual.frame if actor.pixel_visual != null else -1
			if nearby and moving and not skater and not attacking and frame in [0, 3] and frame != previous.get("frame", -1):
				play("world/enemy_step", actor)
			_states[id] = {"attack": attacking, "pursuit": pursuing, "frame": frame}
		elif actor is HandgunEnemy3D:
			if actor is TankEnemy3D:
				_loop("world/tank_tracks", actor, nearby and actor.is_on_floor() and absf(actor.velocity.x) > 0.1 and not actor.is_defeated())
			var warning: bool = actor._state == HandgunEnemy3D.CombatState.TELEGRAPH or actor._holding_notice_pose
			if nearby and warning and not previous.get("warning", false): play("combat/enemy_notice", actor)
			_states[id] = {"warning": warning}
		elif actor.get_script() == BOSS:
			var walking: bool = actor._animation == "walk" and actor.visual.texture == BOSS.SHEETS.walk \
				and actor.is_on_floor() and absf(actor.velocity.x) > 0.1
			var frame: int = actor.visual.frame if walking else -1
			if active and walking and actor._on_screen() and frame in BOSS_STEP_FRAMES and frame != previous.get("frame", -1):
				play("boss/footstep", actor)
			var noticing: bool = actor._noticing
			if active and noticing and not previous.get("notice", false): play("boss/launcher_swivel", actor)
			_states[id] = {"frame": frame, "notice": noticing}
		elif actor.get_script() == BOSS_MISSILE:
			_loop("boss/rocket_flight", actor, active and actor._launched and not actor._expired)
		elif actor is HoveringHazard3D:
			var phase_flyer: bool = actor.get_script() == PHASE_FLYER
			if phase_flyer: _loop("boss/flyer_flight", actor, nearby and actor.is_active())
			else: _loop("world/flyer_hover", actor, nearby)
			var spark: bool = actor.is_discharging()
			if nearby and spark and not previous.get("spark", false): play("world/flyer_spark", actor)
			_states[id] = {"spark": spark}
		elif actor.get_script() == LIFT:
			var moving: bool = actor.is_moving()
			if nearby and moving != previous.get("moving", false):
				play("world/lift_start" if moving else "world/lift_stop", actor.carriage)
			_loop("world/lift_motor", actor.carriage, nearby and moving)
			_states[id] = {"moving": moving}
	for key in _loops.keys():
		if not _requested.has(key):
			_loops[key].stop()
			_loops[key].queue_free()
			_loops.erase(key)

func _loop(id: String, source: Node3D, active: bool) -> void:
	if not active: return
	var bank: Resource = MIX.event_bank_for(id)
	if bank == null or not bank.has_playable_recording(): return
	var key := "%s:%s" % [source.get_instance_id(), id]
	_requested[key] = true
	if not _loops.has(key):
		if _loops.size() >= MAX_LOOPS: return
		var loop := LOOP.new()
		add_child(loop)
		_loops[key] = loop
	_loops[key].sync(id, true, source)

func _on_player_step(contact: Dictionary) -> void:
	var player := session.player
	if not player.is_on_floor() or absf(player.horizontal_speed) < 0.15 or player.is_dashing() or float(contact.age_seconds) > 0.1: return
	if _on_lift(): play("world/lift_step", player)

func _on_player_landed(speed: float) -> void:
	if speed >= 1.5 and _on_lift(): play("world/lift_land", session.player)

func _on_lift() -> bool:
	var player := session.player
	var query := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3.DOWN * 0.8, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return false
	for actor in _actors:
		if is_instance_valid(actor) and actor.get_script() == LIFT and hit.collider == actor.carriage: return true
	return false
