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
@export_group("Fit both")
## Arena mode: frame the midpoint and zoom out only as far as needed to keep the
## player and the boss in view. The zoom never shows beyond the authored camera
## bounds; if even that view cannot hold both, the player stays in view.
@export var fit_both := false
## 0 limits the zoom only by the arena. A fixed cap, for arenas too large to
## show whole, eases back to player framing past the cap instead.
@export_range(0.0, 2.5, 0.01) var encounter_maximum_zoom := 0.0
## Room kept around both actors, in metres at normal zoom.
@export var fit_margin := Vector2(3.0, 2.5)
## With a fixed cap, the boss is released between it and this multiple of it.
@export_range(1.01, 2.0, 0.01) var fit_release_ratio := 1.25
@export_range(0.0, 1.0, 0.01) var fit_follow_weight := 0.5
@export_group("")
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
	var zoom := 1.0
	var weight := Vector2(encounter_follow_weight, encounter_follow_weight)
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	if not _developer_inspection_enabled and is_instance_valid(encounter_target) \
			and not encounter_target.call("is_defeated"):
		offset = encounter_target.global_position + Vector3.UP * 1.5 - target.global_position
		if fit_both:
			zoom = required_fit_zoom(offset, aspect)
			influence = 1.0
			if encounter_maximum_zoom > 0.0:
				influence = 1.0 - smoothstep(encounter_maximum_zoom,
					encounter_maximum_zoom * fit_release_ratio, zoom)
				zoom = minf(zoom, encounter_maximum_zoom)
			zoom = minf(zoom, room_fit_zoom(aspect))
			# Frame the midpoint, but never so far from the player that it leaves view.
			var half_height := _normal_size * zoom * 0.5
			weight = Vector2(
				minf(fit_follow_weight, maxf(0.0, half_height * aspect - fit_margin.x) / maxf(absf(offset.x), 0.001)),
				minf(fit_follow_weight, maxf(0.0, half_height - fit_margin.y) / maxf(absf(offset.y), 0.001)))
		else:
			influence = (1.0 - smoothstep(encounter_full_distance, encounter_release_distance, absf(offset.x))) \
				* (1.0 - smoothstep(encounter_vertical_full_distance, encounter_vertical_release_distance, absf(offset.y)))
			zoom = encounter_zoom_out
	var desired_size := _normal_size * lerpf(1.0, zoom, influence)
	size = desired_size if not _initialized else lerpf(size, desired_size, 1.0 - exp(-encounter_zoom_response * delta))
	# Feed the normal follow/smoothing/pixel-snapping path temporary encounter
	# composition. Keep authored values intact for inspection, saves and reset.
	var normal_look := look_ahead
	var normal_anchor := vertical_anchor_y
	var normal_minimum := minimum_center_x
	var normal_maximum := maximum_center_x
	var normal_low := minimum_vertical_offset
	var normal_high := maximum_vertical_offset
	look_ahead += offset.x * weight.x * influence
	vertical_anchor_y -= offset.y * weight.y * influence
	var extra_half_width := (size - _normal_size) * aspect * 0.5
	minimum_center_x += extra_half_width
	maximum_center_x -= extra_half_width
	if fit_both:
		# A tall arena needs the zoomed view's top and bottom kept inside it too.
		var extra_half_height := (size - _normal_size) * 0.5
		minimum_vertical_offset = minf(minimum_vertical_offset + extra_half_height, maximum_vertical_offset)
		maximum_vertical_offset = maxf(maximum_vertical_offset - extra_half_height, minimum_vertical_offset)
	super(delta)
	look_ahead = normal_look
	vertical_anchor_y = normal_anchor
	minimum_center_x = normal_minimum
	maximum_center_x = normal_maximum
	minimum_vertical_offset = normal_low
	maximum_vertical_offset = normal_high

## The widest zoom whose view still stays inside the authored camera bounds.
func room_fit_zoom(aspect: float) -> float:
	var half_height := _normal_size * 0.5
	var half_width := half_height * aspect
	var fit := ((maximum_center_x - minimum_center_x) * 0.5 + half_width) / half_width
	if vertical_follow_enabled:
		fit = minf(fit, ((maximum_vertical_offset - minimum_vertical_offset) * 0.5 + half_height) / half_height)
	return maxf(1.0, fit)

## Zoom factor that fits both actors around their midpoint with fit_margin.
func required_fit_zoom(offset: Vector3, aspect: float) -> float:
	var half_height := _normal_size * 0.5
	var half_width := half_height * aspect
	return maxf(1.0, maxf((absf(offset.x) * 0.5 + fit_margin.x) / half_width,
		(absf(offset.y) * 0.5 + fit_margin.y) / half_height))
