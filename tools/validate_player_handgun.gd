extends SceneTree
## Focused contract for the first player firearm before an ammunition economy
## exists: session ownership, two-slot input, presentation, projectile
## allegiance, explicit enemy hurt surfaces, feedback, and reset policy.

const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")
const PATROL_ENEMY := preload("res://scenes/enemies/pixel_patrol_enemy.tscn")

var _completed := false


func _init() -> void:
	create_timer(15.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	_release_test_input()
	printerr("Player handgun validation aborted before completing.")
	quit(1)


func _run() -> void:
	_validate_input_map()
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var level := SHOOTER_AREA.load_into(game_root)
	for frame in 8:
		await physics_frame

	var player := level.player
	var hud := game_root.get_node("Interface/WeaponStatusHUD") as WeaponStatusHUD
	var pickup := level.get_node(
		"ShooterEncounterStaging/GunDropAnchor/HandgunPickup"
	) as HandgunPickup3D
	assert(player != null and hud != null and pickup != null)
	assert(player.player_handgun != null)
	assert(player.player_handgun.definition.weapon_id == PlayerWeapon.HANDGUN)
	assert(player.player_handgun.definition.validation_errors().is_empty())
	_assert_no_ammo_contract(player.player_handgun.definition, hud)

	assert(level.owned_weapon_ids() == [PlayerWeapon.KNIFE])
	assert(player.owned_weapon_ids() == [PlayerWeapon.KNIFE])
	assert(player.equipped_weapon_id() == PlayerWeapon.KNIFE)
	assert(not player.request_weapon(PlayerWeapon.HANDGUN))
	assert(not hud.status_is_visible())

	assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	assert(not level.acquire_weapon(PlayerWeapon.HANDGUN))
	await physics_frame
	assert(level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(player.owns_weapon(PlayerWeapon.HANDGUN))
	assert(player.equipped_weapon_id() == PlayerWeapon.HANDGUN)
	assert(hud.status_is_visible())
	assert(hud.hint_is_visible())
	assert(hud.highlighted_weapon_id() == PlayerWeapon.HANDGUN)
	assert(player.pixel_visual.gun.visible)
	assert(player.pixel_visual.gun_grip.visible)
	assert(not player.pixel_visual.weapon.visible)
	assert(player.pixel_visual.body.texture.resource_path.ends_with(
		"/player_handgun_idle_one_hand.png"
	))
	assert(player.pixel_visual.gun_grip.texture.resource_path.ends_with(
		"/player_handgun_grip_horizontal.png"
	))
	assert(player.pixel_visual.gun.position.z < player.pixel_visual.gun_grip.position.z)
	assert(player.pixel_visual.gun_grip.position.z < player.pixel_visual.body.position.z)
	assert(player.pixel_visual.gun_grip.render_priority < player.pixel_visual.body.render_priority)
	assert(player.pixel_visual.gun.offset.is_equal_approx(
		Vector2(13.5, 3.0) + player.pixel_visual.handgun_grip_offset()
	))

	# The authored key and both directional wheel inputs drive the same two-slot
	# state. With two items, either wheel direction toggles predictably.
	await _press_selection("weapon_slot_1")
	assert(player.equipped_weapon_id() == PlayerWeapon.KNIFE)
	assert(hud.highlighted_weapon_id() == PlayerWeapon.KNIFE)
	await _press_selection("weapon_cycle_previous")
	assert(player.equipped_weapon_id() == PlayerWeapon.HANDGUN)
	await _press_selection("weapon_cycle_next")
	assert(player.equipped_weapon_id() == PlayerWeapon.KNIFE)
	await _press_selection("weapon_slot_2")
	assert(player.equipped_weapon_id() == PlayerWeapon.HANDGUN)

	# Switching cannot rewrite an already-active knife strike. It applies at the
	# exact action boundary instead.
	player.request_weapon(PlayerWeapon.KNIFE)
	Input.action_press("attack")
	for frame in 2:
		await physics_frame
	Input.action_release("attack")
	assert(player.is_melee_attacking())
	assert(player.request_weapon(PlayerWeapon.HANDGUN))
	assert(player.equipped_weapon_id() == PlayerWeapon.KNIFE)
	assert(player.active_attack_weapon_id() == PlayerWeapon.KNIFE)
	player.call(&"_update_attack", player.attack_duration)
	assert(not player.is_attacking())
	assert(player.equipped_weapon_id() == PlayerWeapon.HANDGUN)

	# A real family-2 round must hit the enemy's visible projectile surface at
	# the same height as the visible gun, without enlarging its movement body.
	var target := PATROL_ENEMY.instantiate() as StompableEnemy3D
	target.name = "PlayerHandgunTarget"
	target.position = Vector3(4.0, 0.42, 0.0)
	level.add_child(target)
	target.set_physics_process(false)
	var fired: Array[HandgunProjectile3D] = []
	var impact_count := [0]
	player.projectile_fired.connect(
		func(projectile: HandgunProjectile3D) -> void:
			fired.append(projectile)
	)
	level.combat_feedback.projectile_impact_presented.connect(
		func(_position: Vector3, _normal: Vector3) -> void:
			impact_count[0] += 1
	)
	Input.action_press("attack")
	for frame in 2:
		await physics_frame
	Input.action_release("attack")
	assert(player.active_attack_weapon_id() == PlayerWeapon.HANDGUN)
	assert(not player.is_melee_attacking())
	for frame in 30:
		await physics_frame
		if not fired.is_empty():
			break
	assert(fired.size() == 1)
	var horizontal_round := fired[0]
	assert(horizontal_round.is_player_owned())
	assert(horizontal_round.is_in_group("player_projectile"))
	assert(not horizontal_round.is_in_group("enemy_projectile"))
	assert(horizontal_round.travel_direction().is_equal_approx(Vector3.RIGHT))
	assert(horizontal_round.visual.texture.resource_path.ends_with(
		"/player_handgun_bullet_horizontal.png"
	))
	assert(player.pixel_visual.shot_effect.visible)
	for frame in 60:
		await physics_frame
		if target.is_defeated():
			break
	assert(target.is_defeated())
	assert(impact_count[0] == 1)
	assert(not player.is_dead())

	# The second authored source pose is vertically pixel-flipped for up-diagonal
	# fire. The body stays upright and the projectile really travels upward.
	player.call(&"_finish_active_attack")
	for frame in 20:
		await physics_frame
	Input.action_press("aim_up")
	Input.action_press("attack")
	for frame in 2:
		await physics_frame
	Input.action_release("attack")
	for frame in 30:
		await physics_frame
		if fired.size() >= 2:
			break
	Input.action_release("aim_up")
	assert(fired.size() == 2)
	var diagonal_round := fired[1]
	assert(diagonal_round.travel_direction().x > 0.0)
	assert(diagonal_round.travel_direction().y > 0.0)
	assert(is_equal_approx(
		diagonal_round.travel_direction().x,
		diagonal_round.travel_direction().y
	))
	assert(diagonal_round.visual.texture.resource_path.ends_with(
		"/player_handgun_bullet_diagonal.png"
	))
	assert(diagonal_round.visual.flip_v)
	assert(player.pixel_visual.gun.flip_v)
	assert(not player.pixel_visual.gun_grip.flip_v)
	assert(player.pixel_visual.gun_grip.texture.resource_path.ends_with(
		"/player_handgun_grip_diagonal.png"
	))
	assert(player.pixel_visual.body.texture.resource_path.ends_with(
		"/player_handgun_idle_one_hand.png"
	))
	assert(player.pixel_visual.gun.offset.is_equal_approx(
		Vector2(10.0, 10.0) + player.pixel_visual.handgun_grip_offset()
	))

	Input.action_release("aim_up")
	player.pixel_visual.set_state("idle", true)
	for facing in [-1.0, 1.0]:
		for height in [-20.0, -2.0, 0.0, 2.0, 20.0]:
			var target_point := player.global_position + Vector3(8.0 * facing, height, 0)
			player.player_handgun.update_mouse_aim(facing, target_point)
			var direction := player.player_handgun.aim_direction
			assert(direction.x * facing >= -0.0001)
			assert(absf(direction.y) <= 1.0)
			var muzzle := player.pixel_visual.handgun_muzzle_world()
			var crosshair_ray := (player.player_handgun.crosshair_world - muzzle).normalized()
			assert(crosshair_ray.is_equal_approx(direction))
			if absf(height) <= 2.0:
				assert((target_point - muzzle).normalized().is_equal_approx(direction))
		player.player_handgun.update_mouse_aim(facing, player.global_position + Vector3(-8 * facing, 3, 0))
		assert(player.player_handgun.aim_direction.x * facing < 0.0)
		assert(player.pixel_visual.body.flip_h == (facing > 0.0))
		player.player_handgun.update_mouse_aim(facing, player.global_position + Vector3(-8 * facing, -3, 0))
		assert(player.player_handgun.aim_direction.x * facing < 0.0)
		assert(player.player_handgun.aim_direction.y < 0.0)
		player.player_handgun.update_mouse_aim(facing, player.global_position + Vector3(8 * facing, 0.5, 0))
		var close_target := player.pixel_visual.handgun_muzzle_world() + player.player_handgun.aim_direction * 0.15
		player.player_handgun.update_mouse_aim(facing, close_target)
		assert(player.player_handgun.crosshair_world.distance_to(close_target) < 0.001)
	var movement_facing: float = player._facing_sign
	var dash_direction: float = player._dash_direction
	for previous in [-1.0, 1.0]:
		assert(PlayerHandgun3D.mouse_facing_for_target(0.05, previous) == previous)
		assert(PlayerHandgun3D.mouse_facing_for_target(-0.05, previous) == previous)
		player.player_handgun.update_mouse_aim(previous, player.global_position + Vector3(-3 * previous, 2, 0))
		player.player_handgun.update_mouse_aim(previous, player.global_position + Vector3(0.05, 8, 0))
		assert(player.player_handgun._mouse_facing_sign == -previous)
	assert(player._facing_sign == movement_facing)
	assert(player._dash_direction == dash_direction)
	assert(player.pixel_visual.shot_effect.region_enabled)
	assert(player.pixel_visual.shot_effect.region_rect.size == Vector2(4, 8))
	player.player_handgun.update_mouse_aim(1.0)

	# Checkpoint/death-style reset retains the run reward and selection. Manual R
	# is the full section restart and deliberately rearms the knife encounter.
	level.call(&"_reset_world")
	await physics_frame
	assert(level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(player.equipped_weapon_id() == PlayerWeapon.HANDGUN)
	assert(hud.status_is_visible())
	level.call(&"_reset_run")
	await physics_frame
	assert(not level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(player.equipped_weapon_id() == PlayerWeapon.KNIFE)
	assert(not hud.status_is_visible())
	assert(pickup.is_locked())

	_release_test_input()
	print(
		"Player handgun passed: no-ammo pickup ownership, two-slot input, "
		+ "deferred switching, layered pose wiring, player allegiance, enemy "
		+ "hurt surfaces, impact feedback, and deterministic reset policy."
	)
	_completed = true
	quit(0)


func _press_selection(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)
	await physics_frame


func _validate_input_map() -> void:
	for action in [
		&"weapon_slot_1",
		&"weapon_slot_2",
		&"weapon_cycle_next",
		&"weapon_cycle_previous",
		&"aim_up",
	]:
		assert(InputMap.has_action(action), "Missing player-weapon action '%s'." % action)
	assert(_action_has_key(&"weapon_slot_1", KEY_1))
	assert(_action_has_key(&"weapon_slot_2", KEY_2))
	assert(_action_has_mouse_button(&"weapon_cycle_next", MOUSE_BUTTON_WHEEL_DOWN))
	assert(_action_has_mouse_button(&"weapon_cycle_previous", MOUSE_BUTTON_WHEEL_UP))
	assert(_action_has_joy_button(&"weapon_cycle_next", JOY_BUTTON_RIGHT_SHOULDER))
	assert(_action_has_key(&"aim_up", KEY_W))
	assert(_action_has_key(&"aim_up", KEY_UP))


func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _action_has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == button
		):
			return true
	return false


func _action_has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if (
			event is InputEventJoypadButton
			and (event as InputEventJoypadButton).button_index == button
		):
			return true
	return false


func _assert_no_ammo_contract(
	definition: FirearmDefinition,
	hud: WeaponStatusHUD
) -> void:
	for property in definition.get_property_list():
		assert("ammo" not in String(property.name).to_lower())
	for node in hud.find_children("*", "Label", true, false):
		assert("AMMO" not in (node as Label).text.to_upper())


func _release_test_input() -> void:
	for action in [
		&"attack",
		&"aim_up",
		&"weapon_slot_1",
		&"weapon_slot_2",
		&"weapon_cycle_next",
		&"weapon_cycle_previous",
	]:
		Input.action_release(action)
