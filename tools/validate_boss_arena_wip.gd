extends SceneTree
## Boss Arena WIP graybox: room limits the movement kit can use, and the boss's
## pass-up leaps. Playtesting owns the feel; these are the physical contracts.
var _game: Node
var _level: LevelSession3D
var _boss: CharacterBody3D
var _player: PlayerCharacter
var _controls: Node
var _landings: Array[Vector3] = []

func _init() -> void:
	call_deferred("_run")
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("Boss arena validation timed out.")
		quit(1))

func _run() -> void:
	_game = load("res://scenes/app/game_root.tscn").instantiate()
	_game.persist_progression = false
	root.add_child(_game)
	await process_frame
	var definition: LevelDefinition = null
	for candidate in _game.developer_level_definitions:
		if candidate.level_id == &"dev_boss_arena_wip": definition = candidate
	assert(definition != null, "The arena is listed in the developer selector.")
	assert(_game.developer_level_definitions[4].level_id == &"dev_boss_test_lab",
		"Boss lab checks load entry 4; keep the lab there.")
	_game.load_developer_level(definition)
	await _frames(12)
	_level = _game.current_level
	_boss = _level.get_node("GreenZoneBoss")
	_controls = _level.get_node("BossLabController")
	_player = _level.player
	assert(_level.get("_progression_store") == null, "The arena never writes campaign progress.")
	_boss.landed.connect(func(point: Vector3): _landings.append(point))
	_validate_room()
	await _validate_one_way_decks()
	await _validate_chase_onto_deck()
	await _validate_staged_chase()
	await _validate_attack_leap_keeps_level()
	await _validate_fit_camera()
	await _validate_phase_two()
	await _validate_aim_look_and_ammo()
	await _validate_firebombs()
	print("Boss arena WIP validation passed.")
	quit(0)

func _validate_room() -> void:
	var left := _level.get_node("Platforms/LeftWall") as PixelPlatform3D
	var right := _level.get_node("Platforms/RightWall") as PixelPlatform3D
	var roof := _level.get_node("Platforms/Ceiling") as PixelPlatform3D
	var width := right.position.x - right.size.x * 0.5 - (left.position.x + left.size.x * 0.5)
	# Compressed so the fit-both camera keeps the boss in view across most of it.
	assert(width >= 44.0 and width <= 52.0, "The arena stays about 48 m wide: %.2f m." % width)
	assert(roof.position.y - roof.size.y * 0.5 >= 40.0, "The arena is tall enough for the climb loop.")
	var double_jump := _player.movement.ideal_jump_height() * 2.0
	var boss_half := ((_boss.body_collision.shape as BoxShape3D).size.x) * 0.5
	var tower := _level.get_node("Props/MainTower")
	var spans: Array[Vector3] = tower.deck_spans()
	assert(spans.size() >= 6, "The tower has several staggered decks.")
	var previous_top := 0.0
	for span in spans:
		assert(span.y - previous_top <= double_jump - 0.3,
			"Each tower deck is within a double jump of the one below: %.2f m." % (span.y - previous_top))
		assert(span.z - span.x >= boss_half * 2.0 + 0.4, "Each deck fits the boss's body.")
		previous_top = span.y
	# Supply chests stand on scaffold decks, clear of the deck ends.
	var all_spans: Array[Vector3] = []
	for frame in _level.get_node("Props").get_children():
		if frame.has_method("deck_spans"): all_spans.append_array(frame.deck_spans())
	var chests := 0
	for reward in _level.get_node("Props").get_children():
		if not reward is ItemReward3D: continue
		chests += 1
		var supported := false
		for span in all_spans:
			if absf(reward.global_position.y - span.y) < 0.01 \
					and reward.global_position.x > span.x + 0.6 and reward.global_position.x < span.z - 0.6:
				supported = true
		assert(supported, "%s must stand on a scaffold deck." % reward.name)
	assert(chests >= 2, "The arena has at least two supply chests.")

func _validate_one_way_decks() -> void:
	_controls.set_boss_active(false)
	await _frames(6)
	var spans: Array[Vector3] = _level.get_node("Props/MainTower").deck_spans()
	var low: Vector3 = spans[0]
	var high: Vector3 = spans[1]
	var x := (low.x + low.z) * 0.5
	# Jumping from below passes up through a deck and lands on its top.
	_place_player(Vector3(x, low.y - 2.2, 0))
	_player.velocity.y = _player.movement.jump_velocity
	await _until(func(): return _player.is_on_floor() and _player.velocity.y <= 0.0, 120,
		"The player must come down after rising through the deck.")
	assert(absf(_player.feet_world_y() - low.y) < 0.1, "Rising through a deck lands on its top: %.2f." % _player.feet_world_y())
	# move_down drops through the deck stood on and lands on the next one below.
	_place_player(Vector3(x, high.y, 0))
	await _frames(6)
	assert(_player.is_on_floor() and absf(_player.feet_world_y() - high.y) < 0.1, "The player stands on the upper deck.")
	Input.action_press(&"move_down")
	await _frames(2)
	Input.action_release(&"move_down")
	await _until(func(): return _player.is_on_floor() and _player.feet_world_y() < high.y - 1.0, 120,
		"move_down must drop through the deck.")
	assert(absf(_player.feet_world_y() - low.y) < 0.1, "The drop stops on the deck below, not the floor.")
	# Player bullets cross decks so the player can shoot down at the boss.
	var deck_layer: int = preload("res://scripts/props/scaffold_tower_3d.gd").ONE_WAY_LAYER
	assert(deck_layer & 7 == 0, "Decks stay off the layers that bullets and rockets query.")
	_controls.set_boss_active(true)

func _place_player(position: Vector3) -> void:
	_player.global_position = position + Vector3(0, PlayerCharacter.FEET_OFFSET_Y + 0.02, 0)
	_player.velocity = Vector3.ZERO
	_player.health.reset(5000)

func _place_boss(position: Vector3) -> void:
	_boss.global_position = position
	_boss.velocity = Vector3.ZERO
	_boss.phase_remaining = 0.2

func _validate_chase_onto_deck() -> void:
	_controls.select_pattern(2)
	await _frames(6)
	var deck: Vector3 = _level.get_node("Props/MainTower").deck_spans()[0]
	_place_player(Vector3(deck.x + 2.0, deck.y, 0))
	_place_boss(Vector3(deck.z + 2.0, 0, 0))
	_level.camera.snap_to_target()
	await _frames(4)
	assert(_player.is_on_floor(), "The player stands on the first tower deck.")
	_landings.clear()
	await _until(func(): return _boss.chase_leaps >= 1 and not _landings.is_empty(), 360,
		"The boss must leap up onto the player's deck.")
	var landing: Vector3 = _landings[0]
	assert(absf(landing.y - deck.y) < 0.12, "The chase leap lands on the deck top, not the floor: %.2f." % landing.y)
	assert(landing.x > deck.x + 1.3 and landing.x < deck.z - 1.3, "The whole body lands on the deck span.")
	# The landing jolts the camera in whole screen pixels, then settles.
	var camera = _level.camera
	var shook := false
	for frame in int((_boss.landing_shake_time + 0.2) * 60.0):
		var offset: Vector2 = camera.shake_offset_pixels()
		assert(offset == offset.round(), "Shake offsets stay on whole pixels: %s." % offset)
		shook = shook or offset != Vector2.ZERO
		await _frames(1)
	assert(shook, "A landing shakes the camera.")
	assert(camera.shake_offset_pixels() == Vector2.ZERO, "The shake dies away.")

func _validate_staged_chase() -> void:
	_controls.select_pattern(2)
	await _frames(6)
	var spans: Array[Vector3] = _level.get_node("Props/MainTower").deck_spans()
	var roof: Vector3 = spans[spans.size() - 1]
	var player_x := roof.z - 2.0
	_place_player(Vector3(player_x, roof.y, 0))
	_place_boss(Vector3(player_x + 6.0, 0, 0))
	_level.camera.snap_to_target()
	await _frames(4)
	assert(_player.is_on_floor(), "The player stands on the tower roof.")
	assert(roof.y - _boss.global_position.y > _boss.maximum_chase_rise, "The roof is beyond one leap from the floor.")
	_landings.clear()
	await _until(func(): return not _landings.is_empty(), 360, "The boss must start climbing toward the roof.")
	var first: Vector3 = _landings[0]
	assert(first.y > 2.0 and first.y < roof.y - 0.5, "Out of reach, it lands on an intermediate deck first.")
	assert(first.y - 0.0 <= _boss.maximum_chase_rise + 0.01)

func _validate_attack_leap_keeps_level() -> void:
	_controls.select_pattern(2)
	await _frames(6)
	var deck: Vector3 = _level.get_node("Props/MainTower").deck_spans()[0]
	# The boss stands under the first deck; the player is on the floor beyond the
	# tower. The ordinary leap rises through the deck and comes back to the floor.
	_place_boss(Vector3((deck.x + deck.z) * 0.5, 0, 0))
	_place_player(Vector3(deck.z + 7.0, 0, 0))
	_level.camera.snap_to_target()
	await _frames(4)
	_landings.clear()
	await _until(func(): return not _landings.is_empty(), 360, "The ordinary attack leap must land.")
	assert(absf(_landings[0].y) < 0.12, "An attack leap passes through decks and returns to its own level.")
	assert(_boss.chase_leaps == 0, "A player on the boss's level is attacked, not chased.")

func _validate_fit_camera() -> void:
	_controls.set_boss_active(false)
	await _frames(6)
	var camera := _level.camera as Camera3D
	assert(camera.get("fit_both") == true, "The arena camera fits the player and the boss.")
	assert(is_zero_approx(camera.get("encounter_maximum_zoom")), "No fixed cap: only the arena limits the zoom.")
	var normal: float = camera.get("_normal_size")
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	var room_zoom: float = camera.call("room_fit_zoom", aspect)
	var spans: Array[Vector3] = _level.get_node("Props/MainTower").deck_spans()
	# Close together: normal zoom, both in view.
	await _frame_pair(Vector3(8.0, 0, 0), Vector3(16.0, 0, 0))
	assert(camera.size < normal * 1.05, "Close together the camera stays near normal zoom.")
	assert(_both_visible(camera), "Close together both actors are in view.")
	# Two decks apart and across most of the room: zoomed only as far as needed.
	for pair in [[Vector3(8.0, spans[2].y, 0), Vector3(16.0, 0, 0)],
			[Vector3(8.0, spans[4].y, 0), Vector3(44.0, 0, 0)]]:
		await _frame_pair(pair[0], pair[1])
		var needed: float = camera.call("required_fit_zoom",
			_boss.global_position + Vector3.UP * 1.5 - _player.global_position, aspect)
		assert(needed <= room_zoom, "This separation fits inside the arena view.")
		assert(_both_visible(camera), "Both actors stay in view at %.2fx." % (camera.size / normal))
		assert(camera.size > normal * needed * 0.95 and camera.size < normal * needed * 1.05,
			"It zooms out only as far as needed: %.2fx for %.2fx." % [camera.size / normal, needed])
		_assert_inside_room(camera)
	# Top of the tower against the far floor needs more than the whole room:
	# the view stops at the arena's edges and keeps the player.
	await _frame_pair(Vector3(6.0, spans[spans.size() - 1].y, 0), Vector3(44.0, 0, 0))
	assert(camera.size <= normal * room_zoom + 0.05, "The zoom never shows beyond the arena.")
	assert(camera.size > normal * room_zoom * 0.95, "It uses the whole arena view.")
	assert(camera.is_position_in_frustum(_player.global_position), "The player is always in view.")
	_assert_inside_room(camera)
	_controls.set_boss_active(true)

func _validate_phase_two() -> void:
	_controls.set_boss_active(false)
	await _frames(6)
	var flyers: Array[Node] = _level.get_node("BossPhaseFlyers").flyers()
	assert(flyers.size() == 3, "Three shootable machines wait for phase two.")
	for flyer in flyers:
		assert(not flyer.is_active() and not flyer.visible, "Machines stay dormant in phase one.")
		assert(flyer.get_node("ProjectileHurtbox").collision_layer == 0, "Dormant machines never block bullets.")
		assert(not flyer.is_in_group("melee_target"), "Machines cannot be stabbed or stomped.")
	var maximum: int = _boss.combat.maximum_hp
	var events: Array[int] = []
	_boss.phase_changed.connect(func(new_phase: int): events.append(new_phase))
	_boss.receive_projectile_hit(Vector3.ZERO, CombatHit.new(int(maximum * 0.5), &"test_phase"))
	assert(_boss.phase == 2 and events == [2], "Half health starts phase two once.")
	_boss.receive_projectile_hit(Vector3.ZERO, CombatHit.new(1, &"test_phase"))
	assert(events == [2], "Phase two starts only once.")
	# Arriving machines blink harmlessly before they arm.
	var first: Node3D = flyers[0]
	assert(first.is_active() and not first.is_lethal(), "The first machine arrives arming.")
	_place_player(first.global_position - Vector3(0, PlayerCharacter.FEET_OFFSET_Y, 0))
	await _frames(10)
	assert(not _player.is_dead(), "An arming machine cannot kill.")
	_place_player(Vector3(2.56, 0, 0))
	await _until(func(): return flyers.all(func(f: Node) -> bool: return f.is_lethal()), 300,
		"All machines must arm after their staggered arrival.")
	# Real bullet queries find the machine's hurtbox; three hits destroy it.
	var cast := preload("res://scripts/projectiles/handgun_projectile_3d.gd")
	var hit: Dictionary = cast.cast_shot(first.get_world_3d().direct_space_state,
		first.global_position + Vector3(-3, 0.1, 0), first.global_position + Vector3(3, 0.1, 0), 5, [])
	assert(not hit.is_empty() and hit.collider == first.get_node("ProjectileHurtbox"),
		"Player bullets register on an armed machine.")
	for shot in 3:
		first.get_node("ProjectileHurtbox").receive_projectile_hit(first.global_position, CombatHit.new(25, &"bullet"))
	assert(first.is_destroyed() and not first.visible, "Three handgun hits destroy a machine.")
	await _frames(2)
	assert(first.get_node("ProjectileHurtbox").collision_layer == 0, "A destroyed machine stops catching bullets.")
	# Touching an armed machine is lethal, and the retry starts phase one again.
	var second: Node3D = flyers[1]
	_place_player(second.global_position - Vector3(0, PlayerCharacter.FEET_OFFSET_Y, 0))
	await _until(func(): return _player.is_dead(), 60, "Touching an armed machine must kill.")
	await _until(func(): return not _player.is_dead() and _boss.phase == 1, 400, "Death must reset the fight.")
	await _frames(4)
	for flyer in flyers:
		assert(not flyer.is_active() and flyer.get_node("ProjectileHurtbox").collision_layer == 0,
			"A reset returns every machine to dormant.")
	# Defeat destroys every machine still flying and cancels later arrivals.
	_controls.set_boss_active(false)
	await _frames(4)
	_boss.receive_projectile_hit(Vector3.ZERO, CombatHit.new(int(maximum * 0.5), &"test_phase"))
	await _frames(2)
	_boss.receive_projectile_hit(Vector3.ZERO, CombatHit.new(maximum, &"test_defeat"))
	await _frames(90)
	assert(_boss.is_defeated())
	for flyer in flyers:
		assert(not flyer.is_active(), "No machine survives the boss.")
	_controls.reset_fight()
	await _frames(4)
	_controls.set_boss_active(true)

func _validate_aim_look_and_ammo() -> void:
	_controls.set_boss_active(false)
	_place_player(Vector3(24.0, 0, 0))
	await _frames(6)
	var camera: PixelSideCamera3D = _level.camera
	var handgun: Node = _player.player_handgun
	var maximum: float = camera.aim_look_maximum
	# Checked synchronously: the next physics frame recomputes the real mouse aim.
	handgun.mouse_aim_active = true
	handgun.crosshair_world = _player.global_position + Vector3(4, 6, 0)
	assert(is_equal_approx(camera.aim_look_offset(), 6.0 * camera.aim_look_fraction),
		"Aiming up lifts the view by a fraction of the cursor's height.")
	handgun.crosshair_world = _player.global_position + Vector3(4, 40, 0)
	assert(is_equal_approx(camera.aim_look_offset(), maximum), "The lift is capped.")
	handgun.crosshair_world = _player.global_position + Vector3(4, -3, 0)
	assert(is_zero_approx(camera.aim_look_offset()), "Aiming level or down never moves the view.")
	handgun.mouse_aim_active = false
	handgun.crosshair_world = _player.global_position + Vector3(4, 6, 0)
	assert(is_zero_approx(camera.aim_look_offset()), "Without mouse aim there is no lift.")
	# Infinite ammo tops the reserve back up; reloads still happen.
	assert(_controls.infinite_ammo, "The boss labs default to infinite ammo.")
	_player.inventory.consume(&"handgun_ammo", 40)
	await _frames(2)
	assert(_player.inventory.count(&"handgun_ammo") >= 60, "The reserve refills.")
	_controls.set_no_ammo(true)
	await _frames(4)
	assert(_player.inventory.count(&"handgun_ammo") == 0, "No-ammo mode still wins.")
	_controls.set_no_ammo(false)
	_controls.set_boss_active(true)

func _fires() -> Array[Node]:
	var burning: Array[Node] = []
	for node in get_nodes_in_group("boss_fire"):
		if is_instance_valid(node) and not node.is_queued_for_deletion(): burning.append(node)
	return burning

func _validate_firebombs() -> void:
	assert(_boss.firebomb_enabled, "The arena boss lobs firebombs.")
	# Keep ground punishes out of the earlier checks; they get their own test.
	var camp_time: float = _boss.ground_camp_time
	_boss.ground_camp_time = 999.0
	# A lob commits to the player's spot; patches burn on the floor near it.
	_controls.select_pattern(3)
	await _frames(4)
	_place_player(Vector3(22.0, 0, 0))
	_place_boss(Vector3(32.0, 0, 0))
	await _until(func(): return _boss.lobs_started >= 1, 300, "The boss must lob firebombs.")
	_place_player(Vector3(6.0, 0, 0))
	await _until(func(): return _fires().size() >= _boss.firebombs_per_lob, 180, "Every canister leaves a fire.")
	for fire in _fires():
		assert(absf(fire.global_position.y) < 0.05, "Floor fires sit on the floor surface.")
		assert(absf(fire.global_position.x - 22.0) < _boss.firebomb_spread * 1.6, "Fires land near the committed spot.")
	await _frames(60)
	assert(_fires().size() >= _boss.firebombs_per_lob, "Fires keep burning without contact.")
	# Standing in a fire hurts every second but never puts it out.
	var fire: Node3D = _fires()[0]
	var count := _fires().size()
	_place_player(fire.global_position)
	var health: int = _player.health.current
	await _until(func(): return _player.health.current < health, 60, "A fire must hurt on contact.")
	assert(health - _player.health.current == _boss.firebomb_damage, "A fire deals 25.")
	await _until(func(): return _player.health.current <= health - _boss.firebomb_damage * 2, 120,
		"Staying in a fire hurts again.")
	assert(is_instance_valid(fire) and not fire.is_queued_for_deletion() and _fires().size() == count,
		"Standing in a fire does not put it out.")
	# Landing on it from the air smothers it, at the same single cost.
	_place_player(fire.global_position + Vector3(0, 2.4, 0))
	health = _player.health.current
	var fire_id := fire.get_instance_id()
	await _until(func(): return not is_instance_id_valid(fire_id) or instance_from_id(fire_id).is_queued_for_deletion(), 120,
		"Landing on a fire must put it out.")
	assert(health - _player.health.current == _boss.firebomb_damage, "Putting a fire out costs exactly one hit.")
	assert(_fires().size() == count - 1, "Only the landed-on fire goes out.")
	# Fires go out on their own after their burn time.
	_boss.firebomb_burn_time = 1.0
	_controls.reset_fight()
	await _frames(4)
	assert(_fires().is_empty(), "A reset clears fires.")
	_place_player(Vector3(22.0, 0, 0))
	_place_boss(Vector3(32.0, 0, 0))
	await _until(func(): return _boss.lobs_started >= 1, 300, "Second lob")
	_place_player(Vector3(6.0, 0, 0))
	await _until(func(): return not _fires().is_empty(), 180, "Second lob fires")
	await _until(func(): return _fires().is_empty(), 180, "Fires must burn out after their time.")
	_boss.firebomb_burn_time = 30.0
	# Decks catch canisters: a player on a deck gets a fire on that deck.
	_controls.reset_fight()
	await _frames(4)
	var deck: Vector3 = _level.get_node("Props/MainTower").deck_spans()[0]
	_place_player(Vector3((deck.x + deck.z) * 0.5, deck.y, 0))
	_place_boss(Vector3(deck.z + 4.0, 0, 0))
	await _until(func(): return _boss.lobs_started >= 1, 300, "Deck lob")
	_place_player(Vector3(2.56, 0, 0))
	await _until(func(): return not _fires().is_empty(), 180, "Deck lob fires")
	var on_deck := false
	for burning in _fires():
		on_deck = on_deck or absf(burning.global_position.y - deck.y) < 0.05
	var where := []
	for burning in _fires(): where.append(Vector2(burning.global_position.x, burning.global_position.y))
	assert(on_deck, "A descending canister lands on the deck, not the floor below: %s, deck %s, boss %s, chases %d" % [str(where), str(deck), str(_boss.global_position), _boss.chase_leaps])
	# Standing on the ground too long draws a lob even during the cooldown;
	# standing up on the decks never does.
	_boss.ground_camp_time = camp_time
	_controls.select_pattern(1)
	await _frames(4)
	_place_boss(Vector3(40.0, 0, 0))
	_place_player(Vector3((deck.x + deck.z) * 0.5, deck.y, 0))
	_boss.firebomb_cooldown_remaining = 99.0
	await _frames(int((_boss.ground_camp_time + 1.0) * 60.0))
	assert(_boss.ground_punishes == 0, "Time on a deck is not ground time.")
	_place_player(Vector3(30.0, 0, 0))
	_boss.firebomb_cooldown_remaining = 99.0
	await _until(func(): return _boss.ground_punishes >= 1, int((_boss.ground_camp_time + 3.0) * 60.0),
		"Camping on the ground must draw a lob despite the cooldown.")
	# Defeat clears every fire.
	await _until(func(): return not _fires().is_empty(), 180, "Punish lob fires")
	_boss.receive_projectile_hit(Vector3.ZERO, CombatHit.new(_boss.combat.maximum_hp, &"test_defeat"))
	await _frames(4)
	assert(_fires().is_empty(), "The boss's fires go out with it.")
	_controls.reset_fight()
	_controls.select_pattern(0)
	await _frames(4)

func _frame_pair(player_feet: Vector3, boss_feet: Vector3) -> void:
	_place_player(player_feet)
	_place_boss(boss_feet)
	await _frames(150)

func _both_visible(camera: Camera3D) -> bool:
	return camera.is_position_in_frustum(_player.global_position) \
		and camera.is_position_in_frustum(_boss.global_position + Vector3.UP * 1.5)

func _assert_inside_room(camera: Camera3D) -> void:
	var half_height := camera.size * 0.5
	var floor_block := _level.get_node("Platforms/Floor") as PixelPlatform3D
	var roof := _level.get_node("Platforms/Ceiling") as PixelPlatform3D
	assert(camera.global_position.y - half_height >= floor_block.position.y - floor_block.size.y * 0.5 - 0.05,
		"The view never shows below the floor block.")
	assert(camera.global_position.y + half_height <= roof.position.y + roof.size.y * 0.5 + 0.05,
		"The view never shows above the ceiling block.")

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
