class_name PixelShoreWave3D
extends Node3D
## Presentation-only shoreline surf.
##
## Small crests swell out of the water, drift a short way in, and sink back as
## a foam splash lands. Nothing here is a shrunken version of the pack's big
## roller: a crest is the *low frames* of the source clip played at the game's
## native pixel scale, so the art sits on the same grid as the terrain instead
## of at a finer resolution than everything around it.
##
## The source clip carries its own waterline at `art_base_row`, so the sprites
## are offset to put that row on this node's origin. Place the node at the
## water surface and the crests sit in the water rather than on top of it.
##
## Crests are authored, not random: each entry in `crest_offsets_x` gets its own
## delay and repeats on a fixed cycle, so the surf is identical on every run and
## survives death and restart without resetting.

class Crest:
	var sprite: Sprite3D
	var has_broken := false


@export var crest_texture: Texture2D
@export_range(1, 12, 1) var frame_count := 6
## Crests never reach the source clip's full-size roller. At native scale frame 1
## is a 1.9 m x 0.9 m swell — below the player's height, which is what keeps this
## reading as shoreline lapping rather than surf.
@export_range(1, 11, 1) var peak_frame := 1
@export var foam_texture: Texture2D
@export_range(1, 12, 1) var foam_frame_count := 6
@export_range(1.0, 24.0, 0.5) var foam_frame_rate := 2.5
## Local X where each crest breaks. One entry per crest.
@export var crest_offsets_x := PackedFloat32Array([2.2, 4.3, 6.1])
@export var crest_delays := PackedFloat32Array([0.0, 2.1, 4.0])
@export_range(0.1, 20.0, 0.1) var crest_duration := 3.4
@export_range(0.0, 20.0, 0.1) var cycle_duration := 6.4
## Short inbound drift. Surf this size laps rather than travels.
@export var crest_travel := 0.8
## Point in a crest's life at which it is largest. A symmetric swell peaks
## halfway in and has collapsed by the time it reaches the beach, so the shore
## splash fires on nothing. Peaking on arrival keeps the wave and its splash
## reading as one event.
@export_range(0.05, 0.95, 0.01) var swell_peak_at := 0.88
## Local X of the sand edge, where the water laps the beach.
@export var shoreline_x := 6.4
## How close a crest's leading edge must get to the sand before the splash
## plays. The splash is caused by a wave arriving, so it is driven by position,
## never by a crest's own timeline — crests that settle out in open water do
## not touch the beach and must not splash. Keep this tight: a loose tolerance
## fires the splash while the wave is still visibly short of the sand.
@export var foam_reach_tolerance := 0.02
## How far a crest may wash past the sand edge as it collapses. Water laps onto
## a beach; stopping dead at the boundary leaves a visible gap.
@export_range(0.0, 0.32, 0.01) var shoreline_wash := 0.1
## Frames of the splash to play. The source clip grows into a full splash; the
## opening frames alone read as a small lap at the waterline.
@export_range(1, 12, 1) var foam_frame_limit := 1
## Fraction of a crest's life spent dissolving at the end. This is for crests
## that settle offshore, so they sink away instead of blinking out. The crest
## that breaks is cut instead — see crest_hides_on_break.
@export_range(0.0, 1.0, 0.01) var crest_fade_out := 0.18
## Cut the breaking crest the instant its splash appears rather than fading it.
## A dissolve reads as ghosting because the wave is visible through its own
## replacement; a cut under a brighter effect reads as the wave becoming it.
@export var crest_hides_on_break := true
## How far seaward of a breaking crest's leading edge the splash lands. The
## crest's mass sits behind its tip, so a splash placed on the tip appears
## beside the wave; placed on the body it appears to come out of it.
@export var foam_body_offset := -0.5
## Fraction of the splash's life spent fading out. A short clip that simply
## vanishes reads as a pop; dissolving the tail lets it settle instead.
@export_range(0.0, 1.0, 0.01) var foam_fade_out := 0.55
## Row in the foam frame where the splash sits on the water.
@export_range(0, 512, 1) var foam_base_row := 40
## How far each crest sits below the surface, one per crest. Crests render
## behind the water face, so this hides their base and only the part clearing
## the surface is seen — it sets a wave's apparent size without touching art
## scale or the pixel grid.
##
## Values must decrease toward the beach. Offshore water is deeper, so a distant
## swell shows less of itself and waves visibly grow as they come in. A flat
## value would let a small crest sit behind a large one, which reads as wrong.
@export var crest_submerged_depths := PackedFloat32Array([0.58, 0.46, 0.3])
## Local Z of the crests. Must stay behind the water face for the surface to
## mask a submerged base.
@export var crest_depth_offset := -0.22
## Local Z of the splash, which stays in front of the water as surface spray.
@export var foam_depth_offset := 0.0
## Row in the source frame where the art puts its own waterline.
@export_range(0, 512, 1) var art_base_row := 97
## Column of the crest's leading edge *as the player sees it*. Anchoring here
## makes `crest_offsets_x` mean "where this crest breaks".
##
## This is deliberately not the art's absolute right edge (col 126). The last
## ~17 columns are the wave's thin tapering toe, which sits below the surface
## once the crest is submerged and so is masked by the water. Anchoring on the
## absolute edge therefore leaves the visible crest stopping ~0.68 m short of
## the shore, with the splash stranded ahead of it.
@export_range(0, 512, 1) var art_leading_col := 109
@export var source_faces_positive_x := true

var _crests: Array[Crest] = []
var _shore_foam: Sprite3D
var _shore_foam_elapsed := -1.0
var _elapsed := 0.0
var _camera: PixelSideCamera3D


func _ready() -> void:
	assert(crest_texture != null, "%s requires a crest strip." % name)
	assert(foam_texture != null, "%s requires a foam strip." % name)
	assert(
		crest_texture.get_width() % frame_count == 0,
		"%s crest strip must divide evenly into %d frames." % [name, frame_count]
	)
	assert(
		foam_texture.get_width() % foam_frame_count == 0,
		"%s foam strip must divide evenly into %d frames." % [name, foam_frame_count]
	)
	assert(
		crest_offsets_x.size() == crest_delays.size(),
		"%s requires one delay per crest." % name
	)
	assert(peak_frame < frame_count)
	assert(
		crest_submerged_depths.size() == crest_offsets_x.size(),
		"%s requires one submerged depth per crest." % name
	)
	for crest_index in range(1, crest_submerged_depths.size()):
		assert(
			crest_submerged_depths[crest_index]
			< crest_submerged_depths[crest_index - 1],
			(
				"%s must submerge offshore crests more than inshore ones, so "
				+ "waves grow toward the beach instead of shrinking behind it."
			) % name
		)
	var reaches_shore := false
	for crest_index in crest_offsets_x.size():
		reaches_shore = reaches_shore or crest_ever_reaches_shore(crest_index)
		assert(
			crest_offsets_x[crest_index] + crest_travel
			<= shoreline_x + shoreline_wash,
			"%s crests may lap onto the sand but never run across it." % name
		)
	assert(reaches_shore, "%s needs at least one crest that reaches the beach." % name)
	assert(crest_duration <= cycle_duration, "%s crests must finish inside their cycle." % name)
	_build_crests()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_tick_shore_foam(delta)
	for crest_index in _crests.size():
		_tick_crest(crest_index)


func crest_count() -> int:
	return _crests.size()


func crest_sprite(crest_index: int) -> Sprite3D:
	assert(crest_index >= 0 and crest_index < _crests.size())
	return _crests[crest_index].sprite


func shore_foam_sprite() -> Sprite3D:
	return _shore_foam


func crest_is_active(crest_index: int) -> bool:
	return crest_sprite(crest_index).visible


func shore_foam_is_playing() -> bool:
	return _shore_foam.visible


## Local life of a crest in [0, 1], or -1 while it is between cycles.
func crest_progress(crest_index: int) -> float:
	assert(crest_index >= 0 and crest_index < _crests.size())
	var local_time := fposmod(_elapsed - crest_delays[crest_index], cycle_duration)
	if local_time > crest_duration:
		return -1.0
	return local_time / crest_duration


## Texture-pixel offset that puts the clip's own waterline on this node's origin.
func waterline_offset_pixels() -> float:
	return float(art_base_row) - crest_texture.get_height() * 0.5


## Texture-pixel offset that puts the art's leading edge on this node's origin.
func leading_edge_offset_pixels() -> float:
	var frame_width := crest_texture.get_width() / float(frame_count)
	return frame_width * 0.5 - float(art_leading_col)


func _build_crests() -> void:
	for crest_index in crest_offsets_x.size():
		var crest := Crest.new()
		crest.sprite = _make_sprite(
			"Crest%02d" % (crest_index + 1),
			crest_texture,
			frame_count,
			-1
		)
		crest.sprite.offset = Vector2(
			leading_edge_offset_pixels(),
			waterline_offset_pixels()
		)
		var travels_positive_x := crest_travel >= 0.0
		crest.sprite.flip_h = travels_positive_x != source_faces_positive_x
		# Seat depth at build time as well as per tick: crests wait out their
		# delay before first ticking, and inspection must not see a stale z.
		crest.sprite.position = Vector3(
			crest_offsets_x[crest_index],
			-crest_submerged_depths[crest_index],
			crest_depth_offset
		)
		_crests.append(crest)
	_shore_foam = _make_sprite("ShoreFoam", foam_texture, foam_frame_count, 1)
	_shore_foam.offset = Vector2(0.0, foam_offset_pixels())
	_shore_foam.position = Vector3(
		_snapped_x(shoreline_x),
		0.0,
		foam_depth_offset
	)


func _make_sprite(
	sprite_name: String,
	texture: Texture2D,
	frames: int,
	priority: int
) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.hframes = frames
	sprite.frame = 0
	sprite.visible = false
	sprite.pixel_size = PixelPlatform3D.TILE_PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = priority
	add_child(sprite)
	return sprite


func _tick_crest(crest_index: int) -> void:
	var crest := _crests[crest_index]
	var progress := crest_progress(crest_index)
	if progress < 0.0:
		crest.sprite.visible = false
		crest.sprite.modulate.a = 1.0
		crest.has_broken = false
		return

	# Swell and sink: the clip's low frames run up to the peak and back down, so
	# a crest rises out of the water and settles into it without ever becoming
	# the pack's full-size roller. The rise is long and the collapse is short, so
	# the crest is at full size when it meets the beach.
	var swell := (
		progress / swell_peak_at
		if progress <= swell_peak_at
		else (1.0 - progress) / (1.0 - swell_peak_at)
	)
	crest.sprite.frame = clampi(roundi(swell * peak_frame), 0, peak_frame)
	crest.sprite.position = Vector3(
		_snapped_x(crest_offsets_x[crest_index] + crest_travel * progress),
		-crest_submerged_depths[crest_index],
		crest_depth_offset
	)
	crest.sprite.visible = true
	crest.sprite.modulate.a = (
		1.0
		if crest_fade_out <= 0.0 or progress <= 1.0 - crest_fade_out
		else clampf((1.0 - progress) / crest_fade_out, 0.0, 1.0)
	)

	if not crest.has_broken and crest_reaches_shore(crest_index, progress):
		crest.has_broken = true
		_start_shore_foam(crest.sprite.position.x)
	if crest.has_broken and crest_hides_on_break:
		crest.sprite.visible = false


## True once this crest's leading edge has arrived at the beach.
func crest_reaches_shore(crest_index: int, progress: float) -> bool:
	if progress < 0.0:
		return false
	var leading_edge := (
		crest_offsets_x[crest_index] + crest_travel * progress
	)
	return leading_edge >= shoreline_x - foam_reach_tolerance


## True when this crest travels far enough to touch the beach at all. Crests
## that never reach it swell and settle offshore without a splash.
func crest_ever_reaches_shore(crest_index: int) -> bool:
	return (
		crest_offsets_x[crest_index] + crest_travel
		>= shoreline_x - foam_reach_tolerance
	)


## Texture-pixel offset that seats the splash on the water instead of hovering
## it above the surface. The art's own base is `foam_base_row`, not the frame
## edge, so anchoring by frame height floats it by the difference.
func foam_offset_pixels() -> float:
	return float(foam_base_row) - foam_texture.get_height() * 0.5


func _start_shore_foam(breaking_crest_x: float) -> void:
	_shore_foam_elapsed = 0.0
	_shore_foam.frame = 0
	_shore_foam.modulate.a = 1.0
	_shore_foam.position.x = _snapped_x(breaking_crest_x + foam_body_offset)
	_shore_foam.visible = true


func _tick_shore_foam(delta: float) -> void:
	if not _shore_foam.visible:
		return
	_shore_foam_elapsed += delta
	var played_frames := mini(foam_frame_limit, foam_frame_count)
	var duration := float(played_frames) / foam_frame_rate
	_shore_foam.frame = mini(
		played_frames - 1,
		floori(_shore_foam_elapsed * foam_frame_rate)
	)
	var life := _shore_foam_elapsed / duration
	_shore_foam.modulate.a = (
		1.0
		if foam_fade_out <= 0.0 or life <= 1.0 - foam_fade_out
		else clampf((1.0 - life) / foam_fade_out, 0.0, 1.0)
	)
	if _shore_foam_elapsed >= duration:
		_shore_foam.modulate.a = 1.0
		_shore_foam.visible = false


func _snapped_x(local_x: float) -> float:
	## Crests share the camera's output-pixel grid, exactly as the background rig
	## does, so drifting art steps with the static water instead of crawling.
	if _camera == null:
		_camera = get_viewport().get_camera_3d() as PixelSideCamera3D
		if _camera == null:
			return local_x
	return _camera.snap_world_x(global_position.x + local_x) - global_position.x
