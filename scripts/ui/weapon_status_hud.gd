class_name WeaponStatusHUD
extends Control
## Compact gun/ammunition readout; hidden when the knife is equipped.
## Weapon ownership and selection remain gameplay state; this node only mirrors
## that state and owns the short acquisition hint.

const GUN_ICON := preload("res://assets/art/green_zone/weapons/player_handgun_horizontal.png")
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
@export_range(0.5, 10.0, 0.1) var hint_duration := 4.0
@export var selected_slot_style: StyleBox
@export var unselected_slot_style: StyleBox

var _session: LevelSession3D
var _player: PlayerCharacter
var _highlighted_weapon_id: StringName = PlayerWeapon.KNIFE
var _reload_success_remaining := 0.0

@onready var status_panel: PanelContainer = %StatusPanel
@onready var hint_panel: PanelContainer = %HintPanel
@onready var knife_slot: PanelContainer = %KnifeSlot
@onready var handgun_slot: PanelContainer = %HandgunSlot
@onready var hint_timer: Timer = %HintTimer


func _ready() -> void:
	assert(selected_slot_style != null, "WeaponStatusHUD requires a selected-slot style.")
	assert(unselected_slot_style != null, "WeaponStatusHUD requires an unselected-slot style.")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hint_timer.timeout.connect(_hide_hint)
	unbind_session()


func bind_session(session: LevelSession3D) -> void:
	unbind_session()
	if session == null:
		return
	_session = session
	_player = session.player
	assert(_player != null, "WeaponStatusHUD requires the session player.")
	_session.weapon_acquired.connect(_on_weapon_acquired)
	_session.weapon_ownership_changed.connect(_on_weapon_ownership_changed)
	_player.weapon_equipped.connect(_on_weapon_equipped)
	_player.player_handgun.active_reload_succeeded.connect(_on_active_reload_succeeded)
	_sync_snapshot()


func unbind_session() -> void:
	if is_instance_valid(_session):
		if _session.weapon_acquired.is_connected(_on_weapon_acquired):
			_session.weapon_acquired.disconnect(_on_weapon_acquired)
		if _session.weapon_ownership_changed.is_connected(_on_weapon_ownership_changed):
			_session.weapon_ownership_changed.disconnect(_on_weapon_ownership_changed)
	if is_instance_valid(_player) and _player.weapon_equipped.is_connected(_on_weapon_equipped):
		_player.weapon_equipped.disconnect(_on_weapon_equipped)
	if is_instance_valid(_player) and is_instance_valid(_player.player_handgun):
		if _player.player_handgun.active_reload_succeeded.is_connected(_on_active_reload_succeeded):
			_player.player_handgun.active_reload_succeeded.disconnect(_on_active_reload_succeeded)
	_reload_success_remaining = 0.0
	_session = null
	_player = null
	_highlighted_weapon_id = PlayerWeapon.KNIFE
	hint_timer.stop()
	status_panel.visible = false
	hint_panel.visible = false
	_apply_slot_selection(PlayerWeapon.KNIFE)


func status_is_visible() -> bool:
	return is_instance_valid(_player) and not _player.is_dead() and _player.equipped_weapon_id() == PlayerWeapon.HANDGUN


func hint_is_visible() -> bool:
	return hint_panel.visible


func highlighted_weapon_id() -> StringName:
	return _highlighted_weapon_id


func _on_weapon_acquired(weapon_id: StringName) -> void:
	_sync_snapshot()
	if weapon_id == PlayerWeapon.HANDGUN and status_is_visible():
		hint_panel.visible = true
		hint_timer.start(hint_duration)


func _on_weapon_ownership_changed(_owned_weapon_ids: Array[StringName]) -> void:
	_sync_snapshot()


func _on_weapon_equipped(_weapon_id: StringName) -> void:
	_sync_snapshot()


func _sync_snapshot() -> void:
	var handgun_owned := (
		is_instance_valid(_session)
		and is_instance_valid(_player)
		and _session.owns_weapon(PlayerWeapon.HANDGUN)
	)
	status_panel.hide()
	if not handgun_owned:
		_highlighted_weapon_id = PlayerWeapon.KNIFE
		hint_timer.stop()
		hint_panel.visible = false
		_apply_slot_selection(PlayerWeapon.KNIFE)
		return
	_apply_slot_selection(_player.equipped_weapon_id())
	if not status_is_visible():
		hint_timer.stop()
		hint_panel.hide()


func _apply_slot_selection(weapon_id: StringName) -> void:
	_highlighted_weapon_id = (
		PlayerWeapon.HANDGUN
		if weapon_id == PlayerWeapon.HANDGUN
		else PlayerWeapon.KNIFE
	)
	var knife_selected := _highlighted_weapon_id == PlayerWeapon.KNIFE
	knife_slot.add_theme_stylebox_override(
		"panel",
		selected_slot_style if knife_selected else unselected_slot_style
	)
	handgun_slot.add_theme_stylebox_override(
		"panel",
		unselected_slot_style if knife_selected else selected_slot_style
	)
	knife_slot.modulate = Color.WHITE if knife_selected else Color(0.68, 0.74, 0.8, 1.0)
	handgun_slot.modulate = Color(0.68, 0.74, 0.8, 1.0) if knife_selected else Color.WHITE


func _hide_hint() -> void:
	hint_panel.visible = false


var _crosshair_visible := false
var _crosshair_position := Vector2.ZERO
var _cursor_hidden := false


func _on_active_reload_succeeded() -> void:
	_reload_success_remaining = 0.22


func _process(delta: float) -> void:
	_reload_success_remaining = maxf(0.0, _reload_success_remaining - delta)
	if not status_is_visible() or _player.player_handgun.is_reloading():
		_reload_success_remaining = 0.0
	_crosshair_visible = (
		is_instance_valid(_player) and _player.player_handgun.mouse_aim_active
		and _player.pixel_visual.gun.visible and not get_tree().paused
	)
	if _crosshair_visible:
		var camera := _player.get_viewport().get_camera_3d()
		_crosshair_visible = camera != null
		if camera != null:
			_crosshair_position = get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(_player.player_handgun.crosshair_world)
	if _crosshair_visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_cursor_hidden = true
	elif not _crosshair_visible and _cursor_hidden:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_cursor_hidden = false
	queue_redraw()


func _exit_tree() -> void:
	if _cursor_hidden:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _draw() -> void:
	_draw_ammunition()
	_draw_reload_timing()
	if not _crosshair_visible:
		return
	var centre := _crosshair_position.round()
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(centre + direction * 4, centre + direction * 9, Color(0.02, 0.04, 0.07), 4.0)
		draw_line(centre + direction * 4, centre + direction * 8, Color(0.8, 1.0, 0.9), 2.0)


func _draw_ammunition() -> void:
	if not status_is_visible():
		return
	var gun := _player.player_handgun
	var origin := Vector2(24, size.y - 102)
	draw_texture_rect(GUN_ICON, Rect2(origin + Vector2(5, 20), Vector2(66, 42)), false)
	var loaded := str(gun.loaded_rounds)
	var position := origin + Vector2(91, 55)
	var color := Color("#f5f6ed")
	if gun.loaded_rounds == 0:
		color = Color("#fa725c")
	elif gun.loaded_rounds <= ceili(gun.definition.magazine_capacity * 0.25):
		color = Color("#ffb457")
	_draw_counter(loaded, position, 44, color)
	position.x += FONT.get_string_size(loaded, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 9
	_draw_counter("/ %d" % gun.reserve_rounds(), position, 30, Color("#b5cbd6"))



func _draw_reload_timing() -> void:
	if not status_is_visible():
		return
	var gun := _player.player_handgun
	if not gun.is_reloading() and _reload_success_remaining <= 0.0:
		return
	var camera := _player.get_viewport().get_camera_3d()
	var anchor := _player.global_position + Vector3(0, 1.35, 0)
	if camera == null or camera.is_position_behind(anchor):
		return
	var centre := get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(anchor)
	# Screen-sized pixel bar follows the player without scaling with the camera.
	centre.x = clampf(centre.x, 64, size.x - 64)
	centre.y = clampf(centre.y, 16, size.y - 16)
	var track := Rect2((centre - Vector2(56, 5)).round(), Vector2(112, 10))
	draw_rect(track.grow(2), Color("#111524"))
	draw_rect(track, Color("#354758"))
	var lane := track.grow(-2)
	draw_rect(lane, Color("#1b2433"))
	if _reload_success_remaining > 0.0:
		draw_rect(lane, Color("#99ebbc"))
		return
	var window := gun.active_reload_window()
	var zone_start := window.x / gun.definition.reload_duration
	var zone_end := window.y / gun.definition.reload_duration
	var zone := Rect2(lane.position + Vector2(roundf(lane.size.x * zone_start), 0),
		Vector2(roundf(lane.size.x * (zone_end - zone_start)), lane.size.y))
	draw_rect(zone, Color("#99ebbc") if gun.active_reload_available() else Color("#52666b"))
	var marker_x := roundf(lerpf(lane.position.x, lane.end.x, gun.reload_progress())) - 1
	draw_rect(Rect2(Vector2(marker_x, track.position.y - 3), Vector2(3, 16)), Color("#f5f6ed"))


func _draw_counter(text: String, where: Vector2, font_size: int, color: Color) -> void:
	draw_string_outline(FONT, where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color("#121529"))
	draw_string(FONT, where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_crosshair_visible = false
		if _cursor_hidden:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_cursor_hidden = false
		queue_redraw()
