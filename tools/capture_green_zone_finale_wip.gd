extends SceneTree
## Captures the Level 3 WIP lift arrival and its intentionally plain run-up.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews"


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

	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(24.0, 0.7, 0)))
	level.camera.snap_to_target()
	for frame in 8:
		await physics_frame
	await _capture(level, "level_3_wip_run_up")
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
