extends SceneTree
## Drives the production controller through every Level 3 teaching beat,
## including the pickup and each required Double Jump.

const CROSSINGS := [
	{"start_x": 8.4, "second_x": 11.4, "first_hold": 18, "second_hold": 18},
	{"start_x": 16.2, "second_x": -1.0, "first_hold": 10, "second_hold": 0},
	{"start_x": 23.4, "second_x": 28.5, "first_hold": 22, "second_hold": 20},
	{"start_x": 35.6, "second_x": -1.0, "first_hold": 18, "second_hold": 0},
	{"start_x": 42.2, "second_x": -1.0, "first_hold": 10, "second_hold": 0},
	{"start_x": 48.0, "second_x": 51.9, "first_hold": 18, "second_hold": 18},
	{"start_x": 57.4, "second_x": -1.0, "first_hold": 10, "second_hold": 0},
	{"start_x": 64.2, "second_x": 69.5, "first_hold": 22, "second_hold": 22},
	{"start_x": 75.1, "second_x": -1.0, "first_hold": 10, "second_hold": 0},
	{"start_x": 85.0, "second_x": 90.0, "first_hold": 22, "second_hold": 22},
	{"start_x": 96.4, "second_x": -1.0, "first_hold": 10, "second_hold": 0},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"double_jump")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 12:
		await physics_frame

	var crossing_index := 0
	var stage := 0
	var hold_frames := 0
	var saw_airborne := false
	var release_attack := false
	Input.action_press("move_right")
	for frame in 2400:
		if player.is_dead():
			break

		if release_attack:
			Input.action_release("attack")
			release_attack = false
		elif _enemy_is_in_melee_range(level, player):
			Input.action_press("attack")
			release_attack = true

		if crossing_index < CROSSINGS.size():
			var crossing: Dictionary = CROSSINGS[crossing_index]
			if stage == 0 and player.is_on_floor() and player.global_position.x >= crossing.start_x:
				Input.action_press("jump")
				hold_frames = crossing.first_hold
				stage = 1
				saw_airborne = false
			elif stage == 1:
				saw_airborne = saw_airborne or not player.is_on_floor()
				hold_frames -= 1
				if hold_frames <= 0:
					Input.action_release("jump")
					stage = 2
			elif stage == 2:
				if crossing.second_x >= 0.0:
					if (
						not player.is_on_floor()
						and player.global_position.x >= crossing.second_x
					):
						Input.action_press("jump")
						hold_frames = crossing.second_hold
						stage = 3
				elif saw_airborne and player.is_on_floor():
					crossing_index += 1
					stage = 0
			elif stage == 3:
				hold_frames -= 1
				if hold_frames <= 0:
					Input.action_release("jump")
					stage = 4
			elif stage == 4 and player.is_on_floor():
				crossing_index += 1
				stage = 0

		if completion_label.visible:
			break
		await physics_frame

	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("attack")

	if player.is_dead():
		push_error(
			"The scripted Level 3 route died near x=%.2f during crossing %d stage %d."
			% [player.global_position.x, crossing_index, stage]
		)
		quit(1)
		return
	if not completion_label.visible:
		push_error(
			"The scripted Level 3 route stopped near x=%.2f during crossing %d stage %d."
			% [player.global_position.x, crossing_index, stage]
		)
		quit(1)
		return
	assert(crossing_index == CROSSINGS.size(), "The playthrough should exercise every authored crossing.")
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	print("Level 3 scripted playthrough validation passed.")
	quit(0)


func _enemy_is_in_melee_range(level: LevelSession3D, player: PlayerCharacter) -> bool:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		var enemy := node as StompableEnemy3D
		if enemy.is_defeated():
			continue
		var offset := enemy.global_position - player.global_position
		if offset.x >= 0.0 and offset.x <= 1.1 and absf(offset.y) <= 0.9:
			return true
	return false
