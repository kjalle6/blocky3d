extends SceneTree
## Level 3 regression: authored lessons, permanent pickup behavior, checkpoint
## persistence, and replay state.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"double_jump")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	for frame in 10:
		await physics_frame

	assert(level.get_node("Platforms").get_child_count() == 12, "Level 3 requires 12 authored platforms.")
	assert(level.get_node("Hazards").get_child_count() == 1, "Level 3 requires one focused spike row.")
	assert(level.get_node("Checkpoints").get_child_count() == 3, "Level 3 requires three checkpoints.")
	assert(get_nodes_in_group("melee_target").size() == 1, "Level 3 requires one patrol encounter.")
	assert(level.traversal_rail.length() >= 108.0)
	_validate_lesson_geometry(level)

	var player := level.player
	var pickup := level.get_node("DoubleJumpPickup") as AbilityPickup3D
	assert(not player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not pickup.is_claimed())
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(7.2, 0.7, 0)))
	for frame in 4:
		await physics_frame
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP), "Touching the pickup should unlock Double Jump.")
	assert(pickup.is_claimed(), "The permanent pickup should become claimed.")
	assert(
		(game_root.get_node("Interface/AbilityTutorial") as Control).visible,
		"The first unlock should display the non-pausing instruction."
	)

	player.kill()
	for frame in 40:
		await physics_frame
	assert(not player.is_dead())
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP), "Checkpoint death must retain the unlock.")
	assert(pickup.is_claimed())

	level._reset_run()
	await physics_frame
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP), "Manual restart must retain the unlock.")
	assert(pickup.is_claimed())

	# A new session backed by owned progression starts with the ability active
	# and the pickup already absent.
	game_root.queue_free()
	await process_frame
	var definition := load("res://resources/campaign/level_03.tres") as LevelDefinition
	var store := ProgressionStore.new()
	store.save_path = "user://level3_replay_validation.json"
	store.unlock_ability(PlayerAbility.DOUBLE_JUMP)
	var replay := definition.scene.instantiate() as LevelSession3D
	replay.configure(definition, store)
	root.add_child(replay)
	await process_frame
	assert(replay.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(
		(replay.get_node("DoubleJumpPickup") as AbilityPickup3D).is_claimed(),
		"Owned Double Jump should make the replay pickup start claimed."
	)
	if FileAccess.file_exists(store.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
	replay.free()
	store.free()

	print("Level 3 route, pickup, replay, and reset validation passed.")
	quit(0)


func _validate_lesson_geometry(level: LevelSession3D) -> void:
	var opening := level.get_node("Platforms/OpeningGround") as PixelPlatform3D
	var height_lesson := level.get_node("Platforms/HeightLesson") as PixelPlatform3D
	var familiar := level.get_node("Platforms/FamiliarLanding") as PixelPlatform3D
	var distance := level.get_node("Platforms/DistanceLanding") as PixelPlatform3D
	var enemy_island := level.get_node("Platforms/EnemyIsland") as PixelPlatform3D
	var final_proof := level.get_node("Platforms/FinalProof") as PixelPlatform3D

	var opening_top := opening.global_position.y + opening.size.y * 0.5
	var height_top := height_lesson.global_position.y + height_lesson.size.y * 0.5
	assert(
		height_top - opening_top > level.player.movement.ideal_jump_height(),
		"The first lesson should communicate extra height, not duplicate a normal jump."
	)
	assert(
		level.get_node_or_null("Platforms/PracticeCatch") == null,
		"The opening lesson should remain a clean lethal gap without lower support."
	)
	var familiar_right := familiar.global_position.x + familiar.size.x * 0.5
	var distance_left := distance.global_position.x - distance.size.x * 0.5
	assert(distance_left - familiar_right >= 7.5, "The distance lesson must require delayed Double Jump.")
	var enemy_right := enemy_island.global_position.x + enemy_island.size.x * 0.5
	var final_left := final_proof.global_position.x - final_proof.size.x * 0.5
	assert(final_left - enemy_right >= 7.5, "The final proof must retain its full aerial crossing.")
