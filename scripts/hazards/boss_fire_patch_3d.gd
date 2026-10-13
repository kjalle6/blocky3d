extends Area3D
## A burning patch left by the Green Zone boss's firebombs. It denies the spot it
## lands on for burn_time seconds. Standing in it costs a hit every
## CONTACT_INTERVAL; the only way to put it out is to land on it from the air,
## which costs the same hit. Avoiding fire is the right answer.
## Native 4 cm pixels throughout: the fire grows and dies by revealing more or
## fewer rows of the source strip, never by scaling. Shorter flames at both ends
## let the patch taper instead of ending in a cut.

## A landing put the fire out (burning out on its own stays silent).
signal smothered(world_position: Vector3)

const FRAMES: Array[Texture2D] = [
	preload("res://assets/art/vfx/boss/ground_fire_1.png"),
	preload("res://assets/art/vfx/boss/ground_fire_2.png"),
	preload("res://assets/art/vfx/boss/ground_fire_3.png"),
	preload("res://assets/art/vfx/boss/ground_fire_4.png"),
]
const SMOKE: Array[Texture2D] = [
	preload("res://assets/art/vfx/boss/smoke_puff_a.png"),
	preload("res://assets/art/vfx/boss/smoke_puff_b.png"),
	preload("res://assets/art/vfx/boss/smoke_puff_c.png"),
]
## Seconds between hits while the player stays in the fire.
const CONTACT_INTERVAL := 1.0
const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const PIXEL := 0.04
const STRIP_WIDTH := 192
const STRIP_HEIGHT := 32
const CAP_PIXELS := 12
const CAP_ROWS := 19
const FRAME_RATE := 9.0
const IGNITE_TIME := 0.3
const DIE_TIME := 0.8
const WARNING_TIME := 3.0
## Contact only counts once the flames are this far up.
const LETHAL_GROWTH := 0.6

var width_pixels := 96
var burn_time := 30.0
var damage := 25
var strip_offset := 0
var _elapsed := 0.0
var _phase := 0.0
var _next_contact := 0.0
var _player_was_airborne := false
var _sprites: Array[Sprite3D] = []
var _atlases: Array[AtlasTexture] = []


static func spawn(parent: Node, surface_point: Vector3, width_m: float, seconds: float,
		hit_damage: int, variant: int) -> Area3D:
	var patch = new()
	patch.width_pixels = clampi(roundi(width_m / PIXEL), CAP_PIXELS * 2 + 8, STRIP_WIDTH)
	patch.burn_time = seconds
	patch.damage = hit_damage
	patch.strip_offset = posmod(variant * 37, STRIP_WIDTH - patch.width_pixels + 1)
	patch._phase = float(posmod(variant * 5, 4)) / FRAME_RATE
	parent.add_child(patch)
	patch.global_position = Vector3(surface_point.x, surface_point.y, 0)
	return patch


func _ready() -> void:
	add_to_group("run_resettable")
	add_to_group("enemy_projectile")
	add_to_group("boss_fire")
	collision_layer = 0
	collision_mask = 3
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(width_pixels * PIXEL - 0.16, 0.8, 1.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.4
	add_child(collision)
	for index in 3:
		var atlas := AtlasTexture.new()
		var sprite := Sprite3D.new()
		sprite.texture = atlas
		sprite.pixel_size = PIXEL
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.render_priority = 9
		add_child(sprite)
		_atlases.append(atlas)
		_sprites.append(sprite)
	_update_visual()


func is_burning() -> bool:
	return _elapsed < burn_time


func width_metres() -> float:
	return width_pixels * PIXEL


func reset_run() -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_next_contact = maxf(0.0, _next_contact - delta)
	if _elapsed >= burn_time + DIE_TIME:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player != null:
		# A landing is the frame the player goes from airborne to grounded.
		var landed := _player_was_airborne and player.is_on_floor()
		_player_was_airborne = not player.is_on_floor()
		if _growth() >= LETHAL_GROWTH and _touches(player):
			if landed:
				_stomp_out(player)
				return
			# Standing in it burns; passing through the flames in the air does not,
			# so landing on it costs exactly one hit.
			if _next_contact <= 0.0 and player.is_on_floor() and _hurt(player):
				_next_contact = CONTACT_INTERVAL
	_update_visual()


func _touches(player: PlayerCharacter) -> bool:
	if overlaps_body(player):
		return true
	for area in get_overlapping_areas():
		if area.get_parent() == player:
			return true
	return false


func _hurt(player: PlayerCharacter) -> bool:
	# A fresh hit each time: damage deduplication would reject a reused one.
	return player.receive_enemy_hit(global_position, CombatHit.new(damage, &"boss_fire", global_position))


## Landing on the fire smothers it, at the same cost as standing in it.
func _stomp_out(player: PlayerCharacter) -> void:
	_hurt(player)
	# A billow of smoke across the patch, at the boss effects' actor scale and
	# slow enough to read as the fire being smothered.
	var half := width_pixels * PIXEL * 0.5
	for index in 3:
		var x := lerpf(-half * 0.65, half * 0.65, index * 0.5)
		var puff = EFFECT.spawn(get_parent(), global_position + Vector3(x, 0.7 + 0.2 * (index % 2), 0),
			SMOKE[index], 48, 0.06)
		puff.frame_rate = 8.0 + index
	smothered.emit(global_position)
	queue_free()


func _growth() -> float:
	if _elapsed < IGNITE_TIME:
		return smoothstep(0.0, IGNITE_TIME, _elapsed)
	if _elapsed > burn_time:
		return 1.0 - smoothstep(burn_time, burn_time + DIE_TIME, _elapsed)
	return 1.0


func _update_visual() -> void:
	var growth := _growth()
	var texture: Texture2D = FRAMES[int((_elapsed + _phase) * FRAME_RATE) % FRAMES.size()]
	var warning := _elapsed > burn_time - WARNING_TIME and _elapsed <= burn_time
	var alpha := 0.55 if warning and fmod(_elapsed, 0.3) < 0.12 else 1.0
	var middle := width_pixels - CAP_PIXELS * 2
	var left := -width_pixels * 0.5
	var pieces := [
		[0, CAP_PIXELS, CAP_ROWS],
		[CAP_PIXELS, middle, STRIP_HEIGHT],
		[CAP_PIXELS + middle, CAP_PIXELS, CAP_ROWS],
	]
	for index in 3:
		var start: int = pieces[index][0]
		var columns: int = pieces[index][1]
		var rows := roundi(float(pieces[index][2]) * growth)
		var sprite := _sprites[index]
		sprite.visible = rows > 0
		if rows <= 0:
			continue
		_atlases[index].atlas = texture
		_atlases[index].region = Rect2(strip_offset + start, STRIP_HEIGHT - rows, columns, rows)
		sprite.position = Vector3((left + start + columns * 0.5) * PIXEL, rows * PIXEL * 0.5, 1.12)
		sprite.modulate = Color(1, 1, 1, alpha)
