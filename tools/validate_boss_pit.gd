extends SceneTree
## Level 3's boss pit hookup: the gun encounter's plateau runs on into the pit,
## the entry cutscene walks the player off the lip and down the wall while the
## boss readies its missiles, a death sends the run back to the plateau
## checkpoint and walking back in skips the cutscene, and the boss's warhead
## blows the exit open.
## Playtesting owns the feel; these are the contracts.

const PIT_PATH := "res://scenes/dev/green_zone_finale_boss_pit.tscn"
const SHOOTER_PATH := "res://scenes/dev/green_zone_finale_shooter_area_wip.tscn"
const ENCOUNTER := preload("res://scripts/level/green_zone_boss_encounter_3d.gd")
const FIXTURE := preload("res://tools/level_3_shooter_area_fixture.gd")

var _game: Node
var _pit: LevelSession3D
var _player: PlayerCharacter
var _boss: CharacterBody3D
var _encounter: Node
var _sounds: Array[String] = []


func _init() -> void:
	call_deferred("_run")
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("Boss pit validation timed out.")
		quit(1))


func _run() -> void:
	_game = load("res://scenes/app/game_root.tscn").instantiate()
	_game.persist_progression = false
	root.add_child(_game)
	await process_frame
	await _enter_from_gun_encounter()
	await _validate_entry_beat()
	_validate_save_section()
	await _validate_death_returns_to_plateau()
	await _validate_warhead_exit()
	print("Boss pit validation passed: plateau handoff, entry beat, save block, return to the plateau checkpoint, replay and skip, kill autosave and restore, warhead and blast door exit.")
	quit(0)


func _enter_from_gun_encounter() -> void:
	var shooter: LevelSession3D = FIXTURE.load_into(_game)
	await _frames(8)
	var transition := shooter.get_node("BossPitTransition") as LevelTransition3D
	assert(transition.validation_errors().is_empty())
	assert(transition.target_scene != null and transition.target_scene.resource_path == PIT_PATH)
	assert(not transition.completes_source_level, "The pit is still Level 3.")
	# The threshold starts at the plateau's end and stands taller than any jump
	# off it, so leaving the plateau to the right always takes it.
	var plateau := shooter.route_extent.route_end_x
	var query := PhysicsRayQueryParameters3D.create(Vector3(plateau - 1.0, 60.0, 0), Vector3(plateau - 1.0, 0, 0), 1)
	var top: float = shooter.get_world_3d().direct_space_state.intersect_ray(query).position.y
	var shape := (transition.get_node("Collision") as CollisionShape3D).shape as BoxShape3D
	var reach := shooter.player.movement.ideal_jump_height() * 2.0 + PlayerCharacter.FEET_OFFSET_Y * 2.0
	assert(transition.global_position.x - shape.size.x * 0.5 <= plateau + 0.01)
	assert(transition.global_position.y + shape.size.y * 0.5 > top + reach, "No jump clears the threshold.")
	assert(transition.global_position.y - shape.size.y * 0.5 < top - 8.0)
	var checkpoint := shooter.get_node("Checkpoints/PlateauCheckpoint") as LevelCheckpoint3D
	assert(absf(checkpoint.global_position.y - top) < 0.01, "A checkpoint stands on the plateau.")
	var chest := shooter.find_children("*", "ItemReward3D", true, false).filter(
		func(reward: Node) -> bool: return reward.get_meta("layout_id", "") == "object_upper_route_reward")
	if not chest.is_empty():
		assert(checkpoint.global_position.x > chest[0].global_position.x, "It is past the last chest.")
	await _walk_off_plateau(shooter)
	assert(_pit.save_state.last_checkpoint.get("section") == "green_zone_shooter_area",
		"Walking in carries the plateau checkpoint into the pit.")


## Walks off the end of the plateau for real, through the threshold, and binds
## the pit that appears.
func _walk_off_plateau(shooter: LevelSession3D) -> void:
	var plateau := shooter.route_extent.route_end_x
	var query := PhysicsRayQueryParameters3D.create(Vector3(plateau - 1.0, 60.0, 0), Vector3(plateau - 1.0, 0, 0), 1)
	var top: float = shooter.get_world_3d().direct_space_state.intersect_ray(query).position.y
	# Nothing may stand between the plateau and the threshold.
	shooter.player.global_position = Vector3(plateau - 3.0, top + PlayerCharacter.FEET_OFFSET_Y + 0.02, 0)
	shooter.player.velocity = Vector3.ZERO
	shooter.camera.snap_to_target()
	Input.action_press(&"move_right")
	for frame in 240:
		await physics_frame
		if not shooter.player.is_physics_processing():
			break
	Input.action_release(&"move_right")
	assert(not shooter.player.is_physics_processing(), "Walking off the plateau's end takes the threshold.")
	for frame in 120:
		await process_frame
		if _game.current_level != shooter:
			break
	_pit = _game.current_level as LevelSession3D
	assert(_pit != null and _pit.scene_file_path == PIT_PATH, "The plateau leads into the boss pit.")
	assert(_game.current_level_definition.level_id == &"dev_green_zone_finale_wip")
	_player = _pit.player
	_boss = _pit.get_node("GreenZoneBoss")
	_encounter = _pit.get_node("BossEncounter")
	# The saved mix's encounter cues fire on the real beats.
	_pit.combat_feedback.combat_audio.event_played.connect(func(event: Dictionary) -> void:
		if str(event.id).begins_with("boss/"): _sounds.append(event.id))
	for frame in 120:
		await process_frame
		if not _game.completion_fade.visible:
			break
	assert(not _game.completion_fade.visible)


func _validate_entry_beat() -> void:
	var exit_door := _pit.get_node("Props/ExitDoor")
	var attacks: Array[StringName] = []
	_boss.attack_started.connect(func(attack: StringName): attacks.append(attack))
	assert(_encounter.in_cutscene(), "The cutscene takes over as soon as the pit appears.")
	assert(not _player.is_physics_processing(), "The player is held from the start.")
	assert(not _boss.enabled, "The boss holds until the beat ends.")
	assert(not _encounter.health_bar_visible())
	assert(exit_door.is_sealed(), "The only door is the sealed exit.")
	assert(_pit.get_node_or_null("Props/EntryDoor") == null, "The pit opens straight off the plateau.")
	assert(_encounter.entry_lip_y > 30.0, "The lip is high above the pit floor.")
	assert(absf(_player.feet_world_y() - _encounter.entry_lip_y) < 0.05, "The player stands on the lip.")
	assert(_boss.visual.flip_h == false, "The boss starts the beat looking away.")
	# Input during the cutscene changes nothing.
	Input.action_press(&"move_left")
	Input.action_press(&"jump")
	var start_camera_y: float = _pit.camera.global_position.y
	await _until(func(): return _encounter.phase == ENCOUNTER.Phase.LOOK, 180,
		"The cutscene must walk the player to the lip.")
	assert(absf(_player.global_position.x - (_encounter.entry_wall_x - 0.2)) < 0.02, "Toes at the edge.")
	assert(absf(_player.feet_world_y() - _encounter.entry_lip_y) < 0.05)
	# From the look-down until the swing reaches the boss the camera never
	# stops: no hold between the dip, the hop off the lip and the swing.
	var previous: Vector3 = _pit.camera.global_position
	var still_frames := 0
	var longest_still := 0
	var looked_down := false
	var slide_start := 0.0
	for frame in 300:
		await _frames(1)
		var position: Vector3 = _pit.camera.global_position
		var moved := position.distance_to(previous) > 0.005
		previous = position
		# The dip eases in from rest; count stillness once it is under way.
		if position.y < start_camera_y - 1.0:
			still_frames = 0 if moved else still_frames + 1
			longest_still = maxi(longest_still, still_frames)
		if _encounter.phase != ENCOUNTER.Phase.LOOK and not looked_down:
			looked_down = true
			assert(position.y < start_camera_y - 3.0, "The camera looks down into the pit.")
		if _encounter.phase == ENCOUNTER.Phase.SLIDE and slide_start == 0.0:
			Input.action_release(&"move_left")
			Input.action_release(&"jump")
			assert(absf(_player.global_position.x - 0.38) < 0.05, "The player slides against the pit wall.")
			slide_start = _player.feet_world_y()
		if _encounter.get("_swing") >= _encounter.pan_time:
			break
	assert(slide_start > 0.0, "The player must drop onto the wall.")
	assert(longest_still < 4, "The camera held still for %d frames on its way to the boss." % longest_still)
	var furthest_right := 0.0
	var lowest_camera := start_camera_y
	var boss_turned := false
	var revealed := false
	var last_camera_y: float = _pit.camera.global_position.y
	while _encounter.phase == ENCOUNTER.Phase.SLIDE:
		assert(not _player.is_physics_processing(), "The player stays held through the slide.")
		var camera_y: float = _pit.camera.global_position.y
		if not revealed:
			# From the look-down to the boss the camera only ever travels down.
			assert(camera_y <= last_camera_y + 0.05, "The camera rose on its way to the boss: %.2f > %.2f." % [camera_y, last_camera_y])
		last_camera_y = camera_y
		furthest_right = maxf(furthest_right, _pit.camera.global_position.x)
		lowest_camera = minf(lowest_camera, _pit.camera.global_position.y)
		boss_turned = boss_turned or _boss.visual.flip_h
		if _encounter.reveal_active() and not revealed:
			revealed = true
			await _validate_reveal()
		await _frames(1)
	assert(revealed, "The slide freezes for the boss reveal.")
	assert(_sounds.count("boss/reveal") == 1, "The reveal plays its stinger once.")
	assert(furthest_right > _boss.global_position.x - 6.0, "Mid-slide the camera swings right to the boss.")
	assert(lowest_camera < 8.0, "...and down to it.")
	assert(boss_turned and _encounter.health_bar_visible(), "The boss turns to aim; its bar fills.")
	assert(_encounter.phase == ENCOUNTER.Phase.FIGHT)
	assert(_player.is_physics_processing() and _player.velocity.y < 0.0, "Control returns while sliding.")
	var feet := _player.feet_world_y()
	assert(feet > 2.0 and feet < 8.0, "Control returns approaching the bottom: %.2f m." % feet)
	assert(slide_start - feet > 25.0)
	assert(_pit.camera.global_position.x < 16.0, "The camera is back on the player.")
	assert(_pit.camera.get("encounter_target") == _boss, "With control back, the camera holds the boss too.")
	assert(_pit.save_state.safety_error(true) == ENCOUNTER.SAVE_BLOCKED, "No manual saves during the fight.")
	# The boss fires the salvo it was shown readying.
	await _until(func(): return not attacks.is_empty(), 60, "The boss must open with an attack.")
	assert(attacks[0] == &"missiles", "The opening attack is the readied salvo.")
	assert(_boss.enabled)


## The reveal freezes the game on the raised pod, names the boss, holds off a
## press for a moment, then lets go on one; the boss bar fills only after.
func _validate_reveal() -> void:
	assert(paused, "The reveal pauses the game.")
	assert(_boss.visual.flip_h, "It freezes on the boss facing the player.")
	assert(not _encounter.health_bar_visible(), "The bar waits for the reveal to finish.")
	var reveal = _encounter.get("_reveal")
	assert(reveal.get("_title") == _boss.display_name, "The reveal names the boss.")
	var held := _player.global_position
	await _wait_real(0.3)
	assert(_encounter.reveal_active() and paused, "An early press cannot end it yet.")
	_press_key()
	await _wait_real(0.3)
	assert(_encounter.reveal_active(), "Presses inside the minimum hold are ignored.")
	# Past the slam-in and the minimum hold, before the hold runs out.
	await _wait_real(1.2)
	assert(_player.global_position == held, "Nothing moves while frozen.")
	_press_key()
	for frame in 60:
		await process_frame
		if not _encounter.reveal_active() and not paused:
			break
	assert(not _encounter.reveal_active() and not paused, "A press after the hold ends the reveal.")
	assert(_boss.visual.visible, "The boss is back in the world.")
	await _frames(2)
	assert(_encounter.health_bar_visible(), "The boss bar fills as the reveal lets go.")


func _press_key() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		Input.parse_input_event(key)


## Wall-clock waiting that keeps going while the tree is paused.
func _wait_real(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _validate_save_section() -> void:
	# The pit is a registered Level 3 section, so its autosave is a valid save.
	var data: Dictionary = _pit.save_state.capture(Vector3(2.56, 0.6, 0), "entry")
	data.version = SaveSnapshot.VERSION
	data.kind = "auto"
	data.slot = 1
	data.saved_at = 1.0
	assert(data.section == "green_zone_boss_pit")
	var error := SaveSnapshot.validation_error(data)
	assert(error.is_empty(), "A pit autosave must validate: " + error)


## A death in the pit restarts from the plateau checkpoint before it, as the
## run stood there. Walking back in plays the cutscene again, and a fresh
## press skips it to its end.
func _validate_death_returns_to_plateau() -> void:
	assert(not _pit.autosave_on_entry and not _pit.save_state._entry_pending, "The pit never autosaves.")
	var checkpoint: Dictionary = _pit.save_state.last_checkpoint
	var pit := _pit
	_player.kill()
	for frame in 300:
		await process_frame
		if _game.current_level != pit:
			break
	var shooter := _game.current_level as LevelSession3D
	assert(shooter != null and shooter.scene_file_path == SHOOTER_PATH, "A death in the pit goes back to the gun encounter.")
	for frame in 120:
		await process_frame
		if not _game.completion_fade.visible:
			break
	var saved: Array = checkpoint.position
	assert(shooter.player.global_position.distance_to(Vector3(saved[0], saved[1], 0)) < 0.2,
		"The player restarts on the plateau checkpoint.")
	assert(not shooter.player.is_dead())
	assert(shooter.player.health.current == int(checkpoint.player.health.current),
		"Health is what it was at the checkpoint: no healing.")
	assert(shooter.get_node("Checkpoints/PlateauCheckpoint").is_activated(), "The checkpoint stays earned.")
	await _walk_off_plateau(shooter)
	await _frames(2)
	assert(_encounter.in_cutscene(), "Walking back in plays the cutscene again.")
	assert(_pit.save_state.last_checkpoint.get("section") == "green_zone_shooter_area", "Later deaths return there too.")
	var skip := InputEventAction.new()
	skip.action = &"jump"
	skip.pressed = true
	Input.parse_input_event(skip)
	await _frames(1)
	assert(_encounter.phase == ENCOUNTER.Phase.FIGHT, "A press skips the cutscene.")
	assert(absf(_player.feet_world_y() - _encounter.release_feet_y) < 0.6, "...to where it ends, low on the wall.")
	assert(absf(_player.global_position.x - 0.38) < 0.05)
	assert(not _pit.camera.cinematic_override_enabled and _pit.camera.get("encounter_target") == _boss)
	assert(_encounter.health_bar_visible())
	skip.pressed = false
	Input.parse_input_event(skip)
	await _frames(2)
	assert(_player.is_physics_processing(), "Control returns just after the skip.")
	assert(_player.velocity.y <= 0.0, "The skip press is not also a jump.")
	await _until(func(): return _boss.enabled, 60, "The boss joins the fight after the skip.")


func _validate_warhead_exit() -> void:
	var exit_door := _pit.get_node("Props/ExitDoor")
	var goal := _pit.get_node("ExitGoal") as LevelGoal3D
	_boss.set_enabled(false)
	_player.health.reset(5000)
	# Sealed, the exit notch stops the player short of the goal.
	_place_player(Vector3(47.5, 0, 0))
	Input.action_press(&"move_right")
	await _frames(40)
	Input.action_release(&"move_right")
	assert(not goal.overlaps_body(_player) and not _pit._completed, "The sealed door blocks the exit.")
	assert(exit_door.is_sealed(), "Without the warhead the door stays shut.")
	var dropped: Array = []
	_encounter.warhead_dropped.connect(func(pickup: Node3D): dropped.append(pickup))
	_place_player(Vector3(6.0, 0, 0))
	_boss.global_position = Vector3(20.0, 0, 0)
	await _frames(4)
	_boss.health.reset(25)
	for attempt in 20:
		_boss.receive_projectile_hit(_boss.global_position, CombatHit.new(25, &"handgun", _boss.global_position))
		if _boss.is_defeated():
			break
		await _frames(2)
	assert(_boss.is_defeated() and dropped.size() == 1, "Destroying the boss drops its warhead.")
	assert(_sounds.count("boss/warhead_drop") == 1, "The dropped warhead sounds once.")
	assert(_encounter.boss_defeated(), "The kill is kept with the run.")
	assert(_pit.save_state._entry_pending, "The kill autosaves at the first safe footing.")
	assert(_pit.save_state.safety_error(true) != ENCOUNTER.SAVE_BLOCKED, "Manual saves return after the kill.")
	var warhead: Node3D = dropped[0]
	await _until(func(): return warhead.is_landed(), 120, "The warhead falls to the floor.")
	assert(absf(warhead.global_position.y) < 0.05)
	_place_player(warhead.global_position)
	await _until(func(): return _encounter.carrying_warhead, 30, "Touching the warhead takes it.")
	assert(_sounds.count("boss/warhead_pickup") == 1, "Taking the warhead sounds once.")
	# A reload after the kill (a save, or a return after a death) keeps the
	# wreck dead, the warhead in hand, and skips the cutscene.
	_pit._reset_world()
	await _frames(3)
	assert(_boss.is_defeated(), "The boss stays dead after a reload.")
	assert(_encounter.phase == ENCOUNTER.Phase.FIGHT and not _encounter.health_bar_visible())
	assert(_encounter.carrying_warhead, "The warhead stays in hand.")
	assert(_sounds.count("boss/warhead_pickup") == 1 and _sounds.count("boss/warhead_drop") == 1, "A reload restores the warhead silently.")
	assert(_pit.find_children("*", "Area3D", true, false).filter(
		func(area: Node) -> bool: return area.get_script() == ENCOUNTER.WARHEAD).is_empty(), "No second warhead appears.")
	_place_player(Vector3(48.2, 0, 0))
	await _until(func(): return not exit_door.is_sealed(), 30, "Reaching the door with the warhead plants it.")
	await _until(func(): return exit_door.is_open(), 240, "The planted warhead blows the door open.")
	assert(_sounds.count("boss/blast_door") == 1, "The blast sounds once.")
	assert(_pit.save_state.world_flags.get(ENCOUNTER.EXIT_OPEN_FLAG, false), "The open door is kept with the run.")
	Input.action_press(&"move_right")
	await _until(func(): return _pit._completed, 120, "The open doorway ends the level.")
	Input.action_release(&"move_right")
	assert(not _player.visible, "The player vanishes into the doorway.")


func _place_player(position: Vector3) -> void:
	_player.global_position = position + Vector3(0, PlayerCharacter.FEET_OFFSET_Y + 0.02, 0)
	_player.velocity = Vector3.ZERO


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _until(condition: Callable, limit: int, message: String) -> void:
	for index in limit:
		if condition.call():
			return
		await _frames(1)
	printerr(message)
	quit(1)
	assert(false, message)
