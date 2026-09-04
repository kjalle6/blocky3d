extends SceneTree
## Focused hands-on launcher for the current Level 3 shooter introduction.
## It preserves the real level and input stack, but starts the player a few
## seconds before the trigger in Area 2 so review does not require replaying
## the traversal section and its fade handoff.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const REVIEW_START := Vector3(2.56, 0.7, 0.0)
const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var level := SHOOTER_AREA.load_into(game_root)
	for frame in 8:
		await physics_frame
	assert(level != null)
	level.player.reset_at(Transform3D(Basis.IDENTITY, REVIEW_START))
	level.camera.snap_to_target()
	print("Shooter-intro review ready: run right into the encounter.")
