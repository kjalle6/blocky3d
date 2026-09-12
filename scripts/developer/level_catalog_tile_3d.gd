extends StaticBody3D
## A native 32 px tile with its authored grid cell and reviewed solid silhouette.
var _outline := PackedVector2Array()
var _base_outline := PackedVector2Array()
var _collision: CollisionShape3D
var _flipped := false

func configure(entry: Dictionary) -> void:
	var visual := Sprite3D.new()
	visual.name = "Visual"
	visual.texture = load(entry.image)
	visual.pixel_size = 0.04
	visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	visual.shaded = false
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position.z = 1.04 if entry.solid else 0.94
	visual.render_priority = 0 if entry.solid else -2
	add_child(visual)
	if entry.solid:
		for point in entry.polygon:
			_base_outline.append(Vector2((float(point[0]) - 16) * 0.04, (16 - float(point[1])) * 0.04))
		_collision = CollisionShape3D.new()
		_collision.name = "Collision"
		add_child(_collision)
		_rebuild_shape()

func set_horizontal_flip(flipped: bool) -> void:
	get_node("Visual").flip_h = flipped
	if flipped == _flipped: return
	_flipped = flipped
	_rebuild_shape()

func _rebuild_shape() -> void:
	_outline.clear()
	if _collision == null: return
	var points := PackedVector3Array()
	for point in _base_outline:
		var p := Vector2(-point.x if _flipped else point.x, point.y)
		_outline.append(p)
		points.append(Vector3(p.x, p.y, -1))
		points.append(Vector3(p.x, p.y, 1))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_collision.shape = shape

func layout_floor_y_at(world_x: float) -> float:
	var x := world_x - global_position.x
	var top := -INF
	for i in _outline.size():
		var a := _outline[i]
		var b := _outline[(i + 1) % _outline.size()]
		if x < minf(a.x, b.x) or x > maxf(a.x, b.x): continue
		var y := maxf(a.y, b.y) if is_equal_approx(a.x, b.x) else lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		top = maxf(top, y)
	return top + global_position.y
