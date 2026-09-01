extends SceneTree
## Deterministic review frames for the Level 2 cave-slide cutscene proof.

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
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/dev/level_2_slide_intro_lab.tres"
	) as LevelDefinition
	game_root.load_developer_level(definition)
	for frame in 5:
		await process_frame
	game_root.get_node("Interface").visible = false
	var lab := game_root.current_level as Level2SlideIntroLab
	assert(lab != null)
	lab.lab_status.visible = false
	var cutscene := lab.cave_slide_intro

	await _preview_and_capture(cutscene, 0.05, "level_2_slide_intro_entry")
	await _preview_and_capture(cutscene, 0.36, "level_2_slide_intro_descent")
	await _preview_and_capture(cutscene, 0.68, "level_2_slide_intro_lower")
	await _preview_and_capture(cutscene, 0.9, "level_2_slide_intro_handoff")
	quit(0)


func _preview_and_capture(
	cutscene: Level2CaveSlideIntro3D,
	progress: float,
	file_name: String
) -> void:
	cutscene.preview_slide_progress(progress)
	await _capture(file_name)


func _capture(file_name: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Slide intro capture requires a graphical renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png(
		"%s/%s.png" % [OUTPUT_DIRECTORY, file_name]
	)
	assert(error == OK, "Could not save slide-intro preview '%s'." % file_name)
