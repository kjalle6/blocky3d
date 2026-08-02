extends SceneTree
## Deterministic 1920 x 1080 review frames for the development-only campaign
## candidate. These captures validate composition before the slice expands.

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
		"res://resources/dev/arrival_shoreline_slice.tres"
	) as LevelDefinition
	game_root.load_developer_level(definition)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null, "Arrival / Shoreline must instantiate for capture.")
	game_root.get_node("Interface").visible = false
	for frame in 10:
		await physics_frame
	_freeze_enemies(level)

	await _capture_at(level, "arrival_slice_01_opening", Vector3(3.2, 0.7, 0))
	await _capture_water_death(level)
	await _capture_at(level, "arrival_slice_02_fundamentals", Vector3(17.2, 1.34, 0))
	await _capture_at(
		level,
		"arrival_slice_02a_outcrop_readability",
		Vector3(14.5, 1.34, 0)
	)
	await _capture_at(level, "arrival_slice_03_pickup_height", Vector3(30.1, 1.34, 0))

	level.unlock_ability(PlayerAbility.DOUBLE_JUMP)
	(level.get_node("DoubleJumpPickup") as Node3D).visible = false
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(40.35, 3.14, 0)))
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
	await _capture("arrival_slice_04_double_jump_proof")

	await _capture_at(level, "arrival_slice_05_transition_finish", Vector3(59.0, 2.62, 0))
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
