extends SceneTree
## Drives the production controller through the full Level 2 route without
## granting movement abilities that the player has not unlocked.


const JUMP_MARKERS := [
	9.0, 13.1, 17.1, 21.0,
	29.6,
	38.0, 43.6, 47.6, 51.2,
	65.2, 71.1, 74.6, 78.1, 81.6,
	87.4, 94.1, 97.65,
	99.4, 102.4, 105.4,
	111.0, 117.1, 123.0,
]
const JUMP_HOLD_FRAMES := [
	10, 10, 10, 10,
	20,
	20, 10, 10, 10,
	12, 10, 10, 10, 10,
	20, 20, 24,
	10, 10, 12,
	24, 24, 24,
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.campaign = load("res://resources/regression/main_campaign.tres") as CampaignCatalog
	game_root.persist_progression = false
	root.add_child(game_root)
	game_root.load_level(&"gaps_and_spikes")
	await process_frame
	var level := game_root.current_level as LevelSession3D
	var player := level.player
	var completion_label := game_root.get_node("Interface/CompletionLabel") as Label
	for frame in 12:
		await physics_frame

	var next_jump := 0
	var jump_frames_remaining := 0
	var release_attack := false
	var recovering_ground_gap_stomp := false
	var recovering_precision_drop := false
	var recovering_second_spike_landing := false
	var recovering_hazard_step := false
	var ground_gap_enemy := level.get_node("Patrol03") as StompableEnemy3D
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

		if (
			not recovering_ground_gap_stomp
			and next_jump == 5
			and ground_gap_enemy.is_defeated()
			and not player.is_on_floor()
			and player.velocity.y > 0.0
			and player.global_position.x < 40.0
		):
			recovering_ground_gap_stomp = true
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif recovering_ground_gap_stomp and player.is_on_floor():
			recovering_ground_gap_stomp = false
			Input.action_release("move_left")
			Input.action_press("move_right")

		if (
			not recovering_precision_drop
			and next_jump == 14
			and not player.is_on_floor()
			and player.velocity.y < 0.0
			and player.global_position.x > 83.2
		):
			recovering_precision_drop = true
			Input.action_release("move_right")
		elif recovering_precision_drop and player.is_on_floor():
			recovering_precision_drop = false
			Input.action_press("move_right")

		if (
			not recovering_second_spike_landing
			and next_jump == 16
			and not player.is_on_floor()
			and player.velocity.y < 0.0
			and player.global_position.x > 97.25
		):
			recovering_second_spike_landing = true
			Input.action_release("move_right")
		elif recovering_second_spike_landing and player.is_on_floor():
			recovering_second_spike_landing = false
			Input.action_press("move_right")

		if (
			not recovering_hazard_step
			and next_jump >= 17
			and next_jump <= 19
			and not player.is_on_floor()
			and player.global_position.x > 98.8 + float(next_jump - 17) * 3.0
		):
			recovering_hazard_step = true
			Input.action_release("move_right")
		elif recovering_hazard_step and player.is_on_floor():
			recovering_hazard_step = false
			Input.action_press("move_right")

		var can_request_jump := player.is_on_floor() or (
			next_jump == 15 and player.velocity.y < 0.0
		)
		if (
			next_jump < JUMP_MARKERS.size()
			and can_request_jump
			and player.global_position.x >= JUMP_MARKERS[next_jump]
		):
			Input.action_press("jump")
			jump_frames_remaining = JUMP_HOLD_FRAMES[next_jump]
			next_jump += 1
		if jump_frames_remaining > 0:
			jump_frames_remaining -= 1
			if jump_frames_remaining == 0:
				Input.action_release("jump")

		if completion_label.visible:
			break
		await physics_frame

	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("attack")

	if player.is_dead():
		push_error(
			"The scripted Level 2 route died near x=%.2f after jump %d."
			% [player.global_position.x, next_jump]
		)
		quit(1)
		return
	if not completion_label.visible:
		push_error(
			"The scripted Level 2 route stopped near x=%.2f after jump %d."
			% [player.global_position.x, next_jump]
		)
		quit(1)
		return
	assert(next_jump == JUMP_MARKERS.size(), "The playthrough should exercise every authored crossing.")
	print("Level 2 scripted playthrough validation passed.")
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
