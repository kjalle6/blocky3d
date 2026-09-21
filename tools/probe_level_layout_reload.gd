extends SceneTree
## Run in a separate process after prepare_level_layout_probe, also from a PCK.
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(15.0, true).timeout.connect(func() -> void: quit(1))
	assert(FileAccess.file_exists("res://resources/level_layouts/designer_fixture.json"))
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	var definition := LevelDefinition.new()
	definition.level_id = &"dev_designer_fixture"
	definition.title = "Designer fixture"
	definition.scene = load("res://scenes/dev/level_designer_fixture.tscn")
	app._start_session(definition, null)
	await physics_frame
	var level: LevelSession3D = app.current_level
	assert(is_equal_approx(level.get_node("Platforms/Platform").position.x, 25.6))
	assert(is_equal_approx(level.get_node("Checkpoints/Checkpoint").respawn_transform().origin.x, 28.8))
	var enemy: StompableEnemy3D = level.get_node("Skater")
	enemy.position.x += 2.0
	enemy.reset_run()
	assert(is_equal_approx(enemy.position.x, 35.84))
	assert(level.get_node("Platforms").get_child_count() == 3)
	var platform: Node3D = level.get_node("Platforms").get_child(2)
	assert(platform.style.footstep_surface == "sand")
	assert(level.player.test_move(Transform3D(Basis.IDENTITY, Vector3(50.56, 3.26, 0)), Vector3.DOWN))
	var objects: Dictionary = preload("res://scripts/developer/level_layout_objects.gd").inspect(level).nodes
	assert(objects.object_probe_skater_enemy is StompableEnemy3D)
	assert(objects.object_probe_gunner_enemy is HandgunEnemy3D)
	assert(objects.object_probe_spike_row is PixelSpikeRow3D)
	assert(objects.object_probe_flying_hazard is HoveringHazard3D)
	assert(objects.object_probe_checkpoint.get_meta("layout_added_checkpoint", false))
	assert(objects.object_probe_bush.get_node("Visual").texture != null)
	var supply: ItemReward3D = objects.object_probe_supply_chest
	assert(supply.loot_pool == &"level" and not supply.reward_contents().is_empty())
	assert(FileAccess.file_exists("res://resources/loot/chest_pools.json"))
	assert(objects.object_probe_gz_tile_42.get_node("Collision").shape is ConvexPolygonShape3D)
	assert(objects.object_probe_gz_tile_75.get_node_or_null("Collision") == null)
	assert(objects.object_probe_gz_animated_fountain.get_node("Visual")._frames.size() == 4)
	assert(objects.object_probe_gz_prop_other_tree1.get_node("Visual").texture != null)
	if OS.has_feature("blocky_export"):
		assert(not FileAccess.file_exists("res://AGENTS.md"), "Pack probe must not see source-checkout files.")
		assert(not DirAccess.dir_exists_absolute("res://assets/library"), "The source-art catalog is not a runtime dependency.")
		assert(ResourceLoader.exists("res://resources/audio/movement_mix.tres"))
		assert(not REGISTRY.can_author() and not app.developer_tools_enabled)
		app.level_designer.open_panel()
		assert(not app.level_designer.is_active())
		print("Exported pack passed: saved layout, collision, reset, palette assets and disabled authoring UI.")
	else:
		print("Fresh-process saved-layout reload passed.")
	app.free()
	quit(0)
