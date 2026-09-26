class_name TankEnemy3D
extends HandgunEnemy3D
## The brain retaliates against stomps independently of its shell firing cycle.

signal psychic_pulsed(origin: Vector3, player: PlayerCharacter, duration: float)

const NAVIGATION := preload("res://scripts/enemies/ground_enemy_navigation.gd")
@export_range(0.1, 10.0, 0.1) var patrol_speed := 1.25
@export_range(0.0, 50.0, 0.1) var patrol_left_distance := 5.76
@export_range(0.0, 50.0, 0.1) var patrol_right_distance := 5.76
@export var landing_gate_path: NodePath
@export var climb_encounter_path: NodePath
@export_range(0, 999, 1) var ammo_reward := 30
@export_range(1, 100, 1) var psychic_damage := 25
@export_range(0.1, 1.0, 0.05) var psychic_freeze_duration := 0.7
@export_range(0.1, 10.0, 0.1) var psychic_retreat_speed := 2.0
@export_range(1.0, 8.0, 0.1) var fighting_distance := 4.0
var _patrol_sign := -1.0
var _landed_in_arena := false
var _brain_contact_player: PlayerCharacter
var _psychic_retreat_remaining := 0.0
var _pursuing := false
var _returning := false

func _ready() -> void:
	super()
	_patrol_sign = 1.0 if starts_facing_right else -1.0
	add_to_group("persistent_enemy")
	defeated.connect(_on_tank_defeated)

func _settle_velocity(delta: float) -> void:
	super(delta)
	if _defeated: return
	_psychic_retreat_remaining = maxf(0.0, _psychic_retreat_remaining - delta)
	# One pulse per landing; clear only after the player leaves the head area.
	if is_instance_valid(_brain_contact_player):
		var feet := _brain_contact_player.feet_world_y()
		var head := global_position.y + stomp_head_height
		if _brain_contact_player.is_dead() or absf(_brain_contact_player.global_position.x - global_position.x) > 1.25 or feet > head + 0.4 or feet < head - 0.65:
			_brain_contact_player = null
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if _pursuing and (not _engagement_enabled or player == null or player.is_dead() or not _inside_encounter(player)):
		_end_pursuit()
	if not _pursuing and _can_notice(player):
		_pursuing = true
		_returning = false
		_landed_in_arena = true
	if _psychic_retreat_remaining > 0.0:
		if is_on_floor() and not NAVIGATION.can_step(self, _patrol_sign):
			_patrol_sign *= -1.0
		if NAVIGATION.can_step(self, _patrol_sign):
			velocity.x = psychic_retreat_speed * _patrol_sign
		return
	if _pursuing:
		var distance_x := player.global_position.x - global_position.x
		if absf(distance_x) >= 0.1 and not pixel_visual.is_shot_playing():
			_facing_sign = signf(distance_x)
		var climbing := _player_is_climbing(player)
		if climbing:
			distance_x = _climb_encounter().firing_position().x - global_position.x
		if absf(distance_x) <= (0.12 if climbing else fighting_distance): return
		_patrol_sign = signf(distance_x)
		if not NAVIGATION.can_step(self, _patrol_sign) or _terrain_wall_ahead(_patrol_sign):
			if not climbing: _end_pursuit()
			return
		# Crates may stop the body, but keep shooting to break a way through.
		velocity.x = patrol_speed * _patrol_sign
		return
	if _returning:
		var home_distance := _initial_transform.origin.x - global_position.x
		if absf(home_distance) > patrol_speed * delta + 0.05:
			_patrol_sign = signf(home_distance)
			if NAVIGATION.can_step(self, _patrol_sign) and not _terrain_wall_ahead(_patrol_sign):
				velocity.x = patrol_speed * _patrol_sign
			return
		_returning = false
	var left := _initial_transform.origin.x - patrol_left_distance
	var right := _initial_transform.origin.x + patrol_right_distance
	if patrol_left_distance > 0.0 and global_position.x <= left: _patrol_sign = 1.0
	elif patrol_right_distance > 0.0 and global_position.x >= right: _patrol_sign = -1.0
	if is_on_floor() and (is_on_wall() or not NAVIGATION.can_step(self, _patrol_sign)):
		_patrol_sign *= -1.0
	velocity.x = patrol_speed * _patrol_sign
	if _state == CombatState.IDLE:
		_facing_sign = _patrol_sign

func _can_notice(player: PlayerCharacter) -> bool:
	if player == null or player.is_dead() or not _engagement_enabled or not _inside_encounter(player): return false
	if not NAVIGATION.is_on_camera(self): return false
	if _player_is_climbing(player):
		return global_position.distance_to(player.global_position) <= projectile_distance and NAVIGATION.can_reach(self, _climb_encounter().firing_position().x, true)
	if not super._can_engage(player): return false
	if not _landed_in_arena:
		var gate: Node3D = null if landing_gate_path.is_empty() else get_node_or_null(landing_gate_path) as Node3D
		if gate != null and player.global_position.x < gate.global_position.x: return false
		if not player.is_on_floor(): return false
	return NAVIGATION.can_reach(self, player.global_position.x, true)

func _can_engage(player: PlayerCharacter) -> bool:
	# Acquisition range and the arrival gate do not repeatedly switch combat off.
	if not _pursuing or not _engagement_enabled or player == null or player.is_dead() or not _inside_encounter(player): return false
	# The already-seen tank can keep sending shells up its authored shaft after
	# the camera follows the climber. It cannot acquire a new target off screen.
	var camera := get_viewport().get_camera_3d()
	var visible_climber := _player_is_climbing(player) and (camera == null or (
		not camera.is_position_behind(player.global_position)
		and get_viewport().get_visible_rect().has_point(camera.unproject_position(player.global_position))))
	var visible_fight := NAVIGATION.is_on_camera(self) or visible_climber
	return visible_fight and global_position.distance_to(player.global_position) <= projectile_distance

func _climb_encounter() -> Node3D:
	return null if climb_encounter_path.is_empty() else get_node_or_null(climb_encounter_path) as Node3D

func _inside_encounter(player: PlayerCharacter) -> bool:
	var encounter := _climb_encounter()
	return encounter.contains_player(player) if encounter != null else NAVIGATION.is_on_camera(self)

func _player_is_climbing(player: PlayerCharacter) -> bool:
	var encounter := _climb_encounter()
	return encounter != null and encounter.is_climbing(player)

func _face_player(_player: PlayerCharacter) -> void:
	pixel_visual.set_aim_direction(_resolve_shot_direction(), _facing_sign > 0.0)

func is_pursuing() -> bool:
	return _pursuing

func _end_pursuit() -> void:
	_pursuing = false
	_returning = true
	_return_to_idle()

func _terrain_wall_ahead(direction: float) -> bool:
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		if contact.get_normal().x * direction > -0.7: continue
		var body := contact.get_collider() as Node
		if body != null and (body.is_in_group("breakable_cover") or body.is_in_group("melee_target") or body.is_in_group("player_character")): continue
		return true
	return false

func _resolve_shot_direction() -> Vector3:
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player != null:
		var offset := player.global_position - global_position
		if absf(offset.x) > 0.1: _facing_sign = signf(offset.x)
		if _player_is_climbing(player):
			var pivot: Vector3 = pixel_visual.aim_pivot_world_position(_facing_sign > 0.0)
			return Vector3(player.global_position.x - pivot.x, maxf(0.0, player.global_position.y - pivot.y), 0).normalized()
	# Preserve the clearing's jump-over-horizontal-shell rhythm.
	return Vector3.RIGHT * _facing_sign

func projectiles_per_fire_beat() -> int:
	return 1

func fire_beat_count() -> int:
	return 1

func receive_stomp(player: PlayerCharacter) -> void:
	if _defeated or player.is_dead() or _brain_contact_player == player: return
	var hit := CombatHit.new(psychic_damage, &"psychic", global_position)
	if not player.receive_psychic_hit(global_position, hit, psychic_freeze_duration): return
	_brain_contact_player = player
	# A modest burst clears the suspended player before control returns.
	var away := global_position.x - player.global_position.x
	if absf(away) > 0.05:
		_patrol_sign = signf(away)
	var clearance := psychic_retreat_speed * psychic_freeze_duration
	var left_room := global_position.x - (_initial_transform.origin.x - patrol_left_distance) if patrol_left_distance > 0.0 and not _pursuing else INF
	var right_room := (_initial_transform.origin.x + patrol_right_distance) - global_position.x if patrol_right_distance > 0.0 and not _pursuing else INF
	if _patrol_sign > 0.0 and right_room < clearance and left_room > right_room:
		_patrol_sign = -1.0
	elif _patrol_sign < 0.0 and left_room < clearance and right_room > left_room:
		_patrol_sign = 1.0
	if not NAVIGATION.can_step(self, _patrol_sign, clearance):
		_patrol_sign *= -1.0
	_pursuing = true
	_returning = false
	_landed_in_arena = true
	_psychic_retreat_remaining = psychic_freeze_duration
	psychic_pulsed.emit(global_position + Vector3(0, stomp_head_height, 0), player, psychic_freeze_duration)

func receive_melee_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	if _defeated: return false
	if hit == null:
		hit = CombatHit.new(preload("res://resources/combat/knife.tres").damage, &"knife", source_position)
	if hit.kind == &"stomp": return false
	if not health.damage(hit): return false
	if health.current == 0:
		_sequence_shots_remaining = 0
		_defeat(source_position, null)
	else:
		# Do not change attack state, timers, velocity, or animation on a hit.
		play_impact_flash()
		var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
		if hit.kind in [&"knife", &"bullet"] and player != null and _inside_encounter(player) and NAVIGATION.is_on_camera(self):
			_pursuing = true
			_returning = false
			_landed_in_arena = true
	return true

func reset_run() -> void:
	super()
	_patrol_sign = 1.0 if starts_facing_right else -1.0
	_landed_in_arena = false
	_brain_contact_player = null
	_psychic_retreat_remaining = 0.0
	_pursuing = false
	_returning = false
	_restore_saved_defeat()

func _session() -> LevelSession3D:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is LevelSession3D:
		ancestor = ancestor.get_parent()
	return ancestor as LevelSession3D

func _on_tank_defeated(_position: Vector3) -> void:
	_pursuing = false
	var session := _session()
	if session == null or session.save_state == null: return
	session.save_state.mark_world_flag("tank_defeated/" + session.save_state.source_id(self))
	if ammo_reward > 0 and session.save_state.claim_reward(self, &"handgun_ammo", ammo_reward):
		session.item_received.emit(&"handgun_ammo", ammo_reward)

func _restore_saved_defeat() -> void:
	var session := _session()
	if session == null or session.save_state == null: return
	if not session.save_state.world_flags.get("tank_defeated/" + session.save_state.source_id(self), false): return
	_defeated = true
	_state = CombatState.DEFEATED
	health.reset(combat.maximum_hp, 0)
	body_collision.set_deferred("disabled", true)
	contact_collision.set_deferred("disabled", true)
	hide()
	set_physics_process(false)
