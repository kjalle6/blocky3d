class_name GreenZoneShooterIntro3D
extends Node3D
## Orchestrates Green Zone's mutual-surprise reveal and first run to cover.
## Gameplay actors keep ownership of movement, collision, firing, and reset;
## this node only sequences their public contracts and a temporary camera rig.

signal reveal_started
signal player_noticed
signal enemy_pan_started
signal enemy_noticed
signal enemy_aim_started
signal evade_started
signal cover_arrived
signal intro_completed

enum Phase {
	ARMED,
	PENDING_GROUND,
	APPROACH,
	PLAYER_NOTICE,
	PAN_TO_ENEMY,
	ENEMY_NOTICE,
	ENEMY_AIM,
	EVADE,
	COMPLETE,
}

@export var level_session_path: NodePath
@export var player_path: NodePath
@export var camera_path: NodePath
@export var trigger_path: NodePath
## Authored at the final enemy close-up center, then moved as the temporary
## camera target while the cutscene is active.
@export var reveal_camera_anchor_path: NodePath
@export var player_notice_anchor_path: NodePath
@export var player_cover_anchor_path: NodePath
@export var shooter_path: NodePath
@export var encounter_checkpoint_path: NodePath

@export_category("Timing")
@export_range(1.0, 16.0, 0.1) var approach_run_speed := 8.0
@export_range(0.1, 1.5, 0.01) var approach_focus_duration := 0.48
@export_range(0.3, 1.0, 0.01) var player_notice_duration := 0.48
@export_range(0.15, 1.0, 0.01) var enemy_pan_duration := 0.42
@export_range(0.3, 1.0, 0.01) var enemy_notice_duration := 0.45
@export_range(0.1, 1.0, 0.01) var opening_aim_duration := 0.32
@export_range(1.0, 16.0, 0.1) var evade_run_speed := 8.0
## Prevents control returning on the same frame that the player reaches cover.
@export_range(0.1, 2.0, 0.01) var minimum_evade_duration := 0.6

@export_category("Camera choreography")
@export_range(4.0, 12.0, 0.1) var closeup_camera_size := 8.0
@export_range(8.0, 60.0, 1.0) var cinematic_follow_response := 30.0
@export_range(0.08, 0.5, 0.01) var camera_whip_duration := 0.16
@export_range(0.15, 1.0, 0.01) var camera_zoom_out_duration := 0.35

@onready var level_session := (
	get_node_or_null(level_session_path) as LevelSession3D
)
@onready var player := get_node_or_null(player_path) as PlayerCharacter
@onready var camera := get_node_or_null(camera_path) as PixelSideCamera3D
@onready var trigger := get_node_or_null(trigger_path) as Area3D
@onready var reveal_camera_anchor := (
	get_node_or_null(reveal_camera_anchor_path) as Marker3D
)
@onready var player_notice_anchor := (
	get_node_or_null(player_notice_anchor_path) as Marker3D
)
@onready var player_cover_anchor := (
	get_node_or_null(player_cover_anchor_path) as Marker3D
)
@onready var shooter := get_node_or_null(shooter_path) as HandgunEnemy3D
@onready var encounter_checkpoint := (
	get_node_or_null(encounter_checkpoint_path) as LevelCheckpoint3D
)

var _phase := Phase.ARMED
var _phase_elapsed := 0.0
var _first_shot_received := false
var _evade_elapsed := 0.0
var _last_evade_duration := 0.0
var _evade_direction := 1.0
var _cover_reached := false
var _volley_finished := false
var _trigger_enabled := false
var _camera_override_active := false
var _previous_camera_target: Node3D
var _previous_camera_look_ahead := 0.0
var _previous_camera_follow_response := 0.0
var _previous_camera_size := 0.0
var _camera_driver_authored_position := Vector3.ZERO
var _camera_focus_start_x := 0.0
var _camera_focus_start_size := 0.0
var _camera_player_center_x := 0.0
var _camera_enemy_center_x := 0.0
var _camera_whip_start_x := 0.0
var _camera_whip_start_size := 0.0
var _camera_whip_elapsed := 0.0


func _ready() -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self): return
	var errors := validation_errors()
	assert(
		errors.is_empty(),
		"Green Zone shooter intro is invalid:\n%s" % "\n".join(errors)
	)
	_camera_driver_authored_position = reveal_camera_anchor.global_position
	_camera_enemy_center_x = clampf(
		_camera_driver_authored_position.x,
		camera.minimum_center_x,
		camera.maximum_center_x
	)
	trigger.body_entered.connect(_on_trigger_body_entered)
	shooter.shot_fired.connect(_on_shot_fired)
	shooter.volley_completed.connect(_on_volley_completed)
	level_session.run_reset.connect(_on_level_session_run_reset)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.PENDING_GROUND:
			if player.is_dead():
				return
			if player.is_on_floor():
				_begin_approach()
		Phase.APPROACH:
			_phase_elapsed += delta
			_tick_player_focus_camera()
			if (
				_phase_elapsed >= approach_focus_duration
				and _has_reached_anchor(player_notice_anchor, 1.0)
			):
				_begin_player_notice()
		Phase.PLAYER_NOTICE:
			_phase_elapsed += delta
			player.pixel_visual.tick_authored_state(
				delta,
				"notice",
				shooter.global_position.x >= player.global_position.x
			)
			if _phase_elapsed >= player_notice_duration:
				_begin_enemy_pan()
		Phase.PAN_TO_ENEMY:
			_phase_elapsed += delta
			_tick_enemy_pan_camera()
			if _phase_elapsed >= enemy_pan_duration:
				_begin_enemy_notice()
		Phase.ENEMY_NOTICE:
			_phase_elapsed += delta
			if _phase_elapsed >= enemy_notice_duration:
				_begin_enemy_aim()
		Phase.ENEMY_AIM:
			_phase_elapsed += delta
		Phase.EVADE:
			_evade_elapsed += delta
			_tick_evade_camera(delta)
			if (
				not _cover_reached
				and _has_reached_anchor(player_cover_anchor, _evade_direction)
			):
				_reach_cover()
			_try_complete_intro()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var resolved_level := get_node_or_null(level_session_path) as LevelSession3D
	var resolved_player := get_node_or_null(player_path) as PlayerCharacter
	var resolved_camera := get_node_or_null(camera_path) as PixelSideCamera3D
	var resolved_trigger := get_node_or_null(trigger_path) as Area3D
	var resolved_reveal := get_node_or_null(reveal_camera_anchor_path) as Marker3D
	var resolved_notice := get_node_or_null(player_notice_anchor_path) as Marker3D
	var resolved_cover := get_node_or_null(player_cover_anchor_path) as Marker3D
	var resolved_shooter := get_node_or_null(shooter_path) as HandgunEnemy3D
	var resolved_checkpoint := (
		get_node_or_null(encounter_checkpoint_path) as LevelCheckpoint3D
	)
	if resolved_level == null:
		errors.append("level_session_path must resolve to LevelSession3D.")
	if resolved_player == null:
		errors.append("player_path must resolve to PlayerCharacter.")
	elif not resolved_player.has_method(&"finish_transition_run"):
		errors.append("PlayerCharacter must provide finish_transition_run().")
	if resolved_camera == null:
		errors.append("camera_path must resolve to PixelSideCamera3D.")
	if resolved_trigger == null:
		errors.append("trigger_path must resolve to Area3D.")
	if resolved_reveal == null:
		errors.append("reveal_camera_anchor_path must resolve to Marker3D.")
	if resolved_notice == null:
		errors.append("player_notice_anchor_path must resolve to Marker3D.")
	if resolved_cover == null:
		errors.append("player_cover_anchor_path must resolve to Marker3D.")
	if resolved_shooter == null:
		errors.append("shooter_path must resolve to HandgunEnemy3D.")
	else:
		if not resolved_shooter.has_method(&"begin_encounter"):
			errors.append("HandgunEnemy3D must provide begin_encounter().")
		if not resolved_shooter.has_method(&"panic_at_player"):
			errors.append("HandgunEnemy3D must provide panic_at_player().")
		if not resolved_shooter.has_method(&"set_engagement_enabled"):
			errors.append(
				"HandgunEnemy3D must provide set_engagement_enabled()."
			)
	if resolved_checkpoint == null:
		errors.append(
			"encounter_checkpoint_path must resolve to LevelCheckpoint3D."
		)
	if approach_run_speed <= 0.0:
		errors.append("Approach run speed must be positive.")
	if approach_focus_duration <= 0.0:
		errors.append("Approach focus duration must be positive.")
	if player_notice_duration < 0.3:
		errors.append("Player notice must reach its overhead-mark frame.")
	if enemy_pan_duration <= 0.0:
		errors.append("Enemy pan duration must be positive.")
	if enemy_notice_duration < 0.3:
		errors.append("Enemy notice must reach its overhead-mark frame.")
	if opening_aim_duration <= 0.0:
		errors.append("Opening aim duration must be positive.")
	if evade_run_speed <= 0.0:
		errors.append("Evade run speed must be positive.")
	if minimum_evade_duration <= 0.0:
		errors.append("Minimum evade duration must be positive.")
	if closeup_camera_size <= 0.0:
		errors.append("Close-up camera size must be positive.")
	if cinematic_follow_response <= 0.0:
		errors.append("Cinematic follow response must be positive.")
	if camera_whip_duration <= 0.0:
		errors.append("Camera whip duration must be positive.")
	if camera_zoom_out_duration < camera_whip_duration:
		errors.append("Camera zoom-out duration cannot be shorter than the whip.")
	if resolved_trigger != null and resolved_notice != null:
		if resolved_notice.global_position.x <= resolved_trigger.global_position.x:
			errors.append("Player notice anchor must be to the right of the trigger.")
	if resolved_notice != null and resolved_cover != null:
		if resolved_cover.global_position.x <= resolved_notice.global_position.x:
			errors.append("Player cover anchor must be right of the notice anchor.")
	if resolved_notice != null and resolved_reveal != null:
		if resolved_reveal.global_position.x <= resolved_notice.global_position.x:
			errors.append("Enemy camera anchor must be right of the player notice.")
	return errors


func current_phase() -> Phase:
	return _phase


func has_completed() -> bool:
	return _phase == Phase.COMPLETE


func is_camera_override_active() -> bool:
	return _camera_override_active


func reveal_progress() -> float:
	if _phase == Phase.APPROACH:
		return clampf(
			_phase_elapsed / approach_focus_duration,
			0.0,
			1.0
		)
	return 1.0 if _phase > Phase.APPROACH else 0.0


func last_evade_duration() -> float:
	return _last_evade_duration


func has_reached_cover() -> bool:
	return _cover_reached


func has_finished_opening_volley() -> bool:
	return _volley_finished


func trigger_is_armed() -> bool:
	return _phase == Phase.ARMED and _trigger_enabled


## Starts the authored sequence without requiring a physics overlap. Focused
## validators use this to exercise the same path as the live trigger.
func play_from_start_for_review() -> void:
	set_physics_process(true)
	_cancel_active_sequence()
	_set_shooter_engagement(false)
	_set_trigger_enabled(false)
	_phase = Phase.ARMED
	_begin_approach()


## Places the sequence at the enemy's close-up panic composition without
## firing. Capture scripts may snap the camera after this call.
func preview_reveal_composition() -> void:
	_cancel_active_sequence()
	_set_shooter_engagement(false)
	_set_trigger_enabled(false)
	_phase = Phase.ENEMY_NOTICE
	_phase_elapsed = 0.0
	player.stop_for_completion()
	_activate_camera_override()
	_set_camera_driver_x(_camera_enemy_center_x)
	camera.size = closeup_camera_size
	shooter.panic_at_player()
	set_physics_process(false)


func resume_from_preview() -> void:
	if is_physics_processing():
		return
	set_physics_process(true)
	_on_level_session_run_reset()


func _on_trigger_body_entered(body: Node3D) -> void:
	if _phase != Phase.ARMED or body != player or player.is_dead():
		return
	_set_trigger_enabled(false)
	if player.is_on_floor():
		_begin_approach()
	else:
		_phase = Phase.PENDING_GROUND


func _begin_approach() -> void:
	if _phase not in [Phase.ARMED, Phase.PENDING_GROUND]:
		return
	_phase = Phase.APPROACH
	_phase_elapsed = 0.0
	_first_shot_received = false
	_evade_elapsed = 0.0
	_last_evade_duration = 0.0
	_cover_reached = false
	_volley_finished = false
	player.begin_transition_run(
		1.0,
		approach_run_speed,
		_scripted_run_safety_duration(player_cover_anchor, approach_run_speed)
	)
	_activate_camera_override()
	reveal_started.emit()


func _begin_player_notice() -> void:
	if _phase != Phase.APPROACH:
		return
	_phase = Phase.PLAYER_NOTICE
	_phase_elapsed = 0.0
	_set_camera_driver_x(_camera_player_center_x)
	camera.size = closeup_camera_size
	player.call(&"finish_transition_run")
	player.stop_for_completion()
	player.pixel_visual.tick_authored_state(
		0.0,
		"notice",
		shooter.global_position.x >= player.global_position.x
	)
	player_noticed.emit()


func _begin_enemy_pan() -> void:
	if _phase != Phase.PLAYER_NOTICE:
		return
	_phase = Phase.PAN_TO_ENEMY
	_phase_elapsed = 0.0
	_set_camera_driver_x(_camera_player_center_x)
	camera.size = closeup_camera_size
	enemy_pan_started.emit()


func _begin_enemy_notice() -> void:
	if _phase != Phase.PAN_TO_ENEMY:
		return
	_phase = Phase.ENEMY_NOTICE
	_phase_elapsed = 0.0
	_set_camera_driver_x(_camera_enemy_center_x)
	camera.size = closeup_camera_size
	shooter.panic_at_player()
	enemy_noticed.emit()


func _begin_enemy_aim() -> void:
	if _phase != Phase.ENEMY_NOTICE:
		return
	_phase = Phase.ENEMY_AIM
	_phase_elapsed = 0.0
	shooter.begin_encounter(opening_aim_duration)
	enemy_aim_started.emit()


func _on_shot_fired(_projectile: HandgunProjectile3D) -> void:
	# Both guns emit shot_fired during the same beat. The first muzzle flash owns
	# the single whip back to the player and the start of the cover run.
	if _phase != Phase.ENEMY_AIM or _first_shot_received:
		return
	_first_shot_received = true
	_phase = Phase.EVADE
	_evade_elapsed = 0.0
	_camera_whip_elapsed = 0.0
	_camera_whip_start_x = reveal_camera_anchor.global_position.x
	_camera_whip_start_size = camera.size
	var horizontal_distance := (
		player_cover_anchor.global_position.x - player.global_position.x
	)
	_evade_direction = signf(horizontal_distance)
	if is_zero_approx(_evade_direction):
		_evade_direction = 1.0
	player.begin_transition_run(
		_evade_direction,
		evade_run_speed,
		_scripted_run_safety_duration(player_cover_anchor, evade_run_speed)
	)
	evade_started.emit()


func _on_volley_completed(
	_pattern: int,
	_shot_count: int
) -> void:
	if _phase != Phase.EVADE:
		return
	_volley_finished = true
	_try_complete_intro()


func _reach_cover() -> void:
	_cover_reached = true
	player.stop_for_completion()
	cover_arrived.emit()


func _try_complete_intro() -> void:
	if (
		_phase != Phase.EVADE
		or not _cover_reached
		or not _volley_finished
		or _evade_elapsed < minimum_evade_duration
	):
		return
	_complete_intro()


func _complete_intro() -> void:
	if _phase == Phase.COMPLETE:
		return
	_phase = Phase.COMPLETE
	_last_evade_duration = _evade_elapsed
	player.call(&"finish_transition_run")
	_restore_camera()
	_set_trigger_enabled(false)
	if level_session.save_state != null:
		level_session.save_state.mark_world_flag("green_zone_shooter_intro")
	intro_completed.emit()


func _on_level_session_run_reset() -> void:
	set_physics_process(true)
	_cancel_active_sequence()
	if encounter_checkpoint.is_activated() or (level_session.save_state != null and level_session.save_state.world_flags.get("green_zone_shooter_intro", false)):
		_phase = Phase.COMPLETE
		_set_trigger_enabled(false)
		_set_shooter_engagement(true)
	else:
		_phase = Phase.ARMED
		_set_trigger_enabled(true)
		_set_shooter_engagement(false)


func _cancel_active_sequence() -> void:
	_phase_elapsed = 0.0
	_first_shot_received = false
	_evade_elapsed = 0.0
	_last_evade_duration = 0.0
	_evade_direction = 1.0
	_cover_reached = false
	_volley_finished = false
	_camera_whip_elapsed = 0.0
	if player != null and player.has_method(&"finish_transition_run"):
		player.call(&"finish_transition_run")
	_restore_camera()


func _activate_camera_override() -> void:
	if _camera_override_active:
		return
	_camera_override_active = true
	camera.cinematic_override_enabled = true
	_previous_camera_target = camera.target
	_previous_camera_look_ahead = camera.look_ahead
	_previous_camera_follow_response = camera.follow_response
	_previous_camera_size = camera.size
	_camera_focus_start_x = camera.global_position.x
	_camera_focus_start_size = camera.size
	_camera_player_center_x = clampf(
		player_notice_anchor.global_position.x,
		camera.minimum_center_x,
		camera.maximum_center_x
	)
	_set_camera_driver_x(_camera_focus_start_x)
	camera.target = reveal_camera_anchor
	camera.look_ahead = 0.0
	camera.follow_response = cinematic_follow_response


func _tick_player_focus_camera() -> void:
	var progress := _smooth_progress(
		_phase_elapsed / approach_focus_duration
	)
	_set_camera_driver_x(lerpf(
		_camera_focus_start_x,
		_camera_player_center_x,
		progress
	))
	camera.size = lerpf(
		_camera_focus_start_size,
		closeup_camera_size,
		progress
	)


func _tick_enemy_pan_camera() -> void:
	var progress := _smooth_progress(_phase_elapsed / enemy_pan_duration)
	_set_camera_driver_x(lerpf(
		_camera_player_center_x,
		_camera_enemy_center_x,
		progress
	))
	camera.size = closeup_camera_size


func _tick_evade_camera(delta: float) -> void:
	_camera_whip_elapsed += delta
	var whip_progress := _smooth_progress(
		_camera_whip_elapsed / camera_whip_duration
	)
	if _camera_whip_elapsed <= camera_whip_duration:
		_set_camera_driver_x(lerpf(
			_camera_whip_start_x,
			_camera_player_center_x,
			whip_progress
		))
	else:
		_set_camera_driver_x(_camera_player_center_x)
		if camera.target == reveal_camera_anchor:
			camera.target = player
	var zoom_progress := _smooth_progress(
		_camera_whip_elapsed / camera_zoom_out_duration
	)
	camera.size = lerpf(
		_camera_whip_start_size,
		_previous_camera_size,
		zoom_progress
	)
	if camera.target == player:
		var look_progress := clampf(
			(_camera_whip_elapsed - camera_whip_duration)
			/ maxf(camera_zoom_out_duration - camera_whip_duration, 0.001),
			0.0,
			1.0
		)
		camera.look_ahead = lerpf(
			0.0,
			_previous_camera_look_ahead,
			_smooth_progress(look_progress)
		)
	if _camera_whip_elapsed >= camera_zoom_out_duration:
		camera.follow_response = _previous_camera_follow_response


func _restore_camera() -> void:
	if not _camera_override_active or camera == null:
		return
	_camera_override_active = false
	camera.cinematic_override_enabled = false
	camera.target = (
		_previous_camera_target
		if is_instance_valid(_previous_camera_target)
		else player
	)
	camera.look_ahead = _previous_camera_look_ahead
	camera.follow_response = _previous_camera_follow_response
	camera.size = _previous_camera_size
	reveal_camera_anchor.global_position = _camera_driver_authored_position
	_previous_camera_target = null


func _set_camera_driver_x(world_x: float) -> void:
	var next_position := reveal_camera_anchor.global_position
	next_position.x = world_x
	reveal_camera_anchor.global_position = next_position


func _smooth_progress(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _set_trigger_enabled(enabled: bool) -> void:
	_trigger_enabled = enabled
	if trigger != null:
		trigger.set_deferred(&"monitoring", enabled)


func _set_shooter_engagement(enabled: bool) -> void:
	if shooter != null and shooter.has_method(&"set_engagement_enabled"):
		shooter.call(&"set_engagement_enabled", enabled)


func _has_reached_anchor(anchor: Marker3D, direction: float) -> bool:
	const POSITION_EPSILON := 0.08
	var remaining := anchor.global_position.x - player.global_position.x
	return remaining * direction <= POSITION_EPSILON


func _scripted_run_safety_duration(anchor: Marker3D, speed: float) -> float:
	return maxf(
		absf(anchor.global_position.x - player.global_position.x) / speed + 2.0,
		2.5
	)


func _exit_tree() -> void:
	_restore_camera()
