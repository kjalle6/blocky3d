extends SceneTree
## One real head contact, frozen input, overlapping shell damage and cleanup.
const FIXTURE := preload("res://tools/level_3_shooter_area_fixture.gd")
const SHELL := preload("res://scenes/projectiles/tank_shell.tscn")
const ACTIONS := ["move_right", "jump", "dash", "attack", "quick_item_1", "reload"]
var _finished := false

func _init() -> void:
	call_deferred("_run")
	create_timer(20.0).timeout.connect(func():
		if not _finished:
			printerr("Tank psychic validation timed out.")
			quit(1))

func _frames(count: int) -> void:
	for frame in count: await physics_frame

func _run() -> void:
	var level := FIXTURE.instantiate_session()
	root.add_child(level)
	await _frames(5)
	assert(not level.has_meta("layout_error"))
	var player := level.player
	player.died.disconnect(level._on_player_died)
	level.get_node("ShooterEncounterStaging/ShooterIntro").process_mode = Node.PROCESS_MODE_DISABLED
	var tank := level.get_node("TankEncounter/Tank") as TankEnemy3D
	tank._landed_in_arena = true
	player.reset_at(Transform3D(Basis.IDENTITY, tank.global_position + Vector3(-0.1, tank.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y + 0.12, 0)))
	player.velocity.y = -4.0
	level.camera.snap_to_target()
	tank._pursuing = true
	tank._state = HandgunEnemy3D.CombatState.TELEGRAPH
	tank._phase_remaining = 0.12
	for frame in 12:
		await physics_frame
		if player.is_psychically_frozen(): break
	assert(player.is_psychically_frozen(), "A real descending head contact must trigger the brain attack.")
	assert(player.health.current == 75 and tank.health.current == 200)
	assert(Engine.time_scale == 1.0, "Brain attack cannot pause the tank/world clock.")
	assert(not player.can_save_state() and not player.use_quick_item(0))
	assert(level.combat_feedback.combat_audio.last_event.id == "combat/tank_psychic")
	assert(get_nodes_in_group("psychic_pulse_effect").size() == 1)
	var effect_id: int = get_nodes_in_group("psychic_pulse_effect")[0].get_instance_id()
	var state := tank._state
	var phase := tank._phase_remaining
	for duplicate in 8: tank.receive_stomp(player)
	assert(player.health.current == 75, "Overlapping head/body callbacks must count as one landing.")
	assert(tank._state == state and tank._phase_remaining == phase, "Brain contact cannot restart the firing cycle.")
	var frozen_position := player.global_position
	var tank_x := tank.global_position.x
	for action in ACTIONS: Input.action_press(action)
	await _frames(12)
	for action in ACTIONS: Input.action_release(action)
	assert(player.is_psychically_frozen() and player.global_position.is_equal_approx(frozen_position), "Input must not escape the short suspension.")
	assert(tank.global_position.x > tank_x and absf(tank.velocity.x) <= tank.psychic_retreat_speed + 0.001, "Tank uses its modest retreat speed during the freeze.")
	assert(tank.shots_fired_total() == 1, "The pending shot must fire during the psychic freeze.")
	# A real enemy projectile remains damaging while the player is frozen.
	var shell := SHELL.instantiate() as HandgunProjectile3D
	level.add_child(shell)
	shell.global_position = frozen_position + Vector3(-0.8, 0, 0)
	shell.launch(Vector3.RIGHT, tank, CombatHit.new(25, &"tank_shell", shell.global_position))
	await _frames(8)
	assert(player.health.current == 50 and player.is_psychically_frozen(), "Brain and shell damage must stack, with no invulnerability.")
	await _frames(ceili(tank.psychic_freeze_duration * 60.0) - 20 + 2)
	assert(not player.is_psychically_frozen(), "Player must regain control when the freeze expires.")
	assert(absf(tank.global_position.x - player.global_position.x) > 1.25, "Tank must clear the head contact area before the player can drop onto it again.")
	assert(absf(tank.velocity.x) <= tank.patrol_speed + 0.001)
	# A deliberate repeat hit during the text fade refreshes one effect.
	tank.reset_run()
	player.reset_at(Transform3D(Basis.IDENTITY, tank.global_position + Vector3(-0.1, tank.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y, 0)))
	tank.receive_stomp(player)
	assert(player.health.current == 75 and player.is_psychically_frozen())
	assert(get_nodes_in_group("psychic_pulse_effect").size() == 1)
	var repeated_effect: Node = get_nodes_in_group("psychic_pulse_effect")[0]
	assert(repeated_effect.get_instance_id() == effect_id and repeated_effect._elapsed == 0.0, "Repeat pulse must restart its rings and text, not stack them.")
	await _frames(ceili((tank.psychic_freeze_duration + 0.4) * 60.0))
	assert(get_nodes_in_group("psychic_pulse_effect").is_empty())
	# Near a patrol boundary, choose space to retreat instead of turning back under the player.
	tank.reset_run()
	tank.global_position.x += tank.patrol_right_distance - 0.1
	player.reset_at(Transform3D(Basis.IDENTITY, tank.global_position + Vector3(-0.1, tank.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y, 0)))
	level.camera.snap_to_target()
	tank.receive_stomp(player)
	assert(tank._patrol_sign < 0.0)
	await _frames(ceili(tank.psychic_freeze_duration * 60.0) + 2)
	assert(absf(tank.global_position.x - player.global_position.x) > 1.25, "Retreat must also clear the player at the end of the patrol.")
	# Respawn and death always clear the freeze.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(50, 0.7, 0)))
	assert(not player.is_psychically_frozen() and player.pixel_visual.body.modulate == Color.WHITE)
	tank.reset_run()
	player.health.reset(100, 25)
	tank.receive_stomp(player)
	assert(player.is_dead() and not player.is_psychically_frozen(), "A lethal brain hit must enter normal death, never leave a frozen corpse.")
	level.queue_free()
	await process_frame
	_finished = true
	print("Tank psychic passed: head contact, 25 damage, freeze, retreat clearance at patrol centre and boundary, clean repeat effects, uninterrupted fire, simultaneous shell damage and cleanup.")
	quit()
