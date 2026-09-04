extends SceneTree
## Focused hands-on launcher for Level 3's traversal-to-shooter handoff.
## Starts just before the one-way threshold so the fade, new-area run-in, and
## full recognition-to-cover cutscene can be reviewed as one sequence.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const REVIEW_START := Vector3(164.48, 0.7, 0.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	var definition := load(
		"res://resources/dev/green_zone_finale_wip.tres"
	) as LevelDefinition
	assert(packed_root != null and definition != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_developer_level(definition)
	for frame in 8:
		await physics_frame
	var level := game_root.current_level as LevelSession3D
	assert(level != null)
	level.player.reset_at(Transform3D(Basis.IDENTITY, REVIEW_START))
	level.camera.snap_to_target()
	print("Level 3 section-handoff review ready: run right into the fade.")
