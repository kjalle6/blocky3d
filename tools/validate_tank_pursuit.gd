extends SceneTree
## Focused pursuit states; no scripted route or pit crossing.
const FIXTURE := preload("res://tools/level_3_shooter_area_fixture.gd")
var level: LevelSession3D
var player: PlayerCharacter
var tank: TankEnemy3D

func _init() -> void:
	call_deferred("_run")
	create_timer(20.0).timeout.connect(func(): quit(1))

func _frames(count: int) -> void:
	for frame in count: await physics_frame

func _place_player(point: Vector3) -> void:
	player.reset_at(Transform3D(Basis.IDENTITY, point))
	level.camera.snap_to_target()

func _run() -> void:
	level = FIXTURE.instantiate_session()
	root.add_child(level)
	await _frames(5)
	player = level.player
	player.died.disconnect(level._on_player_died)
	level.get_node("ShooterEncounterStaging/ShooterIntro").process_mode = Node.PROCESS_MODE_DISABLED
	tank = level.get_node("TankEncounter/Tank")
	_place_player(Vector3(46.5, 0.7, 0))
	await _frames(6)
	tank.reset_run()
	await _frames(10)
	assert(not tank.is_pursuing() and tank.shots_fired_total() == 0, "Keep the initial safe landing and approach reveal.")
	_place_player(Vector3(50, 0.7, 0))
	await _frames(10)
	assert(tank.is_pursuing() and tank.velocity.x < 0.0, "Tank must notice and advance through the breakable-cover route.")
	assert(not tank._teammate_blocks_shot(Vector3.LEFT), "Crates must not suppress fire as teammates.")
	# Turning around to pursue is independent of the current firing timer.
	tank._state = HandgunEnemy3D.CombatState.RECOVERY
	tank._phase_remaining = 0.8
	_place_player(Vector3(68, 0.7, 0))
	await _frames(6)
	assert(tank.is_pursuing() and tank.velocity.x > 0.0 and tank._facing_sign > 0.0, "Crossing to the far side must turn pursuit and facing toward the player, including during recovery.")
	assert(tank._state == HandgunEnemy3D.CombatState.RECOVERY and tank._phase_remaining < 0.8 and tank._phase_remaining > 0.5)
	# Idle patrol endpoints do not stop an already engaged tank from following.
	tank.global_position.x = tank._initial_transform.origin.x + tank.patrol_right_distance - 0.05
	_place_player(Vector3(71, 0.7, 0))
	await _frames(10)
	assert(tank.is_pursuing() and tank.global_position.x > tank._initial_transform.origin.x + tank.patrol_right_distance)
	# Once engaged, stepping back across the arrival marker does not remove aggro.
	tank.global_position.x = 54.0
	_place_player(Vector3(47.5, 0.7, 0))
	await _frames(6)
	assert(tank.is_pursuing() and tank._can_engage(player))
	# A real pit edge ends pursuit before the body walks into it.
	tank.global_position = Vector3(45.4, 0.45, 0)
	_place_player(Vector3(40, 0.7, 0))
	player.set_physics_process(false)
	await _frames(6)
	assert(not tank.is_pursuing() and tank.global_position.x >= 45.4)
	# Hazard-aware navigation also resets pursuit on continuous ground.
	var hazard := Area3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.2, 1)
	collision.shape = box
	hazard.add_child(collision)
	level.add_child(hazard)
	hazard.global_position = Vector3(63, 0.5, 0)
	hazard.add_to_group("ground_enemy_hazard")
	tank.global_position = Vector3(62, 0.45, 0)
	_place_player(Vector3(68, 0.7, 0))
	tank._pursuing = true
	await _frames(6)
	assert(not tank.is_pursuing() and tank.global_position.x <= 62.01)
	hazard.queue_free()
	await _frames(2)
	# Tanks without an authored climb retain the normal off-camera reset.
	tank.climb_encounter_path = NodePath()
	tank._pursuing = true
	level.camera.set_process(false)
	level.camera.global_position.x = 150
	await _frames(2)
	assert(not tank.is_pursuing())
	tank.reset_run()
	assert(not tank.is_pursuing() and not tank._landed_in_arena)
	level.queue_free()
	await process_frame
	print("Tank pursuit passed: initial reveal, cover engagement, turning, patrol escape, retained aggro, ledge/hazard safety and camera reset.")
	quit()
