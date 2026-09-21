extends SceneTree
## Disk contracts run only in the runner's isolated writable profile.
const PATH := "user://snapshot_validation/progress.json"


func _init() -> void:
	call_deferred("_run")
	create_timer(15.0, true).timeout.connect(func() -> void: quit(1))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var legacy := {"version": 1, "completed_levels": ["arrival_shoreline"], "unlocked_abilities": ["double_jump"]}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var store := ProgressionStore.new()
	store.save_path = PATH
	store.load_progress()
	assert(store.owns_ability(PlayerAbility.DOUBLE_JUMP))
	assert(FileAccess.file_exists(PATH + ".v1.bak"))
	assert(FileAccess.get_sha256(PATH + ".v1.bak") == FileAccess.get_sha256(PATH))
	var snapshot := _snapshot(store)
	assert(store.write_snapshot(snapshot, "manual", 1), store.last_error)
	var manual_hash := FileAccess.get_sha256(store.slot_path("manual", 1))
	var saved: Dictionary = store.read_slot("manual", 1).data
	for index in 5:
		snapshot.player.health.current = 20 + index
		assert(store.write_snapshot(snapshot, "auto"), store.last_error)
	assert(FileAccess.get_sha256(store.slot_path("manual", 1)) == manual_hash)
	assert(int(store.newest_save().player.health.current) == 24)
	store.unlock_ability(PlayerAbility.WALL_JUMP)
	store.unlock_weapon(PlayerWeapon.HANDGUN)
	store.progress.completed_boss_ids.append(&"fixture_boss")
	assert(store.restore_progress(saved, false), store.last_error)
	assert(store.owns_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not store.owns_ability(PlayerAbility.WALL_JUMP))
	assert(PlayerWeapon.HANDGUN not in store.progress.owned_weapon_ids)
	assert(store.progress.completed_boss_ids.is_empty())
	store.free()
	var cold := ProgressionStore.new()
	cold.save_path = PATH
	cold.load_progress()
	assert(cold.owns_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not cold.owns_ability(PlayerAbility.WALL_JUMP))
	assert(cold.read_slot("manual", 1).data == saved)
	assert(cold.start_new_campaign())
	assert(FileAccess.get_sha256(cold.slot_path("manual", 1)) == manual_hash)
	# A failed/interrupted replacement retains the prior valid payload.
	assert(cold.write_snapshot(snapshot, "manual", 2))
	var first: Dictionary = cold.read_slot("manual", 2).data
	snapshot.player.health.current = 75
	assert(cold.write_snapshot(snapshot, "manual", 2))
	file = FileAccess.open(cold.slot_path("manual", 2), FileAccess.WRITE)
	file.store_string("{interrupted")
	file.close()
	var recovered := cold.read_slot("manual", 2)
	assert(recovered.recovered and recovered.data == first)
	var invalid := saved.duplicate(true)
	invalid.player.inventory.quantities.basic_heal = -1
	assert(not SaveSnapshot.validation_error(invalid).is_empty())
	assert(not cold.write_snapshot(invalid, "manual", 1))
	assert(FileAccess.get_sha256(cold.slot_path("manual", 1)) == manual_hash)
	invalid = saved.duplicate(true)
	invalid.position = [0, INF, 0]
	assert(not SaveSnapshot.validation_error(invalid).is_empty())
	invalid = saved.duplicate(true)
	invalid.player.equipped_weapon = "handgun"
	assert(not SaveSnapshot.validation_error(invalid).is_empty())
	invalid = saved.duplicate(true)
	invalid.version += 1
	assert(not SaveSnapshot.validation_error(invalid).is_empty())
	var corrupt_path := "user://snapshot_validation/corrupt.json"
	file = FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var corrupt := ProgressionStore.new()
	corrupt.save_path = corrupt_path
	corrupt.load_progress()
	corrupt.unlock_ability(PlayerAbility.DASH)
	assert(FileAccess.get_file_as_string(corrupt_path) == "{broken")
	assert(not corrupt.last_error.is_empty())
	assert(corrupt.restore_progress(saved, false), corrupt.last_error)
	assert(corrupt.owns_ability(PlayerAbility.DOUBLE_JUMP))
	invalid = saved.duplicate(true)
	invalid.section = "overgrown_coastal_ascent_interior"
	assert(not SaveSnapshot.validation_error(invalid).is_empty())
	corrupt.free()
	cold.free()
	print("Save snapshots passed: migration backup, exact cold-read state, protected manual slots, rotation, rollback, corruption recovery and invalid-data rejection.")
	quit()


func _snapshot(store: ProgressionStore) -> Dictionary:
	return {
		"level_id": "arrival_shoreline", "section": "arrival_shoreline",
		"position": [4.0, 0.55, 0.0], "point_id": "fixture",
		"player": {"health": {"current": 50, "maximum": 100},
			"inventory": {"quantities": {"basic_heal": 7}, "quick_slots": ["basic_heal", ""]},
			"weapons": ["knife"], "equipped_weapon": "knife", "abilities": ["double_jump"], "facing": 1},
		"progress": store.progress.to_dictionary(), "rewards": {"fixture/chest": true}, "world_flags": {},
	}
