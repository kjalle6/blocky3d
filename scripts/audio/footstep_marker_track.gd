extends Resource
## Sprite-sheet equivalent of animation event markers. Cursor is unwrapped
## playback progress in frames, so wrapping and skipped display frames are safe.
@export var frame_count := 6
@export var reverse := false
@export var frames := PackedInt32Array()
@export var feet := PackedStringArray()
@export_enum("run", "walk") var gait := "run"

func contacts_between(previous_cursor: float, cursor: float) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	assert(frames.size() == feet.size())
	for step in range(floori(previous_cursor) + 1, floori(cursor) + 1):
		var displayed_frame := step % frame_count
		if reverse:
			displayed_frame = frame_count - 1 - displayed_frame
		var marker := frames.find(displayed_frame)
		if marker >= 0:
			contacts.append({"foot": feet[marker], "frame": displayed_frame,
				"gait": gait, "cursor": step, "age_frames": cursor - step})
	return contacts
