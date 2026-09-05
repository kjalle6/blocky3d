class_name WeaponStatusHUD
extends Control
## Small contextual loadout display used after the player earns a firearm.
## Weapon ownership and selection remain gameplay state; this node only mirrors
## that state and owns the short acquisition hint.

@export_range(0.5, 10.0, 0.1) var hint_duration := 4.0
@export var selected_slot_style: StyleBox
@export var unselected_slot_style: StyleBox

var _session: LevelSession3D
var _player: PlayerCharacter
var _highlighted_weapon_id: StringName = PlayerWeapon.KNIFE

@onready var status_panel: PanelContainer = %StatusPanel
@onready var hint_panel: PanelContainer = %HintPanel
@onready var knife_slot: PanelContainer = %KnifeSlot
@onready var handgun_slot: PanelContainer = %HandgunSlot
@onready var hint_timer: Timer = %HintTimer


func _ready() -> void:
	assert(selected_slot_style != null, "WeaponStatusHUD requires a selected-slot style.")
	assert(unselected_slot_style != null, "WeaponStatusHUD requires an unselected-slot style.")
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
	_sync_snapshot()


func unbind_session() -> void:
	if is_instance_valid(_session):
		if _session.weapon_acquired.is_connected(_on_weapon_acquired):
			_session.weapon_acquired.disconnect(_on_weapon_acquired)
		if _session.weapon_ownership_changed.is_connected(_on_weapon_ownership_changed):
			_session.weapon_ownership_changed.disconnect(_on_weapon_ownership_changed)
	if is_instance_valid(_player) and _player.weapon_equipped.is_connected(_on_weapon_equipped):
		_player.weapon_equipped.disconnect(_on_weapon_equipped)
	_session = null
	_player = null
	_highlighted_weapon_id = PlayerWeapon.KNIFE
	hint_timer.stop()
	status_panel.visible = false
	hint_panel.visible = false
	_apply_slot_selection(PlayerWeapon.KNIFE)


func status_is_visible() -> bool:
	return status_panel.visible


func hint_is_visible() -> bool:
	return hint_panel.visible


func highlighted_weapon_id() -> StringName:
	return _highlighted_weapon_id


func _on_weapon_acquired(weapon_id: StringName) -> void:
	_sync_snapshot()
	if weapon_id == PlayerWeapon.HANDGUN and status_panel.visible:
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
	status_panel.visible = handgun_owned
	if not handgun_owned:
		_highlighted_weapon_id = PlayerWeapon.KNIFE
		hint_timer.stop()
		hint_panel.visible = false
		_apply_slot_selection(PlayerWeapon.KNIFE)
		return
	_apply_slot_selection(_player.equipped_weapon_id())


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


func _process(_delta: float) -> void:
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
	if not _crosshair_visible:
		return
	var centre := _crosshair_position.round()
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(centre + direction * 4, centre + direction * 9, Color(0.02, 0.04, 0.07), 4.0)
		draw_line(centre + direction * 4, centre + direction * 8, Color(0.8, 1.0, 0.9), 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_crosshair_visible = false
		if _cursor_hidden:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_cursor_hidden = false
		queue_redraw()
