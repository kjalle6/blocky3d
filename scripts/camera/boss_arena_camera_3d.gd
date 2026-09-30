extends PixelSideCamera3D
## Player-led framing for a nearby boss. Other levels keep their own cameras.
@export var encounter_target_path := NodePath("../GreenZoneBoss")
@onready var encounter_target := get_node_or_null(encounter_target_path) as Node3D
@export var encounter_zoom_out := 1.22
@export var encounter_follow_weight := 0.35
@export var encounter_full_distance := 18.0
@export var encounter_release_distance := 24.0
@export var encounter_vertical_full_distance := 9.0
@export var encounter_vertical_release_distance := 15.0
@export var encounter_zoom_response := 3.0
var _normal_size := 12.9375

func _ready() -> void:
	super()
	_normal_size = size

func _process(delta: float) -> void:
	if target == null or cinematic_override_enabled:
		super(delta)
		return
	var influence := 0.0
	var offset := Vector3.ZERO
	if not _developer_inspection_enabled and is_instance_valid(encounter_target) \
			and not encounter_target.call("is_defeated"):
		offset = encounter_target.global_position + Vector3.UP * 1.5 - target.global_position
		influence = (1.0 - smoothstep(encounter_full_distance, encounter_release_distance, absf(offset.x))) \
			* (1.0 - smoothstep(encounter_vertical_full_distance, encounter_vertical_release_distance, absf(offset.y)))
	var desired_size := _normal_size * lerpf(1.0, encounter_zoom_out, influence)
	size = desired_size if not _initialized else lerpf(size, desired_size, 1.0 - exp(-encounter_zoom_response * delta))
	# Feed the normal follow/smoothing/pixel-snapping path temporary encounter
	# composition. Keep authored values intact for inspection, saves and reset.
	var normal_look := look_ahead
	var normal_anchor := vertical_anchor_y
	var normal_minimum := minimum_center_x
	var normal_maximum := maximum_center_x
	look_ahead += offset.x * encounter_follow_weight * influence
	vertical_anchor_y -= offset.y * encounter_follow_weight * influence
	var viewport_size := get_viewport().get_visible_rect().size
	var extra_half_width := (size - _normal_size) * viewport_size.x / maxf(viewport_size.y, 1.0) * 0.5
	minimum_center_x += extra_half_width
	maximum_center_x -= extra_half_width
	super(delta)
	look_ahead = normal_look
	vertical_anchor_y = normal_anchor
	minimum_center_x = normal_minimum
	maximum_center_x = normal_maximum
