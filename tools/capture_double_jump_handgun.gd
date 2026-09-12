extends SceneTree
## Real-renderer pose review and a fixed-step recording of jump + fire.
## Paused readback keeps screenshot overhead out of the animation clock.

const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")
const OUTPUT := "res://build/previews/double_jump_handgun"
const OUTPUT_SIZE := Vector2i(1920, 1080)
const STEP := 1.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var game_root = load("res://scenes/app/game_root.tscn").instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var level := SHOOTER_AREA.load_into(game_root)
	var player := level.player
	var visual := player.pixel_visual
	(level.get_node("ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy") as HandgunEnemy3D).receive_melee_hit(player.global_position)
	assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	for frame in 40:
		await physics_frame
	for layer in game_root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false

	# Inspect all six source poses from both sides before the moving sequence.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(20.48, 3.0, 0.0)))
	level.camera.snap_to_target()
	paused = true
	for facing in [1.0, -1.0]:
		for frame in 6:
			visual.set_mouse_aim(false, 0.0)
			visual.set_weapon_presentation(PlayerWeapon.HANDGUN, &"", false)
			visual.set_state("double_jump", true)
			visual.tick_authored_state((frame + 0.1) / 14.0, "double_jump", facing > 0.0)
			player.player_handgun.update_mouse_aim(facing, player.global_position + Vector3(facing * 8.0, 1.6, 0.0))
			await _capture(level, "pose_%s_%d" % ["right" if facing > 0.0 else "left", frame])
	paused = false

	var shot_records: Array[Dictionary] = []
	player.projectile_fired.connect(func(round: HandgunProjectile3D) -> void:
		assert(round.global_position.is_equal_approx(visual.handgun_muzzle_world()))
		assert(round.travel_direction().is_equal_approx(player.player_handgun.aim_direction))
		shot_records.append({"state": visual.current_state(), "frame": visual.body.frame})
	)
	for facing in [1.0, -1.0]:
		player.reset_at(Transform3D(Basis.IDENTITY, Vector3(20.48, 0.7, 0.0)))
		player.player_handgun.reset_run()
		player.player_handgun._mouse_requested = true
		level.camera.snap_to_target()
		for frame in 8:
			await physics_frame
		var move_action := "move_right" if facing > 0.0 else "move_left"
		Input.action_press(move_action)
		_aim(level, facing)
		Input.action_press("jump")
		for frame in 6:
			await physics_frame
		Input.action_release("jump")
		for frame in 2:
			await physics_frame
		Input.action_press("jump")
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		assert(visual.current_state() == "double_jump")
		assert(player.player_handgun.mouse_aim_active)
		paused = true
		Input.action_release("attack")
		var side := "right" if facing > 0.0 else "left"
		for frame in 46:
			if frame > 0:
				_aim(level, facing)
				if frame == 18:
					Input.action_press("attack")
				elif frame == 19:
					Input.action_release("attack")
				player.player_handgun._physics_process(STEP)
				player._physics_process(STEP)
				for round in get_nodes_in_group("player_projectile"):
					if is_instance_valid(round):
						round._physics_process(STEP)
				level.camera.snap_to_target()
			if frame % 2 == 0:
				await _capture(level, "double_jump_%s_%02d" % [side, frame / 2])
		Input.action_release(move_action)
		Input.action_release("jump")
		Input.action_release("attack")
		for round in get_nodes_in_group("player_projectile"):
			round.reset_run()
		paused = false
	assert(shot_records.size() == 4)
	for record in shot_records:
		assert(record.state == "double_jump")
	var record_file := FileAccess.open(OUTPUT + "/shots.json", FileAccess.WRITE)
	record_file.store_string(JSON.stringify(shot_records, "\t"))
	print("Captured both flip facings and four shots during the live double-jump pose.")
	quit(0)


func _aim(level: LevelSession3D, facing: float) -> void:
	root.warp_mouse(level.camera.unproject_position(level.player.global_position + Vector3(8.0 * facing, 1.6, 0.0)))
	level.player.player_handgun._mouse_requested = true


func _capture(level: LevelSession3D, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var screen := root.get_texture().get_image()
	assert(screen != null, "Double-jump capture requires the real renderer.")
	var center: Vector2 = level.camera.unproject_position(level.player.global_position + Vector3(0.5, 0.3, 0.0))
	var region := Rect2i(Vector2i(center) - Vector2i(360, 200), Vector2i(720, 400))
	assert(Rect2i(Vector2i.ZERO, OUTPUT_SIZE).encloses(region))
	assert(screen.get_region(region).save_png(OUTPUT + "/" + file_name + ".png") == OK)
