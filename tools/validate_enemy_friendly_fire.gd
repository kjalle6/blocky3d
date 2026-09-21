extends SceneTree
## Real ray collisions, paired-gun restraint, and bullets independent of a dead shooter.
const GUNNER := preload("res://scenes/enemies/handgun_enemy.tscn")
const SKATER := preload("res://scenes/enemies/pixel_skater_enemy.tscn")
const ROUND := preload("res://scenes/projectiles/handgun_projectile.tscn")
var _world: Node3D

func _init() -> void:
	call_deferred("_run")
	create_timer(25.0, true).timeout.connect(func() -> void: quit(1))

func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var floor := _box(Vector3(14, -0.64, 0), Vector3(40, 1.28, 3))
	var player := (load("res://scenes/player/pixel_player_character.tscn") as PackedScene).instantiate() as PlayerCharacter
	player.position = Vector3(18, 0.55, 0)
	_world.add_child(player)
	player.set_physics_process(false)
	var shooter := _gunner(Vector3(4, 0.55, 0))
	var ally := _gunner(Vector3(8, 0.55, 0))
	var feedback := CombatFeedback3D.new()
	_world.add_child(feedback)
	feedback.enemy_defeat_pause = 0
	feedback.bind_handgun_enemy(shooter)
	var shot_sounds := [0]
	var character_impacts := [0]
	feedback.combat_audio.event_played.connect(func(event: Dictionary) -> void:
		if event.id == "combat/enemy_gunshot": shot_sounds[0] += 1
		if event.id == "combat/bullet_character": character_impacts[0] += 1)
	await physics_frame
	await physics_frame
	for frame in 80:
		shooter._physics_process(1.0 / 60.0)
		await physics_frame
	assert(shooter.shots_fired_total() == 0 and shot_sounds[0] == 0)
	assert(not ally.is_defeated() and not shooter.pixel_visual.is_shot_playing())
	assert(shooter._sequence_shots_remaining == 3, "Waiting for a teammate must not consume the pending volley.")
	# Move the blocker away; a skater above the clear lane falls into bullets
	# after release. Kill the shooter too: its already-fired rounds must survive.
	ally.position = Vector3(40, 0.55, 0)
	var skater := SKATER.instantiate() as StompableEnemy3D
	skater.position = Vector3(8, 4, 0)
	skater.patrol_speed = 0
	_world.add_child(skater)
	skater.set_physics_process(false)
	feedback.bind_enemy(skater)
	await physics_frame
	for frame in 10:
		shooter._physics_process(1.0 / 60.0)
		await physics_frame
		if shooter.shots_fired_total() > 0: break
	assert(shooter.shots_fired_total() == 2 and shot_sounds[0] == 1)
	assert(not skater.is_defeated() and skater.position.y == 4)
	shooter.receive_projectile_hit(Vector3.ZERO, CombatHit.new(50, &"fixture"))
	assert(shooter.is_defeated() and shooter.active_projectile_count() == 2)
	skater.set_physics_process(true)
	for frame in 55:
		await physics_frame
		if skater.health.current < 50: break
	assert(skater.health.current == 25 and not skater.is_defeated(), "One paired beat deals 25 damage to an entering enemy.")
	assert(character_impacts[0] > 0, "Friendly fire uses the existing character impact sound.")
	_reset_enemy(shooter)
	assert(shooter.active_projectile_count() == 0 and not shooter.is_defeated())
	skater.queue_free()
	await physics_frame
	await physics_frame
	# Generic overlap areas must not swallow a shot. The source's body and
	# every child hurt/contact area are excluded even when firing from inside it.
	ally.position = Vector3(8, 0.55, 0)
	var trigger := Area3D.new()
	trigger.position = Vector3(6, 0.8, 0)
	var trigger_shape := CollisionShape3D.new()
	trigger_shape.shape = BoxShape3D.new()
	trigger_shape.shape.size = Vector3(0.4, 3, 1)
	trigger.add_child(trigger_shape)
	_world.add_child(trigger)
	await physics_frame
	await physics_frame
	var round := _round(Vector3(4, 0.8, 0), shooter)
	round._physics_process(0.5)
	assert(ally.health.current == 25 and not shooter.is_defeated(), "A fast enemy round must hit another gunner and ignore its own hurtboxes.")
	assert(round._expired)
	trigger.queue_free()
	await physics_frame
	await physics_frame
	_reset_enemy(ally)
	ally.position = Vector3(8, 0.55, 0)
	var cover := _box(Vector3(6, 1, 0), Vector3(0.08, 2, 2))
	await physics_frame
	await physics_frame
	var hit_targets: Array[Object] = []
	round = _round(Vector3(4, 0.8, 0), shooter)
	round.impacted.connect(func(_p: Vector3, _n: Vector3, collider: Object) -> void: hit_targets.append(collider))
	round._physics_process(0.5)
	assert(not ally.is_defeated() and hit_targets == [cover], "Thin cover must stop the shot before the friendly target.")
	assert(not shooter._teammate_blocks_shot(Vector3.RIGHT), "A teammate behind solid cover is not exposed to this shot.")
	cover.queue_free()
	# A teammate behind the player is not blocking the intended target.
	ally.position.x = 20
	await physics_frame
	await physics_frame
	assert(not shooter._teammate_blocks_shot(Vector3.RIGHT))
	# Check both forward barrels: a tiny target intersects only the rear gun's
	# lane, between the two muzzles. This must suppress the complete paired beat.
	ally.position = shooter.position
	ally.body_collision.disabled = true
	var hurtbox := ally.get_node("ProjectileHurtbox") as Area3D
	var hurt_shape := hurtbox.get_node("Collision") as CollisionShape3D
	var original_shape := hurt_shape.shape
	var original_position := hurtbox.position
	hurt_shape.shape = BoxShape3D.new()
	hurt_shape.shape.size = Vector3(0.08, 0.03, 0.5)
	hurtbox.position.y = 0.37
	shooter._facing_sign = 1
	await physics_frame
	await physics_frame
	var rear_debug := shooter.pixel_visual.aimed_muzzle_world_position(1, Vector3.RIGHT, true)
	rear_debug.z = 0
	var rear_hit := HandgunProjectile3D.cast_shot(_world.get_world_3d().direct_space_state, rear_debug,
		rear_debug + Vector3.RIGHT * 22, 5, HandgunProjectile3D.source_exclusions(shooter))
	assert(shooter._teammate_blocks_shot(Vector3.RIGHT), "rear=%s hurt=%s layer=%s hit=%s shape=%s" % [rear_debug, hurtbox.global_position, hurtbox.collision_layer, rear_hit, hurt_shape.shape.size])
	var front := shooter.pixel_visual.aimed_muzzle_world_position(0, Vector3.RIGHT, true)
	front.z = 0
	var front_hit := HandgunProjectile3D.cast_shot(_world.get_world_3d().direct_space_state,
		front, front + Vector3.RIGHT * 22, 5, HandgunProjectile3D.source_exclusions(shooter))
	assert(front_hit.collider == player, "The front muzzle is clear; the rear muzzle is the reason to hold fire.")
	hurt_shape.shape = original_shape
	hurtbox.position = original_position
	ally.body_collision.disabled = false
	# Upward, downward and left-facing fire use the same prospective muzzle
	# coordinates as the actual shot animation, without playing a firing marker.
	shooter.position = Vector3(12, 8, 0)
	for facing in [-1.0, 1.0]:
		for vertical in [-1.0, 0.0, 1.0]:
			var direction := Vector3(facing, vertical, 0).normalized()
			shooter._facing_sign = facing
			var start := shooter.pixel_visual.aimed_muzzle_world_position(0, direction, facing > 0)
			start.z = 0
			ally.position = start + direction * 3 - Vector3(0, 0.4, 0)
			await physics_frame
			await physics_frame
			assert(shooter._teammate_blocks_shot(direction), "Hold fire must use the actual angled firing lane.")
	# Reset removes the hit target's defeated state and restores its hurtbox.
	ally.receive_projectile_hit(Vector3.ZERO, CombatHit.new(50, &"fixture"))
	await physics_frame
	await physics_frame
	_reset_enemy(ally)
	await physics_frame
	await physics_frame
	assert(not ally.is_defeated() and hurtbox.collision_layer == 4)
	# A teammate entering between beats pauses the remaining volley too.
	_reset_enemy(shooter)
	ally.position = Vector3(40, 0.55, 0)
	await physics_frame
	await physics_frame
	shooter._begin_volley()
	assert(shooter.shots_fired_total() == 2)
	# Remove the first beat only in this fixture, isolating the waiting logic
	# from the in-flight collision behavior already exercised above.
	shooter.clear_active_projectiles()
	ally.position = Vector3(8, 0.55, 0)
	await physics_frame
	await physics_frame
	var cues_before: int = shot_sounds[0]
	for frame in 24:
		shooter._physics_process(1.0 / 60.0)
		await physics_frame
	assert(shooter.shots_fired_total() == 2 and shooter._sequence_shots_remaining == 2)
	assert(shot_sounds[0] == cues_before and not ally.is_defeated())
	ally.position = Vector3(40, 0.55, 0)
	await physics_frame
	for frame in 8:
		shooter._physics_process(1.0 / 60.0)
		await physics_frame
		if shooter.shots_fired_total() > 2: break
	assert(shooter.shots_fired_total() == 4 and shooter._sequence_shots_remaining == 1)
	shooter.reset_run()
	assert(shooter.active_projectile_count() == 0)
	assert(is_instance_valid(floor))
	_world.free()
	print("Enemy friendly fire passed: paired/angled hold-fire and resumption, no false gunshots, owner exclusion, moving skater hit, gunner damage, thin cover, impact audio, shooter-death bullet lifetime and reset.")
	quit(0)

func _gunner(point: Vector3) -> HandgunEnemy3D:
	var enemy := GUNNER.instantiate() as HandgunEnemy3D
	enemy.position = point
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _reset_enemy(enemy: HandgunEnemy3D) -> void:
	# LevelSession resets both registered nodes on a real respawn.
	enemy.reset_run()
	enemy.get_node("ProjectileHurtbox").reset_run()
	enemy.set_physics_process(false)

func _round(point: Vector3, source: CollisionObject3D) -> HandgunProjectile3D:
	var round := ROUND.instantiate() as HandgunProjectile3D
	_world.add_child(round)
	round.position = point
	round.speed = 40
	round.launch(Vector3.RIGHT, source)
	return round

func _box(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = point
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = size
	body.add_child(collision)
	_world.add_child(body)
	return body
