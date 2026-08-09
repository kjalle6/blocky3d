extends SceneTree
## Deterministic 1920 x 1080 review frames for production World 1 / Level 1.

const OUTPUT_SIZE := Vector2i(1920, 1080)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/previews")
	)
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null, "The application root must load for capture.")
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 8:
		await process_frame

	var definition := load(
		"res://resources/campaign/level_01.tres"
	) as LevelDefinition
	game_root.load_level(definition.level_id)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null, "Arrival / Shoreline must instantiate for capture.")
	game_root.get_node("Interface").visible = false
	for frame in 10:
		await physics_frame
	_freeze_enemies(level)

	await _capture_at(level, "arrival_slice_01_opening", Vector3(3.2, 0.7, 0))
	await _capture_shore_wave(level)
	await _capture_background_only(level, "arrival_background_01_opening")
	await _capture_water_death(level)
	await _capture_at(level, "arrival_slice_02_fundamentals", Vector3(17.2, 1.34, 0))
	await _capture_at(
		level,
		"arrival_slice_02a_outcrop_readability",
		Vector3(14.5, 1.34, 0)
	)
	await _capture_background_only(level, "arrival_background_02_transition")
	await _capture_at(
		level,
		"arrival_slice_02b_established_inland",
		Vector3(24.0, 1.34, 0)
	)
	await _capture_background_only(level, "arrival_background_03_inland")
	await _capture_at(
		level,
		"arrival_slice_03_green_threshold",
		Vector3(29.6, 1.34, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_04_threshold_unlock",
		Vector3(36.2, 1.34, 0)
	)

	level.unlock_ability(PlayerAbility.DOUBLE_JUMP)
	(level.get_node("DoubleJumpPickup") as Node3D).visible = false
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(47.36, 4.54, 0)))
	level.player.set_physics_process(false)
	level.player.pixel_visual.tick(
		0.12,
		false,
		8.0,
		14.0,
		false,
		false,
		true,
		true
	)
	level.camera.snap_to_target()
	await _capture("arrival_slice_05_double_jump_proof")

	await _capture_at(
		level,
		"arrival_slice_06_threshold_landing",
		Vector3(56.0, 1.98, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_07_thorn_garden_entry",
		Vector3(73.6, 1.34, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_08_thorn_basin",
		Vector3(88.4, 2.62, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_08a_terrace_gate_crossing",
		Vector3(90.24, 2.62, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_09_thorn_pocket",
		Vector3(92.2, 2.62, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_10_thorn_wall",
		Vector3(101.0, 3.9, 0)
	)
	await _capture_wall_gate_crossing(level)
	await _capture_at(
		level,
		"arrival_slice_11_garden_exit",
		Vector3(119.0, 1.34, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_12_canopy_root",
		Vector3(132.48, 1.98, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_13_canopy_height",
		Vector3(141.44, 5.18, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_14_canopy_recovery",
		Vector3(149.4, 3.9, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_15_canopy_timing",
		Vector3(159.36, 7.1, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_16_canopy_crown",
		Vector3(168.0, 6.46, 0)
	)
	await _capture_at(
		level,
		"arrival_slice_17_right_clamp",
		Vector3(170.88, 6.46, 0)
	)
	await _capture_background_only(level, "arrival_background_04_right_clamp")
	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _capture_water_death(level: LevelSession3D) -> void:
	level.player.reset_at(
		Transform3D(Basis.IDENTITY, Vector3(-0.7, 0.2, 0))
	)
	level.player.kill(PlayerCharacter.DEATH_KIND_WATER)
	level.player.set_physics_process(false)
	var splash := level.get_node("WaterDeathSplash") as PixelWaterDeathSplash3D
	splash.sprite.frame = 1
	splash.set_process(false)
	level.camera.snap_to_target()
	await _capture("arrival_slice_01b_water_death")
	level._reset_run()
	splash.set_process(true)
	await process_frame


func _capture_shore_wave(level: LevelSession3D) -> void:
	var wave := level.get_node("ShoreWave") as PixelShoreWave3D
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(3.2, 0.7, 0)))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	assert(wave.crest_count() == 3)
	# Sample the surf cycle rather than driving it: the crests are authored on a
	# fixed loop, so waiting lands on real states instead of forced ones.
	var captured_swell := false
	var captured_foam := false
	for frame in 700:
		await physics_frame
		if not captured_swell and wave.crest_sprite(0).frame == wave.peak_frame:
			captured_swell = true
			await _capture("arrival_slice_01a_shore_wave_swell")
		if not captured_foam and wave.shore_foam_is_playing():
			captured_foam = true
			await _capture("arrival_slice_01aa_shore_wave_break")
		if captured_swell and captured_foam:
			break
	assert(captured_swell and captured_foam)


func _freeze_enemies(level: LevelSession3D) -> void:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		if node.has_method("reset_run"):
			node.call("reset_run")
		if node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
		node.set_physics_process(false)


func _capture_at(
	level: LevelSession3D,
	file_name: String,
	position: Vector3
) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	await _capture(file_name)


func _capture_wall_gate_crossing(level: LevelSession3D) -> void:
	var enemy := level.get_node("ThornWallPatrol") as CharacterBody3D
	var previous_enemy_transform := enemy.global_transform
	enemy.global_position = Vector3(103.04, 3.58, 0)
	level.player.reset_at(
		Transform3D(Basis.IDENTITY, Vector3(103.04, 3.9, 0))
	)
	level.player.set_physics_process(false)
	level.player.visible = false
	level.camera.snap_to_target()
	await _capture("arrival_slice_10a_wall_gate_crossing")
	level.player.visible = true
	enemy.global_transform = previous_enemy_transform


func _capture_background_only(level: LevelSession3D, file_name: String) -> void:
	var previous_visibility := {}
	for child in level.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		if node == level.background or node == level.camera:
			continue
		previous_visibility[node] = node.visible
		node.visible = false
	await _capture(file_name)
	for node in previous_visibility:
		(node as Node3D).visible = previous_visibility[node]


func _capture(file_name: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Arrival / Shoreline capture requires a renderer.")
	assert(
		image.get_size() == OUTPUT_SIZE,
		"Arrival / Shoreline capture must be 1920 x 1080, got %s."
		% image.get_size()
	)
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Arrival / Shoreline preview '%s'." % file_name)
