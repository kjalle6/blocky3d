extends SceneTree
## Real projectile collisions at screen edges, including a fast crossing step.
const ROUND := preload("res://scenes/projectiles/player_handgun_projectile.tscn")
const CRATE := preload("res://scenes/props/breakable_crate.tscn")
var world: Node3D
var camera: Camera3D
var target: BreakableCrate3D

func _init() -> void:
	call_deferred("_run")
	create_timer(15.0).timeout.connect(func(): quit(1))

func _run() -> void:
	root.size = Vector2i(1280, 720)
	world = Node3D.new()
	root.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = Vector3(0, 0, 20)
	world.add_child(camera)
	camera.make_current()
	target = CRATE.instantiate()
	world.add_child(target)
	target.set_physics_process(false)
	await physics_frame
	var view := root.get_visible_rect()
	var right := camera.project_position(Vector2(view.end.x, view.size.y * 0.5), 20).x
	var top := camera.project_position(Vector2(view.size.x * 0.5, 0), 20).y
	# Targets fully outside the view cannot be hit even by one large physics step.
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]:
		var edge: float = right if direction.x != 0.0 else top
		target.health.reset(50)
		target.global_position = direction * (edge + 2.0)
		await physics_frame
		var round := _round(Vector3.ZERO, direction)
		round._physics_process(1.0)
		assert(round._expired and target.health.current == 50, "Player shot must stop at the camera edge before damaging unseen cover.")
		await physics_frame
	# The visible part of an edge target can still take a normal hit.
	target.global_position = Vector3(right + 0.2, 0, 0)
	await physics_frame
	var partial := _round(Vector3.ZERO, Vector3.RIGHT)
	partial._physics_process(1.0)
	assert(target.health.current == 25 and partial._expired)
	await physics_frame
	# Diagonal shots use both camera axes, not just a fixed horizontal range.
	target.health.reset(50)
	target.global_position = Vector3(right + 4, top + 4, 0)
	await physics_frame
	var diagonal := _round(Vector3.ZERO, Vector3(1, 1, 0).normalized())
	diagonal._physics_process(1.0)
	assert(diagonal._expired and target.health.current == 50)
	await physics_frame
	# Changing the view while a round is in flight must not leave a damaging round behind.
	var moving := _round(Vector3.ZERO, Vector3.RIGHT)
	moving._physics_process(0.02)
	camera.position.x = -30
	moving._physics_process(1.0)
	assert(moving._expired and target.health.current == 50)
	camera.position.x = 0
	await physics_frame
	# This player restriction must not silently shorten enemy shell travel.
	target.global_position = Vector3(right + 2, 0, 0)
	await physics_frame
	var enemy_round := _round(Vector3.ZERO, Vector3.RIGHT, HandgunProjectile3D.Allegiance.ENEMY)
	enemy_round._physics_process(1.0)
	assert(target.health.current == 25 and enemy_round._expired)
	await physics_frame
	# No camera remains a valid standalone physics setup.
	camera.queue_free()
	await process_frame
	target.health.reset(50)
	var unframed := _round(Vector3.ZERO, Vector3.RIGHT)
	unframed._physics_process(1.0)
	assert(target.health.current == 25)
	world.queue_free()
	await process_frame
	print("Player projectile screen bounds passed: four edges, partial targets, diagonal shots, camera motion, enemy shots and no-camera fixtures.")
	quit()

func _round(origin: Vector3, direction: Vector3, side := HandgunProjectile3D.Allegiance.PLAYER) -> HandgunProjectile3D:
	var round := ROUND.instantiate() as HandgunProjectile3D
	round.allegiance = side
	world.add_child(round)
	round.set_physics_process(false)
	round.global_position = origin
	round.speed = 40.0
	round.launch(direction, null, CombatHit.new(25, &"bullet", origin))
	return round
