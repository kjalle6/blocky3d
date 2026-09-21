extends SceneTree
const LOOT := preload("res://scripts/items/chest_loot.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")

func _init() -> void:
	call_deferred("_run")
	create_timer(35.0, true).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	_check_pools()
	# Designer preview -> placement -> settings -> undo -> disk -> live Test.
	# Runner profile only; never write sandbox.json or the user's recovery.
	STORE.clear_recovery("sandbox")
	var app := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_level(load("res://resources/dev/level_designer_sandbox.tres"))
	var designer: CanvasLayer = app.level_designer
	designer.open_panel()
	var count: int = app.current_level.player.inventory.count(&"basic_heal")
	designer.begin_placement("supply_chest", OBJECTS.CATALOG.defaults("supply_chest"))
	assert(not designer._ghost.monitoring and not designer._ghost._available)
	assert(designer._ghost.visual.texture != null)
	assert(app.current_level.player.inventory.count(&"basic_heal") == count)
	var id: String = designer.place_catalog_object(Vector2(10.24, 0))
	assert(designer.document.working[id].kind == "chest")
	assert(designer.placement_warning(id).is_empty())
	designer.update_values({"loot_pool":"fixed", "basic_heal":2, "handgun_ammo":17})
	assert(designer.nodes[id].reward_contents() == {&"basic_heal":2, &"handgun_ammo":17})
	designer.undo()
	assert(designer.document.working[id].values.loot_pool == "level")
	designer.redo()
	var before_test: Dictionary = designer.document.working.duplicate(true)
	var path := "user://loot_designer_validation.json"
	var stored := STORE.read(path)
	designer.document.disk_hash = stored.hash
	assert(STORE.save(designer.document, path).is_empty())
	var base: Node = load(REGISTRY.SECTIONS.sandbox).instantiate()
	var fresh := DOCUMENT.new()
	stored = STORE.read(path)
	assert(fresh.open(base, stored.data, stored.hash).is_empty())
	if fresh.working != designer.document.working:
		print("Saved: ", fresh.working)
		print("Working: ", designer.document.working)
	assert(fresh.working == designer.document.working)
	base.free()
	var invalid: Dictionary = stored.data.duplicate(true)
	invalid.created[id].values.handgun_ammo = 0.5
	assert(not fresh.resolve(invalid).error.is_empty())
	invalid.created[id].values.handgun_ammo = 0
	invalid.created[id].values.basic_heal = 0
	assert(not fresh.resolve(invalid).error.is_empty())
	invalid = stored.data.duplicate(true)
	invalid.created[id].values.loot_pool = "res://arbitrary.gd"
	assert(not fresh.resolve(invalid).error.is_empty())
	designer.test_layout()
	var session: LevelSession3D = app.current_level
	var chest: ItemReward3D = OBJECTS.inspect(session).nodes[id]
	var before := session.save_state.transfer_state()
	# Use real Area3D overlap, not only collect() calls.
	session.player.reset_at(Transform3D(Basis.IDENTITY, chest.global_position + Vector3(-2, 0.1, 0)))
	Input.action_press("move_right")
	for frame in 60:
		await physics_frame
		if not chest._available: break
	Input.action_release("move_right")
	assert(not chest._available and session.player.inventory.count(&"basic_heal") == count + 2)
	assert(session.player.inventory.count(&"handgun_ammo") == 17)
	assert(not chest.collect())
	var after := session.save_state.transfer_state()
	session._reset_world()
	assert(not chest.collect(), "An ordinary reset cannot farm a claimed chest.")
	session.save_state.apply_state(before)
	assert(chest._available and chest.collect())
	session.save_state.apply_state(after)
	assert(not chest.collect())
	designer.return_to_editing()
	assert(designer.document.working == before_test)
	designer.document.saved = {}
	designer.revert_layout()
	designer.request_close()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(path + suffix)
	app.free()
	paused = false
	# Real campaign chest, full save snapshots and cold reconstruction.
	var store := root.get_node("GameProgression") as ProgressionStore
	store.save_path = "user://loot_campaign_validation/progress.json"
	var campaign := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	root.add_child(campaign)
	assert(campaign.start_campaign())
	session = campaign.current_level
	chest = OBJECTS.inspect(session).nodes.object_shoreline_supply
	assert(session.player.inventory.count(&"basic_heal") == 0)
	var contents := chest.reward_contents()
	assert(not contents.has(&"handgun_ammo"))
	assert(store.write_snapshot(session.save_state.capture(session.player.global_position), "manual", 1))
	var unopened: Dictionary = store.read_slot("manual", 1).data
	assert(chest.collect())
	assert(store.write_snapshot(session.save_state.capture(session.player.global_position), "manual", 2))
	var opened: Dictionary = store.read_slot("manual", 2).data
	assert(campaign.load_snapshot(opened).is_empty())
	session = campaign.current_level
	chest = OBJECTS.inspect(session).nodes.object_shoreline_supply
	assert(not chest._available and not chest.collect())
	assert(session.player.inventory.count(&"basic_heal") == contents[&"basic_heal"])
	assert(campaign.load_snapshot(unopened).is_empty())
	session = campaign.current_level
	chest = OBJECTS.inspect(session).nodes.object_shoreline_supply
	assert(chest._available and chest.reward_contents() == contents)
	assert(session.player.inventory.count(&"basic_heal") == 0)
	assert(chest.collect())
	assert(session.player.inventory.count(&"basic_heal") == contents[&"basic_heal"])
	campaign.free()
	print("Chest loot passed: weights, weapon gating, quantity ranges, stable rolls, preview/author/test/save, contact collection, full campaign snapshot restore.")
	quit()

func _check_pools() -> void:
	assert(LOOT.pool_for_level(&"arrival_shoreline") == "shoreline")
	assert(LOOT.pool_for_level(&"overgrown_coastal_ascent") == "green_zone")
	assert(LOOT.pool_for_level(&"dev_green_zone_finale_wip") == "firearms")
	for pool_id in LOOT.pools:
		var seen := {}
		var amounts := {}
		var singles := 0
		var doubles := 0
		for index in 400:
			var source := "fixture/chest_" + str(index)
			var weapons: Array = [&"knife", &"handgun"]
			var rolled: Dictionary = LOOT.roll(pool_id, 812347, source, weapons)
			assert(rolled == LOOT.roll(pool_id, 812347, source, weapons))
			assert(rolled.size() >= 1 and rolled.size() <= 2)
			singles += int(rolled.size() == 1)
			doubles += int(rolled.size() == 2)
			for item_id in rolled:
				seen[str(item_id)] = true
				amounts[str(item_id) + ":" + str(rolled[item_id])] = true
				for entry in LOOT.pools[pool_id].entries:
					if entry.item == str(item_id):
						assert(rolled[item_id] >= entry.minimum and rolled[item_id] <= entry.maximum)
			var before_gun: Dictionary = LOOT.roll(pool_id, 812347, source, [&"knife"])
			assert(not before_gun.is_empty() and not before_gun.has(&"handgun_ammo"))
		assert(seen.size() == LOOT.pools[pool_id].entries.size())
		assert(amounts.size() > seen.size() and singles > 0 and doubles > 0)
	var variants := {}
	for campaign_seed in range(1, 100):
		variants[JSON.stringify(LOOT.roll("firearms", campaign_seed, "same/chest", [&"knife", &"handgun"]))] = true
	assert(variants.size() > 10, "New campaigns should vary without changing authored placement.")
