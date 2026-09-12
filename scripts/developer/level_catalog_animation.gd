extends Sprite3D
## Visual-only pack animation. All frames share the same crop and ground anchor.
var _frames: Array[AtlasTexture] = []
var _fps := 8.0
var _loop := true
var _time := 0.0

func configure(entry: Dictionary) -> void:
	var sheet := load(entry.image) as Texture2D
	var count := int(entry.frames)
	var frame_width := int(entry.get("frame_width", sheet.get_width() / count))
	var r: Array = entry.frame_region
	for i in count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(i * frame_width + float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		_frames.append(frame)
	_fps = entry.fps
	_loop = entry.loop
	texture = _frames[0]

func _process(delta: float) -> void:
	_time += delta
	var index := int(_time * _fps)
	index = index % _frames.size() if _loop else mini(index, _frames.size() - 1)
	texture = _frames[index]
