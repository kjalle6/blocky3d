extends SceneTree
## Real firing/impact hooks plus bounded voices, room routing, mix controls,
## and cleanup. Fixtures never rewrite the user's saved movement/audio mix.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const EVENTS := preload("res://scripts/audio/sound_event_catalog.gd")
const AREA := preload("res://tools/level_3_shooter_area_fixture.gd")

var _finished := false
var _events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")
	create_timer(20.0).timeout.connect(func() -> void:
		if not _finished:
			push_error("Combat audio validation timed out.")
			quit(1))


func _run() -> void:
	var original_hash := FileAccess.get_sha256(MIX.SAVE_PATH)
	MIX.initialize()
	MIX.saved_events = EVENTS.default_banks()
	MIX.saved_events.merge(MIX.copy_banks(MIX.SOURCE_EVENT_BANKS), true)
	MIX.working_events = MIX.copy_banks(MIX.saved_events)
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	var level := AREA.load_into(game)
	var player := level.player
	var feedback := level.combat_feedback as CombatFeedback3D
	var sound: Node3D = feedback.combat_audio
	var shooter := level.get_node("ShooterEncounterStaging/ShooterEnemyAnchor/HandgunEnemy") as HandgunEnemy3D
	assert(level.acquire_weapon(PlayerWeapon.HANDGUN))
	for tick in 8:
		await physics_frame
	sound.event_played.connect(func(event: Dictionary) -> void:
		event["physics_frame"] = Engine.get_physics_frames()
		_events.append(event))
	var firing_frames: Array[int] = []
	player.projectile_fired.connect(func(_round: HandgunProjectile3D) -> void:
		firing_frames.append(Engine.get_physics_frames()))
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(18.5, 0.7, 0.0)))
	player._facing_sign = -1.0
	player.player_handgun._mouse_requested = false
	await _shoot()
	assert(_count("combat/player_gunshot") == 1)
	assert(_events[0].physics_frame == firing_frames[0], "Sound must release in the actual firing tick.")
	for tick in 20:
		await physics_frame
	assert(_count("combat/bullet_scenery") == 1, "The actual leftward round must sound when it reaches cover.")
	assert(_count("combat/bullet_character") == 0)
	assert(is_equal_approx(sound.last_event.position.z, 0.0))

	# The existing double-jump input and shot must produce exactly one cue.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(18.5, 5.0, 0.0)))
	player.player_handgun.reset_run()
	for tick in 8:
		await physics_frame
	_events.clear()
	Input.action_press("jump")
	await _shoot()
	Input.action_release("jump")
	assert(player.pixel_visual.current_state() == "double_jump")
	assert(_count("combat/player_gunshot") == 1)

	await _check_empty_trigger_audio(game, player, sound)

	# Three live paired beats produce six bullets, but three balanced cues.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(18.5, 0.7, 0.0)))
	_events.clear()
	shooter.set_engagement_enabled(true)
	shooter._begin_volley()
	for tick in 40:
		await physics_frame
		if shooter.completed_volleys_total() >= 1:
			break
	assert(shooter.shots_fired_total() == 6)
	assert(_count("combat/enemy_gunshot") == 3)
	for tick in 45:
		await physics_frame
		if _count("combat/bullet_character") > 0:
			break
	assert(_count("combat/bullet_character") > 0, "A real bullet hitting the player must use the character bank.")
	shooter.set_engagement_enabled(false)
	player.set_physics_process(false)
	for projectile in get_nodes_in_group("player_projectile"):
		projectile.reset_run()
	sound.reset_run()
	assert(sound.active_voice_count() == 0)

	var bank: Resource = MIX.event_bank_for("combat/player_gunshot")
	bank.fixed_index = 1
	bank.volume_db = -25.0
	bank.pitch_scale = 1.1
	bank.pitch_variation = 0.0
	bank.looping = true
	assert(sound.play_event("combat/player_gunshot", player.global_position))
	var first: AudioStreamPlayer3D = sound._voices[0]
	assert(sound.last_event.clip_index == 1 and sound.last_event.volume_db == -25.0)
	assert(is_equal_approx(sound.last_event.pitch, 1.1))
	assert(first.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Live gunshots never loop even when loop preview is enabled.")
	assert(sound.play_event("combat/player_gunshot", player.global_position))
	assert(sound.active_voice_count() == 2 and first.playing, "Rapid shots need independent tails.")
	bank.enabled = false
	assert(not sound.play_event("combat/player_gunshot", player.global_position))
	assert(sound.active_voice_count() == 2)
	MIX.listening_to_saved = true
	assert(sound.play_event("combat/player_gunshot", player.global_position))
	assert(sound.last_event.clip_index == 0 and sound.last_event.volume_db == -12.0)
	MIX.listening_to_saved = false
	bank.enabled = true

	# Impact position chooses the room, even though the voice is level-owned.
	level.set_meta("audio_environment", &"underground")
	assert(sound.play_event("combat/player_gunshot", player.global_position))
	assert(sound.last_event.bus == &"UndergroundSFX")
	bank.use_room_reverb = false
	assert(sound.play_event("combat/player_gunshot", player.global_position))
	assert(sound.last_event.bus == &"Master")
	level.remove_meta("audio_environment")
	bank.volume_db = -70.0
	for index in 40:
		sound.play_event("combat/player_gunshot", player.global_position)
	assert(sound.active_voice_count() == sound.VOICE_COUNT)
	feedback.reset_feedback()
	assert(sound.active_voice_count() == 0)
	MIX.revert()

	# Bullet impacts follow the material struck.
	var nodes := level.find_children("*", "", true, false)
	var crate: Node3D = nodes.filter(func(node: Node) -> bool: return node is BreakableCrate3D)[0]
	assert(feedback._scenery_event(crate, crate.global_position) == "combat/bullet_wood", "Crates are wood.")
	var scaffold_script := preload("res://scripts/props/wall_jump_scaffold_3d.gd")
	var scaffolds := nodes.filter(func(node: Node) -> bool: return node.get_script() == scaffold_script)
	assert(not scaffolds.is_empty() and feedback._scenery_event(scaffolds[0], scaffolds[0].global_position) == "combat/bullet_metal", "Scaffolds are metal.")
	var ground: Node3D = nodes.filter(func(node: Node) -> bool: return node is PixelPlatform3D and node.style != null and node.style.footstep_surface == "grass")[0]
	assert(feedback._scenery_event(ground, ground.global_position) == "combat/bullet_dirt", "Grass ground is dirt.")
	assert(feedback._scenery_event(null, Vector3.ZERO) == "combat/bullet_scenery", "No collider uses the general slot.")
	# Each healing item has its own cue; an empty slot falls back to Medicine.
	var medicine: Resource = MIX.event_bank_for("combat/heal")
	var kit: Resource = MIX.event_bank_for("combat/heal_kit")
	var kit_clips: Array[AudioStream] = kit.clips.duplicate()
	kit.clips.clear()
	_events.clear()
	feedback._on_healing_used(&"large_heal_test", 50, player)
	assert(_events.size() == 1 and _events[0].id == "combat/heal", "An empty kit slot falls back to Medicine.")
	kit.clips = kit_clips if not kit_clips.is_empty() else medicine.clips.duplicate()
	var bag: Resource = MIX.event_bank_for("combat/heal_bag")
	if bag.clips.is_empty(): bag.clips = medicine.clips.duplicate()
	_events.clear()
	feedback._on_healing_used(&"basic_heal", 25, player)
	feedback._on_healing_used(&"large_heal_test", 50, player)
	feedback._on_healing_used(&"medical_bag", 75, player)
	assert(_events.map(func(event: Dictionary) -> String: return event.id) == ["combat/heal", "combat/heal_kit", "combat/heal_bag"], "Each healing item plays its own cue.")

	# Both established combat and newly connected ability entries advertise use.
	game.audio_tuning_panel.open_panel()
	game.audio_tuning_panel.select_event("combat/player_gunshot")
	assert(game.audio_tuning_panel._body.find_child("EventConnectionStatus", true, false).text.begins_with("Connected"))
	game.audio_tuning_panel.select_event("abilities/double_jump")
	assert(game.audio_tuning_panel._body.find_child("EventConnectionStatus", true, false).text.begins_with("Connected"))
	game.audio_tuning_panel.close_panel()
	game.show_level_select()
	assert(not is_instance_valid(sound), "Changing levels must free every combat voice.")
	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_hash)
	_finished = true
	print("Combat audio passed: live shots/impacts, surface materials, per-item healing, empty-trigger audio-tool imports/settings/gates, double jump, paired beats, overlapping tails, mix controls, room routing, and cleanup.")
	quit(0)


func _check_empty_trigger_audio(game: Node, player: PlayerCharacter, sound: Node3D) -> void:
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(18.5, 0.7, 0.0)))
	var gun := player.player_handgun
	gun.reset_run()
	gun.set_loaded_rounds(0)
	player.inventory.add(&"handgun_ammo", 12)
	for tick in 8:
		await physics_frame
	var panel: CanvasLayer = game.audio_tuning_panel
	panel.open_panel()
	panel.select_event("combat/out_of_ammo")
	assert(panel._body.find_child("EventConnectionStatus", true, false).text.begins_with("Connected"))
	# Use real import entry points with stable fixture recordings. No mix is saved.
	panel._add_files(PackedStringArray(["res://assets/audio/combat/shot_1.wav", "res://assets/audio/combat/shot_2.wav"]))
	var bank: Resource = panel._bank()
	assert(bank.clips.size() == 2)
	bank.selection_mode = 1
	bank.fixed_index = 1
	bank.volume_db = -27.0
	bank.pitch_scale = 0.9
	bank.use_room_reverb = false
	panel.close_panel()
	_events.clear()
	var rounds_before := get_nodes_in_group("player_projectile").size()
	var reserve_before := gun.reserve_rounds()
	await _shoot()
	assert(_count("combat/out_of_ammo") == 1)
	assert(sound.last_event.clip_index == 1 and sound.last_event.volume_db == -27.0)
	assert(is_equal_approx(sound.last_event.pitch, 0.9) and sound.last_event.bus == &"Master")
	assert(get_nodes_in_group("player_projectile").size() == rounds_before)
	assert(gun.loaded_rounds == 0 and gun.reserve_rounds() == reserve_before)
	assert(not player.is_attacking() and _count("combat/player_gunshot") == 0)
	await physics_frame
	Input.action_press("attack")
	for tick in 25:
		await physics_frame
	Input.action_release("attack")
	assert(_count("combat/out_of_ammo") == 1, "An early empty press must be ignored, even when held past recovery.")
	await physics_frame
	bank.fixed_index = 0
	await _shoot()
	assert(_count("combat/out_of_ammo") == 2 and sound.last_event.clip_index == 0)
	while gun.is_recovering():
		await physics_frame
	await physics_frame
	bank.enabled = false
	await _shoot()
	assert(_count("combat/out_of_ammo") == 2, "The tool's mute applies to empty-trigger input.")
	assert(gun.is_recovering(), "Muting the cue must not bypass the trigger cooldown.")
	bank.enabled = true
	while gun.is_recovering():
		await physics_frame
	await physics_frame
	assert(gun.start_reload())
	await _shoot()
	assert(_count("combat/out_of_ammo") == 2, "Reloading must not produce empty clicks.")
	gun.cancel_reload()
	await physics_frame
	gun._cooldown_remaining = 0.5
	await _shoot()
	assert(_count("combat/out_of_ammo") == 2, "Shot recovery must not produce empty clicks.")
	gun.reset_run()
	await physics_frame
	player._attack_lock_remaining = 0.5
	await _shoot()
	assert(_count("combat/out_of_ammo") == 2, "Healing/impact attack locks must suppress empty clicks.")
	player._attack_lock_remaining = 0.0
	assert(player.request_weapon(PlayerWeapon.KNIFE))
	await physics_frame
	await _shoot()
	assert(_count("combat/out_of_ammo") == 2, "A knife swing must not trigger the handgun's empty cue.")
	# Restore the fixture for subsequent live enemy checks.
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(18.5, 0.7, 0.0)))
	assert(player.request_weapon(PlayerWeapon.HANDGUN))
	gun.set_loaded_rounds(12)
	gun.reset_run()


func _shoot() -> void:
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")


func _count(event_id: String) -> int:
	var count := 0
	for event in _events:
		if event.id == event_id:
			count += 1
	return count
