extends SceneTree
## Confirmed damage must play both authored Hurt frames through ordinary movement.
var game: Node
var level: LevelSession3D
var player: PlayerCharacter
var controls: Node
var boss: CharacterBody3D

func _init() -> void:
	call_deferred("_run")
	create_timer(25.0).timeout.connect(func():
		printerr("Player Hurt validation timed out.")
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
	controls = level.get_node("BossLabController")
	boss = level.get_node("GreenZoneBoss")

	# Real boss collision enters Hurt before the hit-pause signal is emitted.
	controls.test_close_pressure()
	await _until(func(): return player.health.current == 75, 90, "Charge did not hit.")
	assert(player.pixel_visual.current_state() == "hurt")
	assert(player.pixel_visual.body.frame == 0)
	assert(not player.pixel_visual.gun.visible and not player.pixel_visual.gun_grip.visible)
	var frames := {}
	var hit_x := player.global_position.x
	for tick in 24:
		if player.pixel_visual.current_state() == "hurt":
			frames[player.pixel_visual.body.frame] = true
		await _frames(1)
	assert(frames.has(0) and frames.has(1), "Damage must render both authored Hurt frames.")
	assert(player.global_position.x < hit_x - 2.0, "Hurt must not stop physical knockback.")
	assert(player.pixel_visual.current_state() != "hurt")
	assert(player.pixel_visual.gun.visible and player.pixel_visual.gun_grip.visible)
	assert(player.health.current == 75 and not player.is_control_locked())

	# A normal enemy round uses the same reaction with either equipped weapon.
	for weapon in [PlayerWeapon.KNIFE, PlayerWeapon.HANDGUN]:
		controls.set_boss_active(false)
		player.request_weapon(weapon)
		await _frames(3)
		var round := load("res://scenes/projectiles/handgun_projectile.tscn").instantiate() as HandgunProjectile3D
		level.add_child(round)
		round.global_position = player.global_position + Vector3(-0.9, 0, 0)
		round.launch(Vector3.RIGHT, boss, CombatHit.new(25, &"bullet"))
		await _until(func(): return player.health.current == 75, 30, "Enemy round did not hit.")
		assert(player.pixel_visual.current_state() == "hurt")
		var start_x := player.global_position.x
		Input.action_press("move_right")
		Input.action_press("jump")
		await _frames(5)
		Input.action_release("jump")
		Input.action_release("move_right")
		assert(player.velocity.y > 0.0 and player.global_position.x > start_x)
		assert(player.pixel_visual.current_state() == "hurt", "Movement cannot instantly overwrite Hurt.")
		await _frames(22)
		assert(player.pixel_visual.current_state() != "hurt")
		assert(player.equipped_weapon_id() == weapon)

	# Duplicate contacts do not restart the reaction; distinct hits still stack.
	controls.reset_fight()
	await _frames(3)
	var hit := CombatHit.new(25, &"enemy_melee")
	assert(player.receive_enemy_hit(boss.global_position, hit))
	await _frames(6)
	var remaining: float = player.get("_hurt_visual_remaining")
	assert(not player.receive_enemy_hit(boss.global_position, hit))
	assert(player.get("_hurt_visual_remaining") == remaining)
	assert(player.receive_enemy_hit(boss.global_position, CombatHit.new(25, &"enemy_melee")))
	assert(player.health.current == 50 and player.pixel_visual.body.frame == 0)
	assert(player.get("_hurt_visual_remaining") > remaining)

	# Death immediately overrides Hurt; reset/restore/inspection clear stale poses.
	assert(player.receive_enemy_hit(boss.global_position, CombatHit.new(50, &"test_fatal")))
	assert(player.is_dead() and player.pixel_visual.current_state() == "death")
	assert(player.get("_hurt_visual_remaining") == 0.0)
	controls.reset_fight()
	await _frames(2)
	assert(player.pixel_visual.current_state() == "idle")
	var saved := player.capture_state()
	player.receive_enemy_hit(boss.global_position, CombatHit.new(25, &"test_restore"))
	player.restore_state(saved)
	await _frames(2)
	assert(player.pixel_visual.current_state() != "hurt")
	player.receive_enemy_hit(boss.global_position, CombatHit.new(25, &"test_inspect"))
	player.set_developer_inspection_enabled(true)
	await _frames(2)
	assert(player.get("_hurt_visual_remaining") == 0.0 and player.pixel_visual.current_state() != "hurt")
	player.set_developer_inspection_enabled(false)
	controls.reset_fight()
	await _frames(2)

	# The existing special stun pose stays fixed and expires without stale Hurt.
	assert(player.receive_psychic_hit(boss.global_position, CombatHit.new(25, &"psychic"), 0.3))
	await _frames(12)
	assert(player.is_psychically_frozen() and player.pixel_visual.current_state() == "hurt")
	assert(player.pixel_visual.body.frame == 0 and player.get("_hurt_visual_remaining") == 0.0)
	await _frames(12)
	assert(not player.is_control_locked() and player.pixel_visual.current_state() != "hurt")
	game.queue_free()
	await process_frame
	print("Player Hurt passed: real charge and enemy bullets, both frames, knife/handgun restore, movement during reaction, duplicate rejection, repeat hits, death/reset/restore/inspection and special stun priority.")
	quit()

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
