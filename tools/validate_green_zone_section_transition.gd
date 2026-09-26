extends SceneTree
## Proves that Level 3 remains one level while its traversal and shooter
## encounter are two one-way authored sections joined behind a black fade.

const SHOOTER_SCENE_PATH := (
	"res://scenes/dev/green_zone_finale_shooter_area_wip.tscn"
)
const EXPECTED_DIRECTION := 1.0
const EXPECTED_SPEED := 8.0
const EXPECTED_DURATION := 0.9

var _completed := false


func _init() -> void:
	create_timer(20.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Green Zone section-transition validation aborted before completing.")
	quit(1)


func _run() -> void:
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	var definition := load(
		"res://resources/dev/green_zone_finale_wip.tres"
	) as LevelDefinition
	assert(packed_root != null and definition != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	game_root.load_developer_level(definition)
	for frame in 8:
		await physics_frame

	var traversal := game_root.current_level as LevelSession3D
	assert(traversal != null)
	var traversal_player := traversal.player
	var transition := traversal.get_node(
		"ShooterAreaTransition"
	) as LevelTransition3D
	assert(transition != null)
	assert(transition.validation_errors().is_empty())
	assert(transition.target_level == null)
	assert(transition.target_scene != null)
	assert(transition.target_scene.resource_path == SHOOTER_SCENE_PATH)
	assert(not transition.completes_source_level)
	assert(transition.interstitial_scene == null)
	assert(transition.source_exit_mode == LevelTransition3D.SourceExitMode.STOP)
	assert(transition.run_destination_during_fade_in)
	assert(is_equal_approx(transition.run_direction, EXPECTED_DIRECTION))
	assert(is_equal_approx(transition.run_speed, EXPECTED_SPEED))
	assert(is_equal_approx(transition.run_duration, EXPECTED_DURATION))
	for ability_id in PlayerAbility.IMPLEMENTED:
		assert(traversal_player.has_ability(ability_id))

	transition._on_body_entered(traversal_player)
	await physics_frame
	assert(not traversal_player.is_transition_running())
	assert(not traversal_player.is_physics_processing())
	assert(not game_root.completion_label.visible)

	# The source must be fully gone before Area 2 appears. The approach may begin
	# under the last trace of black, but no recognition beat is spent there.
	for frame in 90:
		await process_frame
		if game_root.current_level != traversal:
			break
	var shooter_area := game_root.current_level as LevelSession3D
	assert(shooter_area != null and shooter_area != traversal)
	assert(not is_instance_valid(traversal))
	assert(game_root.current_level_definition == definition)
	assert(game_root.current_world_definition == null)
	assert(shooter_area.route_extent.route_start_x == 0.0)
	assert(shooter_area.route_extent.route_end_x == 84.48)
	for ability_id in PlayerAbility.IMPLEMENTED:
		assert(shooter_area.player.has_ability(ability_id))
	assert(shooter_area.player.is_transition_running())
	# A scene swap completes during idle processing. Allow a full physics tick
	# before requiring displacement; an idle frame need not contain one.
	await physics_frame
	await physics_frame
	assert(
		shooter_area.player.global_position.x
		> shooter_area.spawn_point.global_position.x
	)
	var intro := shooter_area.get_node(
		"ShooterEncounterStaging/ShooterIntro"
	) as GreenZoneShooterIntro3D
	assert(intro != null)
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.ARMED)
	assert(intro.trigger_is_armed())

	for frame in 90:
		await process_frame
		if not game_root.completion_fade.visible:
			break
	assert(not game_root.completion_fade.visible)
	assert(intro.current_phase() in [
		GreenZoneShooterIntro3D.Phase.ARMED,
		GreenZoneShooterIntro3D.Phase.APPROACH,
	])
	assert(intro.current_phase() < GreenZoneShooterIntro3D.Phase.ENEMY_NOTICE)
	assert(shooter_area.player.global_position.x < 6.4)
	assert(not game_root.completion_label.visible)

	for frame in 90:
		await physics_frame
		if intro.current_phase() != GreenZoneShooterIntro3D.Phase.ARMED:
			break
	assert(intro.current_phase() == GreenZoneShooterIntro3D.Phase.APPROACH)
	assert(shooter_area.player.is_transition_running())
	assert(not game_root.completion_label.visible)

	# The new scene has a physical sealed edge and no return transition.
	var left_boundary := shooter_area.get_node(
		"Platforms/LeftBoundary"
	) as StaticBody3D
	assert(left_boundary != null)
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(0.64, 1.0, 0),
		Vector3(-0.64, 1.0, 0),
		1
	)
	var hit := shooter_area.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	assert(hit.get("collider") == left_boundary)
	assert(_owned_group_nodes(shooter_area, &"level_transition").is_empty())

	# Death resets inside Area 2 rather than reconstructing the traversal.
	shooter_area.player.finish_transition_run()
	shooter_area.player.kill()
	assert(shooter_area.player.is_dead())
	for frame in 90:
		await physics_frame
		if not shooter_area.player.is_dead():
			break
	assert(game_root.current_level == shooter_area)
	assert(not shooter_area.player.is_dead())
	assert(shooter_area.active_checkpoint_index() == -1)
	assert(absf(
		shooter_area.player.global_position.x
		- shooter_area.spawn_point.global_position.x
	) < 0.05)

	print(
		"Green Zone section transition passed: opaque one-level scene swap, "
		+ "visible run-in, sealed return edge, carried kit, and local reset."
	)
	_completed = true
	quit(0)


func _owned_group_nodes(level: LevelSession3D, group: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in get_nodes_in_group(group):
		if level.is_ancestor_of(node):
			found.append(node)
	return found
