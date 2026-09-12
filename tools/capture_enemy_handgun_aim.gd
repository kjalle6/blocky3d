extends SceneTree
## Render actual directional telegraphs and fire markers from both sides.
## Paused readback keeps capture time out of the animation clock.

const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")
const OUTPUT := "res://build/previews/enemy_handgun_aim"
const OUTPUT_SIZE := Vector2i(1920, 1080)


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
	var shortcut := game_root.world_list.get_node("GreenZoneFinaleWipGunEncounterButton") as Button
	shortcut.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_visible_rect().encloses(shortcut.get_global_rect()))
	assert(root.get_texture().get_image().save_png(OUTPUT + "/menu_shortcut.png") == OK)
	var level := SHOOTER_AREA.load_into(game_root)
	var shooter := level.get_node(
		"ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy"
	) as HandgunEnemy3D
	for frame in 8:
		await physics_frame
	for layer in game_root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	paused = true
	level.player.collision_layer = 0
	shooter.set_engagement_enabled(true)
	for facing in [-1.0, 1.0]:
		for vertical in [0.0, 1.0, -1.0]:
			shooter.reset_combat_cycle(true)
			var name := "%s_%s" % [
				"right" if facing > 0.0 else "left",
				"up" if vertical > 0.0 else ("down" if vertical < 0.0 else "forward")
			]
			# Move the real target above/below the enemy without altering the
			# enemy's pose directly. Its normal target selection drives the sheet.
			level.player.global_position = shooter.global_position + Vector3(facing * 1.8, vertical * 1.8, 0.0)
			level.player._facing_sign = -facing
			level.player.pixel_visual.set_state("jump" if vertical != 0.0 else "idle", true)
			level.player._update_pixel_visual(0.0)
			level.camera.snap_to_target()
			shooter._physics_process(0.0)
			assert(shooter.pixel_visual.current_state() == &"telegraph")
			await _capture(level, shooter, name + "_aim")
			shooter._phase_remaining = 0.0
			shooter._physics_process(0.0)
			assert(shooter.shots_fired_total() == 2)
			await _capture(level, shooter, name + "_flash")
			for step in 2:
				shooter._tick_shot_visual(0.05)
				for projectile in shooter._active_projectiles.duplicate():
					if is_instance_valid(projectile):
						projectile._physics_process(0.05)
				await _capture(level, shooter, name + ("_travel" if step == 0 else "_recoil"))
	shooter.clear_active_projectiles()
	await _capture_volleys(level, shooter)
	print("Captured forward, upward, and downward enemy fire from both sides.")
	quit(0)


func _capture_volleys(level: LevelSession3D, shooter: HandgunEnemy3D) -> void:
	level.player.global_position = shooter.global_position + Vector3(-3.84, 0.0, 0.0)
	level.player._facing_sign = 1.0
	level.player.pixel_visual.set_state("idle", true)
	level.player._update_pixel_visual(0.0)
	level.camera.snap_to_target()
	for pattern in [HandgunEnemy3D.FirePattern.TWIN, HandgunEnemy3D.FirePattern.TRIPLE]:
		shooter.set_fire_pattern(pattern)
		var prefix := "volley_twin" if pattern == HandgunEnemy3D.FirePattern.TWIN else "volley_triple"
		var idle_frames := 0
		var frame_count := 0
		for step in 90:
			await _capture(level, shooter, "%s_%02d" % [prefix, step])
			frame_count += 1
			if shooter.completed_volleys_total() > 0 and shooter._state == HandgunEnemy3D.CombatState.IDLE:
				idle_frames += 1
				if idle_frames >= 6:
					break
			for tick in 2:
				for projectile in shooter._active_projectiles.duplicate():
					if is_instance_valid(projectile):
						projectile._physics_process(1.0 / 60.0)
				if idle_frames == 0:
					shooter._physics_process(1.0 / 60.0)
					if shooter.completed_volleys_total() > 0 and shooter._state == HandgunEnemy3D.CombatState.IDLE:
						idle_frames = 1
		assert(shooter.completed_volleys_total() == 1)
		assert(idle_frames >= 6, "Capture must include the return to idle without starting another volley.")
		var record := FileAccess.open(OUTPUT + "/" + prefix + ".json", FileAccess.WRITE)
		record.store_string(JSON.stringify({"frames": frame_count, "fps": 30, "shots": shooter.shots_fired_total()}, "\t"))
		shooter.clear_active_projectiles()


func _capture(level: LevelSession3D, shooter: HandgunEnemy3D, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	assert(rendered != null, "Enemy aim review requires a graphical renderer.")
	var center: Vector2 = level.camera.unproject_position(shooter.global_position + Vector3(0.0, 0.5, 0.0))
	var crop := Rect2i(Vector2i(center) - Vector2i(320, 180), Vector2i(640, 360))
	assert(rendered.get_region(crop).save_png(OUTPUT + "/" + file_name + ".png") == OK)
