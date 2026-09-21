extends SceneTree
func _init() -> void:
	call_deferred("_run")
	create_timer(15.0, true).timeout.connect(func() -> void: quit(1))


func _run() -> void:
	var app := preload("res://scenes/app/game_root.tscn").instantiate()
	root.add_child(app)
	app.load_developer_room()
	await process_frame
	await physics_frame
	var session: LevelSession3D = app.current_level
	var chest := session.get_node("HealingChestFixture") as ItemReward3D
	var drop := session.get_node("HealingDropFixture") as ItemReward3D
	var before := session.save_state.transfer_state()
	var count := session.player.inventory.count(&"basic_heal")
	assert(chest.collect())
	assert(session.player.inventory.count(&"basic_heal") == count + 1)
	assert(not chest.collect())
	var collected := session.save_state.transfer_state()
	# Reload/reset with the banked claim does not reopen or duplicate the chest.
	session.save_state.apply_state(collected)
	assert(not chest.collect())
	assert(session.player.inventory.count(&"basic_heal") == count + 1)
	# Loading before collection restores both the chest and the earlier stack.
	session.save_state.apply_state(before)
	assert(chest.collect())
	var shooter := session.get_node("HandgunEnemy") as HandgunEnemy3D
	shooter.receive_melee_hit(Vector3.ZERO)
	assert(not drop.collect(), "A surviving hit never creates a reward.")
	shooter.receive_melee_hit(Vector3.ZERO)
	assert(drop.collect())
	count = session.player.inventory.count(&"basic_heal")
	shooter.reset_run()
	shooter.receive_melee_hit(Vector3.ZERO, CombatHit.new(50, &"fixture"))
	assert(not drop.collect())
	assert(session.player.inventory.count(&"basic_heal") == count)
	app.free()
	print("Item rewards passed: chest/drops, defeat-only reward, one claim per source, matching inventory/claim restoration.")
	quit()
