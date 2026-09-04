extends SceneTree
## Focused runtime contract for Level 3's first-shooter introduction. The
## camera isolates the player reaction, pans to the enemy's matching panic,
## then whips back on the first shot as the player reaches real cover.
## Completion requires both arrival and the full opening volley, regardless of
## which one finishes first.

const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")

var _completed := false
var _event_order: Array[StringName] = []


func _init() -> void:
	create_timer(20.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Green Zone shooter-intro validation aborted before completing.")
	quit(1)


func _run() -> void:
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var level := SHOOTER_AREA.load_into(game_root)
	for frame in 8:
		await physics_frame

	assert(level != null)
	assert(level == game_root.current_level)
	var intro := level.get_node(
		"ShooterEncounterStaging/ShooterIntro"
	) as GreenZoneShooterIntro3D
	var shooter := level.get_node(
		"ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy"
	) as HandgunEnemy3D
	var checkpoint := level.get_node(
		"Checkpoints/EncounterCheckpoint"
	) as LevelCheckpoint3D
	var reveal_anchor := level.get_node(
		"ShooterEncounterStaging/RevealCameraAnchor"
	) as Marker3D
	var notice_anchor := level.get_node(
		"ShooterEncounterStaging/PlayerNoticeAnchor"
	) as Marker3D
	var cover_anchor := level.get_node(
		"ShooterEncounterStaging/PlayerCoverAnchor"
	) as Marker3D
	var trigger_anchor := level.get_node(
		"ShooterEncounterStaging/IntroTriggerAnchor"
	) as Marker3D
	var respawn_anchor := level.get_node(
		"ShooterEncounterStaging/EncounterRespawnAnchor"
	) as Marker3D
	var gun_drop_anchor := level.get_node(
		"ShooterEncounterStaging/GunDropAnchor"
	) as Marker3D
	var spawn_point := level.get_node("SpawnPoint") as Marker3D
	var route_extent := level.get_node("RouteExtent") as RouteExtent3D
	var shooter_cover := level.get_node("Props/ShooterCover") as StaticBody3D
	assert(intro != null and shooter != null and checkpoint != null)
	var shooter_visual := (
		shooter.get_node("PixelVisual") as PixelHandgunEnemyVisual3D
	)
	var panic_marks := shooter_visual.get_node("PanicMarks") as Sprite3D
	assert(reveal_anchor != null and notice_anchor != null and cover_anchor != null)
	assert(trigger_anchor != null and respawn_anchor != null)
	assert(gun_drop_anchor != null and spawn_point != null)
	assert(route_extent != null and shooter_cover != null)
	assert(is_equal_approx(route_extent.route_start_x, 0.0))
	assert(is_equal_approx(route_extent.route_end_x, 40.96))
	assert(is_equal_approx(spawn_point.global_position.x, 0.64))
	assert(is_equal_approx(trigger_anchor.global_position.x, 5.12))
	assert(is_equal_approx(notice_anchor.global_position.x, 9.6))
	assert(is_equal_approx(cover_anchor.global_position.x, 13.6))
	assert(is_equal_approx(respawn_anchor.global_position.x, 12.8))
	assert(is_equal_approx(checkpoint.global_position.x, 12.8))
	assert(checkpoint.route_index == 1)
	assert(is_equal_approx(reveal_anchor.global_position.x, 23.04))
	assert(is_equal_approx(shooter_cover.global_position.x, 15.36))
	assert(is_equal_approx(shooter.global_position.x, 24.32))
	assert(is_equal_approx(gun_drop_anchor.global_position.x, 23.04))
	assert(shooter_visual != null and panic_marks != null)
	assert(intro.validation_errors().is_empty())
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.ARMED)
	assert(intro.trigger_is_armed())
	assert(not shooter.engagement_enabled())
	assert(is_equal_approx(shooter.facing_direction(), 1.0))
	assert(shooter_visual.texture.resource_path.ends_with("/handgun_idle.png"))
	assert(shooter_visual.current_state() == &"idle")
	assert(not panic_marks.visible)
	assert(level.camera.target == level.player)
	assert(is_equal_approx(level.camera.look_ahead, 5.76))
	assert(not checkpoint.is_activated())

	intro.reveal_started.connect(func() -> void: _event_order.append(&"approach"))
	intro.player_noticed.connect(func() -> void: _event_order.append(&"player"))
	intro.enemy_pan_started.connect(func() -> void: _event_order.append(&"pan"))
	intro.enemy_noticed.connect(func() -> void: _event_order.append(&"enemy"))
	intro.enemy_aim_started.connect(func() -> void: _event_order.append(&"aim"))
	intro.evade_started.connect(func() -> void: _event_order.append(&"evade"))
	intro.cover_arrived.connect(func() -> void: _event_order.append(&"cover"))
	intro.intro_completed.connect(func() -> void: _event_order.append(&"complete"))

	# First prove the volley may finish before a deliberately slow cover run,
	# without releasing either player input or the cinematic camera.
	intro.approach_focus_duration = 0.12
	intro.player_notice_duration = 0.36
	intro.enemy_pan_duration = 0.12
	intro.enemy_notice_duration = 0.36
	intro.opening_aim_duration = 0.18
	intro.approach_run_speed = 12.0
	intro.evade_run_speed = 4.0
	intro.minimum_evade_duration = 0.25
	shooter.telegraph_duration = 0.55
	level.player.reset_at(
		Transform3D(Basis.IDENTITY, Vector3(5.12, 0.7, 0))
	)

	for frame in 60:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.PLAYER_NOTICE:
			break
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.PLAYER_NOTICE)
	assert(_event_order == [&"approach", &"player"])
	assert(level.player.global_position.x >= notice_anchor.global_position.x - 0.1)
	assert(level.player.global_position.x < cover_anchor.global_position.x)
	assert(not level.player.is_transition_running())
	assert(not level.player.is_physics_processing())
	assert(level.player.pixel_visual.current_state() == "notice")
	assert(level.player.pixel_visual.body.texture.resource_path.ends_with(
		"/player_notice.png"
	))
	assert(level.player.pixel_visual.body.hframes == 6)
	assert(level.player.pixel_visual.body.frame == 0)
	assert(level.player.pixel_visual.weapon.visible)
	assert(level.player.pixel_visual.weapon.frame == 0)
	assert(not shooter.engagement_enabled())
	assert(is_equal_approx(shooter.facing_direction(), 1.0))
	assert(shooter_visual.current_state() == &"idle")
	assert(not panic_marks.visible)
	assert(intro.is_camera_override_active())
	assert(level.camera.target == reveal_anchor)
	assert(is_zero_approx(level.camera.look_ahead))
	assert(is_equal_approx(level.camera.size, intro.closeup_camera_size))
	assert(is_equal_approx(
		reveal_anchor.global_position.x,
		level.camera.minimum_center_x
	))

	# The deliberately sparse reaction reads normal -> frame 2 -> normal ->
	# frame 6, then holds the overhead mark until the first shot interrupts it.
	for frame in 7:
		await physics_frame
	assert(level.player.pixel_visual.body.frame == 1)
	for frame in 6:
		await physics_frame
	assert(level.player.pixel_visual.body.frame == 0)
	for frame in 6:
		await physics_frame
	assert(level.player.pixel_visual.body.frame == 5)
	assert(level.player.pixel_visual.weapon.frame == 0)

	for frame in 30:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.PAN_TO_ENEMY:
			break
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.PAN_TO_ENEMY)
	assert(_event_order == [&"approach", &"player", &"pan"])
	assert(level.player.pixel_visual.body.frame == 5)
	assert(not shooter.engagement_enabled())
	assert(shooter_visual.current_state() == &"idle")
	assert(not panic_marks.visible)
	assert(level.camera.target == reveal_anchor)
	assert(is_equal_approx(level.camera.size, intro.closeup_camera_size))

	for frame in 30:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_NOTICE:
			break
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_NOTICE)
	assert(_event_order == [&"approach", &"player", &"pan", &"enemy"])
	assert(not shooter.engagement_enabled())
	assert(shooter.is_holding_panic_pose())
	assert(is_equal_approx(shooter.facing_direction(), -1.0))
	assert(shooter_visual.current_state() == &"panic")
	assert(shooter_visual.texture.resource_path.ends_with("/handgun_idle.png"))
	assert(shooter_visual.frame == 0)
	assert(not panic_marks.visible)
	assert(is_equal_approx(panic_marks.position.x, 0.4))
	assert(is_equal_approx(
		reveal_anchor.global_position.x,
		23.04
	))

	var panic_rest_y := shooter_visual.position.y
	for frame in 7:
		await physics_frame
	assert(shooter_visual.frame == 1)
	assert(is_equal_approx(shooter_visual.position.y, panic_rest_y + 0.08))
	assert(not panic_marks.visible)
	for frame in 6:
		await physics_frame
	assert(shooter_visual.frame == 0)
	assert(is_equal_approx(shooter_visual.position.y, panic_rest_y))
	assert(not panic_marks.visible)
	for frame in 6:
		await physics_frame
	assert(shooter_visual.frame == 0)
	assert(panic_marks.visible)

	for frame in 30:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_AIM:
			break
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_AIM)
	assert(_event_order == [
		&"approach", &"player", &"pan", &"enemy", &"aim",
	])
	assert(shooter.engagement_enabled())
	assert(not shooter.is_holding_panic_pose())
	assert(shooter_visual.current_state() == &"telegraph")
	assert(shooter_visual.texture.resource_path.ends_with("/handgun_attack.png"))
	assert(shooter_visual.hframes == 9)
	assert(shooter_visual.frame == 0)
	assert(not panic_marks.visible)

	for frame in 60:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.EVADE:
			break
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.EVADE)
	assert(_event_order == [
		&"approach", &"player", &"pan", &"enemy", &"aim", &"evade",
	])
	assert(level.player.is_transition_running())
	await physics_frame
	assert(level.player.pixel_visual.current_state() == "run")

	for frame in 90:
		await physics_frame
		if intro.has_finished_opening_volley():
			break
	assert(intro.has_finished_opening_volley())
	assert(not intro.has_reached_cover())
	assert(not intro.has_completed())
	assert(intro.is_camera_override_active())
	assert(level.player.is_physics_processing())
	assert(level.camera.target == level.player)
	assert(is_equal_approx(level.camera.size, 12.9375))
	assert(is_equal_approx(level.camera.look_ahead, 5.76))
	assert(shooter.last_completed_volley_shot_count() == 6)
	assert(shooter.completed_volleys_total() == 1)

	for frame in 90:
		await physics_frame
		if intro.has_completed():
			break
	_assert_completed_intro(level, intro, shooter, checkpoint, cover_anchor)
	assert(_event_order == [
		&"approach", &"player", &"pan", &"enemy", &"aim", &"evade",
		&"cover", &"complete",
	])

	# Rearm the whole run, then prove a fast player can reach cover first and
	# remains held there until the still-active volley resolves.
	level.call(&"_reset_run")
	for frame in 6:
		await physics_frame
	assert(level.active_checkpoint_index() == -1)
	assert(not checkpoint.is_activated())
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.ARMED)
	assert(intro.trigger_is_armed())
	assert(not shooter.engagement_enabled())
	assert(is_equal_approx(shooter.facing_direction(), 1.0))
	_event_order.clear()
	intro.evade_run_speed = 16.0
	level.player.reset_at(
		Transform3D(Basis.IDENTITY, Vector3(5.12, 0.7, 0))
	)

	for frame in 150:
		await physics_frame
		if intro.has_reached_cover():
			break
	assert(intro.has_reached_cover())
	assert(not intro.has_finished_opening_volley())
	assert(not intro.has_completed())
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.EVADE)
	assert(not level.player.is_physics_processing())
	assert(intro.is_camera_override_active())
	assert(_event_order == [
		&"approach", &"player", &"pan", &"enemy", &"aim", &"evade",
		&"cover",
	])

	for frame in 90:
		await physics_frame
		if intro.has_completed():
			break
	_assert_completed_intro(level, intro, shooter, checkpoint, cover_anchor)
	assert(_event_order.back() == &"complete")

	# Death resumes the live fight behind cover without replaying any cinematic
	# beat. An explicit whole-run restart does rearm the original orientation.
	var event_count_before_death := _event_order.size()
	level.player.kill()
	for frame in 90:
		await physics_frame
		if not level.player.is_dead():
			break
	assert(not level.player.is_dead())
	assert(checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 1)
	assert(
		is_equal_approx(
			level.player.global_position.x,
			respawn_anchor.global_position.x
		)
	)
	assert(intro.has_completed())
	assert(not intro.trigger_is_armed())
	assert(shooter.engagement_enabled())
	assert(level.camera.target == level.player)
	assert(_event_order.size() == event_count_before_death)

	level.call(&"_reset_run")
	for frame in 6:
		await physics_frame
	assert(level.active_checkpoint_index() == -1)
	assert(not checkpoint.is_activated())
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.ARMED)
	assert(intro.trigger_is_armed())
	assert(not shooter.engagement_enabled())
	assert(is_equal_approx(shooter.facing_direction(), 1.0))
	assert(level.camera.target == level.player)
	assert(is_equal_approx(level.camera.look_ahead, 5.76))
	assert(is_equal_approx(level.camera.follow_response, 8.0))
	assert(is_equal_approx(level.camera.size, 12.9375))
	assert(is_equal_approx(reveal_anchor.global_position.x, 23.04))
	assert(not panic_marks.visible)

	print(
		"Green Zone shooter intro passed: player close-up, enemy panic pan, "
		+ "shot-driven camera whip, both cover/volley completion orders, "
		+ "checkpoint resume, and full restart."
	)
	_completed = true
	quit(0)


func _assert_completed_intro(
	level: LevelSession3D,
	intro: GreenZoneShooterIntro3D,
	shooter: HandgunEnemy3D,
	checkpoint: LevelCheckpoint3D,
	cover_anchor: Marker3D
) -> void:
	assert(intro.has_completed())
	assert(intro.has_reached_cover())
	assert(intro.has_finished_opening_volley())
	assert(intro.last_evade_duration() >= intro.minimum_evade_duration)
	assert(not intro.is_camera_override_active())
	assert(level.camera.target == level.player)
	assert(is_equal_approx(level.camera.look_ahead, 5.76))
	assert(is_equal_approx(level.camera.follow_response, 8.0))
	assert(is_equal_approx(level.camera.size, 12.9375))
	assert(level.player.is_physics_processing())
	assert(not level.player.is_transition_running())
	assert(level.player.global_position.x >= cover_anchor.global_position.x - 0.1)
	assert(level.player.global_position.x < 14.5)
	assert(shooter.engagement_enabled())
	assert(shooter.last_completed_volley_shot_count() == 6)
	assert(shooter.completed_volleys_total() == 1)
	assert(checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 1)
