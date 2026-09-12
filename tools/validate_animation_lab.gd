extends SceneTree
## Focused contract for Firearm Review Lab and its retained ability fixtures.

var _finished := false


func _init() -> void:
	call_deferred("_run")
	create_timer(12.0).timeout.connect(_on_watchdog_timeout)


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_scene != null)
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame

	game_root.load_developer_room()
	await process_frame
	var room := game_root.current_level as LevelSession3D
	assert(room != null)
	assert(game_root.current_world_definition == null)
	assert(game_root.current_level_definition.level_id == &"dev_animation_lab")
	assert(
		game_root.current_level_definition.available_abilities
		== PlayerAbility.IMPLEMENTED,
		"Every implemented ability must be exposed in Firearm Review Lab."
	)
	assert(room.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(room.player.aerial_jumps_remaining() == 1)
	assert(room.get_node("Platforms").get_child_count() == 3)
	assert(room.get_node_or_null("Platforms/Floor") is StaticBody3D)
	assert(room.get_node_or_null("Platforms/LeftWall") is StaticBody3D)
	assert(room.get_node_or_null("Platforms/RightWall") is StaticBody3D)
	var cover := room.get_node_or_null("Props/CoverRock") as StaticBody3D
	assert(cover != null)
	assert(cover.get_node_or_null("Visual") is Sprite3D)
	assert(is_equal_approx((cover.get_node("Visual") as Sprite3D).pixel_size, 0.04))
	assert(cover.get_node_or_null("TallCollision") is CollisionShape3D)
	assert(cover.get_node_or_null("LowCollision") is CollisionShape3D)
	var shooter := room.get_node_or_null("HandgunEnemy") as HandgunEnemy3D
	assert(shooter != null)
	assert(shooter.current_fire_pattern() == HandgunEnemy3D.FirePattern.TRIPLE)
	assert(is_equal_approx(shooter.projectile_speed, 8.5))
	assert(is_equal_approx(shooter.active_shot_interval(), 0.18))
	assert(is_equal_approx(shooter.triple_shot_interval, 0.18))
	_validate_shot_markers(shooter)
	assert(shooter.projectiles_per_fire_beat() == 2)
	assert(shooter.fire_beat_count() == 3)
	assert(shooter.expected_projectiles_per_attack() == 6)
	shooter.shot_fired.connect(func(projectile: HandgunProjectile3D) -> void:
		var direction := projectile.travel_direction()
		var elevation := atan2(direction.y, absf(direction.x))
		var flash_frame := 1
		var gun_index := (shooter.shots_fired_total() - 1) % 2
		var barrel_pixel: Vector2 = [Vector2(30.0, 26.0), Vector2(18.0, 25.0)][gun_index]
		if elevation > deg_to_rad(22.5):
			flash_frame = 7
			barrel_pixel = [Vector2(26.0, 14.0), Vector2(17.0, 14.0)][gun_index]
		elif elevation < deg_to_rad(-22.5):
			flash_frame = 4
			barrel_pixel = [Vector2(28.0, 36.0), Vector2(19.0, 35.0)][gun_index]
		assert(shooter.pixel_visual.frame == flash_frame, "Each bullet must launch on its directional flash frame.")
		assert(shooter.pixel_visual.flip_h == (shooter.facing_direction() < 0.0))
		assert(projectile.visual.basis.x.normalized().is_equal_approx(projectile.travel_direction()))
		# Check source-art registrations independently of the visual's helper.
		var barrel := shooter.pixel_visual.global_position + Vector3(
			(barrel_pixel.x - 24.0) * shooter.facing_direction(), 24.0 - barrel_pixel.y, 0.0
		) * shooter.pixel_visual.pixel_size
		barrel.z = 0.0
		assert(projectile.global_position.is_equal_approx(barrel), "Each round must leave its own gun, not a shared origin.")
	)
	_validate_directional_aim(shooter, room.player)
	_validate_volley_pose_hold(shooter)
	shooter.pixel_visual.set_state(&"telegraph", true)
	shooter.pixel_visual.tick(0.1, &"telegraph", false)
	assert(
		shooter.pixel_visual.modulate == Color.WHITE,
		"The first handgun enemy must not use a full-body telegraph blink."
	)
	shooter.reset_combat_cycle(true)
	var combat_feedback := room.get_node_or_null("CombatFeedback") as CombatFeedback3D
	assert(combat_feedback != null)
	assert(combat_feedback.projectile_impact_scene != null)
	var impact_positions: Array[Vector3] = []
	var impact_normals: Array[Vector3] = []
	combat_feedback.projectile_impact_presented.connect(
		func(world_position: Vector3, surface_normal: Vector3) -> void:
			impact_positions.append(world_position)
			impact_normals.append(surface_normal)
	)
	var review_controller := room.get_node_or_null(
		"FirearmReviewController"
	) as FirearmReviewLab3D
	assert(review_controller != null)
	var mode_label := room.get_node_or_null(
		"FirearmReviewInterface/ModeLabel"
	) as Label
	assert(mode_label != null)
	assert(mode_label.text.contains("MODE: THREE DUAL SHOTS"))
	assert(room.get_node("Hazards").get_child_count() == 0)
	assert(room.get_tree().get_nodes_in_group("level_goal").filter(
		func(node: Node) -> bool:
			return room.is_ancestor_of(node)
	).is_empty())
	var instructions := game_root.get_node("Interface/Instructions") as Control
	var ability_panel := game_root.get_node(
		"Interface/DeveloperAbilityPanel"
	) as Control
	assert(not instructions.visible)
	assert(not ability_panel.visible)
	_toggle_gameplay_tools(game_root)
	assert(instructions.visible)
	assert(ability_panel.visible)
	_toggle_gameplay_tools(game_root)
	assert(not instructions.visible)
	assert(not ability_panel.visible)

	var double_jump_toggle := game_root.get_node(
		"Interface/DeveloperAbilityPanel/Margin/Options"
		+ "/DeveloperAbilityToggles/DoubleJumpToggle"
	) as CheckButton
	var wall_jump_toggle := game_root.get_node(
		"Interface/DeveloperAbilityPanel/Margin/Options"
		+ "/DeveloperAbilityToggles/WallJumpToggle"
	) as CheckButton
	var dash_toggle := game_root.get_node(
		"Interface/DeveloperAbilityPanel/Margin/Options"
		+ "/DeveloperAbilityToggles/DashToggle"
	) as CheckButton
	assert(double_jump_toggle != null)
	assert(wall_jump_toggle != null)
	assert(dash_toggle != null)
	assert(double_jump_toggle.button_pressed)
	assert(wall_jump_toggle.button_pressed)
	assert(dash_toggle.button_pressed)
	double_jump_toggle.button_pressed = false
	double_jump_toggle.toggled.emit(false)
	assert(not room.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not room.is_session_ability_enabled(PlayerAbility.DOUBLE_JUMP))
	double_jump_toggle.button_pressed = true
	double_jump_toggle.toggled.emit(true)
	assert(room.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(room.is_session_ability_enabled(PlayerAbility.DOUBLE_JUMP))
	dash_toggle.button_pressed = false
	dash_toggle.toggled.emit(false)
	assert(not room.player.has_ability(PlayerAbility.DASH))
	assert(not room.is_session_ability_enabled(PlayerAbility.DASH))
	dash_toggle.button_pressed = true
	dash_toggle.toggled.emit(true)
	assert(room.player.has_ability(PlayerAbility.DASH))
	assert(room.is_session_ability_enabled(PlayerAbility.DASH))

	room._reset_run()
	await process_frame
	assert(
		room.player.has_ability(PlayerAbility.DOUBLE_JUMP),
		"Room reset must retain session-local test abilities."
	)
	assert(room.player.has_ability(PlayerAbility.DASH))

	# Both patterns share the same dual-projectile fire beat, cover, projectile
	# speed, and damage. Their beat count and timing are the comparison variables.
	var protected_transform := room.player.global_transform
	protected_transform.origin = Vector3(14.72, 0.7, 0.0)
	room.player.reset_at(protected_transform)
	impact_positions.clear()
	impact_normals.clear()
	shooter.set_fire_pattern(HandgunEnemy3D.FirePattern.TWIN)
	await _wait_for_first_volley(shooter)
	assert(shooter.last_completed_volley_shot_count() == 4)
	await create_timer(1.3).timeout
	assert(not room.player.is_dead(), "The cover rock must stop both twin volleys.")
	assert(shooter.active_projectile_count() == 0)
	assert(impact_positions.size() == 4, "Each blocked twin round needs one impact.")
	_assert_cover_impact_normals(impact_normals)
	assert(combat_feedback.active_projectile_impact_count() == 0)

	impact_positions.clear()
	impact_normals.clear()
	review_controller.toggle_fire_pattern()
	assert(shooter.current_fire_pattern() == HandgunEnemy3D.FirePattern.TRIPLE)
	assert(is_equal_approx(shooter.active_shot_interval(), 0.18))
	assert(shooter.projectiles_per_fire_beat() == 2)
	assert(shooter.fire_beat_count() == 3)
	assert(shooter.expected_projectiles_per_attack() == 6)
	assert(mode_label.text.contains("MODE: THREE DUAL SHOTS"))
	await _wait_for_first_volley(shooter)
	assert(shooter.last_completed_volley_shot_count() == 6)
	await create_timer(1.3).timeout
	assert(not room.player.is_dead(), "The cover rock must stop both triple volleys.")
	assert(shooter.active_projectile_count() == 0)
	assert(impact_positions.size() == 6, "Each blocked triple round needs one impact.")
	_assert_cover_impact_normals(impact_normals)
	assert(combat_feedback.active_projectile_impact_count() == 0)

	# Moving into the open proves the same projectile that cover stopped really
	# reaches the normal player damage/reset contract.
	var damage_events: Array[Vector3] = []
	room.player.damage_received.connect(
		func(source_position: Vector3) -> void:
			damage_events.append(source_position)
	)
	var exposed_transform := room.player.global_transform
	exposed_transform.origin = Vector3(20.48, 0.7, 0.0)
	room.player.reset_at(exposed_transform)
	impact_positions.clear()
	impact_normals.clear()
	shooter.set_fire_pattern(HandgunEnemy3D.FirePattern.TWIN)
	await _wait_for_damage(damage_events)
	assert(not damage_events.is_empty(), "An unobstructed handgun round must damage the player.")
	assert(not impact_positions.is_empty(), "A player hit must present the generic impact too.")
	shooter.clear_active_projectiles()

	_finished = true
	print("Firearm Review Lab cadence, impact, cover, and damage validation passed.")
	quit(0)


func _validate_shot_markers(shooter: HandgunEnemy3D) -> void:
	var visual := shooter.pixel_visual
	var markers := [0]
	var record_marker := func() -> void: markers[0] += 1
	visual.shot_frame_reached.connect(record_marker)
	for facing in [-1.0, 1.0]:
		for vertical in [-1.0, 0.0, 1.0]:
			var direction := Vector3(facing, vertical, 0.0).normalized()
			var aim_frame := 3 if vertical < 0.0 else (6 if vertical > 0.0 else 0)
			visual.set_state(&"telegraph", true)
			visual.set_aim_direction(direction, facing > 0.0)
			visual.tick(0.1, &"telegraph", facing > 0.0)
			assert(visual.frame == aim_frame)
			var before: int = markers[0]
			visual.begin_shot(direction, facing > 0.0)
			assert(markers[0] == before + 1 and visual.frame == aim_frame + 1)
			visual.set_aim_direction(-direction, facing < 0.0)
			assert(visual.frame == aim_frame + 1 and visual.flip_h == (facing < 0.0))
			visual.tick(0.03, &"attack", facing < 0.0)
			assert(visual.frame == aim_frame + 1)
			visual.tick(0.05, &"attack", facing < 0.0)
			assert(markers[0] == before + 1 and visual.frame == aim_frame + 2)
			assert(visual.flip_h == (facing < 0.0), "A shot also retains its facing through recoil.")
			visual.tick(0.09, &"attack", facing > 0.0)
			assert(visual.is_shot_playing() and visual.frame == aim_frame, "Recoil settles back into aim before the next beat.")
			visual.tick(0.02, &"attack", facing > 0.0)
			assert(not visual.is_shot_playing(), "Every direction retains the 0.18s shot beat.")
			assert(visual.current_state() == &"telegraph" and visual.frame == aim_frame)
			visual.begin_shot(direction, facing > 0.0)
			visual.tick(0.5, &"attack", facing > 0.0)
			assert(markers[0] == before + 2, "A long update must not duplicate the firing marker.")
			assert(not visual.is_shot_playing())
		# Directly vertical targets retain the selected horizontal facing.
		for vertical in [-1.0, 1.0]:
			visual.set_state(&"telegraph", true)
			visual.set_aim_direction(Vector3(0.0, vertical, 0.0), facing > 0.0)
			assert(visual.frame == (3 if vertical < 0.0 else 6))
			assert(visual.flip_h == (facing < 0.0))
	assert(shooter.shots_fired_total() == 0, "Previewing a pose outside combat must not fire.")
	visual.shot_frame_reached.disconnect(record_marker)
	visual.set_state(&"idle", true)
	visual.set_state(&"telegraph", true)
	assert(visual.frame == 0, "Resetting the visual must clear its previous directional pose.")


func _validate_directional_aim(shooter: HandgunEnemy3D, player: PlayerCharacter) -> void:
	var player_transform := player.global_transform
	var shooter_transform := shooter.global_transform
	# Exercise actual telegraph -> fire transitions with targets on both sides
	# and at shallow/diagonal/steep heights, without advancing the player.
	for facing in [-1.0, 1.0]:
		for degrees in [-70.0, -35.0, -10.0, 0.0, 10.0, 35.0, 70.0]:
			shooter.reset_combat_cycle(true)
			shooter.global_position = shooter_transform.origin + Vector3.UP * 4.0
			shooter.velocity = Vector3.ZERO
			var angle := deg_to_rad(degrees)
			var direction := Vector3(cos(angle) * facing, sin(angle), 0.0)
			player.global_position = shooter.global_position + direction * 2.0
			shooter._physics_process(0.0)
			assert(shooter.pixel_visual.current_state() == &"telegraph")
			assert(shooter.pixel_visual.frame == (3 if degrees < -22.5 else (6 if degrees > 22.5 else 0)))
			assert(shooter.pixel_visual.flip_h == (facing < 0.0))
			shooter._phase_remaining = 0.0
			shooter._physics_process(0.0)
			assert(shooter.shots_fired_total() == 2)
			for projectile in shooter._active_projectiles:
				assert(projectile.travel_direction().is_equal_approx(direction), "Sprite selection must not snap the projectile angle.")
			# Next beat can track a moving player without changing this beat's recoil.
			player.global_position = shooter.global_position + Vector3(facing, -direction.y, 0.0)
			shooter._tick_shot_visual(0.08)
			assert(shooter.pixel_visual.frame == (5 if degrees < -22.5 else (8 if degrees > 22.5 else 2)))
			shooter._fire_next_dual_shot()
			assert(shooter.shots_fired_total() == 4)
	shooter.reset_combat_cycle(true)
	shooter.global_transform = shooter_transform
	shooter.velocity = Vector3.ZERO
	player.global_transform = player_transform


func _validate_volley_pose_hold(shooter: HandgunEnemy3D) -> void:
	shooter.set_fire_pattern(HandgunEnemy3D.FirePattern.TWIN)
	shooter._begin_volley()
	shooter._tick_shot_visual(0.2)
	shooter._tick_dual_shot_sequence(0.2)
	assert(shooter.shots_fired_total() == 2)
	assert(not shooter.pixel_visual.is_shot_playing())
	assert(shooter.pixel_visual.current_state() == &"telegraph", "Guns stay raised between the slower twin beats.")
	shooter._tick_shot_visual(0.2)
	shooter._tick_dual_shot_sequence(0.2)
	assert(shooter.shots_fired_total() == 2 and shooter.pixel_visual.current_state() == &"telegraph")
	shooter._tick_dual_shot_sequence(0.16)
	assert(shooter.shots_fired_total() == 4)
	shooter._tick_shot_visual(0.19)
	shooter._tick_dual_shot_sequence(0.19)
	assert(shooter.completed_volleys_total() == 1)
	assert(shooter.pixel_visual.current_state() == &"telegraph", "The final shot settles before the enemy relaxes.")
	shooter.set_fire_pattern(HandgunEnemy3D.FirePattern.TRIPLE)


func _toggle_gameplay_tools(game_root: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F1
	game_root._unhandled_input(event)


func _wait_for_first_volley(shooter: HandgunEnemy3D) -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while shooter.completed_volleys_total() < 1 and Time.get_ticks_msec() < deadline:
		await physics_frame
	assert(shooter.completed_volleys_total() >= 1, "Shooter did not complete a volley in time.")


func _wait_for_damage(damage_events: Array[Vector3]) -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while damage_events.is_empty() and Time.get_ticks_msec() < deadline:
		await physics_frame


func _assert_cover_impact_normals(impact_normals: Array[Vector3]) -> void:
	assert(not impact_normals.is_empty())
	for surface_normal in impact_normals:
		assert(surface_normal.is_normalized())
		assert(
			surface_normal.x > 0.5,
			"Left-moving cover hits must report the rock's right-facing surface."
		)


func _on_watchdog_timeout() -> void:
	if _finished:
		return
	push_error("Firearm Review Lab validator timed out after an earlier failure.")
	quit(9)
