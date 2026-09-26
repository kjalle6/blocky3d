extends SceneTree
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")

func _init() -> void:
	call_deferred("_run")
	create_timer(20.0, true).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	STORE.clear_recovery("sandbox")
	var app := load("res://scenes/app/game_root.tscn").instantiate() as Node
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	var designer: CanvasLayer = app.level_designer
	designer.open_panel()
	var grounded := _place(designer, "gz_prop_leaf_1", Vector2(8.96, 0))
	var airborne := _place(designer, "gz_prop_leaf_2", Vector2(8.96, 1.28))
	var other := _place(designer, "gz_prop_leaf_3", Vector2(10.24, 2.56))
	designer.flip_selected()
	var stone := _place(designer, "stone", Vector2(12.8, 0))
	var original: Dictionary = designer.document.working.duplicate(true)
	assert(app.current_level.get_node_or_null("FallingLeaves") == null)
	designer.test_layout()
	var session: LevelSession3D = app.current_level
	var nodes: Dictionary = OBJECTS.inspect(session).nodes
	var effect: Node = session.get_node("FallingLeaves")
	for frame in 3: await physics_frame
	assert(effect._prepared and effect._leaves.size() == 3)
	var ground_position: Vector3 = nodes[grounded].get_node("Visual").position
	var stone_position: Vector3 = nodes[stone].get_node("Visual").position
	var high: Sprite3D = nodes[other].get_node("Visual")
	assert(high.flip_h)
	var high_depth := high.position.z
	var anchor_before: Transform3D = nodes[airborne].transform
	var positions := {}
	var visible_steps := 0
	var hidden_steps := 0
	for frame in 100:
		effect._physics_process(0.2)
		var visual: Sprite3D = nodes[airborne].get_node("Visual")
		positions[str(visual.position)] = true
		visible_steps += int(visual.modulate.a > 0.9)
		hidden_steps += int(visual.modulate.a < 0.05)
		assert(visual.global_position.y >= ground_position.y and visual.global_position.y <= 1.28 + ground_position.y)
		assert(is_equal_approx(visual.position.x / visual.pixel_size, roundf(visual.position.x / visual.pixel_size)))
		assert(visual.modulate.a >= 0 and visual.modulate.a <= 1)
		assert(nodes[grounded].get_node("Visual").position == ground_position)
		assert(nodes[stone].get_node("Visual").position == stone_position)
		assert(high.flip_h and high.position.z == high_depth)
	assert(positions.size() > 15 and visible_steps > 10 and hidden_steps > 0, "Leaves must fall visibly and disappear before restarting.")
	assert(nodes[airborne].transform == anchor_before, "Animation must not move the saved placement anchor.")
	assert(nodes[airborne].find_children("*", "CollisionObject3D", true, false).is_empty())
	paused = true
	var time_before: float = effect._time
	await create_timer(0.1, true).timeout
	assert(effect._time == time_before, "Inventory/pause must stop leaf motion.")
	paused = false
	session._reset_world()
	assert(effect._time == 0.0)
	designer.return_to_editing()
	assert(not is_instance_valid(effect) and designer.document.working == original)
	assert(app.current_level.get_node_or_null("FallingLeaves") == null)
	assert(designer.nodes[airborne].get_node("Visual").position.x == 0.0)
	assert(designer.nodes[airborne].get_node("Visual").modulate.a == 1.0)
	designer.revert_layout()
	designer.request_close()
	app.free()
	print("Falling leaves passed: designer-to-play, floor clearance, ground/other props stay still, pixel alignment, varied looping, facing/depth, pause/reset and unchanged layout anchors.")
	quit()

func _place(designer: CanvasLayer, template: String, point: Vector2) -> String:
	designer.begin_placement(template, OBJECTS.CATALOG.defaults(template))
	return designer.place_catalog_object(point)
