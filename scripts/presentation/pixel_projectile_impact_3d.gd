class_name PixelProjectileImpact3D
extends Node3D
## One surface-agnostic, self-terminating bullet impact. Collision chooses the
## contact point and normal; this node owns only the brief visual response.

signal finished

const FRAME_COUNT := 4

@export_range(1.0, 60.0, 1.0) var frame_rate := 24.0
@export_range(0.0, 0.2, 0.005) var surface_offset := 0.025

var _elapsed := 0.0
var _playing := false

@onready var spark: Sprite3D = %Spark
@onready var fragments: Sprite3D = %Fragments


func _ready() -> void:
	add_to_group("projectile_impact")
	add_to_group("run_resettable")
	set_process(false)


func play_impact(world_position: Vector3, surface_normal: Vector3) -> void:
	var flat_normal := Vector3(surface_normal.x, surface_normal.y, 0.0)
	if flat_normal.is_zero_approx():
		flat_normal = Vector3.RIGHT
	else:
		flat_normal = flat_normal.normalized()
	global_position = world_position + flat_normal * surface_offset
	rotation = Vector3(0.0, 0.0, atan2(flat_normal.y, flat_normal.x))
	_elapsed = 0.0
	_playing = true
	spark.frame = 0
	fragments.frame = 0
	set_process(true)


func reset_run() -> void:
	_finish()


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var next_frame := floori(_elapsed * frame_rate)
	if next_frame >= FRAME_COUNT:
		_finish()
		return
	spark.frame = next_frame
	fragments.frame = next_frame


func _finish() -> void:
	if not _playing:
		return
	_playing = false
	set_process(false)
	finished.emit()
	queue_free()
