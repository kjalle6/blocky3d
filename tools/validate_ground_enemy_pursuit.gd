extends SceneTree
## Pursuit is grounded, bounded and independent of which way the player faces.
const PLAYER := preload("res://scenes/player/pixel_player_character.tscn")
const ENEMIES := [
	preload("res://scenes/enemies/pixel_patrol_enemy.tscn"),
	preload("res://scenes/enemies/pixel_skater_enemy.tscn"),
]
const SPIKES := preload("res://scenes/hazards/pixel_spike_row.tscn")
const NAVIGATION := preload("res://scripts/enemies/ground_enemy_navigation.gd")
var _world: Node3D
var _player: PlayerCharacter
var _enemy: StompableEnemy3D
var _floor: StaticBody3D
var _errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(80.0).timeout.connect(func(): push_error("Pursuit test timed out."); quit(1))
	for packed in ENEMIES:
		for direction in [-1.0, 1.0]:
			await _jump_over(packed, direction)
		for obstacle in ["ledge", "spikes", "wall", "patrol_limit"]:
			await _barrier(packed, obstacle)
		await _crowded_chase(packed)
		await _camera_exit(packed)
		await _hazard_queries(packed)
	for message in _errors:
		push_error(message)
	print("Ground enemy pursuit checks: %s" % ("passed" if _errors.is_empty() else "%d failed" % _errors.size()))
	quit(0 if _errors.is_empty() else 1)


func _fixture(packed: PackedScene, direction := 1.0) -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_floor = _box(Vector3(40, 1, 4), Vector3(0, -0.5, 0))
	_player = PLAYER.instantiate()
	_world.add_child(_player)
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(1.1 * direction, 0.55, 0)))
	_player.set_physics_process(false)
	_enemy = packed.instantiate()
	_enemy.position = Vector3(0, 0.38, 0)
	_enemy.starts_moving_right = direction > 0.0
	_world.add_child(_enemy)


func _box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	_world.add_child(body)
	return body


func _jump_over(packed: PackedScene, direction: float) -> void:
	_fixture(packed, -direction)
	_enemy.set_physics_process(false)
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(-2.7 * direction, 0.55, 0)))
	await _frames(5)
	_enemy.set_physics_process(true)
	var action := "move_right" if direction > 0.0 else "move_left"
	Input.action_press(action)
	Input.action_press("jump")
	await _frames(45)
	Input.action_release("jump")
	Input.action_release(action)
	var label := "%s jump %s: " % [_enemy.name, direction]
	_check(_player.global_position.x * direction > 1.5, label + "fixture must cross over the enemy")
	_check(not _enemy.is_defeated(), label + "jump must clear the enemy without a stomp")
	_check(_enemy.is_pursuing(), label + "must keep pursuing after the player jumps past")
	var chase_start := _enemy.global_position.x
	await _frames(12)
	_check(_enemy.facing_sign() == direction, label + "must face the player after crossing")
	_check((_enemy.global_position.x - chase_start) * direction > 0.1, label + "must follow rather than continue its old patrol")
	for frame in 120:
		await _frames(1)
		if _player.health.current < 100:
			break
	_check(_player.health.current == 75, label + "must catch a player who lands and stops, then attack")
	_check(not _enemy.is_defeated(), label + "pursuit must survive the jump")
	_world.free()
	await _frames(1)


func _barrier(packed: PackedScene, obstacle: String) -> void:
	_fixture(packed)
	match obstacle:
		"ledge":
			(_floor.get_child(0).shape as BoxShape3D).size.x = 4.0
			_box(Vector3(4, 1, 4), Vector3(6, -0.5, 0))
		"spikes":
			var spikes := SPIKES.instantiate()
			spikes.position = Vector3(3, 0, 0)
			spikes.row_width = 2.0
			_world.add_child(spikes)
		"wall":
			_box(Vector3(0.4, 3, 4), Vector3(2, 1.5, 0))
		"patrol_limit":
			_enemy.patrol_right_distance = 1.3
	await _frames(5)
	_check(_enemy.is_pursuing(), obstacle + ": fixture must engage before retreat")
	_enemy.health.damage(CombatHit.new(10, &"fixture_damage"))
	_player.position.x = 6.0
	var furthest_x := _enemy.position.x
	var lowest_y := _enemy.position.y
	var dropped_pursuit := false
	for frame in 180:
		await _frames(1)
		furthest_x = maxf(furthest_x, _enemy.position.x)
		lowest_y = minf(lowest_y, _enemy.position.y)
		dropped_pursuit = dropped_pursuit or not _enemy.is_pursuing()
	var limit := 1.46 if obstacle == "wall" else 1.40
	_check(furthest_x < limit and lowest_y > 0.35, "%s %s: must stop on safe ground before the obstacle" % [_enemy.name, obstacle])
	_check(dropped_pursuit and not _enemy.is_pursuing(), obstacle + ": must disengage without repeatedly reacquiring across the obstacle")
	_check(_enemy.health.current == 40, obstacle + ": disengagement must preserve damage")
	_enemy.reset_run()
	_check(not _enemy.is_pursuing(), obstacle + ": run reset must clear combat attention")
	_world.free()
	await _frames(1)


func _crowded_chase(packed: PackedScene) -> void:
	_fixture(packed)
	_player.position.x = 3.0
	var front := packed.instantiate() as StompableEnemy3D
	front.position = Vector3(1.8, 0.38, 0)
	_world.add_child(front)
	await _frames(100)
	_check(_enemy.is_pursuing(), "Bumping another enemy must not end pursuit")
	_check(_enemy.facing_sign() > 0.0, "A queued enemy must keep facing the player")
	_check(_enemy.position.x < front.position.x - 0.70, "Pursuit must preserve solid spacing between enemies")
	_world.free()
	await _frames(1)


func _camera_exit(packed: PackedScene) -> void:
	_fixture(packed)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 10.0
	camera.position = Vector3(0, 1, 24)
	_world.add_child(camera)
	camera.current = true
	await _frames(5)
	_check(_enemy.is_pursuing(), "Visible nearby enemy must engage")
	# Complete sprite bounds count; its origin leaving view alone is insufficient.
	var view := root.get_visible_rect().size
	var half_width := camera.size * view.x / view.y * 0.5
	camera.position.x = _enemy.pixel_visual.global_position.x + half_width + 0.3
	_check(NAVIGATION.is_on_camera(_enemy), "Partially visible enemy must remain on camera")
	camera.position.x += 3.0
	_check(not NAVIGATION.is_on_camera(_enemy), "Fully offscreen enemy must leave camera bounds")
	await _frames(2)
	_check(not _enemy.is_pursuing(), "Camera exit must end pursuit even during a swing")
	await _frames(90)
	_check(not _enemy.is_pursuing(), "An offscreen enemy must not reacquire a nearby player")
	_check(is_instance_valid(_enemy) and _enemy.visible, "Disengaging must not despawn the enemy")
	_world.free()
	await _frames(1)


func _hazard_queries(packed: PackedScene) -> void:
	_fixture(packed)
	_enemy.set_physics_process(false)
	var spikes := SPIKES.instantiate()
	spikes.position = Vector3(3, 0, 0)
	_world.add_child(spikes)
	await _frames(2)
	_check(not NAVIGATION.can_reach(_enemy, 6.0), "Layer-zero spikes must block the pursuit route")
	spikes.position.y = 4.0
	_check(NAVIGATION.can_reach(_enemy, 6.0), "A hazard overhead must not block safe ground below")
	spikes.position.y = 0.0
	spikes.monitoring = false
	_check(NAVIGATION.can_reach(_enemy, 6.0), "An inactive hazard must not block pursuit")
	spikes.monitoring = true
	(spikes.get_node("DamageCollision") as CollisionShape3D).disabled = true
	_check(NAVIGATION.can_reach(_enemy, 6.0), "A disabled hazard shape must not block pursuit")
	_world.free()
	await _frames(1)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
