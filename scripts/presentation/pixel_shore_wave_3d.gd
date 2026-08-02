class_name PixelShoreWave3D
extends Node3D
## A presentation-only two-wave set. A small crest travels first; while it is
## still approaching shore, a medium crest enters the same narrow water strip.
## Both use the source pack's subsiding frames and create a contact ripple.

enum Phase {
	IDLE,
	APPROACHING,
	CONTACT,
}

@export var subside_texture: Texture2D
@export var shore_foam_texture: Texture2D
@export_range(1, 12, 1) var frame_count := 6
@export var starting_frames := PackedInt32Array([2, 1])
@export var launch_offsets := PackedFloat32Array([0.0, 1.9])
@export_range(1, 12, 1) var shore_foam_frame_count := 6
@export_range(1.0, 24.0, 0.5) var shore_foam_frame_rate := 10.0
@export_range(0.0, 10.0, 0.1) var initial_delay := 0.8
@export_range(0.0, 10.0, 0.1) var quiet_duration := 3.4
@export_range(0.1, 10.0, 0.1) var travel_duration := 2.8
@export var offshore_x := 1.7
@export var shoreline_x := 6.4
@export var source_faces_positive_x := true

var _phase := Phase.IDLE
var _set_elapsed := 0.0
var _idle_remaining := 0.0
var _shore_foam_elapsed := 0.0
var _wave_sprites: Array[Sprite3D] = []
var _wave_launched: Array[bool] = []
var _wave_finished: Array[bool] = []

@onready var sprite: Sprite3D = $Sprite
@onready var following_sprite: Sprite3D = $FollowingSprite
@onready var shore_foam: Sprite3D = $ShoreFoam


func _ready() -> void:
	_wave_sprites = [sprite, following_sprite]
	_validate_strip(subside_texture, frame_count, "subsiding wave")
	_validate_strip(shore_foam_texture, shore_foam_frame_count, "shore foam")
	_validate_pattern()
	_wave_launched.resize(_wave_sprites.size())
	_wave_finished.resize(_wave_sprites.size())
	for wave_index in _wave_sprites.size():
		_configure_wave_sprite(_wave_sprites[wave_index], starting_frames[wave_index])
	shore_foam.texture = shore_foam_texture
	shore_foam.hframes = shore_foam_frame_count
	shore_foam.frame = 0
	shore_foam.visible = false
	shore_foam.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shore_foam.shaded = false
	shore_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shore_foam.position.x = shoreline_x
	_idle_remaining = initial_delay
	set_process(true)


func _process(delta: float) -> void:
	if shore_foam.visible:
		_tick_shore_foam(delta)
	match _phase:
		Phase.IDLE:
			_idle_remaining -= delta
			if _idle_remaining <= 0.0:
				_start_set()
		Phase.APPROACHING:
			_tick_set(delta)
		Phase.CONTACT:
			pass


func start_now() -> void:
	_start_set()


func phase() -> Phase:
	return _phase


func travel_progress() -> float:
	return wave_progress(0)


func wave_progress(wave_index: int) -> float:
	assert(wave_index >= 0 and wave_index < _wave_sprites.size())
	if _wave_finished[wave_index]:
		return 1.0
	if not _wave_launched[wave_index]:
		return 0.0
	return clampf(
		(_set_elapsed - launch_offsets[wave_index]) / travel_duration,
		0.0,
		1.0
	)


func wave_is_active(wave_index: int) -> bool:
	assert(wave_index >= 0 and wave_index < _wave_sprites.size())
	return _wave_launched[wave_index] and not _wave_finished[wave_index]


func current_starting_frame(wave_index: int = 0) -> int:
	return starting_frames[wave_index]


func shore_foam_is_playing() -> bool:
	return shore_foam.visible


func _configure_wave_sprite(wave: Sprite3D, first_frame: int) -> void:
	wave.texture = subside_texture
	wave.hframes = frame_count
	wave.frame = first_frame
	wave.visible = false
	wave.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wave.shaded = false
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var travels_positive_x := shoreline_x > offshore_x
	wave.flip_h = travels_positive_x != source_faces_positive_x


func _start_set() -> void:
	_phase = Phase.APPROACHING
	_set_elapsed = 0.0
	shore_foam.visible = false
	for wave_index in _wave_sprites.size():
		_wave_launched[wave_index] = false
		_wave_finished[wave_index] = false
		var wave := _wave_sprites[wave_index]
		wave.position.x = offshore_x
		wave.frame = starting_frames[wave_index]
		wave.visible = false
	_launch_wave(0)


func _tick_set(delta: float) -> void:
	_set_elapsed += delta
	for wave_index in _wave_sprites.size():
		if (
			not _wave_launched[wave_index]
			and _set_elapsed >= launch_offsets[wave_index]
		):
			_launch_wave(wave_index)
		if wave_is_active(wave_index):
			_tick_wave(wave_index)
	if _all_waves_finished():
		_phase = Phase.CONTACT
		if not shore_foam.visible:
			_finish_set()


func _launch_wave(wave_index: int) -> void:
	_wave_launched[wave_index] = true
	var wave := _wave_sprites[wave_index]
	wave.position.x = offshore_x
	wave.frame = starting_frames[wave_index]
	wave.visible = true


func _tick_wave(wave_index: int) -> void:
	var progress := wave_progress(wave_index)
	var wave := _wave_sprites[wave_index]
	wave.position.x = lerpf(offshore_x, shoreline_x, progress)
	var first_frame := starting_frames[wave_index]
	var available_frames := frame_count - first_frame
	wave.frame = mini(
		frame_count - 1,
		first_frame + floori(progress * available_frames)
	)
	if progress < 1.0:
		return
	wave.visible = false
	_wave_finished[wave_index] = true
	_start_shore_foam()


func _start_shore_foam() -> void:
	_shore_foam_elapsed = 0.0
	shore_foam.frame = 0
	shore_foam.visible = true


func _tick_shore_foam(delta: float) -> void:
	_shore_foam_elapsed += delta
	shore_foam.frame = mini(
		shore_foam_frame_count - 1,
		floori(_shore_foam_elapsed * shore_foam_frame_rate)
	)
	if _shore_foam_elapsed < (
		float(shore_foam_frame_count) / shore_foam_frame_rate
	):
		return
	shore_foam.visible = false
	if _phase == Phase.CONTACT:
		_finish_set()


func _finish_set() -> void:
	_phase = Phase.IDLE
	_set_elapsed = 0.0
	_idle_remaining = quiet_duration


func _all_waves_finished() -> bool:
	for finished in _wave_finished:
		if not finished:
			return false
	return true


func _validate_strip(texture: Texture2D, frames: int, label: String) -> void:
	assert(texture != null, "%s requires its %s strip." % [name, label])
	assert(
		texture.get_width() % frames == 0,
		"%s %s strip must divide evenly into %d frames."
		% [name, label, frames]
	)


func _validate_pattern() -> void:
	assert(
		starting_frames.size() == _wave_sprites.size(),
		"%s requires one starting frame per wave sprite." % name
	)
	assert(
		launch_offsets.size() == starting_frames.size(),
		"%s requires one launch offset per wave." % name
	)
	assert(is_zero_approx(launch_offsets[0]))
	for wave_index in starting_frames.size():
		assert(
			starting_frames[wave_index] >= 0
			and starting_frames[wave_index] < frame_count,
			"%s pattern frames must be within its subsiding strip." % name
		)
		assert(launch_offsets[wave_index] >= 0.0)
		if wave_index > 0:
			assert(launch_offsets[wave_index] > launch_offsets[wave_index - 1])
			assert(
				launch_offsets[wave_index] < travel_duration,
				"%s follow-up waves must overlap their predecessor." % name
			)
