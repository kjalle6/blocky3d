class_name Level2CaveSlideIntro3D
extends LevelInterstitial3D
## Scene-specific in-engine cutscene for the Level 2 cave descent.
##
## This owns presentation only: one player puppet, one authored path, one camera,
## and a deterministic finish state. It never reads abilities, collision, save
## data, or gameplay input. A future transition host can treat `finished` as the
## point where the unchanged playable interior should load.

const SLIDE_DUST_FRAME_COUNT := 4
const SLIDE_DUST_PUFF_COUNT := 4
const SLIDE_DUST_EMISSION_INTERVAL := 0.07
const SLIDE_DUST_LIFETIME := 0.28
const SLIDE_DUST_START_PROGRESS := 0.05
const SLIDE_DUST_END_PROGRESS := 0.98
const SLIDE_DUST_DEPTH := 1.12
const SLIDE_DUST_COLOR := Color(0.9, 0.72, 0.62, 0.95)

enum Phase {
	STOPPED,
	SLIDING,
	COMPLETE,
}

@export_range(0.5, 8.0, 0.05) var slide_duration := 4.4
@export_range(-80.0, 80.0, 0.5) var slide_visual_angle_degrees := -28.0
@export_range(0.0, 1.0, 0.01) var slide_contact_depth := 0.26
@export_range(3, 41, 2) var chute_rock_count := 39
@export var rock_spacing := 1.28
@export var path_marker_paths: Array[NodePath] = []

@onready var world_environment: WorldEnvironment = %WorldEnvironment
@onready var background: PixelBackgroundRig3D = %Background
@onready var camera: PixelSideCamera3D = %CutsceneCamera
@onready var camera_target: Marker3D = %CameraTarget
@onready var puppet: Node3D = %Puppet
@onready var visual_pivot: Node3D = %SlidePosePivot
@onready var pixel_visual: PixelPlayerVisual3D = %PixelVisual
@onready var chute_floor_rock: Sprite3D = %ChuteFloorRock
@onready var slide_dust_root: Node3D = %SlideDustTrail
@onready var slide_dust_template: Sprite3D = %SlideDustPuff

var _phase := Phase.STOPPED
var _phase_elapsed := 0.0
var _path := Curve3D.new()
var _path_length := 0.0
var _finished_emitted := false
var _was_skipped := false
var _slide_dust_puffs: Array[Sprite3D] = []


func _ready() -> void:
	process_priority = -120
	add_to_group("run_resettable")
	_build_path()
	_build_repeated_rocks(chute_floor_rock, chute_rock_count)
	_build_slide_dust_pool()
	var errors := validation_errors()
	assert(
		errors.is_empty(),
		"Level 2 cave slide intro is invalid:\n%s" % "\n".join(errors)
	)
	camera.current = true
	camera.target = camera_target
	background.bind_camera(camera)
	call_deferred("play_from_start")


func _unhandled_input(event: InputEvent) -> void:
	if (
		_phase != Phase.COMPLETE
		and _phase != Phase.STOPPED
		and event.is_action_pressed("jump")
	):
		skip_to_end()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	match _phase:
		Phase.SLIDING:
			_phase_elapsed = minf(_phase_elapsed + delta, slide_duration)
			var progress := _phase_elapsed / slide_duration
			_apply_slide_progress(progress, delta)
			if is_equal_approx(progress, 1.0):
				_complete(false)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if slide_duration <= 0.0:
		errors.append("The slide duration must be positive.")
	if path_marker_paths.size() < 4:
		errors.append("The cave slide needs at least four authored path markers.")
	for marker_path in path_marker_paths:
		if not get_node_or_null(marker_path) is Marker3D:
			errors.append("Slide path marker '%s' is missing." % marker_path)
	if rock_spacing <= 0.0:
		errors.append("Repeated cave rocks need positive spacing.")
	if chute_rock_count < 3 or chute_rock_count % 2 == 0:
		errors.append("The chute needs an odd rock count of at least three.")
	if background == null or background.profile == null:
		errors.append("The cutscene needs its cave background profile.")
	if world_environment == null or world_environment.environment == null:
		errors.append("The cutscene needs its own world environment.")
	if slide_dust_template == null or slide_dust_template.texture == null:
		errors.append("The cave slide needs its dust strip.")
	elif (
		slide_dust_template.texture.get_width()
		% SLIDE_DUST_FRAME_COUNT != 0
	):
		errors.append("The slide-dust strip must divide into four frames.")
	return errors


func play_from_start() -> void:
	_phase = Phase.SLIDING
	_phase_elapsed = 0.0
	_finished_emitted = false
	_was_skipped = false
	puppet.visible = true
	visual_pivot.rotation.z = deg_to_rad(slide_visual_angle_degrees)
	visual_pivot.scale = Vector3.ONE
	pixel_visual.reset_feedback()
	pixel_visual.set_state("wall_slide", true)
	_apply_slide_progress(0.0, 0.0)
	camera.target = camera_target
	camera.current = true
	camera.snap_to_target()
	background.snap_to_camera(true)


func reset_run() -> void:
	play_from_start()


func skip_to_end() -> void:
	if _phase == Phase.COMPLETE:
		return
	_apply_slide_progress(1.0, 0.0)
	_complete(true)


## Deterministic review hook used by the capture script and focused validator.
func preview_slide_progress(progress: float) -> void:
	_phase = Phase.STOPPED
	_phase_elapsed = clampf(progress, 0.0, 1.0) * slide_duration
	_finished_emitted = false
	_was_skipped = false
	_apply_slide_progress(clampf(progress, 0.0, 1.0), 0.0)
	camera.snap_to_target()
	background.snap_to_camera(true)


func current_phase() -> Phase:
	return _phase


func slide_progress() -> float:
	if _phase == Phase.COMPLETE:
		return 1.0
	return clampf(_phase_elapsed / slide_duration, 0.0, 1.0)


func has_finished() -> bool:
	return _phase == Phase.COMPLETE


func was_skipped() -> bool:
	return _was_skipped


func slide_dust_puff_count() -> int:
	return _slide_dust_puffs.size()


func visible_slide_dust_count() -> int:
	var visible_count := 0
	for puff in _slide_dust_puffs:
		if puff.visible:
			visible_count += 1
	return visible_count


func slide_exit_global_position() -> Vector3:
	return (get_node(path_marker_paths.back()) as Marker3D).global_position


func terminal_horizontal_speed() -> float:
	var sample_start := _path.sample_baked(
		maxf(0.0, _path_length - 0.1),
		true
	)
	var sample_end := _path.sample_baked(_path_length, true)
	var exit_direction := (sample_end - sample_start).normalized()
	return absf(exit_direction.x) * _path_length * 1.18 / slide_duration


func slide_contact_offset() -> Vector3:
	var offset_2d := Vector2(0.0, -slide_contact_depth).rotated(
		deg_to_rad(slide_visual_angle_degrees)
	)
	return Vector3(offset_2d.x, offset_2d.y, 0.0)


func _build_path() -> void:
	_path = Curve3D.new()
	_path.bake_interval = 0.04
	var points: Array[Vector3] = []
	for marker_path in path_marker_paths:
		var marker := get_node_or_null(marker_path) as Marker3D
		if marker != null:
			points.append(to_local(marker.global_position))
	for point_index in points.size():
		var previous := points[maxi(0, point_index - 1)]
		var following := points[mini(points.size() - 1, point_index + 1)]
		var tangent := (following - previous) * 0.16
		_path.add_point(points[point_index], -tangent, tangent)
	_path_length = _path.get_baked_length()


func _build_repeated_rocks(template: Sprite3D, count: int) -> void:
	var half_count := floori(count * 0.5)
	for index in count:
		var slot := index - half_count
		if slot == 0:
			continue
		var copy := template.duplicate() as Sprite3D
		copy.name = (
			"%sL%02d" % [template.name, -slot]
			if slot < 0
			else "%sR%02d" % [template.name, slot]
		)
		copy.position = template.position + Vector3(slot * rock_spacing, 0.0, 0.0)
		copy.flip_h = absi(slot) % 2 == 1
		template.get_parent().add_child(copy)


func _build_slide_dust_pool() -> void:
	_slide_dust_puffs.clear()
	_slide_dust_puffs.append(slide_dust_template)
	for puff_index in range(1, SLIDE_DUST_PUFF_COUNT):
		var puff := slide_dust_template.duplicate() as Sprite3D
		puff.name = "SlideDustPuff%02d" % (puff_index + 1)
		slide_dust_root.add_child(puff)
		_slide_dust_puffs.append(puff)
	_hide_slide_dust()


func _apply_slide_progress(progress: float, delta: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var distance_progress := pow(clamped_progress, 1.18)
	var distance := _path_length * distance_progress
	puppet.global_position = to_global(_path.sample_baked(distance, true))
	var lead_distance := minf(_path_length, distance + 0.8)
	camera_target.global_position = to_global(
		_path.sample_baked(lead_distance, true)
	)
	visual_pivot.rotation.z = deg_to_rad(slide_visual_angle_degrees)
	visual_pivot.position = slide_contact_offset()
	pixel_visual.tick_authored_state(delta, "wall_slide", true, -8.0)
	_apply_slide_dust(clamped_progress)


func _apply_slide_dust(progress: float) -> void:
	if (
		progress < SLIDE_DUST_START_PROGRESS
		or progress >= SLIDE_DUST_END_PROGRESS
	):
		_hide_slide_dust()
		return
	var start_time := SLIDE_DUST_START_PROGRESS * slide_duration
	var effect_elapsed := progress * slide_duration - start_time
	var latest_spawn := floori(
		effect_elapsed / SLIDE_DUST_EMISSION_INTERVAL
	)
	for puff_index in _slide_dust_puffs.size():
		var puff := _slide_dust_puffs[puff_index]
		var spawn_index := latest_spawn - puff_index
		if spawn_index < 0:
			puff.visible = false
			continue
		var spawn_elapsed := (
			spawn_index * SLIDE_DUST_EMISSION_INTERVAL
		)
		var age := effect_elapsed - spawn_elapsed
		if age > SLIDE_DUST_LIFETIME:
			puff.visible = false
			continue
		var spawn_progress := (
			start_time + spawn_elapsed
		) / slide_duration
		var spawn_distance := _path_length * pow(spawn_progress, 1.18)
		var life := clampf(age / SLIDE_DUST_LIFETIME, 0.0, 1.0)
		puff.global_position = to_global(
			_path.sample_baked(spawn_distance, true)
		) + Vector3(-age * 0.2, 0.18 + age * 0.28, SLIDE_DUST_DEPTH)
		puff.frame = mini(
			SLIDE_DUST_FRAME_COUNT - 1,
			floori(life * SLIDE_DUST_FRAME_COUNT)
		)
		var fade := 1.0 - smoothstep(0.62, 1.0, life)
		puff.modulate = Color(
			SLIDE_DUST_COLOR.r,
			SLIDE_DUST_COLOR.g,
			SLIDE_DUST_COLOR.b,
			SLIDE_DUST_COLOR.a * fade
		)
		var puff_scale := lerpf(1.15, 1.3, life)
		puff.scale = Vector3(puff_scale, puff_scale, 1.0)
		puff.visible = true


func _hide_slide_dust() -> void:
	for puff in _slide_dust_puffs:
		puff.visible = false


func _complete(skipped: bool) -> void:
	_phase = Phase.COMPLETE
	_phase_elapsed = slide_duration
	_was_skipped = skipped
	_hide_slide_dust()
	if _finished_emitted:
		return
	_finished_emitted = true
	finished.emit(skipped)
