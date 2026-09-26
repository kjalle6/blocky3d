extends "res://scripts/audio/footstep_sound_bank.gd"
## Settings only. The caller owns the current voice and random-selection history.
const MIX_PROPERTIES := ["clips", "labels", "volume_db", "disabled_indices", "enabled", "selection_mode", "fixed_index", "looping", "pitch_scale", "pitch_variation", "use_room_reverb", "repeat_interval"]
@export var enabled := true
@export_enum("Random pool", "Fixed recording") var selection_mode := 0
@export var fixed_index := -1
@export var looping := false
@export_range(0.5, 2.0, 0.01) var pitch_scale := 1.0
@export_range(0.0, 0.2, 0.01) var pitch_variation := 0.0
@export var use_room_reverb := true
@export_range(0.1, 10.0, 0.1) var repeat_interval := 1.0

func choose_clip(random: RandomNumberGenerator, previous := -1, foot := "") -> int:
	if not enabled:
		return -1
	if selection_mode == 1:
		return fixed_index if fixed_index >= 0 and fixed_index < clips.size() and clips[fixed_index] != null and not fixed_index in disabled_indices else -1
	return super.choose_clip(random, previous, foot)

func choose_pitch(random: RandomNumberGenerator) -> float:
	return clampf(pitch_scale + random.randf_range(-pitch_variation, pitch_variation), 0.5, 2.0)

func has_playable_recording() -> bool:
	if not enabled: return false
	if selection_mode == 1:
		return fixed_index >= 0 and fixed_index < clips.size() and clips[fixed_index] != null and not fixed_index in disabled_indices
	for index in clips.size():
		if clips[index] != null and not index in disabled_indices: return true
	return false
