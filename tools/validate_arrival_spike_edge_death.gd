extends SceneTree
## The long aerial basin may be fair at its tips, but never nonlethal beside
## the visible supporting wall.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	if packed_scene == null:
		_fail("The application root could not be loaded.")
		return
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_level(&"arrival_shoreline")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var exit_platform := level.get_node(
		"Platforms/ThornGardenExit"
	) as PixelPlatform3D
	var spikes := level.get_node(
		"Hazards/AerialBasinSpikes"
	) as PixelSpikeRow3D
	var damage_collision := spikes.get_node(
		"DamageCollision"
	) as CollisionShape3D
	var damage_box := damage_collision.shape as BoxShape3D
	var visible_left := spikes.global_position.x - spikes.row_width * 0.5
	var lethal_left := (
		damage_collision.global_position.x - damage_box.size.x * 0.5
	)
	var wall_edge := (
		exit_platform.global_position.x + exit_platform.size.x * 0.5
	)
	if not is_equal_approx(visible_left, wall_edge):
		_fail("The aerial spike art no longer begins at the Garden exit wall.")
		return
	if not is_equal_approx(lethal_left - visible_left, spikes.collision_end_inset):
		_fail("The long spike row did not retain its fixed fair end inset.")
		return
	if lethal_left - wall_edge > 0.25:
		_fail("The wall-adjacent spike gutter is wide enough to swallow the player.")
		return
	level.player.reset_at(Transform3D(
		Basis.IDENTITY,
		Vector3(wall_edge + 0.41, 1.1, 0.0)
	))
	level.player.velocity = Vector3(0.0, -2.0, 0.0)
	for frame in 90:
		await physics_frame
		if level.player.is_dead():
			break
	if not level.player.is_dead():
		_fail("Stepping beside the wall still bypassed the visible spike bed.")
		return
	if level.player.death_kind() != PlayerCharacter.DEATH_KIND_GENERIC:
		_fail("The spike edge did not trigger the normal spike death.")
		return
	if level.player.pixel_visual.current_state() != "death":
		_fail("The spike-edge death animation did not become visible.")
		return
	print("Arrival wall-adjacent spike death validation passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
