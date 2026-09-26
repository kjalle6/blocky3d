extends Node3D
## Level-owned one-shots. Voices overlap through their natural tails, and are
## freed with the level rather than with the bullet or defeated character.
signal event_played(event: Dictionary)

const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const PLAYBACK := preload("res://scripts/audio/sound_event_voice.gd")
const VOICE_COUNT := 24

var _voices: Array[AudioStreamPlayer3D] = []
var _random := RandomNumberGenerator.new()
var _previous_choices: Dictionary = {}
var _next_voice := 0
var played_count := 0
var last_event: Dictionary = {}


func _ready() -> void:
	_random.randomize()
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "CombatVoice%d" % index
		# The side-view camera supplies left/right placement. Its staging depth
		# must not make a close-up louder or the normal gameplay camera quieter.
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.panning_strength = 0.6
		add_child(voice)
		_voices.append(voice)


func play_event(event_id: String, world_position: Vector3) -> bool:
	var bank: Resource = MIX.event_bank_for(event_id)
	if bank == null:
		return false
	var selected: int = bank.choose_clip(_random, int(_previous_choices.get(event_id, -1)))
	if selected < 0:
		return false
	var voice: AudioStreamPlayer3D
	for offset in VOICE_COUNT:
		var index := (_next_voice + offset) % VOICE_COUNT
		if not _voices[index].playing:
			voice = _voices[index]
			_next_voice = (index + 1) % VOICE_COUNT
			break
	if voice == null:
		# A bounded pool prevents runaway layering. Only saturation replaces an
		# old tail; ordinary rapid fire never restarts its preceding recording.
		voice = _voices[_next_voice]
		_next_voice = (_next_voice + 1) % VOICE_COUNT
		voice.stop()
	_previous_choices[event_id] = selected
	# The first-weapon showcase pauses the world immediately on collection.
	# Let this pickup cue finish through the menu, using the same selected bank.
	voice.process_mode = Node.PROCESS_MODE_ALWAYS if event_id == "pickups/handgun" else Node.PROCESS_MODE_INHERIT
	voice.global_position = world_position
	voice.stream = PLAYBACK.playback_copy(bank.clips[selected], false)
	voice.volume_db = bank.volume_db
	voice.pitch_scale = bank.choose_pitch(_random)
	voice.bus = MIX.bus_for_source(voice) if bank.use_room_reverb else &"Master"
	voice.play()
	played_count += 1
	last_event = {"id": event_id, "clip_index": selected, "position": world_position,
		"volume_db": voice.volume_db, "pitch": voice.pitch_scale, "bus": voice.bus}
	event_played.emit(last_event.duplicate())
	return true


func active_voice_count() -> int:
	var count := 0
	for voice in _voices:
		if voice.playing:
			count += 1
	return count


func reset_run() -> void:
	for voice in _voices:
		voice.stop()
	_previous_choices.clear()
	_next_voice = 0
	MIX.clear_gameplay_tails()
