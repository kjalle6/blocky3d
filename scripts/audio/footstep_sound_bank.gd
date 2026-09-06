extends Resource
## Recordings and mix settings for one surface/gait; selection state belongs
## to the player, never this shared resource.
@export var surface: StringName
@export var gait: StringName
@export var clips: Array[AudioStream] = []
@export var labels := PackedStringArray()
## Optional fixed clip per animation foot; empty leaves selection to the player.
@export var foot_indices: Dictionary = {}
@export var volume_db := -10.0
## Disabled entries remain available in the listening panel.
@export var disabled_indices := PackedInt32Array()

func choose_clip(random: RandomNumberGenerator, previous := -1, foot := "") -> int:
	if not foot_indices.is_empty():
		var index := int(foot_indices.get(foot, -1))
		return index if index >= 0 and index < clips.size() and clips[index] != null and not index in disabled_indices else -1
	var choices: Array[int] = []
	for index in clips.size():
		if clips[index] != null and not index in disabled_indices:
			choices.append(index)
	if choices.size() > 1:
		choices.erase(previous)
	return choices[random.randi_range(0, choices.size() - 1)] if not choices.is_empty() else -1
