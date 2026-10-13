extends Area3D
## A steel door set in a one-tile wall notch, drawn front-on like a shutter.
## The boss pit's exit opens only to a planted warhead: the charge blinks faster
## through a short fuse, blows, and the panels retract.

signal opened
## The planted charge went off; the panels start to retract.
signal blown

enum State { SEALED, ARMED, OPENING, OPEN }

const DOOR := preload("res://assets/art/world_scenery/environment/structures/doors_and_portals/1 Doors/5.png")
const CHARGE := preload("res://assets/art/vfx/boss/warhead.png")
const EXPLOSION := preload("res://assets/art/vfx/boss/explosion.png")
const SMOKE := preload("res://assets/art/vfx/boss/smoke_puff_b.png")
const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const PIXEL := 0.04
## The notch the door closes, in metres; the art overhangs it upward.
const NOTCH := Vector2(1.28, 1.28)
const FRAMES := 6
## The drawn door is 28 px wide at the left of each 32 px cell.
const ART_SHIFT_X := 2

@export_range(0.3, 5.0, 0.05) var fuse_time := 1.6
@export_range(2.0, 30.0, 0.5) var frame_rate := 12.0

var state := State.SEALED
var _time := 0.0
var _door: Sprite3D
var _charge: Sprite3D
var _seal: CollisionShape3D


func _ready() -> void:
	add_to_group("run_resettable")
	collision_layer = 0
	collision_mask = 3
	monitorable = false
	# The arming reach is a little wider than the notch, so standing against
	# the sealed door counts.
	var reach := BoxShape3D.new()
	reach.size = Vector3(NOTCH.x + 0.6, NOTCH.y, 1.2)
	var area := CollisionShape3D.new()
	area.shape = reach
	area.position.y = NOTCH.y * 0.5
	add_child(area)
	var body := StaticBody3D.new()
	body.name = "Seal"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("footstep_surface", "silent")
	add_child(body)
	var block := BoxShape3D.new()
	block.size = Vector3(NOTCH.x, NOTCH.y, 2.0)
	_seal = CollisionShape3D.new()
	_seal.shape = block
	_seal.position.y = NOTCH.y * 0.5
	body.add_child(_seal)
	# Darkness behind the doorway fills the notch either side of the art.
	var backing := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = NOTCH
	backing.mesh = quad
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("#0a0f15")
	backing.material_override = dark
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backing.position = Vector3(0, NOTCH.y * 0.5, -0.9)
	add_child(backing)
	_door = _sprite(DOOR, FRAMES, Vector3(ART_SHIFT_X * PIXEL, 1.28, 1.06), 8)
	# The warhead stands nose-down in the ground beside the door.
	_charge = _sprite(CHARGE, 4, Vector3(-NOTCH.x * 0.5 - 0.3, 0.32, 1.1), 11)
	reset_run()


func arm() -> bool:
	if state != State.SEALED:
		return false
	state = State.ARMED
	_time = 0.0
	_charge.visible = true
	return true


## An opening restored from a save: open at once, without the blast.
func open_instantly() -> void:
	state = State.OPEN
	_time = 0.0
	_door.frame = FRAMES - 1
	_charge.visible = false
	_seal.set_deferred("disabled", true)


func is_open() -> bool:
	return state == State.OPEN


func is_sealed() -> bool:
	return state == State.SEALED


func reset_run() -> void:
	state = State.SEALED
	_time = 0.0
	_door.frame = 0
	_seal.set_deferred("disabled", false)
	_charge.visible = false


func _physics_process(delta: float) -> void:
	match state:
		State.ARMED:
			_time += delta
			# The fuse quickens as it runs out.
			var through := clampf(_time / fuse_time, 0.0, 1.0)
			_charge.frame = int(_time * lerpf(6.0, 22.0, through)) % _charge.hframes
			if _time >= fuse_time:
				_blow()
		State.OPENING:
			_time += delta
			_door.frame = mini(FRAMES - 1, int(_time * frame_rate))
			if _door.frame == FRAMES - 1:
				state = State.OPEN
				_seal.set_deferred("disabled", true)
				opened.emit()


func _blow() -> void:
	_charge.visible = false
	state = State.OPENING
	_time = 0.0
	blown.emit()
	# The explosion art grows up from the bottom of its cell, so each origin
	# sits half a cell above the base it should rise from.
	var origin := global_position + Vector3(-NOTCH.x * 0.5, 0, 0)
	EFFECT.spawn(get_parent(), origin + Vector3(0, 1.36, 0), EXPLOSION, 48, 0.06)
	EFFECT.spawn(get_parent(), origin + Vector3(-0.7, 1.4, 0), EXPLOSION, 48, 0.04, 1.0, 1)
	EFFECT.spawn(get_parent(), origin + Vector3(0.5, 2.1, 0), EXPLOSION, 48, 0.04, 1.0, 1)
	var smoke = EFFECT.spawn(get_parent(), origin + Vector3(-0.8, 0.9, 0), SMOKE, 48, 0.06)
	smoke.frame_rate = 7.0


func _sprite(texture: Texture2D, frames: int, offset: Vector3, priority: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.hframes = frames
	sprite.pixel_size = PIXEL
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = priority
	sprite.position = offset
	add_child(sprite)
	return sprite
