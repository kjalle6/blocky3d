extends PixelHandgunEnemyVisual3D
## Native Green Zone enemy 6 sheets; shot frame and barrel stay aligned.
const TANK_TEXTURES := {
	&"idle": preload("res://assets/art/green_zone/enemies/tank/Idle.png"),
	&"walk": preload("res://assets/art/green_zone/enemies/tank/Walk.png"),
	&"telegraph": preload("res://assets/art/green_zone/enemies/tank/Walk.png"),
	&"attack": preload("res://assets/art/green_zone/enemies/tank/Attack.png"),
	&"death": preload("res://assets/art/green_zone/enemies/tank/Death.png"),
}
const FIRE_TIME := 0.09
const ATTACK_TIME := 0.36
var _aim_direction := Vector3.RIGHT
var _barrel_pivot: Node3D
var _barrel: Sprite3D
var _muzzle_flash: Sprite3D
var _elevated_material: ShaderMaterial

func _ready() -> void:
	_rest_position = position
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_elevated_barrel()
	set_state(&"idle", true)

func tick(delta: float, next_state: StringName, facing_right: bool) -> void:
	if next_state == &"idle" and absf(get_parent().velocity.x) > 0.01:
		next_state = &"walk"
	set_state(next_state)
	_elapsed += delta
	_face(facing_right)
	if _state == &"attack":
		frame = mini(3, floori(_elapsed / 0.09))
		if _elapsed >= FIRE_TIME and _shot_step < 0:
			_shot_step = 0
			shot_frame_reached.emit()
		if _elapsed >= ATTACK_TIME:
			set_state(&"telegraph", true)
	else:
		frame = mini(3, floori(_elapsed * 8.0)) if _state == &"death" else floori(_elapsed * 8.0) % 4
	if not _impact_flashing:
		modulate = Color(1.0, 1.2, 1.25) if _state == &"telegraph" and fmod(_elapsed, 0.2) < 0.1 else Color.WHITE
	_update_elevated_pose()

func set_state(next_state: StringName, force := false) -> void:
	if not force and next_state == _state: return
	_state = next_state
	_elapsed = 0.0
	_shot_step = -1
	texture = TANK_TEXTURES[next_state]
	hframes = 4
	frame = 0
	if _barrel_pivot != null: _update_elevated_pose()

func set_aim_direction(direction: Vector3, facing_right: bool) -> void:
	if not is_shot_playing():
		_aim_direction = direction.normalized()
		_face(facing_right)
		_update_elevated_pose()

func begin_shot(direction: Vector3, facing_right: bool) -> void:
	_aim_direction = direction.normalized()
	set_state(&"attack", true)
	_face(facing_right)
	_update_elevated_pose()

func _face(facing_right: bool) -> void:
	flip_h = not facing_right
	position.x = 0.32 if facing_right else -0.32

func muzzle_world_position(_gun_index: int) -> Vector3:
	if _aim_direction.y > 0.15:
		return aim_pivot_world_position(not flip_h) + _aim_direction * 0.4
	return to_global(Vector3(4.0 * (-1.0 if flip_h else 1.0), -4.0, 0.0) * pixel_size)

func aimed_muzzle_world_position(_gun_index: int, direction: Vector3, facing_right: bool) -> Vector3:
	if direction.y > 0.15:
		return aim_pivot_world_position(facing_right) + direction.normalized() * 0.4
	return get_parent().global_position + Vector3(0.48 * (1.0 if facing_right else -1.0), position.y - 0.16, position.z)

func aim_pivot_world_position(facing_right: bool) -> Vector3:
	return get_parent().global_position + Vector3(0.2 * (1.0 if facing_right else -1.0), position.y - 0.24, position.z)

func reset_feedback() -> void:
	super()
	_aim_direction = Vector3.RIGHT
	if _barrel_pivot != null: _update_elevated_pose()

func _build_elevated_barrel() -> void:
	_elevated_material = ShaderMaterial.new()
	_elevated_material.shader = preload("res://scripts/presentation/tank_elevated_body.gdshader")
	_barrel_pivot = Node3D.new()
	_barrel_pivot.name = "ElevatedBarrel"
	add_child(_barrel_pivot)
	_barrel = Sprite3D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = TANK_TEXTURES[&"idle"]
	atlas.region = Rect2(21, 27, 11, 6)
	_barrel.texture = atlas
	_barrel.pixel_size = pixel_size
	_barrel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_barrel.shaded = false
	_barrel.position = Vector3(0.22, 0, 0.02)
	_barrel_pivot.add_child(_barrel)
	_muzzle_flash = Sprite3D.new()
	_muzzle_flash.texture = preload("res://assets/art/green_zone/effects/player_handgun_shot_horizontal.png")
	_muzzle_flash.hframes = 6
	_muzzle_flash.pixel_size = pixel_size
	_muzzle_flash.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_muzzle_flash.shaded = false
	_muzzle_flash.offset = Vector2(24, 0)
	_muzzle_flash.position = Vector3(0.4, 0, 0.04)
	_barrel_pivot.add_child(_muzzle_flash)

func _update_elevated_pose() -> void:
	var elevated := _aim_direction.y > 0.15 and _state != &"death"
	_barrel_pivot.visible = elevated
	material_override = _elevated_material if elevated else null
	if not elevated:
		texture = TANK_TEXTURES[_state]
		return
	# Keep the body upright and animate its tracks; rotate only the source barrel.
	texture = TANK_TEXTURES[&"walk"] if absf(get_parent().velocity.x) > 0.01 else TANK_TEXTURES[&"idle"]
	_elevated_material.set_shader_parameter("sprite_sheet", texture)
	_barrel_pivot.position = Vector3(0.12 if flip_h else -0.12, -0.24, 0.02)
	_barrel_pivot.rotation.z = atan2(_aim_direction.y, _aim_direction.x)
	_barrel.modulate = modulate
	_muzzle_flash.visible = _state == &"attack" and _elapsed >= FIRE_TIME and _elapsed < FIRE_TIME + 0.08
