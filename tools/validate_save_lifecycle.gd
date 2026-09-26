extends SceneTree
## Exercise real campaign composition, grounded saving and scene reconstruction.
func _init() -> void:
	call_deferred("_run")
	create_timer(35.0, true).timeout.connect(func() -> void: quit(1))


func _run() -> void:
	var mix := preload("res://scripts/audio/movement_audio_mix.gd")
	var mix_hash := FileAccess.get_sha256(mix.SAVE_PATH)
	mix.initialize()
	var respawn_bank: Resource = mix.event_bank_for("combat/player_respawn")
	var cue := AudioStreamWAV.new()
	cue.data = PackedByteArray([0, 0, 0, 0])
	respawn_bank.clips.clear()
	respawn_bank.clips.append(cue)
	respawn_bank.enabled = true
	respawn_bank.disabled_indices.clear()
	respawn_bank.selection_mode = 0
	respawn_bank.volume_db = -70.0
	var store := root.get_node("GameProgression") as ProgressionStore
	store.save_path = "user://lifecycle_validation_" + str(Time.get_ticks_usec()) + "/progress.json"
	store.load_progress()
	var app := preload("res://scenes/app/game_root.tscn").instantiate()
	root.add_child(app)
	assert(app.start_campaign(), store.last_error)
	await _ticks(150)
	var session: LevelSession3D = app.current_level
	assert(not store.newest_save().is_empty(), "Stable entry must create an initial autosave.")
	assert(session.save_state.safety_error().is_empty(), session.save_state.safety_error())
	# Combat attention extends beyond the old five-unit proximity guard.
	var pursuer := session.get_node("ApproachPatrol") as StompableEnemy3D
	pursuer.set_physics_process(false)
	pursuer.receive_melee_hit(session.player.global_position, CombatHit.new(1, &"fixture_hit"))
	assert(pursuer.global_position.distance_to(session.player.global_position) > 5.0)
	assert(session.save_state.safety_error() == "Lose pursuing enemies before saving.")
	assert(not session.save_state.manual_save(2))
	assert(not FileAccess.file_exists(store.slot_path("manual", 2)))
	assert(session.save_state.safety_error(false).is_empty(), "Pursuit does not change autosave activation.")
	pursuer.reset_run()
	assert(session.save_state.safety_error().is_empty(), session.save_state.safety_error())
	session.player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(25, &"test_enemy"))
	session.player.inventory.add(&"basic_heal", 9)
	assert(session.acquire_weapon(PlayerWeapon.HANDGUN))
	session.player.player_handgun.set_loaded_rounds(7)
	await _ticks(130)
	assert(session.save_state.manual_save(1), store.last_error)
	var manual: Dictionary = store.read_slot("manual", 1).data
	var file_hash := FileAccess.get_sha256(store.slot_path("manual", 1))
	assert(int(manual.player.health.current) == 75)
	assert(int(manual.player.handgun_ammo.loaded) == 7)
	session.player.player_handgun.set_loaded_rounds(1)
	session.player.inventory.consume(&"handgun_ammo", 15)
	assert(session.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	assert(session.player.use_quick_item(0))
	assert(session.player.health.current == 100 and session.player.inventory.count(&"basic_heal") == 8)
	session.player.kill()
	await session.death_menu_requested
	await process_frame
	assert(app.campaign_menu.page == "death" and paused, "page=%s paused=%s dead=%s resetting=%s delay=%s" % [app.campaign_menu.page, paused, session.player.is_dead(), session._resetting, session.reset_delay])
	assert(app.load_snapshot(manual).is_empty())
	app.campaign_menu.close()
	session = app.current_level
	assert(session.combat_feedback.combat_audio.last_event.get("id") == "combat/player_respawn", "Loading after death must play the selected respawn bank in the new scene.")
	assert(session.player.health.current == 75 and session.player.inventory.count(&"basic_heal") == 9)
	assert(session.player.player_handgun.loaded_rounds == 7 and session.player.player_handgun.reserve_rounds() == 18)
	assert(not session.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not store.owns_ability(PlayerAbility.DOUBLE_JUMP))
	assert(FileAccess.get_sha256(store.slot_path("manual", 1)) == file_hash, "Loading cannot rewrite the snapshot.")
	assert(session.player.global_position.is_equal_approx(Vector3(manual.position[0], manual.position[1], 0)))
	var bad := manual.duplicate(true)
	bad.section = "overgrown_coastal_ascent_interior"
	var old_session: LevelSession3D = app.current_level
	assert(not app.load_snapshot(bad).is_empty())
	assert(app.current_level == old_session)
	# Snapshot section identity chooses the cave, never Level 2's outdoors.
	var cave := manual.duplicate(true)
	cave.level_id = "overgrown_coastal_ascent"
	cave.section = "overgrown_coastal_ascent_interior"
	cave.position = [4.0, 0.7, 0.0]
	cave.player.abilities = ["double_jump"]
	cave.progress.unlocked_abilities = ["double_jump"]
	assert(app.load_snapshot(cave).is_empty())
	assert(app.current_level.get_meta("layout_section") == "overgrown_coastal_ascent_interior")
	assert(app.current_level.player.health.current == 75)
	assert(app.current_level.player.inventory.count(&"basic_heal") == 9)
	assert(app.current_level.player.player_handgun.loaded_rounds == 7 and app.current_level.player.player_handgun.reserve_rounds() == 18)
	app.free()
	paused = false
	assert(FileAccess.get_sha256(mix.SAVE_PATH) == mix_hash)
	print("Save lifecycle passed: initial autosave, grounded manual save, exact HP/items, death menu, unlock rollback, no load rewrite, section identity and invalid-destination rejection.")
	quit()


func _ticks(count: int) -> void:
	for index in count:
		await physics_frame
