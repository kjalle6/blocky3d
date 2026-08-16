extends SceneTree
## Focused contract for the enclosed-terrain construction proof.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := load(
		"res://resources/dev/enclosed_terrain_lab.tres"
	) as LevelDefinition
	assert(definition != null)
	assert(definition.validation_errors().is_empty())
	assert(definition.assumed_owned_abilities == PlayerAbility.IMPLEMENTED)
	var room := definition.scene.instantiate() as LevelSession3D
	assert(room != null)
	room.configure(definition, null, definition.assumed_owned_abilities)
	root.add_child(room)
	for frame in 4:
		await physics_frame

	var terrain := room.get_node(
		"Platforms/RockShell"
	) as PixelInteriorTerrain3D
	assert(terrain != null)
	assert(terrain.validation_errors().is_empty())
	assert(terrain.row_count() == 20)
	assert(terrain.column_count() == 46)
	assert(terrain.solid_cell_count() > 700)
	assert(terrain.collision_rectangle_count() >= 5)
	assert(terrain.collision_rectangle_count() <= 20)
	var collision_shapes := terrain.get_children().filter(
		func(child: Node) -> bool:
			return child is CollisionShape3D
	)
	assert(collision_shapes.size() == terrain.collision_rectangle_count())
	for collision in collision_shapes:
		assert((collision as CollisionShape3D).shape is BoxShape3D)
	assert(
		(terrain.get_node("Tile_13_01") as Sprite3D).texture.resource_path
		== "res://assets/art/interiors/rock_underworks/terrain/inner_top_left.png"
	)
	assert(
		(terrain.get_node("Tile_18_01") as Sprite3D).texture.resource_path
		== "res://assets/art/interiors/rock_underworks/terrain/inner_bottom_left.png"
	)

	# Entrance tunnel, low shaft opening, shaft, and upper corridor must all be
	# represented by the same grid rather than separate platform patches.
	assert(not terrain.is_solid_cell(14, 3))
	assert(terrain.is_solid_cell(13, 3))
	assert(terrain.is_solid_cell(18, 3))
	assert(terrain.is_solid_cell(15, 24))
	assert(not terrain.is_solid_cell(16, 24))
	for row in range(4, 18):
		assert(not terrain.is_solid_cell(row, 26))
	assert(terrain.is_solid_cell(12, 24))
	assert(terrain.is_solid_cell(12, 28))
	assert(not terrain.is_solid_cell(6, 36))
	assert(terrain.is_solid_cell(8, 36))
	assert(terrain.is_solid_cell(3, 36))
	assert(terrain.is_solid_cell(6, 44))

	assert(room.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(room.player.has_ability(PlayerAbility.WALL_JUMP))
	assert(room.player.has_ability(PlayerAbility.DASH))
	assert(not room.get_node("Background").visible)
	assert(room.camera.vertical_follow_enabled)
	assert(is_equal_approx(room.camera.maximum_vertical_offset, 12.8))

	# Test actual body motion against each important contact direction. These
	# probes catch a room that looks enclosed but is missing a physical surface.
	assert(_blocked(room.player, Vector3(4.48, 0.7, 0), Vector3.DOWN * 1.0))
	assert(_blocked(room.player, Vector3(4.48, 1.5, 0), Vector3.UP * 4.0))
	assert(_blocked(room.player, Vector3(33.92, 6.4, 0), Vector3.LEFT * 3.0))
	assert(_blocked(room.player, Vector3(33.92, 6.4, 0), Vector3.RIGHT * 3.0))
	assert(_blocked(room.player, Vector3(43.52, 13.5, 0), Vector3.DOWN * 1.0))
	assert(_blocked(room.player, Vector3(54.0, 13.5, 0), Vector3.RIGHT * 3.0))

	print(
		"Enclosed Terrain Lab passed: %d solid cells, %d collision rectangles."
		% [terrain.solid_cell_count(), terrain.collision_rectangle_count()]
	)
	quit(0)


func _blocked(body: CharacterBody3D, origin: Vector3, motion: Vector3) -> bool:
	return body.test_move(Transform3D(Basis.IDENTITY, origin), motion)
