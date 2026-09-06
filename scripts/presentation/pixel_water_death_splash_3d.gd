class_name PixelWaterDeathSplash3D
extends Node3D
## Presentation-only water death. PlayerCharacter retains the ordinary death
## contract; this component swaps the body for a restrained shoreline splash
## when a hazard reports the water death kind.

@export var player_path: NodePath
@export var water_surface_y := 0.0
## Optional node whose height carries the water surface, for water that is not
## at a fixed world height - a camera-locked vista, say. When set, this replaces
## water_surface_y so the splash lands where the water is actually drawn.
@export var surface_source_path: NodePath
@export var surface_source_offset := 0.0
@export_range(1, 16, 1) var frame_count := 6
@export_range(1.0, 30.0, 0.5) var frame_rate := 12.0
## Skip an authored clip's quiet lead-in without altering its source audio.
@export_range(0.0, 5.0, 0.01) var audio_start_seconds := 0.0
## Zero lets the full clip play. Duration is measured from water entry.
@export_range(0.0, 5.0, 0.01) var audio_duration_seconds := 0.0
@export_range(0.0, 0.5, 0.01) var audio_fade_seconds := 0.1

var _player: PlayerCharacter
var _elapsed := 0.0
var _active := false
var _audio_tween: Tween
var _audio_volume_db := 0.0

@onready var sprite: Sprite3D = $Sprite
@onready var splash_audio: AudioStreamPlayer = get_node_or_null("Audio") as AudioStreamPlayer


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerCharacter
	assert(_player != null, "%s requires a PlayerCharacter path." % name)
	assert(sprite.texture != null, "%s requires a splash texture." % name)
	assert(
		sprite.texture.get_width() % frame_count == 0,
		"%s splash strip must divide evenly into its frame count." % name
	)
	sprite.hframes = frame_count
	sprite.frame = 0
	sprite.visible = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player.death_started.connect(_on_death_started)
	if splash_audio != null:
		_audio_volume_db = splash_audio.volume_db
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return
	if not _player.is_dead():
		_finish()
		return
	_elapsed += delta
	sprite.frame = mini(frame_count - 1, floori(_elapsed * frame_rate))
	if _elapsed >= float(frame_count) / frame_rate:
		_finish()


func is_playing() -> bool:
	return _active


func _on_death_started(kind: StringName, world_position: Vector3) -> void:
	if kind != PlayerCharacter.DEATH_KIND_WATER:
		return
	if splash_audio != null:
		if _audio_tween != null and _audio_tween.is_valid():
			_audio_tween.kill()
		splash_audio.volume_db = _audio_volume_db
		splash_audio.play(audio_start_seconds)
		if audio_duration_seconds > 0.0:
			var fade_duration := minf(audio_fade_seconds, audio_duration_seconds)
			_audio_tween = create_tween()
			_audio_tween.tween_interval(audio_duration_seconds - fade_duration)
			if fade_duration > 0.0:
				_audio_tween.tween_property(splash_audio, "volume_linear", 0.0, fade_duration)
			_audio_tween.tween_callback(splash_audio.stop)
	_player.visible = false
	global_position = Vector3(
		world_position.x,
		_surface_y(),
		world_position.z
	)
	_elapsed = 0.0
	_active = true
	sprite.frame = 0
	sprite.visible = true
	set_process(true)


func _finish() -> void:
	_active = false
	sprite.visible = false
	set_process(false)


func _surface_y() -> float:
	var source := get_node_or_null(surface_source_path) as Node3D
	if source == null:
		return water_surface_y
	return source.global_position.y + surface_source_offset
