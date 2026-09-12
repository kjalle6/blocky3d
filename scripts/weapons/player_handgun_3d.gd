class_name PlayerHandgun3D
extends Node3D
## Player-owned firing component. Weapon ownership and ammo policy belong to
## the session/player layer. This node resolves constrained mouse aim and
## launches the configured projectile from the matching visual muzzle.

signal shot_fired(projectile: HandgunProjectile3D)

@export var definition: FirearmDefinition

var _cooldown_remaining := 0.0
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


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)


func can_fire() -> bool:
	return definition != null and _cooldown_remaining <= 0.0


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
	projectile.speed = definition.projectile_speed
	projectile.maximum_distance = definition.projectile_distance
	projectile.launch(aim_direction if mouse_aim_active else definition.shot_direction(facing_sign, aim_up), source)
	_cooldown_remaining = definition.fire_interval
	shot_fired.emit(projectile)
	return projectile


func reset_run() -> void:
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
