extends Node3D
## An exposed cave hoist assembled from the source-art scaffold, platform, and
## pulley parts. The carriage is a real AnimatableBody3D so the visual proof
## can also answer whether the player scale and ride feel make sense.

enum TravelState {
	IDLE_BOTTOM,
	BOARDING,
	ASCENDING,
	IDLE_TOP,
	RETURNING,
	DESCENDING,
}

const PIXEL_WORLD_SIZE := 0.04

@export_range(1.28, 20.48, 1.28) var travel_height := 12.8
@export_range(0.2, 8.0, 0.1) var travel_duration := 3.4
@export_range(0.0, 2.0, 0.05) var boarding_delay := 0.45
@export_range(0.0, 4.0, 0.05) var return_delay := 0.8
@export var starts_at_top := false
@export var trigger_on_boarding := true
## A receiving level can leave the carriage parked at its upper landing. The
## ordinary two-way lift keeps the original behavior and returns when empty.
@export var return_from_top_when_empty := true
@export var cable_top_y := 16.6
@export_category("Level exit")
## Empty keeps this a reusable two-way lift. Pointing at a manual LevelGoal3D
## turns the first ascent into a one-way departure and preserves the project's
## existing Goal -> LevelSession -> GameRoot completion/fade contract.
@export var exit_goal_path: NodePath
@export_range(0.0, 1.0, 0.01) var exit_trigger_progress := 0.1
## A level-exit rider must come fully aboard, release movement, and remain
## settled for this long. They choose where to stand; the lift only decides
## when that chosen position has become deliberate.
@export_range(0.25, 3.0, 0.05) var exit_still_duration := 1.0

@onready var carriage: AnimatableBody3D = $Carriage
@onready var carriage_visual: Node3D = $Carriage/Visual
@onready var boarding_area: Area3D = $Carriage/BoardingArea
@onready var left_cable: MeshInstance3D = $Cables/LeftCable
@onready var right_cable: MeshInstance3D = $Cables/RightCable

var _state := TravelState.IDLE_BOTTOM
var _state_time := 0.0
var _rider_count := 0
var _preview_locked := false
var _exit_goal: LevelGoal3D
var _exit_boarding_candidate: PlayerCharacter
var _exit_boarding_still_time := 0.0
var _committed_rider: PlayerCharacter
var _committed_rider_offset := Transform3D.IDENTITY
var _exit_completion_sent := false


func _ready() -> void:
	add_to_group("run_resettable")
	_exit_goal = null
	if not exit_goal_path.is_empty():
		_exit_goal = get_node_or_null(exit_goal_path) as LevelGoal3D
	boarding_area.body_entered.connect(_on_boarding_body_entered)
	boarding_area.body_exited.connect(_on_boarding_body_exited)
	var errors := validation_errors()
	assert(
		errors.is_empty(),
		"%s has invalid cave-lift settings:\n%s" % [name, "\n".join(errors)]
	)
	reset_run()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if travel_height <= 0.0:
		errors.append("Cave lift travel height must be positive.")
	if travel_duration <= 0.0:
		errors.append("Cave lift travel duration must be positive.")
	if cable_top_y <= travel_height:
		errors.append("Cave lift cable header must remain above the top landing.")
	if not exit_goal_path.is_empty() and _exit_goal == null:
		errors.append("Cave lift exit goal path must resolve to a LevelGoal3D.")
	return errors


func _physics_process(delta: float) -> void:
	if _preview_locked:
		return
	_update_exit_boarding(delta)
	_state_time += delta
	match _state:
		TravelState.IDLE_BOTTOM:
			_set_carriage_height(0.0)
		TravelState.BOARDING:
			_set_carriage_height(0.0)
			if _state_time >= boarding_delay:
				_change_state(TravelState.ASCENDING)
		TravelState.ASCENDING:
			var progress := clampf(_state_time / travel_duration, 0.0, 1.0)
			_set_carriage_height(travel_height * _smooth_step(progress))
			_maybe_complete_exit(progress)
			if progress >= 1.0:
				_change_state(TravelState.IDLE_TOP)
		TravelState.IDLE_TOP:
			_set_carriage_height(travel_height)
			if return_from_top_when_empty and _rider_count <= 0:
				_change_state(TravelState.RETURNING)
		TravelState.RETURNING:
			_set_carriage_height(travel_height)
			if _state_time >= return_delay:
				_change_state(TravelState.DESCENDING)
		TravelState.DESCENDING:
			var progress := clampf(_state_time / travel_duration, 0.0, 1.0)
			_set_carriage_height(
				travel_height * (1.0 - _smooth_step(progress))
			)
			if progress >= 1.0:
				_change_state(TravelState.IDLE_BOTTOM)
	_update_motor_vibration()


func begin_travel() -> void:
	if _preview_locked:
		_preview_locked = false
	if _state == TravelState.IDLE_BOTTOM:
		_change_state(TravelState.BOARDING)


func reset_run() -> void:
	_preview_locked = false
	_rider_count = 0
	_exit_boarding_candidate = null
	_exit_boarding_still_time = 0.0
	_committed_rider = null
	_committed_rider_offset = Transform3D.IDENTITY
	_exit_completion_sent = false
	_change_state(
		TravelState.IDLE_TOP if starts_at_top else TravelState.IDLE_BOTTOM
	)
	_set_carriage_height(travel_height if starts_at_top else 0.0)
	carriage_visual.position.x = 0.0


func preview_travel_progress(progress: float) -> void:
	_preview_locked = true
	_state = TravelState.ASCENDING
	_state_time = clampf(progress, 0.0, 1.0) * travel_duration
	_set_carriage_height(preview_height_for_progress(progress))
	carriage_visual.position.x = 0.0


func preview_height_for_progress(progress: float) -> float:
	return snappedf(
		travel_height * _smooth_step(clampf(progress, 0.0, 1.0)),
		PIXEL_WORLD_SIZE
	)


func travel_progress() -> float:
	return clampf(carriage.position.y / travel_height, 0.0, 1.0)


func is_moving() -> bool:
	return _state == TravelState.ASCENDING or _state == TravelState.DESCENDING


func _change_state(next_state: TravelState) -> void:
	_state = next_state
	_state_time = 0.0


func _set_carriage_height(height: float) -> void:
	var snapped_height := snappedf(
		clampf(height, 0.0, travel_height),
		PIXEL_WORLD_SIZE
	)
	carriage.position.y = snapped_height
	_update_cables(snapped_height)
	_sync_committed_rider()


func _maybe_complete_exit(progress: float) -> void:
	if (
		_exit_goal == null
		or _committed_rider == null
		or _exit_completion_sent
		or progress < exit_trigger_progress
	):
		return
	_exit_completion_sent = true
	_exit_goal.reach(_committed_rider)


func _update_exit_boarding(delta: float) -> void:
	if (
		_exit_goal == null
		or _state != TravelState.IDLE_BOTTOM
		or _committed_rider != null
	):
		return
	if not is_instance_valid(_exit_boarding_candidate):
		_exit_boarding_candidate = null
		_exit_boarding_still_time = 0.0
		return
	if (
		not _rider_is_fully_supported(_exit_boarding_candidate)
		or not _exit_boarding_candidate.is_on_floor()
		or absf(_exit_boarding_candidate.horizontal_speed) > 0.15
		or absf(_exit_boarding_candidate.velocity.x) > 0.15
	):
		_exit_boarding_still_time = 0.0
		return
	_exit_boarding_still_time += delta
	if _exit_boarding_still_time < exit_still_duration:
		return
	_commit_exit_rider(_exit_boarding_candidate)
	if trigger_on_boarding:
		begin_travel()


func _rider_is_fully_supported(rider: PlayerCharacter) -> bool:
	var carriage_collision := carriage.get_node("Collision") as CollisionShape3D
	var rider_collision := rider.get_node("CollisionShape3D") as CollisionShape3D
	var carriage_shape := carriage_collision.shape as BoxShape3D
	var rider_shape := rider_collision.shape as BoxShape3D
	if carriage_shape == null or rider_shape == null:
		return false
	var supported_half_width := (
		carriage_shape.size.x * 0.5 - rider_shape.size.x * 0.5
	)
	return absf(carriage.to_local(rider.global_position).x) <= (
		supported_half_width + 0.001
	)


func _commit_exit_rider(rider: PlayerCharacter) -> void:
	_committed_rider = rider
	_committed_rider_offset = (
		_carriage_world_transform().affine_inverse()
		* _committed_rider.global_transform
	)
	_committed_rider.stop_for_completion()


func _sync_committed_rider() -> void:
	if not is_instance_valid(_committed_rider):
		_committed_rider = null
		return
	_committed_rider.global_transform = (
		_carriage_world_transform() * _committed_rider_offset
	)


## AnimatableBody3D synchronizes its physics transform after its authored Node3D
## transform. Compose from the lift and local carriage transforms so the rider
## follows the same frame as the rendered deck, without a one-pixel lag.
func _carriage_world_transform() -> Transform3D:
	return global_transform * carriage.transform


func _update_cables(carriage_height: float) -> void:
	var cable_bottom_y := carriage_height + 0.38
	var cable_length := maxf(PIXEL_WORLD_SIZE, cable_top_y - cable_bottom_y)
	var cable_center_y := cable_bottom_y + cable_length * 0.5
	for cable in [left_cable, right_cable]:
		var mesh := cable.mesh as QuadMesh
		mesh.size = Vector2(0.08, cable_length)
		cable.position.y = cable_center_y


func _update_motor_vibration() -> void:
	if not is_moving():
		carriage_visual.position.x = 0.0
		return
	carriage_visual.position.x = (
		PIXEL_WORLD_SIZE
		if int(floor(_state_time * 18.0)) % 2 == 0
		else -PIXEL_WORLD_SIZE
	)


func _smooth_step(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)


func _on_boarding_body_entered(body: Node3D) -> void:
	if not body is PlayerCharacter:
		return
	_rider_count += 1
	if _exit_goal != null:
		if _committed_rider == null:
			_exit_boarding_candidate = body as PlayerCharacter
			_exit_boarding_still_time = 0.0
		return
	if trigger_on_boarding:
		begin_travel()


func _on_boarding_body_exited(body: Node3D) -> void:
	if not body is PlayerCharacter:
		return
	_rider_count = maxi(_rider_count - 1, 0)
	if body == _exit_boarding_candidate and _committed_rider == null:
		_exit_boarding_candidate = null
		_exit_boarding_still_time = 0.0
