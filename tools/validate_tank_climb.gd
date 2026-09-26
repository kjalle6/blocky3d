extends SceneTree
## Focused combat, geometry and snapshot checks; no traversal input runner.
const FIXTURE := preload("res://tools/level_3_shooter_area_fixture.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
var level: LevelSession3D
var player: PlayerCharacter
var tank: TankEnemy3D

func _init() -> void:
	call_deferred("_run")
	create_timer(25.0).timeout.connect(func(): printerr("Tank climb check timed out."); quit(1))

func _frames(count: int) -> void:
	for frame in count: await physics_frame

func _place(point: Vector3) -> void:
	player.reset_at(Transform3D(Basis.IDENTITY, point))
	player.set_physics_process(false)
	level.camera.snap_to_target()

func _run() -> void:
	level = FIXTURE.instantiate_session()
	root.add_child(level)
	await _frames(5)
	player = level.player
	player.died.disconnect(level._on_player_died)
	level.get_node("ShooterEncounterStaging/ShooterIntro").process_mode = Node.PROCESS_MODE_DISABLED
	tank = level.get_node("TankEncounter/Tank")
	var left: StaticBody3D = level.get_node("Platforms/TankClimbScaffold")
	var right: PixelPlatform3D = level.get_node("Platforms/TankClimbUpperGround")
	assert(is_equal_approx(left.position.y + left.underpass_height, 3.84))
	assert(is_equal_approx(right.position.x - right.size.x / 2 - left.position.x - left.width / 2, 4.48))
	assert(is_equal_approx(right.position.y + right.size.y / 2, 25.6))
	assert(not level.has_node("Platforms/TankClimbRightScaffold"))
	var chest: ItemReward3D = level.get_node("TankEncounter/Climb/ScaffoldReward")
	assert(is_equal_approx(left.height, 35.84))
	assert(is_equal_approx(chest.global_position.y, left.height))
	# The service bracket splits the optional roof climb into two reachable legs.
	var wall_apex := player.movement.wall_jump_vertical_speed ** 2 / (2 * player.movement.gravity)
	assert(wall_apex + player.movement.ideal_jump_height() > left.maintenance_ledge_y - 25.6 + 0.5)
	assert(wall_apex + player.movement.ideal_jump_height() > left.height - left.maintenance_ledge_y + 0.5)
	assert(is_equal_approx(level.get_node("TankEncounter/FarCover").position.y, 25.6))
	# Check actual physics contacts, not just the drawn frame dimensions.
	_place(Vector3(69.0, 5.5, 0))
	var contact := player.move_and_collide(Vector3(-1, 0, 0), true)
	assert(contact != null and contact.get_collider() == left and contact.get_normal().x > 0.9,
		"The visible right upright must be a real wall-jump surface.")
	var space := left.get_world_3d().direct_space_state
	for height in [12.5, 23.5, 35.2]:
		_place(Vector3(69, height, 0))
		contact = player.move_and_collide(Vector3(-1, 0, 0), true)
		assert(contact != null and contact.get_collider() == left)
	for height in [5.5, 13.5, 23.5]:
		_place(Vector3(72.5, height, 0))
		contact = player.move_and_collide(Vector3(1, 0, 0), true)
		assert(contact != null and contact.get_collider() == right)
	_place(Vector3(69.1, 31.5, 0))
	contact = player.move_and_collide(Vector3(0, -1, 0), true)
	assert(contact != null and contact.get_collider() == left and contact.get_normal().y > 0.9)
	# Both right-wall patches point into the shaft and are actually lethal.
	for spike_name in ["ClimbLowerWallSpikes", "ClimbUpperWallSpikes"]:
		var spikes: PixelSpikeRow3D = level.get_node("Hazards/" + spike_name)
		assert((spikes.global_basis * Vector3.UP).is_equal_approx(Vector3.LEFT))
		assert(is_equal_approx(spikes.global_position.x, right.position.x - right.size.x / 2))
		assert(wall_apex > spikes.row_width + 0.8, "A wall kick must clear a spike patch plus body clearance")
		_place(Vector3(72.75, spikes.global_position.y, 0))
		await _frames(3)
		assert(player.is_dead(), "Right-wall spike contact must kill")
		_place(Vector3(72.5, spikes.global_position.y + spikes.row_width / 2 + 0.8, 0))
		await _frames(3)
		assert(not player.is_dead(), "Leave clean wall contact above each spike patch")
	# Upper rewards use ordinary pooled chest/save behavior, once per snapshot.
	var before_chest := level.save_state.capture(Vector3(65.28, 36.39, 0))
	var contents := chest.reward_contents()
	assert(not contents.is_empty() and chest.loot_pool == &"rare_supplies")
	assert(chest.collect() and not chest.collect())
	var after_chest := level.save_state.capture(Vector3(65.28, 36.39, 0))
	level.save_state.apply_state(after_chest, true)
	assert(not chest.collect())
	level.save_state.apply_state(before_chest, true)
	assert(chest.reward_contents() == contents and chest.collect())
	level.save_state.apply_state(before_chest, true)
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(65.92, 4.5, 0), Vector3(65.92, 10.5, 0), 1)).is_empty(),
		"Rear braces must leave the central frame open.")
	_place(Vector3(69.24, 5.5, 0))
	tank.global_position = Vector3(68.04, 0.45, 0)
	tank._pursuing = true
	await _frames(8)
	assert(tank.is_pursuing() and tank.velocity.x > 0, "Move beneath the climber even inside the usual four-unit firing distance.")
	assert(tank.NAVIGATION.can_reach(tank, 70.72, true), "Tank must physically fit through the entrance.")
	# Unrelated camera inspection cannot clear aggro or allow unseen combat.
	level.camera.set_process(false)
	level.camera.global_position.x = 160
	await _frames(2)
	assert(tank.is_pursuing() and not tank._can_engage(player))
	level.camera.set_process(true)
	tank.global_position = Vector3(70.72, 0.45, 0)
	_place(Vector3(69.24, 5.5, 0))
	tank.reset_combat_cycle(true)
	var hp := player.health.current
	for frame in 120:
		await physics_frame
		if player.health.current < hp: break
	assert(player.health.current == hp - 25, "An actual aimed upward shell must reach the player.")
	assert(tank._shot_direction.y > 0.8)
	assert(absf(tank.global_position.x - 70.72) < 0.2)
	# The already-engaged tank continues firing from below the taller camera.
	# Verify a real shell travels beyond the former 22 m limit and hits for 25.
	_place(Vector3(70.6, 24.0, 0))
	assert(not tank.NAVIGATION.is_on_camera(tank) and tank._can_engage(player))
	tank._pursuing = false
	assert(not tank._can_notice(player) and not tank._can_engage(player), "No off-screen acquisition")
	tank._pursuing = true
	tank.reset_combat_cycle(true)
	hp = player.health.current
	for frame in 260:
		await physics_frame
		if player.health.current < hp: break
	assert(player.health.current == hp - 25, "Tank shells must still threaten the upper shaft")
	assert(is_zero_approx(tank.pixel_visual.rotation.z), "Only the barrel turns; the tank body stays upright.")
	var aim := Vector3(-0.4, 0.9, 0).normalized()
	tank.pixel_visual.begin_shot(aim, false)
	var muzzle: Vector3 = tank.pixel_visual.muzzle_world_position(0)
	var preview: Vector3 = tank.pixel_visual.aimed_muzzle_world_position(0, aim, false)
	assert(muzzle.distance_to(preview) < 0.001, "Preview and released shell must share the real elevated muzzle.")
	# The upper ground blocks fire before the player reaches the exit boundary.
	_place(Vector3(75.0, 26.15, 0))
	tank.reset_combat_cycle(true)
	hp = player.health.current
	await _frames(125)
	assert(tank.shots_fired_total() > 0 and player.health.current == hp)
	_place(Vector3(76, 26.15, 0))
	var shots := tank.shots_fired_total()
	await _frames(125)
	assert(tank.is_pursuing() and tank.shots_fired_total() > shots,
		"Reaching the upper ground must not stop fire while the climb remains in view")
	# The higher scaffold roof no longer crosses an invisible height cutoff.
	_place(Vector3(65.28, 36.39, 0))
	assert(tank.is_pursuing() and tank._can_engage(player))
	shots = tank.shots_fired_total()
	await _frames(125)
	assert(tank.shots_fired_total() > shots and tank._shot_direction.y > 0.9)
	# Retain the fight with even a thin part of the shaft in view, then stop
	# precisely when it leaves. This also exercises a changed camera position.
	_place(Vector3(76, 26.15, 0))
	level.camera.set_process(false)
	var view_size := level.camera.get_viewport().get_visible_rect().size
	var half_view_width: float = level.camera.size * view_size.x / view_size.y * 0.5
	var climb := level.get_node("TankEncounter/Climb")
	level.camera.position = Vector3(72.96 + half_view_width - 0.03, 20, 24)
	await _frames(2)
	assert(climb.is_climb_visible() and tank.is_pursuing() and tank._can_engage(player))
	level.camera.position.x += 0.06
	await _frames(4)
	assert(not climb.is_climb_visible() and not tank.is_pursuing())
	assert(tank._state == HandgunEnemy3D.CombatState.IDLE)
	shots = tank.shots_fired_total()
	await _frames(50)
	assert(tank.shots_fired_total() == shots, "Leaving the climb's camera view ends new attacks")
	level.camera.set_process(true)
	# Save ammo, loaded magazine and tank defeat as one logical outcome.
	level.acquire_weapon(&"handgun", 30)
	var loaded := player.player_handgun.loaded_rounds
	var ammo := player.inventory.count(&"handgun_ammo")
	var before := level.save_state.capture(player.global_position)
	var receipts := [0]
	level.item_received.connect(func(id: StringName, amount: int):
		if id == &"handgun_ammo": receipts[0] += amount)
	tank.receive_projectile_hit(player.global_position, CombatHit.new(200, &"bullet", player.global_position))
	assert(tank.is_defeated() and player.inventory.count(&"handgun_ammo") == ammo + 30)
	assert(player.player_handgun.loaded_rounds == loaded and receipts[0] == 30)
	var after := level.save_state.capture(player.global_position)
	level.save_state.apply_state(after, true)
	await _frames(3)
	assert(tank.is_defeated() and not tank.visible and receipts[0] == 30)
	assert(player.inventory.count(&"handgun_ammo") == ammo + 30)
	tank.reset_run()
	assert(tank.is_defeated() and receipts[0] == 30)
	level.save_state.apply_state(before, true)
	await _frames(3)
	assert(not tank.is_defeated() and player.inventory.count(&"handgun_ammo") == ammo)
	var values: Dictionary = OBJECTS.CATALOG.defaults("tank_enemy")
	values.ammo_reward = 45
	assert(OBJECTS.validate("tank", values).is_empty())
	var record := OBJECTS.new_record("tank_enemy", values)
	var placed: TankEnemy3D = OBJECTS.instantiate_record(record)
	assert(placed.ammo_reward == 45)
	placed.free()
	values.ammo_reward = -1
	assert(not OBJECTS.validate("tank", values).is_empty())
	var scaffold_values: Dictionary = OBJECTS.CATALOG.defaults("wall_jump_scaffold")
	scaffold_values.height = 35.84
	assert(OBJECTS.validate("scaffold", scaffold_values).is_empty())
	var scaffold := OBJECTS.instantiate_record(OBJECTS.new_record("wall_jump_scaffold", scaffold_values))
	assert(OBJECTS.read_values(scaffold, "scaffold") == scaffold_values)
	scaffold.free()
	scaffold_values.underpass = scaffold_values.height
	assert(not OBJECTS.validate("scaffold", scaffold_values).is_empty())
	level.queue_free()
	await process_frame
	print("Tank climb passed: scaffold and raised ground contacts, roof reach, chest/save restore, under-shaft positioning, retained pursuit, upward hit, solid shelter, exit, ammo and saved defeat.")
	quit()
