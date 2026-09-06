extends Node
## Ground takeoff and touchdown contacts, independent of sprite frames and steps.
signal contact_played(event: Dictionary)
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const SURFACES := preload("res://scripts/audio/footstep_surface_resolver.gd")
const START_BANKS := {
	"grass": preload("res://resources/audio/grass_jump_start.tres"),
	"sand": preload("res://resources/audio/sand_jump_start.tres"),
}
const LAND_BANKS := {
	"grass": preload("res://resources/audio/grass_jump_land.tres"),
	"sand": preload("res://resources/audio/sand_jump_land.tres"),
}
const VOICE_COUNT := 4
const MIN_LANDING_AIR_TIME := 0.05
const MIN_LANDING_SPEED := 1.5

var _voices: Array[AudioStreamPlayer] = []
var _random := RandomNumberGenerator.new()
var _previous_choices: Dictionary = {}
var _last_ground: Dictionary = {}
var _has_support := false
var _air_time := 0.0
var played_count := 0
var last_event: Dictionary = {}
var history: Array[Dictionary] = []
@onready var player := get_parent() as PlayerCharacter

func _ready() -> void:
	_random.randomize()
	player.ground_jump_started.connect(_on_ground_jump_started)
	player.landed.connect(_on_landed)
	player.movement_reset.connect(reset_run)
	player.death_started.connect(_on_death)
	add_to_group("run_resettable")
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "JumpContactVoice%d" % index
		add_child(voice)
		_voices.append(voice)

func _physics_process(delta: float) -> void:
	if not _can_play():
		_clear_support()
		if player.is_developer_inspection_enabled():
			_stop_voices()
		return
	if player.is_on_floor():
		var ground := SURFACES.sample(player)
		if ground.get("collider", "none") != "none":
			_last_ground = ground
		_has_support = true
		_air_time = 0.0
	elif _has_support:
		_air_time += delta

func _can_play() -> bool:
	return not player.is_dead() and not player.is_developer_inspection_enabled() and not player.is_transition_running()

func _on_ground_jump_started() -> void:
	if not _can_play():
		return
	var ground: Dictionary
	if player.is_on_floor():
		ground = SURFACES.sample(player)
		if ground.get("collider", "none") == "none" and _has_support:
			ground = _last_ground
	elif _has_support and _air_time <= player.movement.coyote_time:
		# A coyote jump uses the floor just left, not geometry below the gap.
		ground = _last_ground
	else:
		return
	_play_contact(MIX.bank_for(str(ground.get("surface", "silent")) + "/jump_start"), ground)

func _on_landed(impact_speed: float) -> void:
	# Spawn settling and tiny floor-snap changes are not audible landings.
	var real_landing := _has_support and _air_time >= MIN_LANDING_AIR_TIME and impact_speed >= MIN_LANDING_SPEED
	_air_time = 0.0
	if _can_play() and real_landing:
		var ground := SURFACES.sample(player)
		_play_contact(MIX.bank_for(str(ground.get("surface", "silent")) + "/jump_land"), ground)

func _play_contact(bank: Resource, ground: Dictionary) -> void:
	if bank == null or ground.get("surface", "silent") != str(bank.surface):
		return
	var voice: AudioStreamPlayer
	for available in _voices:
		if not available.playing:
			voice = available
			break
	if voice == null:
		return
	var key := str(bank.surface) + "/" + str(bank.gait)
	var previous := int(_previous_choices.get(key, -1))
	var selected: int = bank.choose_clip(_random, previous)
	if selected < 0:
		return
	_previous_choices[key] = selected
	voice.stream = bank.clips[selected]
	voice.pitch_scale = 1.0
	voice.volume_db = bank.volume_db
	voice.bus = MIX.bus_for_source(player)
	voice.play()
	played_count += 1
	last_event = ground.duplicate()
	last_event.merge({"kind": str(bank.gait), "clip": voice.stream.resource_path.get_file()}, true)
	history.append(last_event.duplicate())
	if history.size() > 20:
		history.pop_front()
	contact_played.emit(last_event.duplicate())

func _clear_support() -> void:
	_has_support = false
	_last_ground.clear()
	_air_time = 0.0

func _stop_voices() -> void:
	for voice in _voices:
		voice.stop()

func _on_death(_kind: StringName, _position: Vector3) -> void:
	reset_run()

func reset_run() -> void:
	_stop_voices()
	_clear_support()
