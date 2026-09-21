extends SceneTree
## Contact regressions: visible target edges, late thrust contact, moving poses,
## and real falling-body head crossings. No campaign or tuning saves are used.

const PLAYER := preload("res://scenes/player/pixel_player_character.tscn")
const ENEMIES := [
	preload("res://scenes/enemies/pixel_patrol_enemy.tscn"),
	preload("res://scenes/enemies/pixel_skater_enemy.tscn"),
	preload("res://scenes/enemies/handgun_enemy.tscn"),
]
var _world: Node3D
var _player: PlayerCharacter
var _errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_player = PLAYER.instantiate()
	_world.add_child(_player)
	_player.set_physics_process(false)
	await physics_frame
	await process_frame
	for scene in ENEMIES:
		for facing in [-1.0, 1.0]:
			var enemy := _enemy(scene)
			enemy.pixel_visual.tick(0.0, "idle", facing < 0.0)
			_reset_player(facing)
			_place_enemy(enemy, 1.5 * facing)
			_start_attack()
			_player.call("_update_attack", 0.14)
			_check(enemy.is_defeated(), "%s: knife must hit the near body edge, facing %s" % [enemy.name, facing])
			enemy.free()
			await process_frame

		var enemy := _enemy(scene)
		_reset_player(1.0)
		_place_enemy(enemy, 3.0)
		_start_attack()
		_player.call("_update_attack", 0.14)
		_check(not enemy.is_defeated(), "A distant target must survive the impact tick")
		_place_enemy(enemy, 1.0)
		_player.call("_update_attack", 0.11)
		_check(enemy.is_defeated(), "%s: contact during the extended thrust must count" % enemy.name)
		enemy.free()
		await process_frame

		for position_x in [-1.0, 2.0]:
			enemy = _enemy(scene)
			_reset_player(1.0)
			_place_enemy(enemy, position_x)
			_start_attack()
			_player.call("_update_attack", 0.14)
			_check(not enemy.is_defeated(), "Knife must miss behind the player and beyond its reach")
			enemy.free()
			await process_frame

		enemy = _enemy(scene)
		_reset_player(1.0)
		_place_enemy(enemy, 1.0)
		_start_attack()
		_player.call("_update_attack", 0.10)
		_check(not enemy.is_defeated(), "Knife windup must not deal damage")
		_player.call("_update_attack", 0.04)
		_check(enemy.is_defeated(), "The impact window must follow the windup")
		enemy.free()
		await process_frame

		enemy = _enemy(scene)
		_reset_player(1.0)
		_place_enemy(enemy, 3.0)
		_start_attack()
		_player.call("_update_attack", 0.27)
		_place_enemy(enemy, 1.0)
		_player.call("_update_attack", 0.02)
		_check(not enemy.is_defeated(), "Recovery frames must not deal fresh knife damage")
		enemy.free()
		await process_frame

	# Starting/stopping movement must not rewind the same visible thrust.
	var visual := _player.pixel_visual
	visual.set_weapon_presentation(PlayerWeapon.KNIFE, PlayerWeapon.KNIFE, false)
	visual.set_state("attack", true)
	visual.tick(0.17, true, 0.0, 0.0, true, false, true)
	var previous_frame: int = visual.weapon.frame
	visual.tick(0.01, true, 8.0, 0.0, true, false, true)
	_check(visual.weapon.frame >= previous_frame, "Starting to run must not rewind the thrust")
	visual.tick(0.01, true, 0.0, 0.0, true, false, true)
	_check(visual.weapon.frame >= previous_frame, "Stopping must not rewind the thrust")

	# A maximum-speed fall must connect at the visible head, before sinking
	# through the sprite toward the much shorter navigation body.
	for scene in ENEMIES:
		for horizontal_offset in [-1.2, -0.6, 0.0, 0.6, 1.2]:
			var enemy := _enemy(scene)
			_place_enemy(enemy, 0.0)
			var head_y: float = enemy.global_position.y + enemy.stomp_head_height
			_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(horizontal_offset, head_y + 1.0, 0)))
			_player.velocity.y = -28.0
			await physics_frame
			await physics_frame
			await physics_frame
			_check(enemy.is_defeated() == (absf(horizontal_offset) < 0.7), "%s: descending head contact at X %.2f" % [enemy.name, horizontal_offset])
			if enemy.is_defeated():
				_check(_player.velocity.y > 0.0, "A stomp must bounce immediately")
			_player.set_physics_process(false)
			enemy.free()
			await process_frame

		# Ascending through the head and descending beside the torso are not
		# stomps, even when the old contact area is already overlapping.
		for rising in [true, false]:
			var enemy := _enemy(scene)
			_place_enemy(enemy, 0.0)
			var head_y: float = enemy.global_position.y + enemy.stomp_head_height
			_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.6, head_y + 0.25, 0)))
			_player.velocity.y = 8.0 if rising else -2.0
			await physics_frame
			await physics_frame
			await physics_frame
			_check(not enemy.is_defeated(), "Rising and side contact must not become stomps")
			_player.set_physics_process(false)
			enemy.free()
			await process_frame

		# An edge can miss the offset visual head yet land on the solid body.
		# Actual top contact must stomp instead of carrying the player as a floor.
		for facing in [-1.0, 1.0]:
			for horizontal_offset in [-0.69, 0.0, 0.69]:
				var enemy := _enemy(scene)
				enemy.pixel_visual.tick(0.0, "idle", facing > 0.0)
				var head_y: float = enemy.global_position.y + enemy.stomp_head_height
				var start_y := head_y + 1.0
				if is_zero_approx(horizontal_offset):
					# A short hop can descend below the head before reaching the body.
					start_y = (enemy.body_collision.shape as BoxShape3D).size.y * 0.5 + 0.65
				_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(horizontal_offset, start_y, 0)))
				_player.velocity.y = -6.0
				for frame in 30:
					await physics_frame
					await process_frame
					if enemy.is_defeated() or _player.is_on_floor():
						break
				_check(enemy.is_defeated(), "%s: solid top landing must stomp at body offset %.2f, facing %s" % [enemy.name, horizontal_offset, facing])
				if enemy.is_defeated():
					_check(_player.velocity.y > 0.0, "Solid top contact must bounce immediately")
				_player.set_physics_process(false)
				enemy.free()
				await process_frame

	# A real horizontal collision still blocks without becoming a stomp.
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20, 1, 2)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5
	_world.add_child(floor_body)
	for scene in ENEMIES:
		var enemy := _enemy(scene)
		enemy.position.y = (enemy.body_collision.shape as BoxShape3D).size.y * 0.5
		_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(-1.2, 0.55, 0)))
		Input.action_press("move_right")
		for frame in 20:
			await physics_frame
			await process_frame
		Input.action_release("move_right")
		_check(_player.is_on_wall(), "Side-contact fixture must reach the enemy's solid body")
		_check(not enemy.is_defeated() and not _player.is_dead(), "Passive side contact must stay solid and nonlethal")
		_player.set_physics_process(false)
		enemy.free()
		await process_frame
	_world.free()
	for message in _errors:
		push_error(message)
	print("Ground combat contact checks: %s" % ("passed" if _errors.is_empty() else "%d failed" % _errors.size()))
	quit(0 if _errors.is_empty() else 1)


func _enemy(scene: PackedScene) -> Node3D:
	var enemy := scene.instantiate() as Node3D
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	# Contact geometry fixture; default two-hit health is covered separately.
	enemy.health.reset(25)
	if enemy is StompableEnemy3D:
		enemy.pixel_visual.tick(0.0, "idle", true)
	else:
		enemy.pixel_visual.tick(0.0, &"idle", false)
	return enemy


func _place_enemy(enemy: Node3D, body_x: float) -> void:
	# Measured native torso centres, including the skater's 11px registration.
	var offset := -0.4 if enemy is HandgunEnemy3D else -0.427083
	if enemy is StompableEnemy3D and not enemy.pixel_visual.animation_textures.is_empty():
		offset = 0.0427083
	if enemy.pixel_visual.flip_h:
		offset *= -1.0
	enemy.position.x = body_x - offset


func _reset_player(facing: float) -> void:
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)))
	_player.set_physics_process(false)
	_player.set("_facing_sign", facing)


func _start_attack() -> void:
	Input.action_press("attack")
	_player.call("_update_attack", 0.0)
	Input.action_release("attack")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
