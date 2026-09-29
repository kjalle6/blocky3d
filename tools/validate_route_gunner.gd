extends SceneTree
## Reusable route-gunner behavior and save checks, independent of campaign layout.
const FIXTURE = preload("res://tools/level_3_shooter_area_fixture.gd")
const OBJECTS = preload("res://scripts/developer/level_layout_objects.gd")
var level: LevelSession3D
var player: PlayerCharacter
var mobile: HandgunEnemy3D
var guard: HandgunEnemy3D

func _init() -> void:
	call_deferred("_run")
	create_timer(30).timeout.connect(func(): printerr("Route gunner check timed out"); quit(1))

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
	level.get_node("TankEncounter/Tank").set_engagement_enabled(false)
	mobile = load("res://scenes/enemies/route_gunner.tscn").instantiate()
	mobile.name = "TestMovingGunner"
	mobile.position = Vector3(94, 26.15, 0)
	level.add_child(mobile)
	guard = load("res://scenes/enemies/route_gunner.tscn").instantiate()
	guard.name = "TestStationaryGunner"
	guard.position = Vector3(100, 26.15, 0)
	guard.mobile = false
	level.add_child(guard)
	await _frames(5)
	# Catalog defaults and existing stationary gunner saves both round-trip.
	assert(OBJECTS.validate("gunner", {"x": 1, "y": 2, "facing_right": false}).is_empty())
	var values: Dictionary = OBJECTS.CATALOG.defaults("route_gunner")
	assert(OBJECTS.validate("gunner", values).is_empty())
	values.ammo_reward = -1
	assert(not OBJECTS.validate("gunner", values).is_empty())
	var edited = load("res://scenes/enemies/route_gunner.tscn").instantiate()
	values.ammo_reward = 12
	values.mobile = false
	OBJECTS.apply(edited, "gunner", values)
	assert(OBJECTS.read_values(edited, "gunner") == JSON.parse_string(JSON.stringify(values, "", true)))
	edited.free()
	guard.set_engagement_enabled(false)
	_place(Vector3(84, 26.3, 0))
	mobile.reset_run()
	await _frames(12)
	assert(mobile.is_pursuing() and mobile.velocity.x < 0, "Pursue the player across the open fight.")
	assert(mobile.pixel_visual.current_state() == &"walk")
	_place(mobile.global_position + Vector3(-4, 0, 0))
	await _frames(3)
	assert(mobile._state == HandgunEnemy3D.CombatState.TELEGRAPH and is_zero_approx(mobile.velocity.x))
	mobile._begin_volley()
	var aim: Vector3 = mobile._shot_direction
	_place(mobile.global_position + Vector3(4, 0, 0))
	assert(mobile._resolve_shot_direction().is_equal_approx(aim), "A burst cannot instantly reverse behind the player.")
	mobile.receive_melee_hit(player.global_position, CombatHit.new(1, &"knife", player.global_position))
	assert(mobile._state == HandgunEnemy3D.CombatState.RECOVERY and mobile._sequence_shots_remaining == 0)
	mobile.clear_active_projectiles()
	mobile._phase_remaining = 0.01
	await _frames(3)
	assert(mobile.facing_direction() > 0, "Reacquire the player after recovery.")
	_place(Vector3(25, 0.55, 0))
	await _frames(3)
	assert(not mobile.is_pursuing() and mobile._state == HandgunEnemy3D.CombatState.IDLE)
	mobile.set_engagement_enabled(false)
	# The same reusable variant can hold a stationary position.
	guard.reset_run()
	_place(Vector3(94, 26.3, 0))
	await _frames(4)
	assert(guard._can_engage(player))
	var fixed_position := guard.global_position
	await _frames(8)
	assert(guard.global_position.distance_to(fixed_position) < 0.05 and not guard.mobile)
	# Ordinary kills give one small reward and survive a snapshot load. Loading
	# the older snapshot restores both the enemy and the earlier ammo count.
	guard.set_engagement_enabled(false)
	_place(Vector3(84, 26.3, 0))
	var before := level.save_state.capture(player.global_position)
	var ammo := player.inventory.count(&"handgun_ammo")
	mobile.receive_projectile_hit(player.global_position, CombatHit.new(100, &"bullet", player.global_position))
	assert(mobile.is_defeated() and player.inventory.count(&"handgun_ammo") == ammo + 6)
	var after := level.save_state.capture(player.global_position)
	level.save_state.apply_state(after, true)
	assert(mobile.is_defeated() and player.inventory.count(&"handgun_ammo") == ammo + 6)
	assert(not mobile.receive_projectile_hit(player.global_position))
	level.save_state.apply_state(before, true)
	assert(not mobile.is_defeated() and player.inventory.count(&"handgun_ammo") == ammo)
	print("Route gunner: walking/pursuit, committed bursts, interruption, camera disengagement, stationary option, authoring and exact reward saves PASS")
	level.queue_free()
	await process_frame
	quit()
