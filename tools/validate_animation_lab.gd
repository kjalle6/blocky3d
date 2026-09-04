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
	assert(shooter.forward_fire_frames == PackedInt32Array([1, 7]))
	assert(is_equal_approx(shooter.active_shot_interval(), 0.18))
	assert(is_equal_approx(shooter.triple_shot_interval, 0.18))
	assert(is_equal_approx(shooter.forward_visual_duration, 0.18))
	assert(shooter.projectiles_per_fire_beat() == 2)
	assert(shooter.fire_beat_count() == 3)
	assert(shooter.expected_projectiles_per_attack() == 6)
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
