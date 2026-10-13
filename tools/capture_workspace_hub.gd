extends SceneTree
## Refreshes the Mr. Mak Workspace hub's game captures: each campaign level's
## opening, a spread of its checkpoints, one view per enemy type, and the boss
## pit. Run through the runner with -Visual. Output: build/previews/workspace_hub
## plus an index.json recording what each frame shows.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews/workspace_hub"
const CHECKPOINT_SAMPLES := 4
const LEVEL_3 := preload("res://resources/dev/green_zone_finale_wip.tres")
const BOSS_ARENA := preload("res://resources/dev/boss_arena_wip.tres")
const ENEMY_CONTACT := preload("res://scripts/combat/enemy_combat_contact.gd")

var _game_root: Node
var _index: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	_game_root = (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	_game_root.persist_progression = false
	root.add_child(_game_root)
	await process_frame

	_game_root.load_level(&"arrival_shoreline")
	# Let the opening ability banner clear before the first frame.
	await _settle(240)
	await _survey("level_1")
	await _head_landing()
	await _inventory()
	_game_root.load_level(&"overgrown_coastal_ascent")
	await _survey("level_2")
	await _enter_cave()
	await _survey("level_2_cave")
	_game_root.load_developer_level(LEVEL_3)
	await _survey("level_3")
	_game_root.load_developer_level(LEVEL_3, &"gun_encounter")
	await _survey("level_3_gun_area")
	_game_root.load_developer_level(LEVEL_3, &"boss_encounter")
	await _settle(10)
	await _capture("level_3_boss_lip", "Level 3 · boss pit lip before the reveal")
	_game_root.load_developer_level(BOSS_ARENA)
	await _settle(10)
	await _capture("boss_arena_start", "Boss Arena WIP · floor spawn")
	await _settle(150)
	await _capture("boss_arena_fight", "Boss Arena WIP · about 2.5 s into the fight")

	var file := FileAccess.open(OUTPUT_DIRECTORY + "/index.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_index, "  "))
	file.close()
	print("Workspace hub captures: %d frames in %s" % [_index.size(), OUTPUT_DIRECTORY])
	quit(0)


func _survey(prefix: String) -> void:
	await _settle(10)
	var level := _level()
	await _capture(prefix + "_00_start", "%s · opening" % prefix)

	var checkpoints: Array[Node] = level.find_children("*", "LevelCheckpoint3D", true, false)
	checkpoints.sort_custom(func(a: Node, b: Node) -> bool: return a.global_position.x < b.global_position.x)
	var picks: Array[Node] = []
	for sample in mini(CHECKPOINT_SAMPLES, checkpoints.size()):
		var index := roundi(float(sample + 1) * (checkpoints.size() - 1) / CHECKPOINT_SAMPLES) if checkpoints.size() > CHECKPOINT_SAMPLES else sample
		if not checkpoints[index] in picks:
			picks.append(checkpoints[index])
	for number in picks.size():
		var checkpoint := picks[number] as LevelCheckpoint3D
		level.player.reset_at(checkpoint.respawn_transform())
		await _settle(10)
		await _capture("%s_%02d_checkpoint" % [prefix, number + 1],
			"%s · checkpoint %s at x %.1f" % [prefix, checkpoint.name, checkpoint.global_position.x])

	# One view per enemy or hazard scene, approached from its left.
	var seen := {}
	var actors: Array[Node] = level.find_children("*", "Node3D", true, false)
	actors = actors.filter(func(node: Node) -> bool:
		return not node is PlayerCharacter and (node.has_method("is_defeated") or node is HoveringHazard3D))
	actors.sort_custom(func(a: Node, b: Node) -> bool: return a.global_position.x < b.global_position.x)
	for actor in actors:
		var kind := actor.scene_file_path.get_file().get_basename()
		if kind.is_empty() or seen.has(kind):
			continue
		seen[kind] = true
		var at := (actor as Node3D).global_position
		level.player.reset_at(Transform3D(Basis.IDENTITY, at + Vector3(-3.2, 0.6, 0)))
		await _settle(6)
		await _capture("%s_enemy_%s" % [prefix, kind], "%s · %s (%s)" % [prefix, kind, actor.name])


func _head_landing() -> void:
	# The no-stomp rule: a real fall onto a frozen patrol's head, caught on the hit.
	var level := _level()
	var patrol := level.find_child("ApproachPatrol", true, false) as StompableEnemy3D
	if patrol == null:
		return
	patrol.set_physics_process(false)
	var head := ENEMY_CONTACT.stomp_bounds(patrol)
	level.player.reset_at(Transform3D(Basis.IDENTITY,
		Vector3(head.get_center().x + 0.1, head.end.y + PlayerCharacter.FEET_OFFSET_Y + 0.6, 0)))
	level.player.velocity.y = -8.0
	for frame in 30:
		await physics_frame
		if level.player.health.current < 100:
			break
	await _settle(2)
	await _capture("level_1_head_landing", "level_1 · landing on a patrol's head: hit flash and knock away")
	patrol.set_physics_process(true)


func _inventory() -> void:
	await _toggle_action(&"inventory")
	await _settle(20)
	await _capture("inventory_screen", "Inventory and quick slots, opened with Tab")
	await _toggle_action(&"inventory")
	await _settle(10)


func _toggle_action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _enter_cave() -> void:
	# Walk the player into Level 2's cave transition and wait out the slide.
	var level := _level()
	var transitions: Array[Node] = level.find_children("*", "LevelTransition3D", true, false)
	assert(not transitions.is_empty(), "Level 2 needs its cave transition.")
	level.player.reset_at(Transform3D(Basis.IDENTITY, (transitions[0] as Node3D).global_position))
	for frame in 900:
		await physics_frame
		if _level() != level and _level() != null:
			break
	await _settle(480)


func _level() -> LevelSession3D:
	return _game_root.current_level as LevelSession3D


func _settle(frames: int) -> void:
	for frame in frames:
		await physics_frame


func _capture(file_name: String, description: String) -> void:
	var level := _level()
	if level != null and level.camera != null:
		level.camera.snap_to_target()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Workspace hub captures require a graphical renderer.")
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIRECTORY, file_name])
	assert(error == OK, "Could not save hub capture '%s'." % file_name)
	_index.append({"file": file_name + ".png", "shows": description})
