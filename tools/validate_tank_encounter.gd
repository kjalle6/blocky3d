extends SceneTree
## Focused combat contract: tank cadence, absorbing cover, damage, save
## restoration and placeable objects. The player owns traversal playtesting.
const FIXTURE := preload("res://tools/level_3_shooter_area_fixture.gd")
const SHELL := preload("res://scenes/projectiles/tank_shell.tscn")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
var level: LevelSession3D
var player: PlayerCharacter
var tank: TankEnemy3D
var _finished := false

func _init() -> void:
	call_deferred("_run")
	create_timer(45.0).timeout.connect(_timeout)

func _timeout() -> void:
	if not _finished:
		printerr("Tank encounter validation timed out.")
		quit(1)

func _frames(count: int) -> void:
	for frame in count: await physics_frame

func _run() -> void:
	level = FIXTURE.instantiate_session()
	root.add_child(level)
	await _frames(10)
	assert(not level.has_meta("layout_error"))
	player = level.player
	# Keep unexpected damage in place instead of automatically restarting.
	player.died.disconnect(level._on_player_died)
	level.get_node("ShooterEncounterStaging/ShooterIntro").process_mode = Node.PROCESS_MODE_DISABLED
	tank = level.get_node("TankEncounter/Tank")
	tank.set_engagement_enabled(false)
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(46.0, 0.7, 0)))
	await _frames(8)
	tank.reset_run()
	await _frames(120)
	assert(tank.shots_fired_total() == 0, "Do not fire into the pit landing.")
	# Now stand behind both cover layers. The tank must keep moving while it fires.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(50.0, 0.7, 0)))
	await _frames(8)
	var start_x := tank.global_position.x
	var inner := level.get_node("TankEncounter/InnerCrates/Right") as BreakableCrate3D
	var outer := level.get_node("TankEncounter/OuterCrates/Right") as BreakableCrate3D
	var upper := level.get_node("TankEncounter/OuterCrates/Top") as BreakableCrate3D
	var neighbour := level.get_node("TankEncounter/OuterCrates/Left") as BreakableCrate3D
	var before_cover := level.save_state.capture(player.global_position)
	var hp := player.health.current
	for frame in 240:
		await physics_frame
		if outer.is_defeated(): break
	assert(outer.is_defeated() and not inner.is_defeated(), "First shell must destroy only the first individual box.")
	assert(not upper.is_defeated() and not neighbour.is_defeated(), "The other boxes in the pile must survive.")
	assert(player.health.current == hp, "A broken layer must absorb its shell.")
	assert(absf(tank.global_position.x - start_x) > 0.5, "Tank should move during its attack cycle.")
	var state := tank._state
	var timer := tank._phase_remaining
	var motion := tank.velocity
	assert(not tank.receive_melee_hit(player.global_position, CombatHit.new(50, &"stomp", player.global_position)))
	assert(tank.health.current == 200 and not tank.health.has_taken_damage)
	assert(tank.receive_projectile_hit(player.global_position, CombatHit.new(25, &"bullet", player.global_position)))
	assert(tank._state == state and tank._phase_remaining == timer and tank.velocity == motion, "Nonlethal hits cannot interrupt the tank.")
	tank.set_engagement_enabled(false)
	await _frames(35)
	assert(upper.global_position.y < 0.55, "Unsupported upper box must fall to the ground.")
	assert(not upper.is_defeated() and not neighbour.is_defeated())
	await _fire_at(Vector3(57, 0.8, 0), Vector3.LEFT, &"tank_shell", HandgunProjectile3D.Allegiance.ENEMY)
	assert(upper.is_defeated() and not neighbour.is_defeated() and not inner.is_defeated())
	await _fire_at(Vector3(57, 0.8, 0), Vector3.LEFT, &"tank_shell", HandgunProjectile3D.Allegiance.ENEMY)
	assert(neighbour.is_defeated() and not inner.is_defeated())
	assert(player.health.current == hp, "Every destroyed box must absorb its breaking shell.")
	await _fire_at(Vector3(53.5, 0.8, 0), Vector3.LEFT, &"tank_shell", HandgunProjectile3D.Allegiance.ENEMY)
	assert(inner.is_defeated())
	var broken_cover := level.save_state.capture(player.global_position)
	level.save_state.apply_state(before_cover, false)
	await _frames(2)
	assert(not inner.is_defeated() and not outer.is_defeated(), "Loading the earlier snapshot restores its cover.")
	level.save_state.apply_state(broken_cover, false)
	await _frames(2)
	assert(inner.is_defeated() and outer.is_defeated(), "Loading the later snapshot keeps its broken cover.")
	# Same solid crate accepts player rounds and knife hits, but no duplicate hit.
	var far := level.get_node("TankEncounter/FarCover/Left") as BreakableCrate3D
	var hit := CombatHit.new(25, &"knife", player.global_position)
	assert(far.receive_melee_hit(player.global_position, hit))
	assert(not far.receive_melee_hit(player.global_position, hit))
	assert(far.health.current == 25 and not far.is_defeated())
	# Review this player shot in the current view, as ordinary gameplay requires.
	player.global_position = far.global_position + Vector3(-1.1, 0.07, 0)
	level.camera.snap_to_target()
	await _fire_at(far.global_position + Vector3(-0.9, 0.32, 0), Vector3.RIGHT, &"bullet", HandgunProjectile3D.Allegiance.PLAYER)
	assert(far.is_defeated(), "Real player projectile must hit crate collision.")
	# Seven handgun rounds leave 25 HP; the eighth defeats it.
	tank.reset_run()
	tank.set_engagement_enabled(false)
	for shot in 7:
		assert(tank.receive_projectile_hit(player.global_position, CombatHit.new(25, &"bullet", player.global_position)))
	assert(tank.health.current == 25 and not tank.is_defeated())
	assert(tank.receive_projectile_hit(player.global_position, CombatHit.new(25, &"bullet", player.global_position)))
	assert(tank.is_defeated())
	# Catalog placement must create the actual actors.
	for template in ["tank_enemy", "breakable_crates"]:
		var values: Dictionary = OBJECTS.CATALOG.defaults(template)
		values.x = 80.0
		values.y = 0.0
		var record: Dictionary = OBJECTS.new_record(template, values)
		assert(OBJECTS.validate(record.kind, values).is_empty())
		var node: Node3D = OBJECTS.instantiate_record(record)
		assert(node != null)
		node.free()
	_finished = true
	print("Tank encounter passed: landing gate, moving uninterrupted fire, stomp immunity, eight-shot HP, absorbing layered cover, damage and snapshot restoration.")
	level.queue_free()
	await process_frame
	quit()

func _fire_at(origin: Vector3, direction: Vector3, kind: StringName, owner_side: int) -> void:
	var shell := SHELL.instantiate() as HandgunProjectile3D
	shell.allegiance = owner_side
	level.add_child(shell)
	shell.global_position = origin
	shell.launch(direction, player if owner_side == HandgunProjectile3D.Allegiance.PLAYER else null, CombatHit.new(25, kind, origin))
	for frame in 45:
		await physics_frame
		if not is_instance_valid(shell): return
	assert(false, "Expected a nearby solid collision.")
