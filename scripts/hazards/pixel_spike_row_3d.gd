class_name PixelSpikeRow3D
extends Hazard3D
## A reusable pixel-art spike row with deliberately inset foot-level damage.

const SPIKE_TEXTURE := preload("res://assets/art/shared/hazards/spike.svg")
const SOURCE_SIZE := Vector2(24.0, 24.0)

@export_range(0.6, 20.0, 0.05, "or_greater") var row_width := 2.5
@export_range(0.0, 0.5, 0.01) var collision_end_inset := 0.2
@export_range(0.2, 1.5, 0.01) var spike_height := 0.76
@export_range(0.1, 1.0, 0.01) var collision_height := 0.36
var _generated_children: Array[Node] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	rebuild_geometry()
	super()


func rebuild_geometry() -> void:
	for child in _generated_children:
		if is_instance_valid(child):
			remove_child(child)
			child.free()
	_generated_children.clear()
	_build_damage_shape()
	_build_spikes()


func _build_damage_shape() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "DamageCollision"
	collision.position.y = collision_height * 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(0.1, row_width - collision_end_inset * 2.0),
		collision_height,
		0.7
	)
	collision.shape = shape
	add_child(collision)
	_generated_children.append(collision)


func _build_spikes() -> void:
	var spike_count := maxi(1, roundi(row_width / spike_height))
	var spacing := row_width / spike_count
	var source_world_size := SOURCE_SIZE.x * spike_height / SOURCE_SIZE.y
	for index in spike_count:
		var sprite := Sprite3D.new()
		sprite.name = "Spike%02d" % (index + 1)
		sprite.texture = SPIKE_TEXTURE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.pixel_size = spike_height / SOURCE_SIZE.y
		sprite.scale.x = spacing / source_world_size
		sprite.position = Vector3(
			-row_width * 0.5 + spacing * (index + 0.5),
			spike_height * 0.5,
			1.18
		)
		sprite.render_priority = 9
		add_child(sprite)
		_generated_children.append(sprite)
