class_name PlayerHandgun3D
extends Node3D
## Owns loaded rounds, reload timing and constrained aim. Reserve ammunition
## is an inventory stack, so pickups and saves share the same source of truth.

signal shot_fired(projectile: HandgunProjectile3D)
signal reload_started
signal reload_finished
signal reload_cancelled
signal active_reload_succeeded

const AMMO_ID: StringName = &"handgun_ammo"
const RELOAD_AUDIO := preload("res://assets/audio/weapons/handgun_reload.wav")
@export var definition: FirearmDefinition
var loaded_rounds := 0
var _reload_voice: AudioStreamPlayer

var _cooldown_remaining := 0.0
var _reload_remaining := 0.0
var _reload_duration := 0.0
var _reload_start_health := 0
var _active_reload_attempted := false
var _active_reload_window := Vector2.ZERO
var _reload_random := RandomNumberGenerator.new()
var mouse_aim_active := false
var aim_direction := Vector3.RIGHT
var crosshair_world := Vector3.ZERO
var _mouse_requested := false
var _mouse_facing_sign := 1.0
## About three source pixels: retain facing while aiming almost vertically.
const MOUSE_FACING_TOLERANCE := 0.13


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_requested = true
	elif event is InputEventJoypadButton and event.pressed:
		_mouse_requested = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.25:
		_mouse_requested = false


func update_mouse_aim(facing_sign: float, target_override: Variant = null) -> void:
	var player := get_parent() as PlayerCharacter
	if player == null or player.pixel_visual == null:
		return
	var visual := player.pixel_visual
	var was_mouse_aim_active := mouse_aim_active
	mouse_aim_active = (
		(_mouse_requested or target_override != null) and player.equipped_weapon_id() == PlayerWeapon.HANDGUN
		and not player.is_dead() and not player.is_transition_running()
		and visual.supports_handgun_aim()
		and not Input.is_action_pressed("aim_up")
	)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		mouse_aim_active = false
	if not mouse_aim_active:
		visual.set_mouse_aim(false, 0.0)
		return
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var hit: Variant = target_override if target_override != null else Plane(Vector3.FORWARD, 0.0).intersects_ray(ray_origin, ray_direction)
	if hit == null:
		mouse_aim_active = false
		visual.set_mouse_aim(false, 0.0)
		return
	var target: Vector3 = hit
	if not was_mouse_aim_active:
		_mouse_facing_sign = facing_sign
	_mouse_facing_sign = mouse_facing_for_target(
		target.x - player.global_position.x, _mouse_facing_sign
	)
	# Aim facing is presentation/firearm state. Locomotion keeps its own facing
	# so retreating fire cannot reverse a dash, wall jump, or knife attack.
	facing_sign = _mouse_facing_sign
	visual._apply_facing(facing_sign > 0.0)
	var shoulder_pixels := visual.handgun_shoulder_pixels()
	var shoulder := visual.global_position + Vector3(shoulder_pixels.x, shoulder_pixels.y, 0) * visual.gun.pixel_size
	shoulder.z = 0
	var delta := target - shoulder
	var local_target := Vector2(delta.x * facing_sign, delta.y)
	# The barrel sits four source pixels above the arm pivot. Account for that
	# height so shots intersect the crosshair rather than running parallel to it.
	var radius := maxf(local_target.length(), 0.0001)
	var angle := clamped_aim_angle(local_target, 4.0 * visual.gun.pixel_size, radius)
	aim_direction = Vector3(cos(angle) * facing_sign, sin(angle), 0)
	visual.set_mouse_aim(true, angle * facing_sign)
	visual.set_weapon_presentation(player.equipped_weapon_id(), player.active_attack_weapon_id(), false)
	var muzzle := visual.handgun_muzzle_world()
	var distance := clampf((target - muzzle).dot(aim_direction), 0.05, definition.projectile_distance)
	crosshair_world = muzzle + aim_direction * distance


static func mouse_facing_for_target(horizontal_distance: float, previous_facing: float) -> float:
	if horizontal_distance > MOUSE_FACING_TOLERANCE:
		return 1.0
	if horizontal_distance < -MOUSE_FACING_TOLERANCE:
		return -1.0
	return previous_facing


static func clamped_aim_angle(target: Vector2, barrel_height: float, radius: float) -> float:
	var angle := atan2(target.y, target.x) - asin(clampf(barrel_height / radius, -1, 1))
	return clampf(angle, -PI / 2.0, PI / 2.0)



func _ready() -> void:
	assert(definition != null, "PlayerHandgun3D requires a FirearmDefinition.")
	assert(
		definition.validation_errors().is_empty(),
		"Player handgun definition is invalid:\n%s"
		% "\n".join(definition.validation_errors())
	)
	add_to_group("run_resettable")
	_reload_random.randomize()
	_reload_voice = AudioStreamPlayer.new()
	_reload_voice.stream = RELOAD_AUDIO
	_reload_voice.volume_db = -12.0
	add_child(_reload_voice)
	reload_started.connect(_reload_voice.play)
	reload_cancelled.connect(_reload_voice.stop)
	reload_finished.connect(_reload_voice.stop)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not is_reloading():
		return
	if _reload_interrupted():
		cancel_reload()
		return
	_reload_remaining = maxf(0.0, _reload_remaining - delta)
	var elapsed := _reload_duration - _reload_remaining
	# One brief pull-in/tilt/return. The bar continues for the full reload.
	var gesture_duration := minf(0.4, _reload_duration * 0.5)
	var phase := elapsed / gesture_duration
	var weight := smoothstep(0.0, 0.3, phase) * (1.0 - smoothstep(0.5, 1.0, phase))
	var player := get_parent() as PlayerCharacter
	player.pixel_visual.set_reload_gesture(weight if is_reloading() else 0.0)
	if not is_reloading():
		_finish_reload()


func _reload_interrupted() -> bool:
	var player := get_parent() as PlayerCharacter
	return (player == null or player.is_dead() or player.is_control_locked() or player.is_transition_running()
		or player.equipped_weapon_id() != PlayerWeapon.HANDGUN
		or player.health.current < _reload_start_health or player.healing_remaining > 0.0)


func start_reload() -> bool:
	var player := get_parent() as PlayerCharacter
	if (definition == null or is_reloading() or is_recovering() or player == null or get_tree().paused
		or loaded_rounds >= definition.magazine_capacity or reserve_rounds() <= 0
		or player.is_dead() or player.is_control_locked() or player.is_transition_running() or player.is_attacking()
		or player.equipped_weapon_id() != PlayerWeapon.HANDGUN
		or player.healing_remaining > 0.0):
		return false
	_reload_duration = definition.reload_duration
	_reload_remaining = definition.reload_duration
	_reload_start_health = player.health.current
	_active_reload_attempted = false
	var window_start := _reload_random.randf_range(definition.active_reload_earliest, definition.active_reload_latest)
	_active_reload_window = Vector2(window_start, window_start + definition.active_reload_window)
	player.pixel_visual.set_reload_gesture(0.0)
	reload_started.emit()
	return true


func try_active_reload() -> bool:
	if get_tree().paused or not is_reloading() or _active_reload_attempted:
		return false
	# Damage or switching on this frame must still interrupt before a timed press.
	if _reload_interrupted():
		cancel_reload()
		return false
	_active_reload_attempted = true
	var elapsed := _reload_duration - _reload_remaining
	if elapsed < _active_reload_window.x or elapsed > _active_reload_window.y:
		return false
	_finish_reload()
	active_reload_succeeded.emit()
	return true


func active_reload_window() -> Vector2:
	return _active_reload_window


func active_reload_available() -> bool:
	return is_reloading() and not _active_reload_attempted and (
		_reload_duration - _reload_remaining <= _active_reload_window.y
	)


func _finish_reload() -> void:
	_reload_remaining = 0.0
	var player := get_parent() as PlayerCharacter
	player.pixel_visual.set_reload_gesture(0.0)
	var transfer := mini(definition.magazine_capacity - loaded_rounds, reserve_rounds())
	if transfer > 0 and player.inventory.consume(AMMO_ID, transfer):
		loaded_rounds += transfer
	reload_finished.emit()


func cancel_reload() -> void:
	var was_reloading := is_reloading()
	_reload_remaining = 0.0
	_active_reload_attempted = false
	var player := get_parent() as PlayerCharacter
	if player != null and is_instance_valid(player.pixel_visual):
		player.pixel_visual.set_reload_gesture(0.0)
	if was_reloading:
		reload_cancelled.emit()


func is_reloading() -> bool:
	return _reload_remaining > 0.0


func reload_progress() -> float:
	return clampf(1.0 - _reload_remaining / _reload_duration, 0.0, 1.0) if _reload_duration > 0.0 else 0.0


func is_recovering() -> bool:
	return _cooldown_remaining > 0.0


func can_fire() -> bool:
	var player := get_parent() as PlayerCharacter
	return definition != null and not is_recovering() and not is_reloading() and loaded_rounds > 0 \
		and (player == null or not player.is_control_locked())


func try_empty_trigger() -> bool:
	if definition == null or loaded_rounds != 0 or is_reloading() or is_recovering():
		return false
	# An empty pull has the same cadence as a shot, even if its audio is muted.
	_cooldown_remaining = definition.fire_interval
	return true


func reserve_rounds() -> int:
	var player := get_parent() as PlayerCharacter
	return player.inventory.count(AMMO_ID) if player != null else 0


func set_loaded_rounds(amount: int) -> void:
	cancel_reload()
	loaded_rounds = clampi(amount, 0, definition.magazine_capacity)


func grant_initial_ammo(total: int) -> void:
	set_loaded_rounds(mini(maxi(total, 0), definition.magazine_capacity))
	var reserve := maxi(0, total - loaded_rounds)
	if reserve > 0:
		(get_parent() as PlayerCharacter).inventory.add(AMMO_ID, reserve)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload") and not event.is_echo():
		if is_reloading():
			try_active_reload()
		else:
			start_reload()
		get_viewport().set_input_as_handled()


func fire(
	facing_sign: float,
	aim_up: bool,
	source: CollisionObject3D
) -> HandgunProjectile3D:
	if not can_fire() or source == null:
		return null
	var projectile := definition.projectile_scene.instantiate() as HandgunProjectile3D
	assert(
		projectile != null,
		"%s must instantiate HandgunProjectile3D." % definition.weapon_id
	)
	var session := _find_level_session(source)
	if session == null:
		projectile.free()
		push_error("PlayerHandgun3D requires PlayerCharacter inside LevelSession3D.")
		return null

	session.add_child(projectile)
	update_mouse_aim(facing_sign)
	var visual := source.get_node_or_null("PixelVisual") as PixelPlayerVisual3D
	if visual != null and not mouse_aim_active:
		visual._apply_facing(facing_sign > 0.0)
		visual.set_weapon_presentation(PlayerWeapon.HANDGUN, PlayerWeapon.HANDGUN, aim_up)
	projectile.global_position = source.global_position + definition.muzzle_offset(facing_sign, aim_up)
	if visual != null:
		projectile.global_position = visual.handgun_muzzle_world()
	projectile.damage = definition.damage
	projectile.speed = definition.projectile_speed
	projectile.maximum_distance = definition.projectile_distance
	projectile.launch(aim_direction if mouse_aim_active else definition.shot_direction(facing_sign, aim_up), source)
	loaded_rounds -= 1
	_cooldown_remaining = definition.fire_interval
	shot_fired.emit(projectile)
	return projectile


func reset_run() -> void:
	cancel_reload()
	_cooldown_remaining = 0.0


func cooldown_remaining() -> float:
	return _cooldown_remaining


func _find_level_session(source: Node) -> LevelSession3D:
	var candidate: Node = source
	while candidate != null:
		if candidate is LevelSession3D:
			return candidate as LevelSession3D
		candidate = candidate.get_parent()
	return null


func is_retreating(horizontal_motion: float) -> bool:
	return mouse_aim_active and horizontal_motion * _mouse_facing_sign < -0.01
