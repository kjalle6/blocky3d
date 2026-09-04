extends SceneTree
## Captures the Level 3 WIP lift arrival, ravine opener, deceptive drop, short
## deep-cave encounter, long Wall Jump return, and the separate shooter area.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews"
const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")

var _impact_seen := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/dev/green_zone_finale_wip.tres"
	) as LevelDefinition
	game_root.load_developer_level(definition)
	for frame in 8:
		await physics_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null)
	await _capture(level, "level_3_wip_lift_start")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(15.8, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_double_jump_takeoff")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(32.64, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_first_dash_takeoff")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(53.12, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_second_dash_takeoff")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(69.76, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_spike_landing")

	# Pin the mixed encounter so this review frame does not depend on how much
	# time the preceding captures took.
	var runup_patrol := level.get_node("RunupPatrol") as StompableEnemy3D
	var runup_flyer := level.get_node("RunupFlyer") as HoveringHazard3D
	assert(runup_patrol != null and runup_flyer != null)
	runup_patrol.reset_run()
	runup_patrol.set_physics_process(false)
	runup_flyer.horizontal_phase = 0.4
	runup_flyer.reset_run()
	runup_flyer.set_physics_process(false)
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(88.32, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_enemy_runup")

	# Capture the ordinary look-ahead revealing the far lip during the attempt;
	# the route deliberately avoids a fixed takeoff camera lock.
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(115.2, 2.8, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_deceptive_gap")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(127.0, -4.0, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_background_boundary")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(127.0, -12.0, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_long_descent")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(132.48, -24.9, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_deep_run")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(157.44, -24.9, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_wall_jump_bottom")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(157.44, -7.0, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_wall_jump_material_join")

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(165.12, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_wall_jump_exit")

	level = SHOOTER_AREA.load_into(game_root)
	for frame in 8:
		await physics_frame
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(13.6, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_shooter_encounter")

	var intro := level.get_node(
		"ShooterEncounterStaging/ShooterIntro"
	) as GreenZoneShooterIntro3D
	var shooter := level.get_node(
		"ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy"
	) as HandgunEnemy3D
	var shooter_visual := (
		shooter.get_node("PixelVisual") as PixelHandgunEnemyVisual3D
	)
	var handgun_pickup := level.get_node(
		"ShooterEncounterStaging/GunDropAnchor/HandgunPickup"
	) as HandgunPickup3D
	var panic_marks := shooter_visual.get_node("PanicMarks") as Sprite3D
	var feedback := level.get_node("CombatFeedback") as CombatFeedback3D
	assert(
		intro != null
		and shooter != null
		and shooter_visual != null
		and handgun_pickup != null
		and panic_marks != null
		and feedback != null
	)
	_impact_seen = false
	feedback.projectile_impact_presented.connect(
		func(_position: Vector3, _normal: Vector3) -> void:
			_impact_seen = true
	)
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(3.84, 0.7, 0)))
	intro.play_from_start_for_review()
	for frame in 120:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.PLAYER_NOTICE:
			break
	assert(
		intro.current_phase() == GreenZoneShooterIntro3D.Phase.PLAYER_NOTICE,
		"Shooter-intro capture never reached the player-notice beat."
	)
	for frame in 30:
		await physics_frame
		if level.player.pixel_visual.body.frame == 5:
			break
	assert(
		intro.current_phase() == GreenZoneShooterIntro3D.Phase.PLAYER_NOTICE,
		"Shooter-intro player reaction ended before frame 6."
	)
	assert(level.player.pixel_visual.body.frame == 5)
	await _capture(level, "level_3_wip_shooter_intro_player_notice")

	for frame in 120:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_NOTICE:
			break
	assert(
		intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_NOTICE,
		"Shooter-intro capture never reached the enemy-notice beat."
	)
	for frame in 30:
		await physics_frame
		if panic_marks.visible:
			break
	assert(
		intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_NOTICE,
		"Shooter-intro enemy reaction ended before its panic mark."
	)
	assert(panic_marks.visible)
	await _capture(level, "level_3_wip_shooter_intro_enemy_notice")

	for frame in 60:
		await physics_frame
		if intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_AIM:
			break
	assert(
		intro.current_phase() == GreenZoneShooterIntro3D.Phase.ENEMY_AIM,
		"Shooter-intro capture never reached the enemy-aim beat."
	)
	await _capture(level, "level_3_wip_shooter_intro_enemy_aim")

	for frame in 240:
		await physics_frame
		if _impact_seen:
			break
	assert(_impact_seen, "Shooter-intro capture never reached the cover impact.")
	await _capture(level, "level_3_wip_shooter_intro_impact")

	for frame in 240:
		await physics_frame
		if intro.has_completed():
			break
	assert(intro.has_completed(), "Shooter intro must finish before drop review.")
	shooter.receive_melee_hit(level.player.global_position)
	for frame in 10:
		await physics_frame
	assert(handgun_pickup.is_airborne())
	await _capture(level, "level_3_wip_handgun_drop_airborne")
	for frame in 90:
		await physics_frame
		if handgun_pickup.is_available():
			break
	assert(handgun_pickup.is_available())
	await _capture(level, "level_3_wip_handgun_drop_settled")
	quit(0)


func _capture(level: LevelSession3D, file_name: String) -> void:
	level.camera.snap_to_target()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Level 3 WIP capture requires a graphical renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIRECTORY, file_name])
	assert(error == OK, "Could not save Level 3 WIP preview '%s'." % file_name)
