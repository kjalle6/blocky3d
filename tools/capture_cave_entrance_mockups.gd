extends SceneTree
## Captures the cave entrance as the grounded end of a real level approach.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews/cave_entrance_mockups"
const SCENE_PATH := "res://scenes/dev/cave_entrance_mockup_lab.tscn"

const CAPTURE_FILE := "level_end_grounded_approach"
const CAPTURE_PLAYER_POSITION := Vector3(26.88, -0.58, 0.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	var packed_scene := load(SCENE_PATH) as PackedScene
	assert(packed_scene != null, "Could not load the cave-entrance mockup lab.")
	var room := packed_scene.instantiate() as LevelSession3D
	assert(room != null)
	var definition := LevelDefinition.new()
	definition.level_id = &"dev_cave_entrance_mockups"
	definition.available_abilities = []
	room.configure(definition)
	root.add_child(room)
	for frame in 6:
		await physics_frame
	room.player.global_position = CAPTURE_PLAYER_POSITION
	room.player.velocity = Vector3.ZERO
	room.camera.snap_to_target()
	if room.background != null:
		room.background.snap_to_camera(true)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Mockup capture requires a graphical renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var output_path := "%s/%s.png" % [OUTPUT_DIRECTORY, CAPTURE_FILE]
	assert(image.save_png(output_path) == OK)

	quit(0)
