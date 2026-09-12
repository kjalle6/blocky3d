extends AudioStreamPlayer
## Explicit start/stop playback for the panel and future gameplay owners.
## This component does not subscribe to any gameplay events itself.
var last_pitch := 1.0

func play_recording(bank: Resource, index: int, random: RandomNumberGenerator, output_bus: StringName) -> bool:
	if index < 0 or index >= bank.clips.size() or bank.clips[index] == null:
		return false
	stop()
	stream = playback_copy(bank.clips[index], bank.looping)
	volume_db = bank.volume_db
	last_pitch = bank.choose_pitch(random)
	pitch_scale = last_pitch
	bus = output_bus
	play()
	return true

static func playback_copy(recording: AudioStream, should_loop: bool) -> AudioStream:
	# Never mutate the saved stream (it may also be used by another event).
	var copy: AudioStream = recording.duplicate()
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
		copy.loop_begin = 0
		copy.loop_end = roundi(copy.get_length() * copy.mix_rate)
	elif copy is AudioStreamOggVorbis or copy is AudioStreamMP3:
		copy.loop = should_loop
		copy.loop_offset = 0.0
	return copy
