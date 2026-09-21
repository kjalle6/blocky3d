extends SceneTree
## Real physics regressions for approach, contact, committed swings and recovery.
const PLAYER := preload("res://scenes/player/pixel_player_character.tscn")
const ENEMIES := [
	preload("res://scenes/enemies/pixel_patrol_enemy.tscn"),
	preload("res://scenes/enemies/pixel_skater_enemy.tscn"),
]
var _world: Node3D
var _player: PlayerCharacter
var _errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Engagement test timed out."); quit(1))
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
	for packed in ENEMIES:
		for facing in [-1.0, 1.0]:
			await _check_encounter(packed, facing)
	Input.action_release("move_left")
	Input.action_release("move_right")
	_world.free()
	for message in _errors:
		push_error(message)
	print("Ground enemy engagement checks: %s" % ("passed" if _errors.is_empty() else "%d failed" % _errors.size()))
	quit(0 if _errors.is_empty() else 1)


func _check_encounter(packed: PackedScene, facing: float) -> void:
	var enemy := packed.instantiate() as StompableEnemy3D
	enemy.position = Vector3(0, 0.38, 0)
	enemy.starts_moving_right = facing > 0.0
	_world.add_child(enemy)
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(1.6 * facing, 0.55, 0)))
	_player.set_physics_process(false)
	var label := "%s facing %s: " % [enemy.name, facing]
	for frame in 90:
		await _frame()
		if enemy.is_attacking():
			break
	_check(enemy.is_attacking(), label + "must approach and begin an attack")
	var start_distance := absf(_player.position.x - enemy.position.x)
	var reachable := enemy.attack_damage_distance + enemy.attack_move_speed * enemy.attack_impact_time
	_check(start_distance <= reachable + 0.01, label + "must not swing before it can reach a stationary player")
	if enemy.attack_move_speed > 0.0:
		_check(start_distance > enemy.attack_damage_distance, label + "rolling attack must still close distance")
	for frame in 60:
		await _frame()
		if not enemy.is_attacking():
			break
	_check(_player.health.current == 75, label + "one complete attack must hit a stationary player exactly once")
	# Retreat after impact: recovery must remain an opening, not a pursuit.
	_player.position.x = enemy.position.x + 4.0 * facing
	var recovery_x := enemy.position.x
	var recovery_direction := enemy.facing_sign()
	for frame in 24:
		await _frame()
	_check(absf(enemy.position.x - recovery_x) < 0.02, label + "must stay still during recovery")
	_check(enemy.facing_sign() == recovery_direction, label + "must not turn during recovery")
	for frame in 30:
		await _frame()
	_check((enemy.position.x - recovery_x) * facing > 0.15, label + "must resume approaching once recovery ends")

	# Move behind a winding-up enemy: the active attack cannot turn to hit us.
	enemy.reset_run()
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(1.1 * facing, 0.55, 0)))
	_player.set_physics_process(false)
	for frame in 8:
		await _frame()
	_check(enemy.is_attacking(), label + "close player must receive a windup")
	var committed_direction := enemy.facing_sign()
	_player.position.x = enemy.position.x - 1.1 * facing
	for frame in 40:
		await _frame()
	_check(enemy.facing_sign() == committed_direction, label + "swing and recovery must keep their committed facing")
	_check(_player.health.current == 100, label + "crossing behind a committed swing must avoid its damage")

	# A player holding into the enemy must not make it jitter or reverse.
	enemy.reset_run()
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(1.05 * facing, 0.55, 0)))
	var action := "move_left" if facing > 0.0 else "move_right"
	Input.action_press(action)
	var wrong_turn := false
	for frame in 110:
		await _frame()
		wrong_turn = wrong_turn or enemy.facing_sign() != facing
	Input.action_release(action)
	_check(not wrong_turn, label + "solid player contact must not reverse the enemy")
	_check(_player.health.current == 50, label + "two telegraphed attacks must have distinct damage beats")
	_check(absf(_player.position.x - enemy.position.x) >= 0.70, label + "solid contact must not pass through either body")
	_player.set_physics_process(false)

	# A nonlethal interruption cancels the pending hit and its forward motion.
	enemy.reset_run()
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(1.1 * facing, 0.55, 0)))
	_player.set_physics_process(false)
	for frame in 7:
		await _frame()
	enemy.receive_melee_hit(_player.position)
	var interrupted_x := enemy.position.x
	for frame in 24:
		await _frame()
	_check(_player.health.current == 100, label + "interrupted windup must not land a delayed hit")
	_check(absf(enemy.position.x - interrupted_x) < 0.02, label + "hurt recovery must not walk into the player")
	enemy.free()
	await _frame()


func _frame() -> void:
	await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
