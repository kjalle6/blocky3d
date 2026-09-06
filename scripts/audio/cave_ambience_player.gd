extends AudioStreamPlayer
## One continuous bed for the current room or the tuning panel's listening space.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const BUS := &"Ambience"
const FADE_SECONDS := 0.4
var _presence := 0.0
var _source: AudioStream
var _environment: StringName = &"cave"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, &"Master")
	bus = BUS
	volume_db = -80.0

func _process(delta: float) -> void:
	var game := get_parent()
	var panel: CanvasLayer = game.audio_tuning_panel
	var environment: StringName = &"outdoors"
	if panel != null and panel.is_open:
		environment = panel.listening_environment()
	elif game.current_level != null:
		environment = MIX.environment_for(game.current_level.player)
	var desired: AudioStream
	if environment in MIX.ENVIRONMENTS:
		var settings := MIX.ambience_settings(environment)
		if settings.enabled:
			desired = settings.recording
	# Fade the current recording out before replacing it; never restart a bed
	# simply because contacts, a bank, the panel, or a respawn changed.
	var replacing := desired != _source
	var active := desired != null and not replacing
	_presence = move_toward(_presence, 1.0 if active else 0.0, delta / FADE_SECONDS)
	if is_zero_approx(_presence) and replacing:
		stop()
		_source = desired
		_environment = environment
		stream = _looping_copy(desired) if desired != null else null
		if desired != null:
			_presence = minf(delta / FADE_SECONDS, 1.0)
	elif not replacing:
		_environment = environment
	if _presence > 0.0:
		volume_db = MIX.ambience_settings(_environment).volume_db + linear_to_db(_presence)
		if not playing:
			play()
	elif playing:
		stop()

func _looping_copy(recording: AudioStream) -> AudioStream:
	# Loop inside the audio mixer rather than waiting for a finished callback.
	var loop: AudioStream = recording.duplicate()
	if loop is AudioStreamWAV:
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	elif loop is AudioStreamOggVorbis or loop is AudioStreamMP3:
		loop.loop = true
		loop.loop_offset = 0.0
	return loop
