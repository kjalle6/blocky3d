extends SceneTree
## Real knife input and falling-body stomps; no production saves are written.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const EVENTS := preload("res://scripts/audio/sound_event_catalog.gd")
const AREA := preload("res://tools/level_3_shooter_area_fixture.gd")
const PREVIEW := preload("res://scripts/developer/level_layout_preview.gd")
const SKATER := preload("res://scenes/enemies/pixel_skater_enemy.tscn")
const GUNNER := preload("res://scenes/enemies/handgun_enemy.tscn")

var _events: Array[Dictionary] = []
var _world: Node3D
var _player: PlayerCharacter
var _feedback: CombatFeedback3D
var _finished := false


func _init() -> void:
	call_deferred("_run")
	create_timer(25.0).timeout.connect(func() -> void:
		if not _finished:
			push_error("Melee audio validation timed out.")
			quit(1))


func _run() -> void:
	var original_hash := FileAccess.get_sha256(MIX.SAVE_PATH)
	MIX.initialize()
	MIX.saved_events = EVENTS.default_banks()
	MIX.saved_events.merge(MIX.copy_banks(MIX.SOURCE_EVENT_BANKS), true)
	MIX.working_events = MIX.copy_banks(MIX.saved_events)
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40, 1, 3)
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)
	_player = load("res://scenes/player/pixel_player_character.tscn").instantiate()
	_player.position = Vector3(0, 0.56, 0)
	_world.add_child(_player)
	_feedback = CombatFeedback3D.new()
	_feedback.enemy_defeat_pause = 0.0
	_feedback.player_damage_pause = 0.0
	_world.add_child(_feedback)
	_feedback.bind_player(_player)
	_feedback.bind_player(_player)
	var sound: Node3D = _feedback.combat_audio
	sound.event_played.connect(func(event: Dictionary) -> void:
		event["frame"] = Engine.get_physics_frames()
		_events.append(event))
	var contact_frames: Array[int] = []
	_player.attack_connected.connect(func(_target: Node3D) -> void:
		contact_frames.append(Engine.get_physics_frames()))
	var bounce_frames: Array[int] = []
	_player.stomp_bounced.connect(func(_position: Vector3) -> void:
		bounce_frames.append(Engine.get_physics_frames()))
	await _ticks(8)

	# A miss sounds once. Holding the button does not restart the swing.
	Input.action_press("attack")
	await _ticks(30)
	Input.action_release("attack")
	assert(_count("combat/knife_swing") == 1 and _count("combat/knife_hit") == 0)
	assert(_count("combat/stomp") == 0)
	await _ticks(2)

	# Both real enemy types can be hit by one swing, with one contact cue.
	var skater := _enemy(SKATER, Vector3(1.05, 0.55, 0))
	var gunner := _enemy(GUNNER, Vector3(1.20, 0.55, 0))
	await _ticks(2)
	_events.clear()
	await _attack()
	assert(_count("combat/knife_swing") == 1 and _count("combat/knife_hit") == 0,
		"Contact must wait for the knife's impact timing.")
	# A second press during this attack must not create another swing.
	await _attack()
	await _ticks(20)
	assert(skater.is_defeated() and gunner.is_defeated())
	assert(contact_frames.size() == 2, "Deduplicating audio must preserve all damage.")
	assert(_count("combat/knife_swing") == 1 and _count("combat/knife_hit") == 1)
	assert(_events[1].frame == contact_frames[0])
	var elapsed := float(_events[1].frame - _events[0].frame + 1) / Engine.physics_ticks_per_second
	assert(absf(elapsed - _player.attack_impact_time) <= 1.0 / Engine.physics_ticks_per_second)
	assert(_count("combat/stomp") == 0 and _count("combat/bullet_character") == 0)
	await _attack()
	await _ticks(22)
	assert(_count("combat/knife_hit") == 1 and contact_frames.size() == 2,
		"Defeated actors must not report fresh knife contacts.")
	skater.free()
	gunner.free()

	# Reset and death cancel contact, without cutting off an accepted swing's tail.
	for cancel_kind in ["reset", "death", "dash"]:
		_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.56, 0)))
		_player.configure_abilities([PlayerAbility.DASH], [PlayerAbility.DASH])
		skater = _enemy(SKATER, Vector3(1.05, 0.55, 0))
		await _ticks(3)
		_events.clear()
		await _attack()
		if cancel_kind == "reset":
			_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.56, 0)))
		elif cancel_kind == "death":
			_player.kill()
		else:
			Input.action_press("dash")
			await _ticks(2)
			Input.action_release("dash")
		await _ticks(24)
		assert(_count("combat/knife_swing") == 1 and _count("combat/knife_hit") == 0, cancel_kind)
		assert(not skater.is_defeated(), cancel_kind)
		skater.free()

	# Actual downward motion enters each enemy's contact area and bounces.
	for scene in [SKATER, GUNNER]:
		_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 4, 0)))
		var target := _enemy(scene, Vector3(0, 0.55, 0))
		_events.clear()
		for tick in 90:
			await physics_frame
			if target.is_defeated(): break
		assert(target.is_defeated() and _player.velocity.y > 0.0)
		assert(_count("combat/stomp") == 1 and _count("combat/knife_hit") == 0)
		assert(_events[0].frame == bounce_frames.back(), "Stomp sound must occur on the bounce tick.")
		target.free()
		await _ticks(2)
	_player.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 4, 0)))
	_events.clear()
	await _ticks(60)
	assert(_player.is_on_floor() and _count("combat/stomp") == 0)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	await _ticks(60)
	assert(_count("combat/stomp") == 0, "Ground jumps and landings are not stomps.")
	# Each new bank uses the same live selection/mute/A-B and one-shot rules.
	_player.set_physics_process(false)
	for event_id in ["combat/knife_swing", "combat/knife_hit", "combat/stomp"]:
		var bank: Resource = MIX.event_bank_for(event_id)
		assert(not bank.clips.is_empty())
		var selected_index: int = bank.clips.size() - 1
		_feedback.reset_feedback()
		bank.fixed_index = selected_index
		bank.volume_db = -29.0
		bank.looping = true
		assert(sound.play_event(event_id, _player.position))
		assert(sound.last_event.clip_index == selected_index and sound.last_event.volume_db == -29.0)
		var stream: AudioStream = sound._voices[0].stream
		assert(stream.get_length() > 0.0)
		if stream is AudioStreamWAV:
			assert(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED)
		else:
			assert(stream is AudioStreamMP3 or stream is AudioStreamOggVorbis)
			assert(not stream.loop)
		bank.enabled = false
		assert(not sound.play_event(event_id, _player.position))
		MIX.listening_to_saved = true
		assert(sound.play_event(event_id, _player.position) and sound.last_event.clip_index == 0)
		MIX.listening_to_saved = false
	_feedback.reset_feedback()
	assert(sound.active_voice_count() == 0)
	_world.free()
	assert(not is_instance_valid(sound))
	MIX.revert()

	# Confirm normal LevelSession wiring, connected tool pages, and silent previews.
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	var level := AREA.load_into(game)
	assert(level.player.melee_swung.is_connected(level.combat_feedback._on_melee_swung))
	assert(level.player.stomp_bounced.is_connected(level.combat_feedback._on_stomp_bounced))
	level.player.reset_at(Transform3D(Basis.IDENTITY, Vector3(12, 0.7, 0)))
	assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	level.player.player_handgun._mouse_requested = false
	level.combat_feedback.combat_audio.event_played.connect(func(event: Dictionary) -> void: _events.append(event))
	await _ticks(8)
	_events.clear()
	await _attack()
	assert(_count("combat/player_gunshot") == 1 and _count("combat/knife_swing") == 0)
	game.audio_tuning_panel.open_panel()
	for event_id in ["combat/knife_swing", "combat/knife_hit", "combat/stomp"]:
		game.audio_tuning_panel.select_event(event_id)
		assert(game.audio_tuning_panel._body.find_child("EventConnectionStatus", true, false).text.begins_with("Connected"))
	game.audio_tuning_panel.close_panel()
	game.free()
	var preview := AREA.instantiate_session()
	PREVIEW.prepare(preview)
	root.add_child(preview)
	PREVIEW.finish(preview)
	assert(not preview.player.melee_swung.is_connected(preview.combat_feedback._on_melee_swung))
	preview.player.melee_swung.emit(Vector3.ZERO)
	preview.player.stomp_bounced.emit(Vector3.ZERO)
	assert(preview.combat_feedback.combat_audio.played_count == 0)
	preview.free()
	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_hash)
	_finished = true
	print("Melee audio passed: real knife input/contact, multi-hit, defeated targets, cancellation, both enemy stomps, live controls, cleanup, and silent previews.")
	quit(0)


func _enemy(scene: PackedScene, position: Vector3) -> Node3D:
	var enemy := scene.instantiate() as Node3D
	enemy.position = position
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	# Defeat/audio fixture; health validation covers nonlethal default damage.
	enemy.health.reset(25)
	return enemy


func _attack() -> void:
	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(1)


func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame


func _count(event_id: String) -> int:
	var count := 0
	for event in _events:
		if event.id == event_id: count += 1
	return count
