extends SceneTree
## Captures every major beat of the complete Level 5 Dash route.

const CAPTURES := [
	{"name": "level_05_opening", "position": Vector3(3.2, 0.7, 0)},
	{"name": "level_05_pickup_runway", "position": Vector3(20.0, 0.7, 0)},
	{"name": "level_05_first_launch", "position": Vector3(32.0, 0.7, 0)},
	{"name": "level_05_first_landing", "position": Vector3(52.0, 0.7, 0)},
	{"name": "level_05_rising_landing", "position": Vector3(79.0, 1.98, 0)},
	{"name": "level_05_mid_breather", "position": Vector3(104.0, 0.7, 0)},
	{"name": "level_05_high_landing", "position": Vector3(133.0, 3.26, 0)},
	{"name": "level_05_descent_landing", "position": Vector3(158.0, 1.98, 0)},
	{"name": "level_05_finish", "position": Vector3(184.0, 0.7, 0)},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/previews"))
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 8:
		await process_frame
	game_root.load_level(&"dash")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	game_root.get_node("Interface").visible = false
	for frame in 8:
		await physics_frame

	for capture: Dictionary in CAPTURES:
		await _capture_at(level, capture.name, capture.position)
	quit(0)


func _capture_at(
	level: LevelSession3D,
	file_name: String,
	position: Vector3
) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	for frame in 8:
		await process_frame
	print(
		"%s player=(%.2f, %.2f) camera_x=%.2f"
		% [
			file_name,
			level.player.global_position.x,
			level.player.global_position.y,
			level.camera.global_position.x,
		]
	)
	var image := root.get_texture().get_image()
	assert(image != null, "Level 5 capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Level 5 preview.")
