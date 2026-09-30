extends SceneTree
## Real scene/physics checks for the isolated first-boss prototype.
var _game: Node
var _level: LevelSession3D
var _boss: CharacterBody3D
var _player: PlayerCharacter
var _controls: Node
var _landing_position := Vector3.ZERO
var _first_missile: Node3D
var _attack_trace: Array[Dictionary] = []
var _trace_time := 0.0

func _init() -> void:
	call_deferred("_run")
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("Boss lab validation timed out.")
		quit(1))

func _run() -> void:
	_game = load("res://scenes/app/game_root.tscn").instantiate()
	_game.persist_progression = false
	root.add_child(_game)
	await process_frame
	var menu := _game.get_node("Interface/LevelSelect/Center/Panel/Margin/Options/WorldList")
	assert(menu.get_node("BossTestLabButton").text == "BOSS TEST LAB")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_8
	key.pressed = true
	_game._unhandled_input(key)
	await process_frame
	assert(_game.current_level_definition.level_id == &"dev_boss_test_lab")
	assert(_game.campaign.find_by_id(&"dev_boss_test_lab") == null)
	_level = _game.current_level
	_boss = _level.get_node("GreenZoneBoss")
	_controls = _level.get_node("BossLabController")
	_player = _level.player
	assert(_level.get("_progression_store") == null)
	for ability in [PlayerAbility.DOUBLE_JUMP, PlayerAbility.WALL_JUMP, PlayerAbility.DASH]:
		assert(_player.has_ability(ability), "All movement abilities start enabled.")
	assert(_player.player_handgun.loaded_rounds == 12)
	assert(_player.inventory.count(&"handgun_ammo") == 60)
	assert(_boss.health.current == 300)
	assert(_boss not in _game.health_inventory_hud.get("_targets"),
		"Bosses use only their encounter bar, never a regular enemy overhead bar.")
	_boss.landed.connect(func(point: Vector3): _landing_position = point)
	_boss.missile_fired.connect(func(projectile: Node3D):
		if not is_instance_valid(_first_missile): _first_missile = projectile)
	_boss.attack_started.connect(func(attack: StringName):
		_attack_trace.append({"attack": attack, "time": _trace_time,
			"missile_wait": _boss.missile_cooldown_remaining,
			"jump_wait": _boss.jump_cooldown_remaining,
			"charge_wait": _boss.charge_cooldown_remaining}))
	await _frames(12)
	assert(_player.is_on_floor() and _boss.is_on_floor())
	_validate_expanded_room()

	# Six real rockets ripple out; extra fixture HP lets the complete attack
	# finish without the death/reset path interrupting the measured salvo.
	_controls.select_pattern(1)
	await _frames(12)
	_player.set_physics_process(false)
	_player.health.reset(1000)
	await _until(func(): return _boss.missiles_fired == 1, 180, "First missile did not fire.")
	var muzzle_y: float = _first_missile.global_position.y
	assert(_first_missile.get("_direction").y > 0.0, "Missiles must launch outward/upward.")
	await _frames(5)
	assert(_first_missile.global_position.y > muzzle_y, "The boost must not dip toward the target.")
	await _until(func(): return _boss.missiles_fired == 6, 180, "Six-tube ripple did not finish.")
	await _frames(100)
	var rocket_damage: int = 1000 - _player.health.current
	assert(rocket_damage >= 25 and rocket_damage <= 150 and rocket_damage % 25 == 0,
		"The fixed-area ripple must threaten a stationary player with ordinary 25 HP hits.")
	assert(_boss.health.current == 300, "The source's hurtbox must not intercept its missiles.")

	# Close targets do not pull the nose straight down or make a missile loop.
	_controls.reset_fight()
	_player.set_physics_process(false)
	_player.global_position = Vector3(12.5, 0.55, 0)
	_first_missile = null
	await _until(func(): return _boss.missiles_fired == 1, 180, "Close-range salvo did not fire.")
	var close_missile := _first_missile
	var locked_target: Vector3 = close_missile.target_position
	_player.global_position.x = 3.0
	await _frames(20)
	assert(is_instance_valid(close_missile))
	assert(close_missile.target_position == locked_target, "Missiles must not follow player movement.")
	assert(close_missile.global_position.y > 2.7, "A close target must not cause an immediate dive.")
	assert(close_missile.get("_direction").x < 0.0, "A missed rocket must not turn back.")

	# Lock a landing destination, then move away. Jump must travel, not retarget.
	_controls.select_pattern(2)
	_player.set_physics_process(false)
	_player.global_position = Vector3(6.0, 0.55, 0)
	await _until(func(): return _boss.state_name() == "JUMP", 180, "Jump did not start.")
	var committed: float = _boss.jump_target_x
	assert(is_equal_approx(committed, 6.0))
	_player.global_position.x = 17.0
	await _until(func(): return _boss.landing_count == 1, 130, "Jump never landed.")
	assert(absf(_landing_position.x - committed) < 0.5, "Jump must reach its committed destination.")
	assert(absf(_landing_position.y) < 0.05, "Impact must be on the arena floor.")
	assert(_player.health.current == 100, "Moving outside the landing footprint must evade it.")
	assert(_boss.state_name() == "RECOVERY")
	assert(_boss.phase_remaining > _boss.landing_active_time + 1.0)

	# Standing at impact loses HP once, despite multiple active physics ticks.
	_controls.reset_fight()
	_player.set_physics_process(false)
	_player.global_position = Vector3(6.0, 0.55, 0)
	await _until(func(): return _boss.landing_count == 1, 240, "Damage test never landed.")
	assert(_player.health.current == 75, "Landing AoE must hit a grounded player.")
	assert(_boss.smoke_escapes == 0 and not _player.is_ground_held(), "The boss's own landing blast must not deploy smoke.")
	assert(absf(_landing_position.y) < 0.05, "Boss must not land on the player's body.")
	await _frames(18)
	assert(_player.health.current == 75, "One landing cannot hit the same player twice.")

	# A player above the impact can evade without leaving its horizontal span.
	_controls.reset_fight()
	_player.set_physics_process(false)
	_player.global_position = Vector3(6.0, 0.55, 0)
	await _until(func(): return _boss.state_name() == "JUMP", 180, "Aerial dodge test did not start.")
	_player.global_position.y = 3.0
	await _until(func(): return _boss.landing_count == 1, 130, "Aerial dodge test never landed.")
	assert(_player.health.current == 100, "Aerial clearance must evade the low landing blast.")

	# Mixed attacks recharge independently while the boss walks between recovery windows.
	_controls.select_pattern(0)
	_player.set_physics_process(false)
	_player.health.reset(10000)
	_attack_trace.clear()
	_trace_time = 0.0
	var walk_frames: Dictionary = {}
	var walking_distance := 0.0
	var previous_x: float = _boss.global_position.x
	for tick in 1000:
		_trace_time += 1.0 / Engine.physics_ticks_per_second
		await _frames(1)
		if _boss.state_name() == "IDLE" and absf(_boss.velocity.x) > 0.1:
			assert(_boss.visual.texture.resource_path.ends_with("/Walk.png"))
			walk_frames[_boss.visual.frame] = true
			walking_distance += absf(_boss.global_position.x - previous_x)
		elif _boss.state_name() in ["SALVO", "RECOVERY"]:
			assert(is_zero_approx(_boss.velocity.x), "Attack and recovery cannot slide across the floor.")
		previous_x = _boss.global_position.x
		assert(_boss.global_position.x >= _boss.minimum_x - 0.01 and _boss.global_position.x <= _boss.maximum_x + 0.01)
	assert(walk_frames.size() >= 4 and walking_distance > 3.0, "The boss must actually walk using its authored cycle.")
	assert(_attack_trace.size() >= 4, "Mixed pattern must continue across cooldown cycles.")
	var primary_attacks := _attack_trace.filter(func(entry): return entry.attack != &"space_charge")
	assert(primary_attacks[0].attack == &"missiles" and primary_attacks[1].attack == &"jump")
	assert(primary_attacks[1].missile_wait > 0.0, "Jump must work while missiles recharge.")
	assert(primary_attacks[2].attack == &"missiles" and primary_attacks[2].jump_wait > 0.0,
		"Missiles must work while jump recharges.")
	var last_attack_time: Dictionary = {}
	for entry in _attack_trace:
		if entry.attack == &"space_charge":
			assert(is_zero_approx(entry.charge_wait))
			continue
		var own_wait: float = entry.missile_wait if entry.attack == &"missiles" else entry.jump_wait
		assert(is_zero_approx(own_wait), "An attack cannot bypass its own cooldown.")
		if last_attack_time.has(entry.attack):
			var minimum_gap: float = _boss.missile_cooldown + _boss.salvo_duration() if entry.attack == &"missiles" else _boss.jump_cooldown + _boss.jump_duration - 0.08
			assert(entry.time - last_attack_time[entry.attack] >= minimum_gap - 0.05)
		last_attack_time[entry.attack] = entry.time

	# Actual knife input and hurtbox detection can finish the boss without ammo.
	_controls.set_no_ammo(true)
	_controls.set_boss_active(false)
	assert(_player.player_handgun.loaded_rounds == 0)
	assert(_player.inventory.count(&"handgun_ammo") == 0)
	_player.global_position = Vector3(13.3, 0.55, 0)
	_player.set_physics_process(true)
	_player.request_weapon(PlayerWeapon.KNIFE)
	for attack_index in 24:
		Input.action_press("attack")
		await _frames(2)
		Input.action_release("attack")
		await _frames(36)
		assert(_boss.health.current == 300 - floori((attack_index + 1) * 12.5),
			"Each real knife swing must deal half damage, preserving fractional HP.")
	assert(_boss.is_defeated(), "The boss must accept a full no-ammo knife kill.")
	assert(_boss.health.current == 0)
	await _frames(2)
	assert(_boss.get_node("ProjectileHurtbox").collision_layer == 0)
	var final_count: int = _boss.missiles_fired
	await _frames(90)
	assert(_boss.missiles_fired == final_count and _boss.landing_count == 0)
	assert(get_nodes_in_group("enemy_projectile").is_empty())

	# Reset restores boss hurtboxes, health and selected loadout.
	_controls.reset_fight()
	await _frames(2)
	assert(_boss.health.current == 300 and not _boss.is_defeated())
	assert(_boss.get_node("ProjectileHurtbox").collision_layer == 4)
	assert(_player.health.current == 100)
	assert(_player.player_handgun.loaded_rounds == 0)
	_controls.set_no_ammo(false)
	_player.set_physics_process(false)
	# Keep this damage/hurtbox probe inside the follow camera, independent of
	# desktop mouse position and camera smoothing after the preceding reset.
	_player.global_position = Vector3(11, 0.55, 0)
	_player.player_handgun.set("_mouse_requested", false)
	_level.camera.snap_to_target()
	await _frames(2)
	var shot := _player.player_handgun.fire(1.0, false, _player)
	assert(shot != null)
	await _until(func(): return _boss.health.current < 300, 160, "Player bullet did not damage boss.")
	assert(_boss.health.current == 275, "Machine armor must not reduce handgun damage.")
	_controls.set_boss_active(true)
	# This checks airborne defeat, so survive the now six-rocket opening first.
	_player.health.reset(1000)
	await _until(func(): return _boss.state_name() == "JUMP" and _boss.global_position.y > 2.0,
		420, "Final jump did not reach the air after the mixed salvo/recovery.")
	_boss.receive_melee_hit(_player.global_position, CombatHit.new(300, &"test_defeat"))
	await _frames(120)
	assert(_boss.is_defeated() and absf(_boss.global_position.y) < 0.05,
		"An airborne defeat must settle to the floor without an impact attack.")
	_controls.reset_fight()
	await _frames(2)
	assert(get_nodes_in_group("enemy_projectile").is_empty())
	Input.action_release("attack")
	_game.queue_free()
	await process_frame
	print("Boss test lab passed: expanded room/follow camera, walking cycle, independent staggered cooldowns, menu, save isolation, mobility, missiles, committed jump, landing dodges, knife kill, projectile hurtbox, defeat and reset.")
	quit(0)

func _validate_expanded_room() -> void:
	var left := _level.get_node("Platforms/LeftWall") as PixelPlatform3D
	var right := _level.get_node("Platforms/RightWall") as PixelPlatform3D
	var roof := _level.get_node("Platforms/Ceiling") as PixelPlatform3D
	assert(is_equal_approx(right.position.x - right.size.x * 0.5 - left.position.x - left.size.x * 0.5, 19.2 * 3.0))
	assert(is_equal_approx(roof.position.y - roof.size.y * 0.5, 10.24 * 3.0))
	assert(is_equal_approx(left.size.y, 30.72) and is_equal_approx(right.size.y, 30.72))
	for point in [Vector3(-17.0, 0.55, 0), Vector3(37.0, 0.55, 0)]:
		assert(_player.test_move(Transform3D(Basis.IDENTITY, point + Vector3.UP), Vector3.DOWN * 2.0), "Expanded floor must be solid at both ends.")
	var spawn := _player.global_transform
	for point in [Vector3(-17, 0.55, 0), Vector3(37, 0.55, 0), Vector3(0, 26, 0)]:
		_player.global_position = point
		_level.camera.snap_to_target()
		assert(_level.camera.size >= 12.9375 and _level.camera.size <= 12.9375 * 1.22 + 0.001,
			"Boss framing must stay within its modest zoom range.")
		assert(_level.camera.is_position_in_frustum(point), "Follow camera must keep the player visible throughout the room.")
	_player.global_transform = spawn
	_level.camera.snap_to_target()

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _until(condition: Callable, limit: int, message: String) -> void:
	for index in limit:
		if condition.call():
			return
		await _frames(1)
	quit(1)
	assert(false, message)
