extends Control
## Projection and cheap gesture outlines; geometry changes once on release.
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const TILE := 1.28
var designer: CanvasLayer
var hover := ""
var locked_hover := ""
var gesture := ""
var _start_screen := Vector2.ZERO
var _last_screen := Vector2.ZERO
var _start_world := Vector2.ZERO
var _before: Dictionary = {}
var _preview: Dictionary = {}
var _moved := false
var _clicked_selected := false
var _additive := false
var _hits: Array[String] = []
var _handles: Dictionary = {}
var _paint_occupants: Dictionary = {}
var _paint_ids: Dictionary = {}
var _last_cell := Vector2i.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready(): cancel_gesture()

func world_at(point: Vector2) -> Vector2:
	var camera: Camera3D = designer.camera
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var world := origin + direction * (-origin.z / direction.z)
	return Vector2(world.x, world.y)

func screen_at(point: Vector2) -> Vector2:
	return designer.camera.unproject_position(Vector3(point.x, point.y, 0.0))

func screen_rect(rect: Rect2) -> Rect2:
	var a := screen_at(rect.position)
	var b := screen_at(rect.end)
	return Rect2(a.min(b), (a - b).abs())

func hit_objects(point: Vector2) -> Array[String]:
	var result: Array[String] = []
	for id in designer.document.working:
		if screen_rect(OBJECTS.bounds(designer.document.working[id])).grow(5.0).has_point(point): result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool:
		return OBJECTS.bounds(designer.document.working[a]).get_area() < OBJECTS.bounds(designer.document.working[b]).get_area())
	return result

func _gui_input(event: InputEvent) -> void:
	if not designer.is_editing() or designer.camera == null or designer.dialog_open() or designer.object_browser.visible: return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			_zoom(event.position, 0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				cancel_gesture()
				gesture = "pan"
				_last_screen = event.position
			else: cancel_gesture()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if designer.cancel_placement():
				cancel_gesture()
				designer.panel.refresh()
				designer.set_status("Placement cancelled")
			elif not cancel_gesture(): open_context_menu(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _press(event.position, event.shift_pressed)
			else: _release(event.position)
			accept_event()
	elif event is InputEventMouseMotion:
		_motion(event.position)
		accept_event()

func open_context_menu(point: Vector2) -> void:
	grab_focus()
	var hits := hit_objects(point)
	var selected_hit := false
	for id in designer.selection:
		if id in hits:
			selected_hit = true
			break
	# Keep a group when clicking one of its members; otherwise target the
	# clicked object, never an unrelated previous selection.
	if not selected_hit: designer.choose(hits[0] if not hits.is_empty() else "")
	var protected_id := _locked_at(point) if hits.is_empty() else ""
	designer.context_menu.open_at(point, protected_id)

func _press(point: Vector2, additive: bool) -> void:
	grab_focus()
	_start_screen = point
	_last_screen = point
	_start_world = world_at(point)
	_moved = false
	_additive = additive
	_before = designer.document.working.duplicate(true)
	_preview = {}
	if designer.tool == "place":
		gesture = "place"
		designer.update_placement(_start_world)
		if designer._placement_record.kind == "tile":
			gesture = "paint"
			_preview = _before.duplicate(true)
			_paint_occupants.clear()
			_paint_ids.clear()
			for id in _before:
				var record: Dictionary = _before[id]
				if record.kind != "tile": continue
				var cell := Vector2i((Vector2(record.values.x, record.values.y) / TILE - Vector2.ONE * 0.5).round())
				if (Vector2(cell) * TILE + Vector2.ONE * TILE * 0.5).distance_to(Vector2(record.values.x, record.values.y)) < 0.001:
					_paint_occupants[_paint_key(cell, designer.CATALOG.ENTRIES[record.template].solid)] = id
			_last_cell = Vector2i((_start_world / TILE).floor())
			_paint_at(_start_world)
		return
	for key in _handles:
		if _handles[key].distance_to(point) < 10.0:
			gesture = key
			return
	_hits = hit_objects(point)
	if _hits.is_empty():
		if not additive: designer.choose("")
		locked_hover = _locked_at(point)
		if not locked_hover.is_empty(): designer.set_status(designer.locked[locked_hover].reason)
		queue_redraw()
		return
	var id := _hits[0]
	for selected in designer.selection:
		if selected in _hits:
			id = selected
			break
	_clicked_selected = id in designer.selection
	if not _clicked_selected or additive: designer.choose(id, additive)
	if not designer.selection.is_empty(): gesture = "move"
	queue_redraw()

func _motion(point: Vector2) -> void:
	if designer.tool == "place" and gesture != "pan":
		designer.update_placement(world_at(point))
		if gesture == "paint": _paint_at(world_at(point))
		return
	if gesture == "pan":
		var offset := world_at(_last_screen) - world_at(point)
		designer.camera.position += Vector3(offset.x, offset.y, 0.0)
		_last_screen = point
		designer.refresh_presentation()
		return
	if gesture.is_empty():
		var hits := hit_objects(point)
		hover = hits[0] if not hits.is_empty() else ""
		locked_hover = _locked_at(point) if hover.is_empty() else ""
		queue_redraw()
		return
	_moved = _moved or point.distance_to(_start_screen) >= 4.0
	if not _moved: return
	var current := world_at(point)
	if gesture.begins_with("move"):
		var offset := current - _start_world
		var anchor := OBJECTS.bounds(_before[designer.selection[0]]).position
		if designer.snap > 0.0:
			offset = (anchor + offset).snapped(Vector2.ONE * designer.snap) - anchor
		if gesture == "move_x": offset.y = 0.0
		if gesture == "move_y": offset.x = 0.0
		_preview = _before.duplicate(true)
		for id in designer.selection:
			_preview[id].values.x += offset.x
			_preview[id].values.y += offset.y
	elif gesture.begins_with("patrol_"):
		_preview = _before.duplicate(true)
		var record: Dictionary = _preview[designer.selection[0]]
		var x: float = record.values.x + record.offset.x
		var distance: float = x - current.x if gesture == "patrol_left" else current.x - x
		if designer.snap > 0.0: distance = snappedf(distance, designer.snap)
		record.values[gesture.trim_prefix("patrol_")] = clampf(distance, 0.04, 50.0)
	else:
		_resize(current)
	queue_redraw()

func _resize(current: Vector2) -> void:
	_preview = _before.duplicate(true)
	var record: Dictionary = _preview[designer.selection[0]]
	var bounds := OBJECTS.bounds(record)
	var step: float = TILE if record.kind == "platform" else designer.snap
	var minimum: float = TILE if record.kind == "platform" else 2.56 if record.kind == "scaffold" else 0.6 if record.kind == "spikes" else 0.1
	var left := bounds.position.x
	var right := bounds.end.x
	var bottom := bounds.position.y
	var top := bounds.end.y
	# Snap the changed dimension relative to the fixed opposite edge. Existing
	# half-tile offsets stay intact even when dimensions are whole tiles.
	match gesture:
		"left":
			var width := maxf(minimum, right - current.x)
			left = right - (maxf(minimum, snappedf(width, step)) if step > 0.0 else width)
		"right":
			var width := maxf(minimum, current.x - left)
			right = left + (maxf(minimum, snappedf(width, step)) if step > 0.0 else width)
		"bottom":
			var height := maxf(minimum, top - current.y)
			bottom = top - (maxf(minimum, snappedf(height, step)) if step > 0.0 else height)
		"top":
			var height := maxf(minimum, current.y - bottom)
			top = bottom + (maxf(minimum, snappedf(height, step)) if step > 0.0 else height)
	record.values.width = right - left
	record.values.x = (left + right) * 0.5 - record.offset.x
	if record.kind != "spikes":
		record.values.height = top - bottom
		record.values.y = ((top + bottom) * 0.5 if record.kind == "platform" else bottom) - record.offset.y

func _release(point: Vector2) -> void:
	if gesture.is_empty(): return
	if gesture == "paint":
		_paint_at(world_at(point))
		var painted: bool = designer.commit_records("Paint tiles", _preview)
		if painted:
			designer.set_status("Built %d blocks · Keep clicking or dragging · Right-click / Esc to finish · Ctrl+Z to undo" % _paint_ids.size())
	elif gesture == "place":
		designer.place_catalog_object(world_at(point), _additive)
	elif _moved and not _preview.is_empty():
		designer.commit_records("Move selection" if gesture.begins_with("move") else "Set patrol limit" if gesture.begins_with("patrol") else "Resize object", _preview)
	elif gesture == "move" and _clicked_selected and not _additive:
		# A repeated click cycles overlapping objects without affecting a drag.
		var hits := hit_objects(point)
		if hits.size() > 1:
			var current: String = designer.selection[0] if not designer.selection.is_empty() else hits[0]
			designer.choose(hits[(hits.find(current) + 1) % hits.size()])
	cancel_gesture()

func cancel_gesture() -> bool:
	var was_active := not gesture.is_empty()
	gesture = ""
	_before.clear()
	_preview.clear()
	_paint_occupants.clear()
	_paint_ids.clear()
	_moved = false
	queue_redraw()
	return was_active

func _paint_at(point: Vector2) -> void:
	var cell := Vector2i((point / TILE).floor())
	var distance := cell - _last_cell
	var steps := maxi(absi(distance.x), absi(distance.y))
	for i in mini(steps + 1, 513):
		if _paint_ids.size() >= 512: break
		var next := Vector2i(Vector2(_last_cell).lerp(Vector2(cell), float(i) / maxf(steps, 1)).round())
		var entry: Dictionary = designer.CATALOG.ENTRIES[designer._placement_record.template]
		var key := _paint_key(next, entry.solid)
		var id: String = _paint_occupants.get(key, "")
		if id.is_empty():
			id = "object_" + Crypto.new().generate_random_bytes(12).hex_encode()
			_paint_occupants[key] = id
		var record: Dictionary = designer._placement_record.duplicate(true)
		var center := Vector2(next) * TILE + Vector2.ONE * TILE * 0.5
		record.values.x = center.x
		record.values.y = center.y
		_preview[id] = record
		_paint_ids[id] = true
	_last_cell = cell
	queue_redraw()

func _paint_key(cell: Vector2i, solid: bool) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, int(solid)]

func _zoom(point: Vector2, factor: float) -> void:
	if not gesture.is_empty(): return
	var before := world_at(point)
	designer.camera.size = clampf(designer.camera.size * factor, 6.0, 180.0)
	var offset := before - world_at(point)
	designer.camera.position += Vector3(offset.x, offset.y, 0)
	designer.refresh_presentation()

func _locked_at(point: Vector2) -> String:
	for id in designer.locked:
		if screen_rect(designer.locked[id].bounds).has_point(point): return id
	return ""

func _draw() -> void:
	if not designer.is_editing() or designer.camera == null or designer.document == null: return
	_draw_grid()
	if gesture == "paint":
		for id in _paint_ids:
			var painted: Dictionary = _preview[id]
			var rect := screen_rect(OBJECTS.bounds(painted))
			if rect.intersects(Rect2(Vector2.ZERO, size)):
				draw_texture_rect(designer.CATALOG.icon(painted.template), rect, false, Color(1, 1, 1, 0.65))
				draw_rect(rect, Color("65ffd0"), false)
	var records: Dictionary = designer.document.working if _preview.is_empty() else _preview
	_handles.clear()
	for id in records:
		var record: Dictionary = records[id]
		var rect := screen_rect(OBJECTS.bounds(record))
		if not rect.intersects(Rect2(Vector2.ZERO, size)): continue
		var selected: bool = id in designer.selection
		var color := Color("65ffd0") if selected else Color("addbed")
		if selected or id == hover or record.kind == "checkpoint":
			draw_rect(rect, Color(color, 0.12), true)
			draw_rect(rect, color, false, 2.0 if selected else 1.0)
			if selected or id == hover: _text(rect.position + Vector2(0, -9), record.name, color)
		if selected and designer.selection.size() == 1:
			_draw_handles(record, rect)
	if designer.selection.size() > 1:
		var center := Vector2.ZERO
		for id in designer.selection: center += screen_rect(OBJECTS.bounds(records[id])).get_center()
		_draw_move_handles(center / designer.selection.size())
	if not locked_hover.is_empty() and designer.locked.has(locked_hover):
		var rect := screen_rect(designer.locked[locked_hover].bounds)
		draw_rect(rect, Color("bdabb4"), false, 1.0)
		_text(rect.position + Vector2(0, -8), "Protected · " + designer.locked[locked_hover].name, Color("dfc6a4"))
	if designer.tool == "place" and not designer._placement_record.is_empty():
		var rect := screen_rect(OBJECTS.bounds(designer._placement_record))
		draw_rect(rect, Color("73ffbc"), false, 2.0)
		_text(rect.position + Vector2(0, -10), "Place " + designer._placement_record.name, Color("73ffbc"))
	var mouse := get_local_mouse_position()
	if Rect2(Vector2.ZERO, size).has_point(mouse):
		var point := world_at(mouse)
		_text(Vector2(24, size.y - 92), "X %.2f   Y %.2f   ·   Middle mouse: pan  ·  Wheel: zoom" % [point.x, point.y], Color("b3d6e4"))

func _draw_grid() -> void:
	var a := world_at(Vector2(0, size.y))
	var b := world_at(Vector2(size.x, 0))
	var step := 0.64 if designer.camera.size < 22.0 else TILE if designer.camera.size < 70.0 else TILE * 5.0
	if designer._placement_record.get("kind", "") == "tile" and designer.camera.size < 70.0: step = TILE
	for index in range(floori(a.x / step), ceili(b.x / step) + 1):
		var x := index * step
		draw_line(screen_at(Vector2(x, a.y)), screen_at(Vector2(x, b.y)), Color(0.45, 0.8, 0.95, 0.10 if index % 2 else 0.18), 1.0)
	for index in range(floori(a.y / step), ceili(b.y / step) + 1):
		var y := index * step
		draw_line(screen_at(Vector2(a.x, y)), screen_at(Vector2(b.x, y)), Color(0.45, 0.8, 0.95, 0.10 if index % 2 else 0.18), 1.0)
	if a.y <= 0.0 and b.y >= 0.0:
		draw_line(screen_at(Vector2(a.x, 0)), screen_at(Vector2(b.x, 0)), Color(0.5, 1.0, 0.8, 0.55), 2.0)

func _draw_handles(record: Dictionary, rect: Rect2) -> void:
	if record.kind in ["platform", "scaffold", "spikes", "checkpoint"]:
		_handles.left = Vector2(rect.position.x, rect.get_center().y)
		_handles.right = Vector2(rect.end.x, rect.get_center().y)
		if record.kind != "spikes":
			_handles.top = Vector2(rect.get_center().x, rect.position.y)
			_handles.bottom = Vector2(rect.get_center().x, rect.end.y)
		for key in _handles:
			var box := Rect2(_handles[key] - Vector2.ONE * 5, Vector2.ONE * 10)
			draw_rect(box, Color("102938"))
			draw_rect(box, Color("65ffd0"), false, 2.0)
	if record.kind == "enemy" or (record.kind == "gunner" and record.values.has("mobile")):
		var center: Vector2 = Vector2(record.values.x, record.values.y + 1.8) + record.offset
		for side in ["left", "right"]:
			var automatic: bool = is_zero_approx(record.values[side])
			var distance: float = 2.56 if automatic else record.values[side]
			var end := center + Vector2((-1.0 if side == "left" else 1.0) * distance, 0)
			var start_screen := screen_at(center)
			var end_screen := screen_at(end)
			_handles["patrol_" + side] = end_screen
			draw_dashed_line(start_screen, end_screen, Color("ffce77"), 2.0, 7.0)
			draw_circle(end_screen, 6.0, Color("ffce77"))
			_text(end_screen + Vector2(-18, -15), "Auto" if automatic else "%.2f m" % distance, Color("ffce77"))
		var spawn := screen_at(center - Vector2(0, 1.8))
		var direction := 1.0 if record.values.facing_right else -1.0
		draw_line(spawn, spawn + Vector2(direction * 28, 0), Color("ffce77"), 3)
		_text(spawn + Vector2(direction * 32 - 5, 5), "›" if direction > 0.0 else "‹", Color("ffce77"))
	_draw_move_handles(rect.get_center())

func _draw_move_handles(center: Vector2) -> void:
	_handles.move_x = center + Vector2(34, 0)
	_handles.move_y = center + Vector2(0, -34)
	draw_line(center, _handles.move_x, Color("ff8d93"), 2.0)
	draw_line(center, _handles.move_y, Color("85c9ff"), 2.0)
	draw_circle(_handles.move_x, 4, Color("ff8d93"))
	draw_circle(_handles.move_y, 4, Color("85c9ff"))

func _text(position: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("081522"))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
