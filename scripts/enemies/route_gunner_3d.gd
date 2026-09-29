extends HandgunEnemy3D
## Ordinary dual-pistol enemy for authored routes. Walking, taking aim and
## firing are separate readable beats; the introductory gunner stays unchanged.
const NAVIGATION := preload("res://scripts/enemies/ground_enemy_navigation.gd")
@export var mobile := true
@export_range(0.1, 10.0, 0.1) var patrol_speed := 2.6
@export_range(0.0, 50.0, 0.32) var patrol_left_distance := 5.12
@export_range(0.0, 50.0, 0.32) var patrol_right_distance := 5.12
@export_range(0, 999, 1) var ammo_reward := 6
@export var preferred_firing_distance := 6.0
var _pursuing := false
var _patrol_sign := -1.0
var _burst_direction := Vector3.LEFT

func _ready() -> void:
	super()
	_patrol_sign = _facing_sign
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self): return
	add_to_group("persistent_enemy")
	defeated.connect(_on_route_defeated)

func is_route_gunner() -> bool:
	return true

func is_pursuing() -> bool:
	return _pursuing

func _idle_visual_state() -> StringName:
	return &"walk" if absf(velocity.x) > 0.1 else &"idle"

func _target_in_route(player: PlayerCharacter) -> bool:
	return (super._can_engage(player) and NAVIGATION.is_on_camera(self)
		and absf(player.global_position.x - _initial_transform.origin.x) <= detection_range + patrol_left_distance + patrol_right_distance)

func _settle_velocity(delta: float) -> void:
	super(delta)
	if _defeated or not _engagement_enabled: return
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	var sees_player := _target_in_route(player)
	if _pursuing and not sees_player:
		_pursuing = false
		# A volley cannot continue firing from outside the camera.
		_return_to_idle()
	if sees_player: _pursuing = true
	if not mobile or _state != CombatState.IDLE or not is_on_floor(): return
	if _pursuing:
		var offset := player.global_position.x - global_position.x
		_patrol_sign = signf(offset)
		if absf(offset) <= preferred_firing_distance: return
	else:
		var left := _initial_transform.origin.x - patrol_left_distance
		var right := _initial_transform.origin.x + patrol_right_distance
		if patrol_left_distance > 0 and global_position.x <= left: _patrol_sign = 1.0
		elif patrol_right_distance > 0 and global_position.x >= right: _patrol_sign = -1.0
	if NAVIGATION.can_step(self, _patrol_sign) and not is_on_wall():
		velocity.x = _patrol_sign * patrol_speed
		_facing_sign = _patrol_sign
	else:
		_patrol_sign *= -1.0

func _can_engage(player: PlayerCharacter) -> bool:
	if not _target_in_route(player): return false
	# Close distance before taking aim, but fire across an obstacle instead of
	# endlessly walking into it. The projectile still collides with real cover.
	return not mobile or absf(player.global_position.x - global_position.x) <= preferred_firing_distance or not NAVIGATION.can_step(self, signf(player.global_position.x - global_position.x))

func _begin_volley() -> void:
	_burst_direction = super._resolve_shot_direction()
	super()

func _resolve_shot_direction() -> Vector3:
	return _burst_direction if _state == CombatState.FIRING else super._resolve_shot_direction()

func reset_run() -> void:
	super()
	_pursuing = false
	_patrol_sign = _facing_sign
	_restore_saved_defeat()

func _session() -> LevelSession3D:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is LevelSession3D:
		ancestor = ancestor.get_parent()
	return ancestor as LevelSession3D

func _on_route_defeated(_position: Vector3) -> void:
	_pursuing = false
	var session := _session()
	if session == null or session.save_state == null: return
	session.save_state.mark_world_flag("gunner_defeated/" + session.save_state.source_id(self))
	if ammo_reward > 0 and session.save_state.claim_reward(self, &"handgun_ammo", ammo_reward):
		session.item_received.emit(&"handgun_ammo", ammo_reward)

func _restore_saved_defeat() -> void:
	var session := _session()
	if session == null or session.save_state == null: return
	if not session.save_state.world_flags.get("gunner_defeated/" + session.save_state.source_id(self), false): return
	_defeated = true
	_state = CombatState.DEFEATED
	health.reset(combat.maximum_hp, 0)
	body_collision.set_deferred("disabled", true)
	contact_collision.set_deferred("disabled", true)
	hide()
	set_physics_process(false)
