extends SceneTree
## Level 6 capstone structure, full-kit entry policy, encounter safety, vertical
## finale geometry, and deterministic death/manual-restart behavior.

const AUTHORED_DASH_GAP := 14.08
const GEOMETRY_TOLERANCE := 0.01
const PLAYER_HALF_WIDTH := 0.36


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"green_zone_finale")
	await process_frame

	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 8:
		await physics_frame

	_validate_identity_and_entry_policy(game_root, level, player)
	_validate_route(level, player)
	_validate_camera(level, player)
	_validate_checkpoints(level)
	_validate_spikes(level)
	_validate_enemies(level)
	await _validate_review_patrol_seam(level, player)
	_validate_props_and_finish(level)
	await _validate_reset_contract(
		level,
		player,
		completion_label
	)
	# Let reset-cancelled enemy defeat timers release their signal callbacks
	# before freeing the test scene.
	for frame in 40:
		await physics_frame

	root.remove_child(game_root)
	game_root.free()
	await process_frame
	print(
		(
			"Level 6 full-kit route, safe encounters, vertical finale, "
			+ "presentation, and reset validation passed."
		)
	)
	quit(0)


func _validate_identity_and_entry_policy(
	game_root: Node,
	level: LevelSession3D,
	player: PlayerCharacter
) -> void:
	assert(game_root.current_world_definition.world_id == &"green_zone_regression")
	assert(game_root.current_level_definition.level_id == &"green_zone_finale")
	assert(game_root.current_level_definition.display_number == 6)
	assert(level.name == "World01Level06")
	_assert_complete_kit(level, player, "Level 6 entry")
	assert(
		not (game_root.get_node("Interface/AbilityTutorial") as Control).visible,
		"Assumed entry abilities must not display a new-ability tutorial."
	)

	var pickup_count := 0
	for node in get_nodes_in_group("ability_pickup"):
		if level.is_ancestor_of(node):
			pickup_count += 1
	assert(
		pickup_count == 0,
		"The no-new-ability World 1 finale must not contain an ability pickup."
	)


func _validate_route(level: LevelSession3D, player: PlayerCharacter) -> void:
	var expected_platforms := [
		"OpeningGround",
		"FamiliarStep",
		"OpeningRun",
		"DoubleJumpRise",
		"DoubleJumpCatch",
		"HazardAndShaftFloor",
		"ReviewLeftWall",
		"ReviewRightWall",
		"ReviewExit",
		"DashLanding",
		"DescentStep",
		"FinaleFloor",
		"FinaleLeftWall",
		"FinaleRightWall",
		"FinaleLanding",
		"FinishGround",
		"ChestPlinth",
	]
	assert(level.get_node("Platforms").get_child_count() == expected_platforms.size())
	for platform_name in expected_platforms:
		assert(
			_platform(level, platform_name) != null,
			"Level 6 is missing platform %s." % platform_name
		)

	assert(
		absf(level.route_extent.length() - 208.64) <= GEOMETRY_TOLERANCE
	)
	assert(is_equal_approx(_top_edge(_platform(level, "OpeningGround")), 0.0))
	assert(is_equal_approx(_gap(
		_platform(level, "OpeningGround"),
		_platform(level, "FamiliarStep")
	), 2.56))
	assert(is_equal_approx(
		_top_edge(_platform(level, "FamiliarStep")),
		0.0
	))
	assert(is_equal_approx(_gap(
		_platform(level, "FamiliarStep"),
		_platform(level, "OpeningRun")
	), 2.56))

	var opening_run := _platform(level, "OpeningRun")
	var double_jump_rise := _platform(level, "DoubleJumpRise")
	var double_jump_catch := _platform(level, "DoubleJumpCatch")
	assert(is_equal_approx(_gap(opening_run, double_jump_rise), 3.84))
	assert(is_equal_approx(
		_top_edge(double_jump_rise) - _top_edge(opening_run),
		3.84
	))
	assert(
		_top_edge(double_jump_rise) - _top_edge(opening_run)
			> player.movement.ideal_jump_height(),
		"The review rise must still require Double Jump height."
	)
	assert(is_equal_approx(
		_gap(double_jump_rise, double_jump_catch),
		3.84
	))
	assert(is_equal_approx(_top_edge(double_jump_catch), 1.28))
	assert(is_equal_approx(_gap(
		double_jump_catch,
		_platform(level, "HazardAndShaftFloor")
	), 2.56))
	assert(is_equal_approx(
		_platform(level, "HazardAndShaftFloor").size.x,
		23.04
	))

	var review_left := _platform(level, "ReviewLeftWall")
	var review_right := _platform(level, "ReviewRightWall")
	var review_exit := _platform(level, "ReviewExit")
	assert(is_equal_approx(_left_edge(review_right) - _right_edge(review_left), 5.12))
	assert(is_equal_approx(_bottom_edge(review_left), 2.56))
	assert(is_equal_approx(_bottom_edge(review_right), 0.0))
	assert(is_equal_approx(_top_edge(review_left), 15.36))
	assert(is_equal_approx(_top_edge(review_right), 11.52))
	assert(is_equal_approx(_top_edge(review_exit), 11.52))
	assert(is_equal_approx(_left_edge(review_exit), _right_edge(review_right)))

	var dash_landing := _platform(level, "DashLanding")
	assert(is_equal_approx(_gap(review_exit, dash_landing), AUTHORED_DASH_GAP))
	assert(is_equal_approx(_top_edge(review_exit), _top_edge(dash_landing)))
	assert(is_equal_approx(dash_landing.size.x, AUTHORED_DASH_GAP))
	_assert_open_void(level, _right_edge(review_exit), _left_edge(dash_landing))

	var descent := _platform(level, "DescentStep")
	var finale_floor := _platform(level, "FinaleFloor")
	assert(is_equal_approx(_gap(dash_landing, descent), 2.56))
	assert(is_equal_approx(
		_top_edge(dash_landing) - _top_edge(descent),
		5.12
	))
	assert(is_equal_approx(_gap(descent, finale_floor), 2.56))
	assert(is_equal_approx(_top_edge(finale_floor), 0.0))

	var finale_left := _platform(level, "FinaleLeftWall")
	var finale_right := _platform(level, "FinaleRightWall")
	var finale_landing := _platform(level, "FinaleLanding")
	assert(is_equal_approx(_left_edge(finale_right) - _right_edge(finale_left), 5.12))
	assert(is_equal_approx(_bottom_edge(finale_left), 2.56))
	assert(is_equal_approx(_bottom_edge(finale_right), 0.0))
	assert(is_equal_approx(_top_edge(finale_left), 14.08))
	assert(is_equal_approx(_top_edge(finale_right), 12.8))
	assert(is_equal_approx(
		_right_edge(finale_right),
		_right_edge(finale_floor)
	), "The final wall-jump shaft must not leave a standable pocket on its right.")
	assert(is_equal_approx(_top_edge(finale_landing), 14.08))
	assert(is_equal_approx(
		_left_edge(finale_landing) - _right_edge(finale_right),
		9.6
	))
	assert(
		finale_landing.size.x >= 11.52,
		"The final combined-ability landing must remain broad."
	)

	var finish_ground := _platform(level, "FinishGround")
	assert(is_equal_approx(
		_gap(finale_landing, finish_ground),
		5.12
	))
	assert(is_equal_approx(
		_top_edge(finale_landing) - _top_edge(finish_ground),
		14.08
	))
	assert(
		absf(finish_ground.size.x - 28.16) <= GEOMETRY_TOLERANCE,
		"The finale needs its authored 28.16 m calm finish lawn."
	)

	var kill_plane := level.get_node("KillPlane") as Area3D
	var kill_shape := kill_plane.get_node("Collision") as CollisionShape3D
	var kill_box := kill_shape.shape as BoxShape3D
	assert(absf(kill_box.size.x - 220.16) <= GEOMETRY_TOLERANCE)
	assert(is_equal_approx(kill_plane.global_position.x, 104.32))
	assert(
		kill_plane.global_position.x + kill_box.size.x * 0.5
			> level.route_extent.length(),
		"The kill plane must cover the complete authored route."
	)


func _validate_camera(level: LevelSession3D, player: PlayerCharacter) -> void:
	assert(level.camera is PixelSideCamera3D)
	assert(level.camera.target == player)
	assert(level.camera.vertical_follow_enabled)
	assert(is_equal_approx(level.camera.look_ahead, 8.0))
	assert(is_equal_approx(level.camera.maximum_vertical_offset, 16.5))
	assert(
		absf(level.camera.maximum_center_x - 202.17) <= GEOMETRY_TOLERANCE,
		"Level 6 camera end clamp changed to %.3f."
		% level.camera.maximum_center_x
	)
	assert(
		level.camera.maximum_vertical_offset
			>= _top_edge(_platform(level, "FinaleLanding")),
		"The camera must retain enough vertical travel for the final climb."
	)


func _validate_checkpoints(level: LevelSession3D) -> void:
	var contracts := [
		{
			"checkpoint": "CheckpointDoubleJump",
			"support": "DoubleJumpCatch",
			"route_index": 1,
		},
		{
			"checkpoint": "CheckpointWallExit",
			"support": "ReviewExit",
			"route_index": 2,
		},
		{
			"checkpoint": "CheckpointDashLanding",
			"support": "DashLanding",
			"route_index": 3,
		},
		{
			"checkpoint": "CheckpointFinaleFloor",
			"support": "FinaleFloor",
			"route_index": 4,
		},
		{
			"checkpoint": "CheckpointFinaleLanding",
			"support": "FinaleLanding",
			"route_index": 5,
		},
	]
	assert(level.get_node("Checkpoints").get_child_count() == contracts.size())
	for contract: Dictionary in contracts:
		var checkpoint := level.get_node(
			"Checkpoints/%s" % contract.checkpoint
		) as LevelCheckpoint3D
		var support := _platform(level, contract.support)
		assert(checkpoint.route_index == contract.route_index)
		assert(is_equal_approx(checkpoint.global_position.y, _top_edge(support)))
		assert(
			checkpoint.global_position.x - _left_edge(support) >= 2.4,
			"%s is too close to the support's entry edge." % checkpoint.name
		)
		assert(
			_right_edge(support) - checkpoint.global_position.x >= 2.4,
			"%s is too close to the support's exit edge." % checkpoint.name
		)
		var respawn := checkpoint.respawn_transform().origin
		assert(is_equal_approx(respawn.x, checkpoint.global_position.x))
		assert(is_equal_approx(respawn.y, _top_edge(support) + 0.7))


func _validate_spikes(level: LevelSession3D) -> void:
	assert(level.get_node("Hazards").get_child_count() == 3)
	var support := _platform(level, "HazardAndShaftFloor")
	var first := level.get_node("Hazards/SpikeReviewA") as PixelSpikeRow3D
	var second := level.get_node("Hazards/SpikeReviewB") as PixelSpikeRow3D
	var opening := level.get_node(
		"Hazards/OpeningSpikePair"
	) as PixelSpikeRow3D
	var left_wall := _platform(level, "ReviewLeftWall")
	for spike in [first, second, opening]:
		assert(spike != null)
		var collision := spike.get_node("DamageCollision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D
		assert(is_equal_approx(
			shape.size.x,
			spike.row_width * spike.collision_width_ratio
		))
		assert(shape.size.y <= spike.spike_height * 0.5)

	for spike in [first, second]:
		assert(is_equal_approx(spike.row_width, 2.0))
		assert(is_equal_approx(spike.global_position.y, _top_edge(support)))

	assert(
		_visible_left(first) - _left_edge(support) >= 6.0,
		"The spike review needs a full-speed safe entry lane."
	)
	assert(
		_visible_left(second) - _visible_right(first) >= 0.5,
		"The two spike rows need a readable recovery beat."
	)
	assert(
		_left_edge(left_wall) - _visible_right(second) >= 4.0,
		"The final spike row must leave a clean wall-shaft entry."
	)

	var opening_ground := _platform(level, "OpeningGround")
	assert(is_equal_approx(opening.row_width, 1.52))
	assert(is_equal_approx(opening.global_position.y, _top_edge(opening_ground)))
	assert(
		_visible_left(opening) - level.spawn_point.global_position.x >= 5.5,
		"The opening spike pair needs a readable lane from spawn."
	)
	assert(
		_right_edge(opening_ground) - _visible_right(opening) >= 3.5,
		"The opening spike pair must leave room for a separate gap jump."
	)


func _validate_enemies(level: LevelSession3D) -> void:
	var level_enemies: Array[StompableEnemy3D] = []
	for node in get_nodes_in_group("melee_target"):
		if level.is_ancestor_of(node):
			level_enemies.append(node as StompableEnemy3D)
	assert(level_enemies.size() == 3, "Level 6 needs exactly three flow patrols.")

	var opening := level.get_node("OpeningPatrol") as StompableEnemy3D
	var review := level.get_node("ReviewExitPatrol") as StompableEnemy3D
	var dash := level.get_node("DashLandingPatrol") as StompableEnemy3D
	_assert_flow_enemy(
		opening,
		_platform(level, "OpeningRun"),
		_left_edge(_platform(level, "OpeningRun")),
		"the opening platform entry"
	)
	var review_checkpoint := level.get_node(
		"Checkpoints/CheckpointWallExit"
	) as LevelCheckpoint3D
	_assert_flow_enemy(
		review,
		_platform(level, "ReviewExit"),
		review_checkpoint.global_position.x,
		"the wall-exit checkpoint"
	)
	var dash_checkpoint := level.get_node(
		"Checkpoints/CheckpointDashLanding"
	) as LevelCheckpoint3D
	_assert_flow_enemy(
		dash,
		_platform(level, "DashLanding"),
		dash_checkpoint.global_position.x,
		"the Dash-landing checkpoint"
	)

	var finish_left := _left_edge(_platform(level, "FinishGround"))
	for enemy in level_enemies:
		assert(
			enemy._initial_transform.origin.x < finish_left,
			"The calm finish lawn must not contain an enemy."
		)
	assert(
		level.get_node_or_null("FinishPatrol") == null,
		"The World 1 completion lawn must stay enemy-free."
	)


func _assert_flow_enemy(
	enemy: StompableEnemy3D,
	support: PixelPlatform3D,
	safe_entry_x: float,
	entry_description: String
) -> void:
	var authored_position := enemy._initial_transform.origin
	assert(is_equal_approx(enemy.patrol_speed, 1.2))
	assert(enemy.starts_moving_right)
	assert(enemy.facing_sign() > 0.0)
	assert(absf(authored_position.y - (_top_edge(support) + 0.42)) <= 0.01)
	assert(
		authored_position.x - safe_entry_x >= 6.0,
		"%s must begin clear of %s." % [enemy.name, entry_description]
	)
	assert(authored_position.x >= _left_edge(support) + 6.0)
	assert(authored_position.x <= _right_edge(support) - 3.0)


func _validate_review_patrol_seam(
	level: LevelSession3D,
	player: PlayerCharacter
) -> void:
	var review := level.get_node("ReviewExitPatrol") as StompableEnemy3D
	var player_transform := player.global_transform
	player.set_physics_process(false)
	player.global_position = Vector3(-100.0, 100.0, 0.0)

	review.starts_moving_right = false
	review.reset_run()
	review.global_position = Vector3(
		81.9,
		review._initial_transform.origin.y,
		review._initial_transform.origin.z
	)
	var reached_seam := false
	var reversed_from_seam := false
	var resumed_patrol := false
	for frame in 90:
		await physics_frame
		reached_seam = reached_seam or review.global_position.x <= 81.7
		reversed_from_seam = (
			reversed_from_seam
			or (reached_seam and review.facing_sign() > 0.0)
		)
		if reversed_from_seam and review.global_position.x >= 82.2:
			resumed_patrol = true
			break

	assert(reached_seam, "The wall-exit patrol regression must reach the left seam.")
	assert(
		reversed_from_seam,
		"The wall-exit patrol must reverse instead of stalling at the wall seam."
	)
	assert(
		resumed_patrol,
		"The wall-exit patrol must move away after its seam reversal."
	)

	review.starts_moving_right = true
	review.reset_run()
	player.global_transform = player_transform
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await physics_frame


func _validate_props_and_finish(level: LevelSession3D) -> void:
	assert(level.get_node("Props").get_child_count() == 4)
	var opening_tree := level.get_node("Props/OpeningTree") as Sprite3D
	var left_tree := level.get_node("Props/FinishTreeLeft") as Sprite3D
	var bench := level.get_node("Props/FinishBench") as Sprite3D
	var right_tree := level.get_node("Props/FinishTreeRight") as Sprite3D
	_assert_tree(opening_tree, 0.04, 0.0)
	_assert_tree(left_tree, 0.035, 0.0)
	_assert_tree(right_tree, 0.035, 0.0)
	assert(is_equal_approx(bench.pixel_size, 0.04))
	assert(is_equal_approx(bench.global_position.z, 1.36))
	assert(bench.render_priority == 20)
	assert(absf(_sprite_bottom(bench) - 0.03) <= 0.01)

	var finish := _platform(level, "FinishGround")
	var plinth := _platform(level, "ChestPlinth")
	var goal := level.get_node("Goal") as PixelGoal3D
	assert(is_equal_approx(_bottom_edge(plinth), _top_edge(finish)))
	assert(is_equal_approx(goal.global_position.x, plinth.global_position.x))
	assert(is_equal_approx(goal.global_position.y, _top_edge(plinth)))
	assert(_left_edge(plinth) >= _left_edge(finish))
	assert(_right_edge(plinth) <= _right_edge(finish))
	assert(absf(goal.global_position.x - bench.global_position.x) >= 9.5)
	assert(
		right_tree.global_position.x - goal.global_position.x >= 5.4,
		"The right finish tree must frame rather than obscure the chest."
	)


func _assert_tree(tree: Sprite3D, pixel_size: float, support_y: float) -> void:
	assert(
		tree.texture.resource_path
			== "res://assets/art/green_zone/props/tree_grounded.png"
	)
	assert(is_equal_approx(tree.pixel_size, pixel_size))
	assert(is_equal_approx(tree.global_position.z, 1.0))
	assert(tree.render_priority == 0)
	assert(absf(_sprite_bottom(tree) - support_y) <= GEOMETRY_TOLERANCE)


func _validate_reset_contract(
	level: LevelSession3D,
	player: PlayerCharacter,
	completion_label: Label
) -> void:
	var opening := level.get_node("OpeningPatrol") as StompableEnemy3D
	var review := level.get_node("ReviewExitPatrol") as StompableEnemy3D
	var dash := level.get_node("DashLandingPatrol") as StompableEnemy3D
	var goal := level.get_node("Goal") as PixelGoal3D
	var checkpoint := level.get_node(
		"Checkpoints/CheckpointFinaleFloor"
	) as LevelCheckpoint3D
	var opening_transform := opening._initial_transform
	var review_transform := review._initial_transform
	var dash_transform := dash._initial_transform

	player.reset_at(checkpoint.respawn_transform())
	for frame in 14:
		await physics_frame
	assert(checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 4)

	opening.receive_melee_hit(player.global_position)
	review.receive_melee_hit(player.global_position)
	dash.receive_melee_hit(player.global_position)
	await process_frame
	assert(opening.is_defeated() and review.is_defeated() and dash.is_defeated())

	var death_reset_count := [0]
	level.run_reset.connect(func() -> void: death_reset_count[0] += 1)
	player.kill()
	for frame in 80:
		await physics_frame
		if death_reset_count[0] > 0:
			break
	assert(death_reset_count[0] == 1, "Death must complete one fast run reset.")
	assert(not player.is_dead())
	assert(level.active_checkpoint_index() == 4)
	assert(checkpoint.is_activated())
	assert(
		player.global_position.distance_to(checkpoint.respawn_transform().origin) < 0.2
	)
	_assert_complete_kit(level, player, "Level 6 checkpoint death")
	_assert_enemy_reset(opening, opening_transform)
	_assert_enemy_reset(review, review_transform)
	_assert_enemy_reset(dash, dash_transform)

	opening.receive_melee_hit(player.global_position)
	review.receive_melee_hit(player.global_position)
	dash.receive_melee_hit(player.global_position)
	goal._on_body_entered(player)
	await process_frame
	assert(opening.is_defeated() and review.is_defeated() and dash.is_defeated())
	assert(goal._opening)
	assert(completion_label.visible)

	level._reset_run()
	await physics_frame
	assert(level.active_checkpoint_index() == -1)
	for node in level.get_node("Checkpoints").get_children():
		assert(not (node as LevelCheckpoint3D).is_activated())
	assert(
		player.global_position.distance_to(level.spawn_point.global_position) < 0.2
	)
	_assert_complete_kit(level, player, "Level 6 manual restart")
	_assert_enemy_reset(opening, opening_transform)
	_assert_enemy_reset(review, review_transform)
	_assert_enemy_reset(dash, dash_transform)
	assert(not goal._opening, "Manual restart must close and reset the chest.")
	assert(not completion_label.visible)


func _assert_complete_kit(
	level: LevelSession3D,
	player: PlayerCharacter,
	context: String
) -> void:
	for ability_id in PlayerAbility.IMPLEMENTED:
		assert(
			player.has_ability(ability_id),
			"%s must provide %s." % [context, PlayerAbility.display_name(ability_id)]
		)
		assert(
			level.is_session_ability_enabled(ability_id),
			"%s must retain %s as a session ability."
			% [context, PlayerAbility.display_name(ability_id)]
		)
	assert(player.aerial_jumps_remaining() == 1)
	assert(player.dash_available())


func _assert_enemy_reset(
	enemy: StompableEnemy3D,
	initial_transform: Transform3D
) -> void:
	assert(not enemy.is_defeated())
	assert(enemy.visible)
	assert(enemy.global_position.distance_to(initial_transform.origin) <= 0.1)
	assert(enemy.facing_sign() > 0.0)


func _assert_open_void(
	level: LevelSession3D,
	left_x: float,
	right_x: float
) -> void:
	for node in level.get_node("Platforms").get_children():
		var platform := node as PixelPlatform3D
		var overlap := minf(_right_edge(platform), right_x) - maxf(
			_left_edge(platform),
			left_x
		)
		assert(
			overlap <= GEOMETRY_TOLERANCE,
			"%s places playable support beneath the strict Dash gap." % platform.name
		)


func _platform(level: LevelSession3D, node_name: String) -> PixelPlatform3D:
	return level.get_node("Platforms/%s" % node_name) as PixelPlatform3D


func _left_edge(platform: PixelPlatform3D) -> float:
	return platform.global_position.x - platform.size.x * 0.5


func _right_edge(platform: PixelPlatform3D) -> float:
	return platform.global_position.x + platform.size.x * 0.5


func _top_edge(platform: PixelPlatform3D) -> float:
	return platform.global_position.y + platform.size.y * 0.5


func _bottom_edge(platform: PixelPlatform3D) -> float:
	return platform.global_position.y - platform.size.y * 0.5


func _gap(left: PixelPlatform3D, right: PixelPlatform3D) -> float:
	return _left_edge(right) - _right_edge(left)


func _visible_left(spike: PixelSpikeRow3D) -> float:
	return spike.global_position.x - spike.row_width * 0.5


func _visible_right(spike: PixelSpikeRow3D) -> float:
	return spike.global_position.x + spike.row_width * 0.5


func _sprite_bottom(sprite: Sprite3D) -> float:
	return (
		sprite.global_position.y
		- sprite.texture.get_height() * sprite.pixel_size * absf(sprite.scale.y) * 0.5
	)
