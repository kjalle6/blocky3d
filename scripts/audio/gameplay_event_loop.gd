extends Node
## One bank-backed continuous sound. Empty/muted banks own no playing voice.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const PLAYBACK := preload("res://scripts/audio/sound_event_voice.gd")
var positional := true
var voice: Node
var event_id := ""
var _selection: Array = []
var _previous := -1
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	if positional:
		voice = AudioStreamPlayer3D.new()
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.panning_strength = 0.6
	else:
		voice = AudioStreamPlayer.new()
	add_child(voice)

func sync(next_event: String, active: bool, source: Node3D = null) -> void:
	if not active or next_event.is_empty():
		stop()
		return
	var bank: Resource = MIX.event_bank_for(next_event)
	if bank == null:
		stop()
		return
	var selection: Array = [next_event, bank.enabled, bank.selection_mode, bank.fixed_index,
		bank.clips.duplicate(), bank.disabled_indices.duplicate(), bank.pitch_scale, bank.pitch_variation]
	if selection != _selection:
		voice.stop()
		_selection = selection
		event_id = next_event
		var index: int = bank.choose_clip(_random, _previous)
		voice.stream = null if index < 0 else PLAYBACK.playback_copy(bank.clips[index], true)
		if index >= 0:
			_previous = index
			voice.pitch_scale = bank.choose_pitch(_random)
	voice.volume_db = bank.volume_db
	voice.bus = MIX.bus_for_source(source) if bank.use_room_reverb and is_instance_valid(source) else &"Master"
	if positional and is_instance_valid(source):
		voice.global_position = source.global_position
	if voice.stream != null and not voice.playing:
		voice.play()

func stop() -> void:
	if voice != null:
		voice.stop()
	_selection.clear()
	event_id = ""

func is_playing() -> bool:
	return voice != null and voice.playing
