extends RefCounted
## One shared session mix across respawns and levels. Only Save writes to disk.
const SETTINGS := preload("res://scripts/audio/movement_audio_settings.gd")
const BANK := preload("res://scripts/audio/footstep_sound_bank.gd")
const EVENTS := preload("res://scripts/audio/sound_event_catalog.gd")
const EVENT_BANK := preload("res://scripts/audio/sound_event_bank.gd")
const DEFAULTS := preload("res://resources/audio/movement_mix.tres")
const SAVE_PATH := "res://resources/audio/movement_mix.tres"
const ASSET_DIRECTORY := "res://assets/audio/tuned"
const REVERB := preload("res://scripts/audio/cave_reverb_settings.gd")
const AMBIENCE := preload("res://scripts/audio/cave_ambience_settings.gd")
const CAVE_BUS := &"CaveSFX"
const PREVIEW_BUS := &"CavePreview"
const ENVIRONMENTS := [&"cave", &"underground"]
const GAMEPLAY_BUSES := {&"cave": CAVE_BUS, &"underground": &"UndergroundSFX"}
const PREVIEW_BUSES := {&"cave": PREVIEW_BUS, &"underground": &"UndergroundPreview"}
const SOURCE_BANKS := {
	"grass/run": preload("res://resources/audio/grass_run.tres"),
	"grass/walk": preload("res://resources/audio/grass_walk.tres"),
	"sand/step": preload("res://resources/audio/sand.tres"),
	"grass/jump_start": preload("res://resources/audio/grass_jump_start.tres"),
	"grass/jump_land": preload("res://resources/audio/grass_jump_land.tres"),
	"sand/jump_start": preload("res://resources/audio/sand_jump_start.tres"),
	"sand/jump_land": preload("res://resources/audio/sand_jump_land.tres"),
}
const SOURCE_EVENT_BANKS := {
	"combat/tank_psychic": preload("res://resources/audio/combat/tank_psychic.tres"),
	"combat/tank_shot": preload("res://resources/audio/combat/tank_shot.tres"),
	"world/tank_tracks": preload("res://resources/audio/combat/tank_tracks.tres"),
	"world/crate_break": preload("res://resources/audio/combat/crate_break.tres"),
	"combat/player_gunshot": preload("res://resources/audio/combat/player_gunshot.tres"),
	"combat/enemy_gunshot": preload("res://resources/audio/combat/enemy_gunshot.tres"),
	"combat/bullet_scenery": preload("res://resources/audio/combat/bullet_scenery.tres"),
	"combat/bullet_character": preload("res://resources/audio/combat/bullet_character.tres"),
	"combat/knife_swing": preload("res://resources/audio/combat/knife_swing.tres"),
	"combat/knife_hit": preload("res://resources/audio/combat/knife_hit.tres"),
	"combat/stomp": preload("res://resources/audio/combat/stomp.tres"),
	"combat/heal": preload("res://resources/audio/combat/heal.tres"),
}
static var working: Dictionary = {}
static var saved: Dictionary = {}
static var working_events: Dictionary = {}
static var saved_events: Dictionary = {}
static var working_reverb: Resource
static var saved_reverb: Resource
static var working_ambience: Resource
static var saved_ambience: Resource
static var working_underground_reverb: Resource
static var saved_underground_reverb: Resource
static var working_underground_ambience: Resource
static var saved_underground_ambience: Resource
static var listening_to_saved := false:
	set(value):
		listening_to_saved = value
		refresh_reverb_buses()

static func initialize(use_project_defaults := true) -> void:
	saved = copy_banks(SOURCE_BANKS)
	for environment in ENVIRONMENTS:
		for kind in ["step", "jump_start", "jump_land"]:
			var bank := BANK.new()
			bank.surface = environment
			bank.gait = StringName(kind)
			if kind == "step":
				bank.foot_indices = {"left": 0, "right": 1}
			saved[str(environment) + "/" + kind] = bank
	if use_project_defaults:
		saved.merge(copy_banks(DEFAULTS.banks), true)
	saved_events = EVENTS.default_banks()
	if use_project_defaults:
		saved_events.merge(copy_banks(SOURCE_EVENT_BANKS), true)
		# Explicit saved choices, including empty banks, remain authoritative.
		saved_events.merge(copy_saved_events(DEFAULTS.event_banks), true)
	working_events = copy_banks(saved_events)
	saved_reverb = DEFAULTS.cave_reverb.duplicate() if use_project_defaults else REVERB.new()
	working_reverb = saved_reverb.duplicate()
	saved_ambience = DEFAULTS.cave_ambience.duplicate() if use_project_defaults else AMBIENCE.new()
	if not saved_ambience.recording_configured:
		# Mixes saved before the picker existed had a fixed cave drip recording.
		saved_ambience.recording = preload("res://assets/audio/ambience/nox_cave_drips_loop.wav")
		saved_ambience.recording_configured = true
	working_ambience = saved_ambience.duplicate()
	saved_underground_reverb = (DEFAULTS.underground_reverb if use_project_defaults else preload("res://resources/audio/underground_reverb.tres")).duplicate()
	working_underground_reverb = saved_underground_reverb.duplicate()
	saved_underground_ambience = (DEFAULTS.underground_ambience if use_project_defaults else preload("res://resources/audio/underground_ambience.tres")).duplicate()
	working_underground_ambience = saved_underground_ambience.duplicate()
	working = copy_banks(saved)
	listening_to_saved = false

static func copy_banks(banks: Dictionary) -> Dictionary:
	var result := {}
	for key in banks:
		var bank: Resource = banks[key].duplicate(false)
		bank.clips = banks[key].clips.duplicate()
		bank.labels = banks[key].labels.duplicate()
		bank.foot_indices = banks[key].foot_indices.duplicate()
		bank.disabled_indices = banks[key].disabled_indices.duplicate()
		result[key] = bank
	return result

static func copy_saved_events(banks: Dictionary) -> Dictionary:
	var result := copy_banks(banks)
	# Older mixes used one forest bank for both levels. Seed Level 2 once,
	# preserving an independently saved Level 2 bank even when it is empty.
	if result.has("ambience/forest") and not result.has("ambience/level_2_forest"):
		result.merge(copy_banks({"ambience/level_2_forest": result["ambience/forest"]}))
	# The old player_death bank covered both surviving damage and death.
	if result.has("combat/player_death") and not result.has("combat/player_hit"):
		result.merge(copy_banks({"combat/player_hit": result["combat/player_death"]}))
	return result

static func bank_for(key: String) -> Resource:
	if working.is_empty():
		initialize()
	return saved.get(key) if listening_to_saved else working.get(key)

static func step_key(surface: String, gait: String) -> String:
	return surface + "/" + (gait if surface == "grass" else "step")

static func event_bank_for(event_id: String) -> Resource:
	if working.is_empty():
		initialize()
	return saved_events.get(event_id) if listening_to_saved else working_events.get(event_id)

static func revert() -> void:
	working = copy_banks(saved)
	working_events = copy_banks(saved_events)
	working_reverb = saved_reverb.duplicate()
	working_ambience = saved_ambience.duplicate()
	working_underground_reverb = saved_underground_reverb.duplicate()
	working_underground_ambience = saved_underground_ambience.duplicate()
	listening_to_saved = false

static func has_changes() -> bool:
	if working_events.size() != saved_events.size():
		return true
	for key in working_events:
		if not saved_events.has(key):
			return true
		for property in EVENT_BANK.MIX_PROPERTIES:
			if working_events[key].get(property) != saved_events[key].get(property):
				return true
	for pair in [[working_ambience, saved_ambience], [working_underground_ambience, saved_underground_ambience]]:
		for property in ["enabled", "volume_db", "recording"]:
			if pair[0].get(property) != pair[1].get(property):
				return true
	for pair in [[working_reverb, saved_reverb], [working_underground_reverb, saved_underground_reverb]]:
		for property in ["enabled", "amount", "room_size", "damping"]:
			if pair[0].get(property) != pair[1].get(property):
				return true
	for key in working:
		if not saved.has(key):
			return true
		for property in ["clips", "volume_db", "foot_indices", "disabled_indices"]:
			if working[key].get(property) != saved[key].get(property):
				return true
	return false

static func load_recording(path: String) -> AudioStream:
	var stream: AudioStream
	match path.get_extension().to_lower():
		"wav": stream = AudioStreamWAV.load_from_file(path)
		"ogg": stream = AudioStreamOggVorbis.load_from_file(path)
		"mp3": stream = AudioStreamMP3.load_from_file(path)
	if stream != null:
		stream.set_meta("source_file", path)
		stream.set_meta("source_sha256", FileAccess.get_sha256(path))
	return stream

static func clip_name(stream: AudioStream) -> String:
	return str(stream.get_meta("source_file", stream.resource_path)).get_file().get_basename()

static func save_defaults(path := SAVE_PATH, asset_directory := ASSET_DIRECTORY) -> Error:
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		return ERR_FILE_BAD_PATH
	# First stage an independent resource. A failed write leaves both the saved
	# comparison and the previous on-disk defaults intact.
	var settings := SETTINGS.new()
	settings.banks = copy_banks(working)
	settings.event_banks = copy_banks(working_events)
	settings.cave_reverb = working_reverb.duplicate()
	settings.cave_ambience = working_ambience.duplicate()
	settings.underground_reverb = working_underground_reverb.duplicate()
	settings.underground_ambience = working_underground_ambience.duplicate()
	var promoted := {}
	for bank: Resource in settings.banks.values() + settings.event_banks.values():
		for index in bank.clips.size():
			bank.clips[index] = _promote_recording(bank.clips[index], asset_directory, promoted)
			if bank.clips[index] == null:
				return ERR_CANT_CREATE
	for environment in ENVIRONMENTS:
		var ambience: Resource = settings.get(str(environment) + "_ambience")
		if ambience.recording != null:
			ambience.recording = _promote_recording(ambience.recording, asset_directory, promoted)
			if ambience.recording == null:
				return ERR_CANT_CREATE
	var pending := path.get_basename() + ".pending.tres"
	var error := ResourceSaver.save(settings, pending)
	if error != OK:
		return error
	var verification := ResourceLoader.load(pending, "", ResourceLoader.CACHE_MODE_IGNORE)
	if verification == null or verification.banks.size() != settings.banks.size():
		return ERR_FILE_CORRUPT
	if verification.event_banks.size() != settings.event_banks.size():
		return ERR_FILE_CORRUPT
	for key in settings.event_banks:
		var expected: Resource = settings.event_banks[key]
		var actual: Resource = verification.event_banks.get(key)
		if actual == null or actual.clips.size() != expected.clips.size():
			return ERR_FILE_CORRUPT
		for property in EVENT_BANK.MIX_PROPERTIES:
			if property != "clips" and actual.get(property) != expected.get(property):
				return ERR_FILE_CORRUPT
		for index in expected.clips.size():
			if actual.clips[index].resource_path != expected.clips[index].resource_path:
				return ERR_FILE_CORRUPT
	for environment in ENVIRONMENTS:
		for suffix in ["_reverb", "_ambience"]:
			var expected: Resource = settings.get(str(environment) + suffix)
			var actual: Resource = verification.get(str(environment) + suffix)
			var properties := ["enabled", "amount", "room_size", "damping"] if suffix == "_reverb" else ["enabled", "volume_db"]
			for property in properties:
				if actual.get(property) != expected.get(property):
					return ERR_FILE_CORRUPT
			if suffix == "_ambience":
				if (expected.recording == null) != (actual.recording == null):
					return ERR_FILE_CORRUPT
				if expected.recording != null and actual.recording.resource_path != expected.recording.resource_path:
					return ERR_FILE_CORRUPT
	error = DirAccess.rename_absolute(pending, path)
	if error != OK:
		return error
	saved = copy_banks(settings.banks)
	working = copy_banks(saved)
	saved_events = copy_banks(settings.event_banks)
	working_events = copy_banks(saved_events)
	saved_reverb = settings.cave_reverb.duplicate()
	working_reverb = saved_reverb.duplicate()
	saved_ambience = settings.cave_ambience.duplicate()
	working_ambience = saved_ambience.duplicate()
	saved_underground_reverb = settings.underground_reverb.duplicate()
	working_underground_reverb = saved_underground_reverb.duplicate()
	saved_underground_ambience = settings.underground_ambience.duplicate()
	working_underground_ambience = saved_underground_ambience.duplicate()
	listening_to_saved = false
	return OK

static func _promote_recording(stream: AudioStream, asset_directory: String, promoted: Dictionary) -> AudioStream:
	if not stream.resource_path.is_empty():
		return stream
	if not stream.has_meta("source_sha256"):
		return null
	var hash: String = stream.get_meta("source_sha256")
	var target := asset_directory.path_join(clip_name(stream).validate_filename() + "_" + hash.left(12) + ".res")
	if not promoted.has(target):
		if DirAccess.make_dir_recursive_absolute(asset_directory) != OK:
			return null
		# Persist only selected audio, including ambience, without an import step.
		if ResourceSaver.save(stream, target, ResourceSaver.FLAG_COMPRESS) != OK:
			return null
		promoted[target] = ResourceLoader.load(target, "AudioStream", ResourceLoader.CACHE_MODE_IGNORE)
	return promoted[target]

static func ambience_settings(environment: StringName = &"cave") -> Resource:
	if working_ambience == null:
		initialize()
	if environment == &"underground":
		return saved_underground_ambience if listening_to_saved else working_underground_ambience
	return saved_ambience if listening_to_saved else working_ambience

static func reverb_settings(environment: StringName = &"cave") -> Resource:
	if working_reverb == null:
		initialize()
	if environment == &"underground":
		return saved_underground_reverb if listening_to_saved else working_underground_reverb
	return saved_reverb if listening_to_saved else working_reverb

static func environment_for(source: Node) -> StringName:
	# The room owns its acoustics. A grass patch inside a cave reverberates;
	# a stone platform outdoors does not. A closer ancestor can override it.
	var node := source
	while node != null:
		var selected: Node3D
		if source is Node3D:
			for child in node.get_children():
				if child.is_in_group("audio_environment_region") and child.contains_world_position(source.global_position):
					if selected == null or child.priority > selected.priority:
						selected = child
		if selected != null:
			return selected.environment
		if node.has_meta("audio_environment"):
			return StringName(node.get_meta("audio_environment"))
		node = node.get_parent()
	return &"outdoors"

static func bus_for_source(source: Node) -> StringName:
	var environment := environment_for(source)
	if GAMEPLAY_BUSES.has(environment):
		var bus: StringName = GAMEPLAY_BUSES[environment]
		_ensure_reverb_bus(bus)
		return bus
	return &"Master"

static func preview_bus(environment: StringName) -> StringName:
	if PREVIEW_BUSES.has(environment):
		var bus: StringName = PREVIEW_BUSES[environment]
		_ensure_reverb_bus(bus)
		return bus
	return &"Master"

static func _ensure_reverb_bus(bus: StringName) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
		AudioServer.add_bus_effect(index, AudioEffectReverb.new())
	_apply_reverb(AudioServer.get_bus_effect(index, 0) as AudioEffectReverb, _bus_environment(bus))
	return index

static func _bus_environment(bus: StringName) -> StringName:
	return &"underground" if bus in [GAMEPLAY_BUSES[&"underground"], PREVIEW_BUSES[&"underground"]] else &"cave"

static func _apply_reverb(effect: AudioEffectReverb, environment: StringName) -> void:
	var settings := reverb_settings(environment)
	# Preserve the contact transient at unity gain. Short early reflections
	# add room without shifting the animation/physical event or source audio.
	effect.dry = 1.0
	effect.wet = settings.amount if settings.enabled else 0.0
	effect.room_size = settings.room_size
	effect.damping = settings.damping
	effect.predelay_msec = 18.0
	effect.predelay_feedback = 0.0

static func refresh_reverb_buses() -> void:
	if working_reverb == null:
		return
	for bus in GAMEPLAY_BUSES.values() + PREVIEW_BUSES.values():
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			_apply_reverb(AudioServer.get_bus_effect(index, 0) as AudioEffectReverb, _bus_environment(bus))

static func clear_reverb_tail(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	# Stopping a voice does not empty the bus effect's internal delay buffers.
	AudioServer.remove_bus_effect(index, 0)
	AudioServer.add_bus_effect(index, AudioEffectReverb.new(), 0)
	_apply_reverb(AudioServer.get_bus_effect(index, 0) as AudioEffectReverb, _bus_environment(bus))

static func clear_preview_tails() -> void:
	for bus in PREVIEW_BUSES.values():
		clear_reverb_tail(bus)

static func clear_gameplay_tails() -> void:
	for bus in GAMEPLAY_BUSES.values():
		clear_reverb_tail(bus)

static func mute_gameplay_reverb() -> Dictionary:
	var previous := {}
	for bus in GAMEPLAY_BUSES.values():
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			previous[bus] = AudioServer.is_bus_mute(index)
			AudioServer.set_bus_mute(index, true)
	return previous

static func restore_gameplay_reverb(previous: Dictionary) -> void:
	for bus in previous:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_mute(index, previous[bus])
