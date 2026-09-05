extends SceneTree
## Focused contract for the first gun's death-gated physical presentation,
## collection, and run-local ownership lifecycle.

const SHOOTER_AREA := preload("res://tools/level_3_shooter_area_fixture.gd")

var _completed := false
var _drop_started_count := 0
var _settled_count := 0
var _acquired_count := 0


func _init() -> void:
	create_timer(12.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Green Zone handgun-drop validation aborted before completing.")
	quit(1)


func _run() -> void:
	var packed_root := load("res://scenes/app/game_root.tscn") as PackedScene
	assert(packed_root != null)
	var game_root := packed_root.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var level := SHOOTER_AREA.load_into(game_root)
	for frame in 8:
		await physics_frame

	var shooter := level.get_node(
		"ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy"
	) as HandgunEnemy3D
	var anchor := level.get_node(
		"ShooterEncounterStaging/GunDropAnchor"
	) as Marker3D
	var pickup := anchor.get_node("HandgunPickup") as HandgunPickup3D
	assert(shooter != null and anchor != null and pickup != null)
	assert(level.get_tree().get_nodes_in_group("weapon_pickup").size() == 1)
	assert(pickup.validation_errors().is_empty())
	assert(pickup.is_locked())
	assert(not pickup.visible)
	assert(pickup.collection_enabled)
	assert(not pickup.collection_is_active())
	assert(pickup.collection_shape.disabled)
	assert(pickup.landing_position().is_equal_approx(anchor.global_position))
	assert(is_equal_approx(anchor.global_position.x, 23.04))
	assert(is_equal_approx(anchor.global_position.y, 0.18))

	pickup.drop_started.connect(func() -> void: _drop_started_count += 1)
	pickup.settled.connect(func() -> void: _settled_count += 1)
	level.weapon_acquired.connect(
		func(weapon_id: StringName) -> void:
			if weapon_id == PlayerWeapon.HANDGUN:
				_acquired_count += 1
	)
	shooter.receive_melee_hit(level.player.global_position)
	assert(shooter.is_defeated())
	assert(_drop_started_count == 1)
	assert(pickup.is_airborne())
	assert(pickup.visible)
	assert(not pickup.collection_is_active())
	assert(pickup.visual.texture.resource_path.ends_with(
		"/handgun_pickup_airborne.png"
	))
	assert(pickup.global_position.x > pickup.landing_position().x)
	assert(pickup.global_position.y > pickup.landing_position().y)

	# A defeated enemy cannot create another reward from repeated hit requests.
	shooter.receive_melee_hit(level.player.global_position)
	assert(_drop_started_count == 1)

	for frame in 90:
		await physics_frame
		if pickup.is_available():
			break
	assert(pickup.is_available())
	assert(_settled_count == 1)
	assert(pickup.global_position.is_equal_approx(anchor.global_position))
	assert(pickup.visual.texture.resource_path.ends_with("/handgun_pickup.png"))
	assert(is_zero_approx(pickup.visual.rotation.z))
	assert(pickup.collection_is_active())
	assert(not pickup.collection_shape.disabled)

	# Entering the settled pickup grants exactly one session-owned gun and
	# auto-equips it. The scene-authored actor is claimed rather than replaced.
	level.player.reset_at(Transform3D(
		Basis.IDENTITY,
		Vector3(anchor.global_position.x, 0.7, 0.0)
	))
	for frame in 8:
		await physics_frame
	assert(_acquired_count == 1)
	assert(level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.equipped_weapon_id() == PlayerWeapon.HANDGUN)
	assert(pickup.is_claimed())
	assert(not pickup.visible)
	assert(not pickup.collection_is_active())
	assert(pickup.collection_shape.disabled)

	# A death/checkpoint world reset retains the earned weapon and cannot reveal
	# or duplicate its one pickup.
	level.call(&"_reset_world")
	for frame in 6:
		await physics_frame
	assert(level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.equipped_weapon_id() == PlayerWeapon.HANDGUN)
	assert(pickup.is_claimed())
	assert(not pickup.visible)
	assert(_acquired_count == 1)

	# Manual R is the authored full-section restart: it clears the session gun,
	# rearms the shooter, and reuses the same locked pickup actor.
	level.call(&"_reset_run")
	for frame in 6:
		await physics_frame
	assert(not shooter.is_defeated())
	assert(not level.owns_weapon(PlayerWeapon.HANDGUN))
	assert(level.player.equipped_weapon_id() == PlayerWeapon.KNIFE)
	assert(pickup.is_locked())
	assert(not pickup.visible)
	assert(not pickup.collection_is_active())
	assert(pickup.global_position.is_equal_approx(anchor.global_position))

	# Resetting during the kick cannot leave a delayed bounce or ghost pickup.
	shooter.receive_melee_hit(level.player.global_position)
	for frame in 8:
		await physics_frame
	assert(pickup.is_airborne())
	assert(_drop_started_count == 2)
	level.call(&"_reset_run")
	for frame in 45:
		await physics_frame
	assert(not shooter.is_defeated())
	assert(pickup.is_locked())
	assert(not pickup.visible)
	assert(_settled_count == 1)

	# The exact same actor can perform the complete deterministic drop again.
	shooter.receive_melee_hit(level.player.global_position)
	for frame in 90:
		await physics_frame
		if pickup.is_available():
			break
	assert(pickup.is_available())
	assert(_drop_started_count == 3)
	assert(_settled_count == 2)
	assert(pickup.global_position.is_equal_approx(anchor.global_position))
	assert(pickup.collection_is_active())
	assert(level.get_tree().get_nodes_in_group("weapon_pickup").size() == 1)

	print(
		"Green Zone handgun drop passed: one authored pickup, crisp two-pose "
		+ "kick, one acquisition, death persistence, full-restart rearm, and "
		+ "reset cancellation."
	)
	_completed = true
	quit(0)
