extends SceneTree
## Captures the major visual beats of the complete World 1 finale.

const CAPTURES := [
	{
		"name": "level_06_opening",
		"position": Vector3(4.8, 0.7, 0.0),
	},
	{
		"name": "level_06_double_jump_review",
		"position": Vector3(37.0, 2.6, 0.0),
	},
	{
		"name": "level_06_spike_review",
		"position": Vector3(62.0, 0.7, 0.0),
	},
	{
		"name": "level_06_wall_shaft",
		"position": Vector3(77.44, 6.4, 0.0),
	},
	{
		"name": "level_06_dash_crossing",
		"position": Vector3(94.0, 12.22, 0.0),
	},
	{
		"name": "level_06_finale_combo",
		"position": Vector3(153.04, 13.4, 0.0),
	},
	{
		"name": "level_06_finish",
		"position": Vector3(188.84, 0.7, 0.0),
	},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/previews")
	)
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 8:
		await process_frame
	game_root.load_level(&"green_zone_finale")
	await process_frame

	var level := game_root.current_level as LevelSession3D
	game_root.get_node("Interface").visible = false
	for frame in 8:
		await physics_frame
	_freeze_enemies(level)

	for capture: Dictionary in CAPTURES:
		await _capture_at(level, capture.name, capture.position)
	quit(0)


func _freeze_enemies(level: LevelSession3D) -> void:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		var enemy := node as StompableEnemy3D
		enemy.reset_run()
		enemy.velocity = Vector3.ZERO
		enemy.set_physics_process(false)


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
		"%s player=(%.2f, %.2f) camera=(%.2f, %.2f)"
		% [
			file_name,
			level.player.global_position.x,
			level.player.global_position.y,
			level.camera.global_position.x,
			level.camera.global_position.y,
		]
	)
	var image := root.get_texture().get_image()
	assert(image != null, "Level 6 capture requires a graphical renderer.")
	var error := image.save_png("res://build/previews/%s.png" % file_name)
	assert(error == OK, "Could not save Level 6 preview '%s'." % file_name)
