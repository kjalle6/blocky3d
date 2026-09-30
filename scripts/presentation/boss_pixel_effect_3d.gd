extends Sprite3D
## Short-lived catalog VFX. Only spawned on impact, never as advance warnings.

var elapsed := 0.0
var frame_rate := 18.0
var first_frame := 0
var frame_count := 6

static func spawn(parent: Node, origin: Vector3, sheet: Texture2D, cell: int,
		pixel_scale: float, flatten := 1.0, start_frame := 0) -> Sprite3D:
	var effect := new()
	effect.texture = sheet
	effect.hframes = sheet.get_width() / cell
	effect.frame_count = effect.hframes
	effect.first_frame = start_frame
	effect.frame = start_frame
	effect.pixel_size = pixel_scale
	effect.scale.y = flatten
	effect.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	effect.shaded = false
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.render_priority = 14
	parent.add_child(effect)
	effect.global_position = origin + Vector3(0, 0, 1.4)
	return effect

func _ready() -> void:
	add_to_group("run_resettable")

func _process(delta: float) -> void:
	elapsed += delta
	var index := first_frame + int(elapsed * frame_rate)
	if index >= frame_count:
		queue_free()
	else:
		frame = index

func reset_run() -> void:
	queue_free()
