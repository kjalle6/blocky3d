extends Control
## Presentation only: granted items pop above the player in signal order.
## Inventory and claim state are committed before any of these animations start.
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
const PLAYBACK_SPEED := 1.15
const POPUP_INTERVAL := 0.65
const POPUP_LIFETIME := 1.25
const RISE_PIXELS := 90.0
const ICON_SIZE := 40.0
const FONT_SIZE := 26
var _session: LevelSession3D
var _pending: Array[Dictionary] = []
var _active: Array[Dictionary] = []
var _next_popup := 0.0


func _ready() -> void:
	name = "LootReceipt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear()


func bind_session(session: LevelSession3D) -> void:
	if is_instance_valid(_session):
		if _session.item_received.is_connected(_on_item_received):
			_session.item_received.disconnect(_on_item_received)
		if _session.run_reset.is_connected(clear):
			_session.run_reset.disconnect(clear)
		if is_instance_valid(_session.player) and _session.player.death_started.is_connected(_on_player_death):
			_session.player.death_started.disconnect(_on_player_death)
	_session = session
	if _session != null:
		_session.item_received.connect(_on_item_received)
		_session.run_reset.connect(clear)
		_session.player.death_started.connect(_on_player_death)
	clear()


func _on_item_received(item_id: StringName, amount: int) -> void:
	var item := ItemCatalog.definition(item_id)
	if item == null or item.icon == null or amount <= 0:
		return
	_pending.append({"item_id": item_id, "amount": amount, "age": 0.0})
	if _next_popup <= 0.0:
		_spawn_next()
	show()
	queue_redraw()


func _spawn_next() -> void:
	if _pending.is_empty():
		return
	_active.append(_pending.pop_front())
	_next_popup = POPUP_INTERVAL


func _process(delta: float) -> void:
	# Advance the whole sequence together to preserve its motion and spacing.
	delta *= PLAYBACK_SPEED
	if not is_instance_valid(_session) or not is_instance_valid(_session.player):
		clear()
		return
	if _session.player.is_dead():
		clear()
		return
	for index in range(_active.size() - 1, -1, -1):
		_active[index].age += delta
		if float(_active[index].age) >= POPUP_LIFETIME:
			_active.remove_at(index)
	_next_popup = maxf(0.0, _next_popup - delta)
	if _next_popup <= 0.0:
		_spawn_next()
	visible = not _active.is_empty() or not _pending.is_empty()
	if visible:
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_session) or not is_instance_valid(_session.player):
		return
	var player := _session.player
	var camera := get_viewport().get_camera_3d()
	var anchor := player.global_position + Vector3(0, 1.35, 0)
	if camera == null or camera.is_position_behind(anchor):
		return
	var screen := get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(anchor)
	for popup in _active:
		var age := float(popup.age)
		var opacity := smoothstep(0.0, 0.07, age) * (1.0 - smoothstep(0.88, POPUP_LIFETIME, age))
		var pop_scale := lerpf(0.7, 1.15, smoothstep(0.0, 0.12, age))
		if age > 0.12:
			pop_scale = lerpf(1.15, 1.0, smoothstep(0.12, 0.25, age))
		var item := ItemCatalog.definition(popup.item_id)
		var text := "+%d" % int(popup.amount)
		var text_width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var width := ICON_SIZE + 8 + text_width
		var centre := screen - Vector2(0, 36 + RISE_PIXELS * age / POPUP_LIFETIME)
		centre.x = clampf(centre.x, width * 0.5 + 8, size.x - width * 0.5 - 8)
		centre.y = clampf(centre.y, 28, size.y - 28)
		var origin := (centre - Vector2(width * 0.5, 0)).round()
		var icon_size := roundf(ICON_SIZE * pop_scale)
		var icon_rect := Rect2(origin + Vector2((ICON_SIZE - icon_size) * 0.5, -icon_size * 0.5).round(),
			Vector2(icon_size, icon_size))
		draw_texture_rect(item.icon, Rect2(icon_rect.position + Vector2(2, 2), icon_rect.size),
			false, Color(0.02, 0.04, 0.07, opacity * 0.65))
		draw_texture_rect(item.icon, icon_rect, false, Color(1, 1, 1, opacity))
		var baseline := origin + Vector2(ICON_SIZE + 8,
			roundf(FONT.get_ascent(FONT_SIZE) - FONT.get_height(FONT_SIZE) * 0.5))
		draw_string_outline(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, 4, Color(0.04, 0.06, 0.10, opacity))
		draw_string(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, Color(0.96, 0.98, 0.88, opacity))


func _on_player_death(_kind: StringName, _position: Vector3) -> void:
	clear()


func clear() -> void:
	_pending.clear()
	_active.clear()
	_next_popup = 0.0
	hide()
