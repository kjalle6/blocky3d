extends SceneTree
## Real head crossings, grounded input lock, retreat clearance, cleanup and hurt art.
var game: Node
var level: LevelSession3D
var player: PlayerCharacter
var boss: CharacterBody3D
var controls: Node
const ACTIONS := ["move_right", "jump", "dash", "attack", "reload", "quick_item_1"]

func _init() -> void:
	call_deferred("_run")
	create_timer(60.0).timeout.connect(func():
		printerr("Boss smoke escape validation timed out.")
		quit(1))

func _run() -> void:
	game = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	game.load_developer_level(game.developer_level_definitions[4])
	await process_frame
	level = game.current_level
	player = level.player
	boss = level.get_node("GreenZoneBoss")
	controls = level.get_node("BossLabController")
	controls.set_boss_active(false)
	await _frames(10)
	# Run into its solid side, then cross its head upward: neither is a stomp.
	boss.receive_stomp(player)
	assert(boss.smoke_escapes == 0 and not player.is_ground_held())
	player.global_position = boss.global_position + Vector3(-3.0, PlayerCharacter.FEET_OFFSET_Y, 0)
	Input.action_press("move_right")
	await _frames(44)
	Input.action_release("move_right")
	assert(player.global_position.x < boss.global_position.x - 1.65, "Grounded boss must block side passage.")
	assert(boss.smoke_escapes == 0 and not player.is_ground_held())
	controls.reset_fight()
	player.global_position = boss.global_position + Vector3(0, boss.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y - 0.1, 0)
	player.velocity.y = 8.0
	await _frames(4)
	assert(player.velocity.y > 0.0 and boss.smoke_escapes == 0 and not player.is_ground_held())

	await _head_landing()
	assert(boss.health.current == 300 and player.health.current == 100)
	assert(player.velocity.y <= 0.0, "Head contact must not bounce the player.")
	assert(boss.smoke_escapes == 1 and boss.state_name() == "SMOKE_ESCAPE")
	assert(get_nodes_in_group("boss_smoke").size() == 1)
	assert(not player.can_save_state(false) and not player.request_weapon(PlayerWeapon.HANDGUN))
	assert(not player.player_handgun.start_reload() and not player.player_handgun.can_fire())
	assert(not boss.receive_melee_hit(player.global_position, CombatHit.new(50, &"stomp")))
	for duplicate in 8: boss.receive_stomp(player)
	assert(boss.smoke_escapes == 1, "One head contact cannot retrigger the escape.")
	var captured_x := player.global_position.x
	var loaded := player.player_handgun.loaded_rounds
	for action in ACTIONS: Input.action_press(action)
	await _frames(28)
	for action in ACTIONS: Input.action_release(action)
	assert(player.is_ground_held() and player.is_on_floor())
	assert(absf(player.global_position.x - captured_x) < 0.03)
	assert(absf(player.feet_world_y()) < 0.05, "Player must fall onto the actual floor.")
	assert(not player.is_attacking() and not player.is_dashing())
	assert(player.player_handgun.loaded_rounds == loaded and not player.player_handgun.is_reloading())
	assert(boss.health.current == 300, "Locked attack input cannot damage the boss.")
	# Existing threats still hurt: this is a control hold, not invulnerability.
	assert(player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(25, &"test_bullet")))
	assert(player.health.current == 75 and player.is_ground_held())
	player.inventory.add(&"basic_heal", 1)
	player.inventory.equip(0, &"basic_heal")
	assert(not player.use_quick_item(0) and player.inventory.count(&"basic_heal") == 1)
	await _until(func(): return not player.is_ground_held(), 190, "Escape never released control.")
	assert(absf(boss.global_position.x - player.global_position.x) >= boss.smoke_escape_clearance - 0.01)
	assert(boss.state_name() == "RECOVERY")
	assert(get_nodes_in_group("boss_smoke").size() == 1, "Fading wisps should remain briefly after release.")
	var lingering := get_nodes_in_group("boss_smoke")[0] as Node3D
	Input.action_press("move_left")
	await _frames(12)
	Input.action_release("move_left")
	assert(absf(lingering.global_position.x - player.global_position.x) < 0.2, "Fading smoke must follow the player.")
	assert(lingering.get("_fade_remaining") < boss.smoke_fade_tail)
	await _frames(32)
	assert(get_nodes_in_group("boss_smoke").is_empty(), "Smoke must finish its gradual fade.")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	assert(player.velocity.y > 0.0, "Jump must work after release.")

	for edge in [boss.minimum_x + 0.1, boss.maximum_x - 0.1]:
		await _head_landing(float(edge))
		var initial_x := boss.global_position.x
		await _until(func(): return not player.is_ground_held(), 220, "Wall-side escape never released.")
		assert(absf(boss.global_position.x - player.global_position.x) >= boss.smoke_escape_clearance - 0.01)
		assert(boss.global_position.x >= boss.minimum_x and boss.global_position.x <= boss.maximum_x)
		assert((boss.global_position.x > initial_x) == (edge < 0.0), "Escape must choose space inside the room.")

	# Abort an airborne jump into smoke without a second landing attack.
	controls.set_boss_active(true)
	player.set_physics_process(false)
	boss._start_jump(player)
	await _frames(12)
	assert(boss.global_position.y > 1.0)
	player.set_physics_process(true)
	player.global_position = boss.global_position + Vector3(0, boss.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y, 0)
	player.velocity.y = -4.0
	player.set("_descending_before_slide", true)
	boss.receive_stomp(player)
	assert(boss.state_name() == "SMOKE_ESCAPE" and boss.jump_cooldown_remaining > 0.0)
	player.health.reset(1000)
	await _until(func(): return not player.is_ground_held(), 240, "Airborne escape never released.")
	assert(boss.landing_count == 0 and boss.health.current == 300, "Interrupted leap must not produce a landing blast.")
	assert(boss.missiles_fired == 6, "Escape should counterattack before releasing the player.")

	await _counterattack_check(1)
	await _counterattack_check(2)

	# Ownership must also clear after retreat, while the counterattack is active.
	for cleanup in ["reset", "defeat", "player_reset", "inspection"]:
		await _head_landing(INF, 1)
		await _until(func(): return boss.state_name() == "SALVO", 140, "Expected smoke counterattack.")
		assert(player.is_ground_held())
		match cleanup:
			"reset": controls.reset_fight()
			"defeat": boss.receive_melee_hit(player.global_position, CombatHit.new(300, &"test_defeat"))
			"player_reset": player.reset_at(level.spawn_point.global_transform)
			"inspection": player.set_developer_inspection_enabled(true)
		await _frames(2)
		assert(not player.is_ground_held() and get_nodes_in_group("boss_smoke").is_empty(),
			"Counterattack cleanup failed: " + cleanup)
		if cleanup == "inspection": player.set_developer_inspection_enabled(false)

	# Reset, death, missing source and obstruction all release ownership.
	await _head_landing()
	controls.reset_fight()
	assert(not player.is_ground_held())
	await _frames(2)
	assert(get_nodes_in_group("boss_smoke").is_empty())
	await _head_landing()
	boss.receive_melee_hit(player.global_position, CombatHit.new(300, &"test_defeat"))
	assert(boss.is_defeated() and not player.is_ground_held())
	await _head_landing()
	player.kill()
	assert(not player.is_ground_held())
	await _frames(2)
	assert(boss.state_name() != "SMOKE_ESCAPE")
	await _head_landing()
	player.reset_at(level.spawn_point.global_transform)
	await _frames(2)
	assert(not player.is_ground_held() and boss.state_name() != "SMOKE_ESCAPE")
	var source := Node3D.new()
	level.add_child(source)
	await process_frame # Let the level's deferred actor/audio binding finish.
	assert(player.begin_ground_hold(source, 5.0))
	source.free()
	await _frames(2)
	assert(not player.is_ground_held() and player.get("_ground_hold_remaining") == 0.0)
	await _head_landing()
	var speed: float = boss.smoke_escape_speed
	boss.smoke_escape_speed = 0.0
	await _until(func(): return not player.is_ground_held(), 180, "Obstructed retreat trapped the player.")
	boss.smoke_escape_speed = speed

	# A hit displays both authored Hurt frames while the live salvo continues.
	controls.set_boss_active(true)
	player.set_physics_process(false)
	boss._start_salvo(player)
	await _frames(12)
	var phase: float = boss.phase_time
	boss.receive_melee_hit(player.global_position, CombatHit.new(25, &"knife"))
	var hurt_frames := {}
	for tick in 14:
		await _frames(1)
		if boss.visual.texture.resource_path.ends_with("/Hurt.png"):
			hurt_frames[boss.visual.frame] = true
	assert(hurt_frames.has(0) and hurt_frames.has(1), "Both source Hurt frames must play.")
	assert(boss.state_name() == "SALVO" and boss.phase_time > phase + 0.18)
	assert(boss.missiles_fired >= 1, "Hurt presentation cannot cancel the pending missile.")
	assert(not boss.visual.texture.resource_path.ends_with("/Hurt.png"))
	assert(boss.health.current == 288)
	assert(boss.smoke_escapes == 0 and not player.is_ground_held(), "Knife hits must not deploy smoke.")
	boss.receive_projectile_hit(player.global_position, CombatHit.new(25, &"bullet"))
	assert(boss.health.current == 263 and boss.smoke_escapes == 0 and not player.is_ground_held(),
		"Bullets must not deploy smoke.")

	# Normal tank suspension remains a separate unchanged status.
	controls.reset_fight()
	assert(player.receive_psychic_hit(Vector3.ZERO, CombatHit.new(25, &"psychic"), 0.15))
	assert(player.is_psychically_frozen() and not player.is_ground_held())
	await _frames(12)
	assert(not player.is_control_locked())
	game.queue_free()
	await process_frame
	print("Boss smoke escape passed: real head contact, no stomp damage/bounce, grounded input lock through real counterattacks, gradual following smoke, wall clearance, airborne interruption, release/cleanup/failsafe, Hurt frames and uninterrupted salvo.")
	quit()

func _counterattack_check(attack_pattern: int) -> void:
	await _head_landing(INF, attack_pattern)
	player.health.reset(1000) # Measure real incoming hits without an automatic death/reset.
	var held_x := player.global_position.x
	await _until(func(): return boss.state_name() != "SMOKE_ESCAPE", 140, "Retreat did not lead to a counterattack.")
	assert(player.is_ground_held() and player.is_on_floor())
	assert(boss.state_name() == ("JUMP" if attack_pattern == 2 else "SALVO"))
	var smoke := get_nodes_in_group("boss_smoke")[0] as Node3D
	var fade_start: float = smoke.get("_fade_remaining")
	var held_frames := 0
	var held_time := 0.0
	var damaged_while_held := false
	for action in ACTIONS: Input.action_press(action)
	while player.is_ground_held() and held_frames < 240:
		damaged_while_held = damaged_while_held or player.health.current < 1000
		held_frames += 1
		held_time += boss.get_physics_process_delta_time()
		await physics_frame
	for action in ACTIONS: Input.action_release(action)
	assert(not player.is_ground_held() and held_time >= 1.45 and held_time <= 1.6,
		"Counterattack punishment must last about 1.5 game seconds; hit-stop can extend wall time: " + str(held_time))
	assert(damaged_while_held, "The boss must get a real attack opportunity before the player escapes.")
	assert(is_instance_valid(smoke) and smoke.get("_fade_remaining") < fade_start)
	assert(absf(smoke.global_position.x - player.global_position.x) < 0.2)
	assert(absf(smoke.global_position.y - player.feet_world_y()) < 0.1)
	if attack_pattern == 1:
		assert(boss.missiles_fired == 6 and boss.missile_cooldown_remaining > 4.0)
		assert(absf(player.global_position.x - held_x) < 0.03, "Running and dash must stay locked through the barrage.")
	else:
		assert(boss.landing_count == 1 and boss.jump_cooldown_remaining > 6.0)
	print("Smoke counterattack pattern=", attack_pattern, " held_frames=", held_frames, " game_seconds=", held_time,
		" damage_before_release=", 1000 - player.health.current)

func _head_landing(edge := INF, counter_pattern := -1) -> void:
	controls.set_boss_active(false)
	boss.set_pattern(maxi(counter_pattern, 0))
	await _frames(3)
	if counter_pattern >= 0:
		boss.set_enabled(true)
		if counter_pattern == 1: boss._start_salvo(player)
	if is_finite(edge): boss.global_position.x = edge
	player.reset_at(Transform3D(Basis.IDENTITY, boss.global_position +
		Vector3(0, boss.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y + 0.2, 0)))
	player.velocity.y = -5.0
	level.camera.snap_to_target()
	await _until(func(): return player.is_ground_held(), 30, "A real descending head contact must trigger smoke.")

func _frames(count: int) -> void:
	for tick in count: await physics_frame

func _until(predicate: Callable, maximum_frames: int, message: String) -> void:
	for tick in maximum_frames:
		if predicate.call(): return
		await physics_frame
	if not predicate.call():
		printerr(message)
		quit(1)
		assert(false, message)
