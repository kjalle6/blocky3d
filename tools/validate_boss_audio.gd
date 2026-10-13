extends SceneTree
## Boss sound slots follow the real fight events in the Boss Arena WIP: empty
## banks stay silent, contact cues need contact, loops end with their owners,
## and the defeat clears its machines under one cue. Never saves the mix.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const CATALOG := preload("res://scripts/audio/sound_event_catalog.gd")
var _game: Node
var _level: LevelSession3D
var _boss: CharacterBody3D
var _player: PlayerCharacter
var _controls: Node
var _owner: Node
var _events: Array[String] = []
var _finished := false

func _init() -> void:
	call_deferred("_run")
	create_timer(120.0).timeout.connect(func() -> void:
		if not _finished:
			printerr("Boss audio validation timed out.")
			quit(1))

func _run() -> void:
	var original_hash := FileAccess.get_sha256(MIX.SAVE_PATH)
	MIX.initialize()
	# Project defaults ship one trial pick per boss slot (assets/audio/boss).
	for entry in CATALOG.entries_for("boss"):
		var shipped: Resource = MIX.event_bank_for(entry.id)
		assert(shipped.has_playable_recording() and shipped.volume_db < 0.0, "%s has a trial pick." % entry.id)
		assert(shipped.looping == entry.get("loop", false), "%s keeps its catalog loop mode." % entry.id)
	# The routing checks below start from empty slots.
	MIX.saved_events = CATALOG.default_banks()
	MIX.working_events = MIX.copy_banks(MIX.saved_events)
	_game = load("res://scenes/app/game_root.tscn").instantiate()
	_game.persist_progression = false
	root.add_child(_game)
	await process_frame
	var definition: LevelDefinition = null
	for candidate in _game.developer_level_definitions:
		if candidate.level_id == &"dev_boss_arena_wip": definition = candidate
	_game.load_developer_level(definition)
	await _frames(12)
	_level = _game.current_level
	_boss = _level.get_node("GreenZoneBoss")
	_controls = _level.get_node("BossLabController")
	_player = _level.player
	_owner = _level.get_node("EventAudio")
	_level.combat_feedback.combat_audio.event_played.connect(func(event: Dictionary) -> void:
		if str(event.id).begins_with("boss/") or event.id in ["combat/bullet_machine", "combat/knife_metal_hit", "combat/bullet_character", "combat/knife_hit"]: _events.append(event.id))
	var ids: Array[String] = []
	for entry in CATALOG.entries_for("boss"):
		ids.append(entry.id)
		assert(entry.has("gameplay"), "Every boss slot names its gameplay owner.")
	assert(ids.size() == 22, "16 boss slots plus six encounter and fire slots.")

	# Empty slots: a full salvo makes no boss sound and owns no loop.
	_controls.test_missile_ripple()
	await _until(func(): return _boss.missiles_fired == 6, 120, "Silent salvo")
	await _frames(2)
	assert(_events.is_empty() and _boss_loops().is_empty(), "Empty boss slots must stay silent.")
	var filled: Array[String] = ids.duplicate()
	filled.append_array(["combat/bullet_machine", "combat/knife_metal_hit", "combat/bullet_character", "combat/knife_hit"])
	_fill_banks(filled)

	# Salvo: one swivel, six launches, a flight loop per live rocket, impact blasts.
	_controls.test_missile_ripple()
	await _until(func(): return _boss.missiles_fired == 6, 120, "Salvo")
	assert(_count("boss/launcher_swivel") == 1 and _count("boss/rocket_launch") == 6)
	await _frames(2)
	assert(_boss_loops().filter(func(key: String) -> bool: return key.ends_with("boss/rocket_flight")).size() >= 1,
		"Flying rockets carry their motor loop.")
	await _until(func(): return get_nodes_in_group("enemy_projectile").all(func(p: Node) -> bool: return p._expired), 240, "Rockets end")
	await _frames(2)
	assert(_count("boss/rocket_explosion") >= 1, "Rocket impacts explode audibly.")
	assert(_boss_loops().is_empty(), "Rocket loops end with their flight.")

	# Charge: the rush sounds once; contact sounds only when the shove lands.
	_events.clear()
	_controls.test_close_pressure()
	await _until(func(): return _boss.state_name() == "SPACE_CHARGE", 60, "Charge")
	assert(_count("boss/charge") == 1 and _count("boss/shove_contact") == 0)
	await _until(func(): return _player.health.current < 100, 60, "Charge contact")
	assert(_count("boss/shove_contact") == 1)
	_events.clear()
	_controls.test_close_pressure()
	await _until(func(): return _boss.state_name() == "SPACE_CHARGE", 60, "Dodged charge")
	Input.action_press("jump")
	await _frames(34)
	Input.action_release("jump")
	assert(_player.health.current == 100 and _count("boss/charge") == 1 and _count("boss/shove_contact") == 0,
		"A dodged charge has no contact cue.")

	# Head landing vents smoke once.
	_events.clear()
	_controls.test_head_landing()
	await _until(func(): return _boss.smoke_escapes == 1, 60, "Smoke escape")
	assert(_count("boss/smoke_vent") == 1)

	# Jump: thruster at take-off, landing only on physical contact.
	_events.clear()
	_controls.select_pattern(2)
	await _frames(4)
	_place_player(Vector3(_boss.global_position.x - 8.0, 0, 0))
	_boss.phase_remaining = 0.2
	await _until(func(): return _boss.state_name() == "JUMP", 240, "Jump")
	assert(_count("boss/jump_thruster") == 1 and _count("boss/landing") == 0, "No landing cue before contact.")
	await _until(func(): return _boss.landing_count == 1, 120, "Landing")
	assert(_count("boss/landing") == 1)

	# Firebombs: one release cue per lob, one burst per canister.
	_events.clear()
	_boss.ground_camp_time = 999.0
	_controls.select_pattern(3)
	await _frames(4)
	_place_player(Vector3(22.0, 0, 0))
	_boss.global_position = Vector3(32.0, 0, 0)
	_boss.phase_remaining = 0.2
	await _until(func(): return _boss.lobs_started >= 1, 300, "Lob")
	assert(_count("boss/firebomb_launch") == 0, "The lob's start is not its release.")
	_place_player(Vector3(6.0, 0, 0))
	await _until(func(): return _count("boss/firebomb_burst") == _boss.firebombs_per_lob, 180, "Bursts")
	assert(_count("boss/firebomb_launch") == 1)
	# Burning fires carry a loop; a landing that smothers one sounds once.
	await _frames(2)
	assert(_boss_loops().any(func(key: String) -> bool: return key.ends_with("boss/fire_burning")), "Burning fires carry their loop.")
	var fire: Node = get_nodes_in_group("boss_fire")[0]
	fire._stomp_out(_player)
	assert(_count("boss/fire_smothered") == 1)

	# Hits on armour use the metal sounds, not flesh.
	_events.clear()
	var hurtbox: Node3D = _boss.get_node("ProjectileHurtbox")
	_level.combat_feedback._on_handgun_projectile_impacted(_boss.global_position, Vector3.LEFT, hurtbox)
	_level.combat_feedback._knife_hit_sound_played = false
	_level.combat_feedback._on_melee_connected(_boss)
	assert(_count("combat/bullet_machine") == 1 and _count("combat/bullet_character") == 0, "Bullets ring off the boss.")
	assert(_count("combat/knife_metal_hit") == 1 and _count("combat/knife_hit") == 0, "The knife clangs off the boss.")

	# Walking: steps on planted frames only.
	_events.clear()
	_controls.select_pattern(1)
	await _frames(4)
	_boss.global_position = Vector3(30.0, 0, 0)
	_place_player(Vector3(12.0, 0, 0))
	_boss.phase_remaining = 99.0
	await _until(func(): return _count("boss/footstep") >= 2, 120, "Boss footsteps")

	# Phase two, machines, and a defeat that clears them under one cue.
	_events.clear()
	_controls.set_boss_active(false)
	await _frames(4)
	var maximum: int = _boss.combat.maximum_hp
	_boss.receive_projectile_hit(Vector3.ZERO, CombatHit.new(int(maximum * 0.5), &"audio_phase"))
	assert(_count("boss/phase_two") == 1)
	var flyers: Array[Node] = _level.get_node("BossPhaseFlyers").flyers()
	var first: Node3D = flyers[0]
	_place_player(first.global_position + Vector3(6, -PlayerCharacter.FEET_OFFSET_Y, 0))
	_player.health.reset(5000)
	await _frames(3)
	assert(_owner._loops.has("%s:boss/flyer_flight" % first.get_instance_id()), "An active machine has its flight loop.")
	assert(not _owner._loops.has("%s:world/flyer_hover" % first.get_instance_id()), "It replaces the generic hover.")
	for shot in 3:
		first.get_node("ProjectileHurtbox").receive_projectile_hit(first.global_position, CombatHit.new(25, &"bullet"))
	assert(_count("boss/flyer_destroyed") == 1)
	await _frames(2)
	assert(not _owner._loops.has("%s:boss/flyer_flight" % first.get_instance_id()), "A destroyed machine stops its loop.")
	await _until(func(): return flyers[1].is_active(), 120, "Second machine")
	_boss.receive_projectile_hit(Vector3.ZERO, CombatHit.new(maximum, &"audio_defeat"))
	assert(_count("boss/defeat") == 1 and _count("boss/flyer_destroyed") == 1,
		"The defeat clears remaining machines without their own cues.")
	_events.clear()
	_boss.restore_defeat()
	assert(_events.is_empty(), "A restored defeat is silent.")
	_controls.reset_fight()
	await _frames(2)
	assert(_boss_loops().is_empty(), "A reset leaves no boss loop.")

	assert(FileAccess.get_sha256(MIX.SAVE_PATH) == original_hash, "The saved mix is untouched.")
	_finished = true
	print("Boss audio validation passed: 22 slots, silent when empty, salvo/rockets, charge contact, smoke, jump/landing, firebombs, burning and smothered fires, armour hits, footsteps, phase two, machines and defeat.")
	quit(0)

func _fill_banks(ids: Array[String]) -> void:
	var fixture := AudioStreamWAV.new()
	fixture.mix_rate = 22050
	fixture.format = AudioStreamWAV.FORMAT_16_BITS
	var pcm := PackedByteArray()
	pcm.resize(44100)
	fixture.data = pcm
	for id in ids:
		var bank: Resource = MIX.event_bank_for(id)
		bank.clips.append(fixture)
		bank.volume_db = -70.0
		bank.use_room_reverb = false
		assert(bank.has_playable_recording())

func _boss_loops() -> Array:
	return _owner._loops.keys().filter(func(key: String) -> bool: return key.contains(":boss/"))

func _count(id: String) -> int:
	return _events.count(id)

func _place_player(position: Vector3) -> void:
	_player.global_position = position + Vector3(0, PlayerCharacter.FEET_OFFSET_Y + 0.02, 0)
	_player.velocity = Vector3.ZERO
	_player.health.reset(5000)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _until(condition: Callable, limit: int, message: String) -> void:
	for index in limit:
		if condition.call():
			return
		await _frames(1)
	printerr(message, " | boss=", _boss.state_name(), " events=", _events)
	quit(1)
	assert(false, message)
