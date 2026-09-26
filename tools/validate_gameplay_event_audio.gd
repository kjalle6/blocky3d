extends SceneTree
## Exercise optional banks through their gameplay owners; never save the mix.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const CATALOG := preload("res://scripts/audio/sound_event_catalog.gd")
const LIFT := preload("res://scripts/presentation/cave_construction_lift_3d.gd")
var events: Array[String] = []
var finished := false

func _init() -> void:
	call_deferred("_run")
	create_timer(45.0).timeout.connect(func() -> void:
		if not finished:
			push_error("Gameplay event audio timed out.")
			quit(1))

func _run() -> void:
	var original_hash := FileAccess.get_sha256(MIX.SAVE_PATH)
	MIX.initialize()
	MIX.saved_events = CATALOG.default_banks()
	MIX.working_events = MIX.copy_banks(MIX.saved_events)
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await _ticks(2)
	var app_audio: Node = game.event_audio
	app_audio.event_played.connect(func(event: Dictionary) -> void: events.append(event.id))
	assert(not app_audio._music.is_playing(), "An empty music slot must remain silent.")
	game.load_level(&"arrival_shoreline")
	await _ticks(8)
	var session: LevelSession3D = game.current_level
	var player := session.player
	var sound: Node3D = session.combat_feedback.combat_audio
	sound.event_played.connect(func(event: Dictionary) -> void: events.append(event.id))
	var owner: Node = session.get_node("EventAudio")
	player.set_physics_process(false)
	player._perform_double_jump()
	assert(events.is_empty(), "An unassigned ability must not play fallback audio.")
	var fixture := AudioStreamWAV.new()
	fixture.mix_rate = 22050
	fixture.format = AudioStreamWAV.FORMAT_16_BITS
	var pcm := PackedByteArray()
	pcm.resize(4410)
	fixture.data = pcm
	for entry in CATALOG.EVENTS:
		assert(entry.has("room") or entry.has("gameplay"), "Every current slot must have a gameplay owner.")
		if entry.has("room"): continue
		var bank: Resource = MIX.event_bank_for(entry.id)
		bank.clips.append(fixture)
		bank.volume_db = -70.0
		bank.pitch_scale = 1.0
		bank.pitch_variation = 0.0
		bank.use_room_reverb = false
		assert(bank.has_playable_recording())
	await _ticks(2)
	assert(app_audio._music.event_id == "music/level_1" and app_audio._music.is_playing(), "Music: id=%s playing=%s context=%s tools=%s" % [app_audio._music.event_id, app_audio._music.is_playing(), app_audio._music_id, game._developer_tool_owner])
	assert(app_audio._ambience.event_id == "ambience/beach")
	player.global_position.x = session.get_node("BackgroundTransitionAnchor").global_position.x + 1.0
	await _ticks(2)
	assert(app_audio._ambience.event_id == "ambience/forest")

	# Real ability and damage methods publish to the same router as input.
	assert(session.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	assert(events.count("pickups/double_jump") == 1)
	assert(session.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	assert(events.count("pickups/double_jump") == 1)
	player._perform_double_jump()
	assert(events.count("abilities/double_jump") == 1)
	player._last_wall_contact_direction = 1.0
	player._perform_wall_jump()
	assert(events.count("abilities/wall_jump") == 1)
	player._wall_sliding = true
	await _ticks(2)
	var wall_loop: Node = owner._loops.get("%s:abilities/wall_slide" % player.get_instance_id())
	assert(wall_loop != null and wall_loop.is_playing())
	var bank: Resource = MIX.event_bank_for("abilities/wall_slide")
	bank.enabled = false
	await _ticks(2)
	assert(not is_instance_valid(wall_loop), "Muting must release continuous voices.")
	bank.enabled = true
	player._wall_sliding = false
	player.global_position = Vector3(2.0, 0.7, 0.0)
	player._facing_sign = 1.0
	assert(session.acquire_weapon(PlayerWeapon.HANDGUN))
	assert(events.count("combat/weapon_switch") == 1)
	assert(events.count("pickups/handgun") == 0, "A grant is not a physical pickup.")
	assert(player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(25, &"audio_test")))
	assert(events.count("combat/player_hit") == 1 and events.count("combat/player_death") == 0)
	player._attack_lock_remaining = 0.0
	assert(player.receive_enemy_hit(Vector3.ZERO, CombatHit.new(100, &"audio_fatal")))
	assert(events.count("combat/player_death") == 1 and events.count("combat/player_hit") == 1, "Fatal damage plays death only, without layering a hit cue.")
	player.kill()
	assert(events.count("combat/player_death") == 1, "An already dead player must not repeat the death cue.")
	session._reset_run(false)
	player.set_physics_process(false)
	assert(events.count("combat/player_respawn") == 1)
	session._reset_run(false)
	player.set_physics_process(false)
	assert(events.count("combat/player_respawn") == 1, "Ordinary reset must not sound like a respawn.")

	# Deferred actor discovery, real attack/defeat and lift state transitions.
	var enemy := load("res://scenes/enemies/pixel_patrol_enemy.tscn").instantiate() as StompableEnemy3D
	enemy.position = Vector3(3.0, 0.7, 0)
	session.add_child(enemy)
	await _ticks(8)
	enemy.set_physics_process(false)
	enemy.reset_run()
	player.global_position = enemy.global_position + Vector3(0.4, 0, 0)
	assert(enemy._try_start_attack())
	await _ticks(2)
	assert(events.has("combat/enemy_attack") and events.has("combat/enemy_notice"))
	assert(enemy.receive_melee_hit(player.global_position, CombatHit.new(100, &"audio_defeat")))
	assert(events.has("combat/enemy_defeat"))
	var flyer := load("res://scenes/enemies/green_zone_flyer.tscn").instantiate() as HoveringHazard3D
	flyer.position = player.global_position + Vector3(3, 3, 0)
	session.add_child(flyer)
	await _ticks(2)
	flyer.set_physics_process(false)
	assert(owner._loops.has("%s:world/flyer_hover" % flyer.get_instance_id()))
	flyer._set_spark(false)
	await _ticks(2)
	flyer._set_spark(true)
	await _ticks(2)
	assert(events.has("world/flyer_spark"))
	flyer.position.x += 100
	await _ticks(2)
	assert(not owner._loops.has("%s:world/flyer_hover" % flyer.get_instance_id()))
	var lift: Node3D = load("res://scenes/presentation/cave_construction_lift.tscn").instantiate()
	lift.position = player.global_position + Vector3(4, 0, 0)
	lift.boarding_delay = 0.0
	lift.travel_duration = 0.2
	lift.return_from_top_when_empty = false
	session.add_child(lift)
	await _ticks(2)
	lift.begin_travel()
	await _ticks(3)
	assert(events.has("world/lift_start"))
	assert(owner._loops.has("%s:world/lift_motor" % lift.carriage.get_instance_id()))
	await _ticks(20)
	assert(events.has("world/lift_stop"))
	assert(not owner._loops.has("%s:world/lift_motor" % lift.carriage.get_instance_id()))

	# Menu sounds run during pause, while the audio tool suppresses all owners.
	game.campaign_menu.show_pause()
	await _ticks(2)
	assert(paused)
	var close_button: Button = game.campaign_menu.options_panel.close_button
	close_button.mouse_entered.emit()
	assert(events.has("interface/focus"))
	close_button.pressed.emit()
	assert(not paused and events.has("interface/back"))
	game.campaign_menu.show_pause()
	await _ticks(2)
	var button := Button.new()
	button.text = "Test choice"
	game.campaign_menu.overlay.add_child(button)
	await _ticks(2)
	button.pressed.emit()
	assert(events.has("interface/confirm"))
	button.disabled = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	button.gui_input.emit(click)
	assert(events.has("interface/unavailable"))
	game.campaign_menu.close()
	game.audio_tuning_panel.open_panel()
	await _ticks(2)
	assert(not app_audio._music.is_playing() and not app_audio._ambience.is_playing())
	assert(not app_audio.play_event("interface/confirm"))
	game.audio_tuning_panel.close_panel()
	await _ticks(2)
	assert(app_audio._music.is_playing())
	game.show_level_select()
	await _ticks(2)
	assert(not is_instance_valid(owner) and not is_instance_valid(sound))
	assert(app_audio._music.event_id == "music/menu" and not app_audio._ambience.is_playing())

	game.load_level(&"overgrown_coastal_ascent")
	await _ticks(8)
	session = game.current_level
	player = session.player
	player.set_physics_process(false)
	sound = session.combat_feedback.combat_audio
	sound.event_played.connect(func(event: Dictionary) -> void: events.append(event.id))
	owner = session.get_node("EventAudio")
	assert(app_audio._music.event_id == "music/level_2")
	assert(app_audio._ambience.event_id == "ambience/level_2_forest")
	for ability in [PlayerAbility.WALL_JUMP, PlayerAbility.DASH]:
		assert(session.unlock_ability(ability))
		assert(events.has("pickups/" + str(ability)))
	assert(player._try_start_dash(1.0))
	assert(events.has("abilities/dash_ground"))
	player._finish_dash()
	player._refresh_dash()
	player.global_position.y += 10
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	assert(player._try_start_dash(1.0))
	assert(events.has("abilities/dash_air"))
	player._finish_dash()
	player._refresh_dash()
	await _ticks(2)
	assert(events.has("abilities/dash_ready"))
	session.set_meta("audio_environment", "cave")
	await _ticks(2)
	assert(not app_audio._ambience.is_playing())
	player.kill(PlayerCharacter.DEATH_KIND_WATER)
	assert(events.has("world/cave_splash"))
	assert(events.count("combat/player_death") == 2 and events.count("combat/player_hit") == 1, "Instant hazards also play death, without a hit cue.")
	session._reset_run(false)
	player.set_physics_process(false)
	game.show_level_select()
	await _ticks(2)
	var intro := load("res://scenes/cutscenes/level_2_cave_slide_intro.tscn").instantiate() as Level2CaveSlideIntro3D
	game.world.add_child(intro)
	game._active_interstitial = intro
	await _ticks(2)
	assert(app_audio._slide.is_playing())
	intro.skip_to_end()
	await _ticks(2)
	assert(not app_audio._slide.is_playing() and not events.has("world/cave_slide_exit"))
	intro.play_from_start()
	intro.slide_duration = 0.1
	await _ticks(12)
	assert(events.count("world/cave_slide_exit") == 1 and not app_audio._slide.is_playing())
	game._free_active_interstitial()
	preload("res://tools/level_3_shooter_area_fixture.gd").load_into(game)
	await _ticks(2)
	assert(app_audio._music.event_id == "music/level_3")
	assert(app_audio._ambience.event_id == "ambience/level_3_outdoors")
	game.current_level.combat_feedback.combat_audio.event_played.connect(func(event: Dictionary) -> void: events.append(event.id))
	# Completion signals remain owned by the level; avoid the app's scene change here.
	game.current_level.run_completed.disconnect(game._on_run_completed)
	game.current_level.run_completed.emit()
	assert(events.count("music/completion") == 1)
	assert(events.has("pickups/level_complete"))
	await _ticks(2)
	assert(not app_audio._music.is_playing())
	game.current_level.run_reset.emit()
	await _ticks(2)
	assert(app_audio._music.is_playing())
	game.free()
	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_hash)
	finished = true
	print("Gameplay event audio passed: empty/assigned banks, abilities, damage, respawn, dynamic enemies, lift/flyer loops, menu/pause, music/ambience, slide skip/end, completion and cleanup; saved mix preserved.")
	quit()

func _ticks(count: int) -> void:
	for tick in count: await physics_frame
	await process_frame
	await process_frame
