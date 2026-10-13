extends SceneTree
## No stomp kills: a real falling landing on an ordinary enemy costs the
## player one ordinary hit and knocks them clear. The enemy is unharmed, there
## is no stomp bounce, and the player never rides an enemy.

const PLAYER := preload("res://scenes/player/pixel_player_character.tscn")
const CONTACT := preload("res://scripts/combat/enemy_combat_contact.gd")
const ENEMIES := [
	preload("res://scenes/enemies/pixel_patrol_enemy.tscn"),
	preload("res://scenes/enemies/pixel_skater_enemy.tscn"),
	preload("res://scenes/enemies/handgun_enemy.tscn"),
	preload("res://scenes/enemies/route_gunner.tscn"),
]
var _world: Node3D
var _player: PlayerCharacter
var _bounces := 0
var _hits := 0
var _errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0).timeout.connect(func(): push_error("Head landing test timed out."); quit(1))
	for packed in ENEMIES:
		for offset in [-0.15, 0.0, 0.15]:
			await _knocked_off(packed, offset)
		await _held_toward_enemy(packed)
		await _wall_behind(packed)
	await _live_enemy()
	for message in _errors:
		push_error(message)
	print("Enemy head landing checks: %s" % ("passed" if _errors.is_empty() else "%d failed" % _errors.size()))
	quit(0 if _errors.is_empty() else 1)


func _knocked_off(packed: PackedScene, offset: float) -> void:
	var enemy := await _fixture(packed)
	var label := "%s offset %.2f: " % [enemy.name, offset]
	var enemy_health: int = enemy.health.current
	var head_x := CONTACT.stomp_bounds(enemy).get_center().x
	var head_y := await _drop_on_head(enemy, offset)
	await _until_grounded()
	_check(_hits == 1 and _player.health.current == 75, label + "one head landing must cost exactly one 25-damage hit, got %d hits" % _hits)
	_check(not enemy.is_defeated() and enemy.health.current == enemy_health, label + "a head landing must not hurt the enemy")
	_check(_bounces == 0, label + "a head landing must not report a stomp bounce")
	_check(_player.is_on_floor() and _player.feet_world_y() < head_y - 0.5, label + "the player must be knocked onto the floor, not rest on the enemy")
	# Off-centre landings go to their own side; a centred drop goes back.
	var side := signf(offset) if offset != 0.0 else -1.0
	_check((_player.global_position.x - head_x) * side > 0.6, label + "the player must be knocked clear toward the expected side")
	_world.free()
	await _frames(1)


func _held_toward_enemy(packed: PackedScene) -> void:
	# Holding toward the enemy must not steer the player back onto its head:
	# one hit, a committed throw clear of it, and the player ends on the floor.
	var enemy := await _fixture(packed)
	var head_x := CONTACT.stomp_bounds(enemy).get_center().x
	Input.action_press("move_left")
	var head_y := await _drop_on_head(enemy, 0.15)
	var furthest := 0.0
	for frame in 100:
		await physics_frame
		furthest = maxf(furthest, _player.global_position.x - head_x)
	Input.action_release("move_left")
	_check(_hits == 1, "%s: holding toward the enemy must cost exactly one hit, got %d" % [enemy.name, _hits])
	_check(furthest > 1.2, "%s: the throw must carry the player clear before steering returns (%.2f m)" % [enemy.name, furthest])
	_check(_player.is_on_floor() and _player.feet_world_y() < head_y - 0.5, "%s: the player must end on the floor, not on the enemy" % enemy.name)
	_world.free()
	await _frames(1)


func _wall_behind(packed: PackedScene) -> void:
	# A wall on the landing side flips the throw so the player cannot drop
	# straight back onto the head.
	var enemy := await _fixture(packed)
	var head := CONTACT.stomp_bounds(enemy)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 6, 4)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(head.end.x + 0.6, 3, 0)
	_world.add_child(wall)
	await _frames(1)
	await _drop_on_head(enemy, 0.15)
	await _until_grounded()
	_check(_hits == 1, "%s: a wall behind must not lead to repeated hits, got %d" % [enemy.name, _hits])
	_check(_player.global_position.x < head.get_center().x - 0.6, "%s: a wall on the landing side must flip the throw" % enemy.name)
	_world.free()
	await _frames(1)


func _live_enemy() -> void:
	# A walking patrol must not carry the player along on its head or keep
	# hitting them while they clear it.
	var enemy := await _fixture(ENEMIES[0])
	enemy.set_physics_process(true)
	await _frames(5)
	var head_y := await _drop_on_head(enemy, 0.0)
	await _until_grounded()
	_check(_player.is_on_floor() and _player.feet_world_y() < head_y - 0.5, "A moving enemy must not carry the player")
	_check(_hits == 1, "Landing on a moving enemy must cost exactly one hit, got %d" % _hits)
	_world.free()
	await _frames(1)


func _fixture(packed: PackedScene) -> Node3D:
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 1, 4)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -0.5
	_world.add_child(floor_body)
	_player = PLAYER.instantiate()
	_world.add_child(_player)
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(-6, 0.55, 0)))
	_bounces = 0
	_player.stomp_bounced.connect(func(_position: Vector3) -> void: _bounces += 1)
	_hits = 0
	_player.damage_received.connect(func(_position: Vector3) -> void: _hits += 1)
	var enemy := packed.instantiate() as Node3D
	_world.add_child(enemy)
	enemy.global_position = Vector3(0, (enemy.body_collision.shape as BoxShape3D).size.y * 0.5, 0)
	# Frozen like the contact validator, so the head cannot walk or turn
	# under the drop. The live case is checked separately.
	enemy.set_physics_process(false)
	await _frames(3)
	return enemy


func _drop_on_head(enemy: Node3D, offset: float) -> float:
	var head_y: float = enemy.global_position.y + enemy.stomp_head_height
	var head_x := CONTACT.stomp_bounds(enemy).get_center().x
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(head_x + offset, head_y + 0.8, 0)))
	_player.velocity.y = -8.0
	for frame in 20:
		await physics_frame
		if _bounces > 0 or enemy.is_defeated() or _hits > 0:
			break
	return head_y


func _until_grounded() -> void:
	for frame in 90:
		await physics_frame
		if _player.is_on_floor() and _player.velocity.y <= 0.0:
			return


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
