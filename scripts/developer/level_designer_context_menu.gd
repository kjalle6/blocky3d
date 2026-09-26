extends PopupMenu
## A shortcut to the same editor commands; no separate mutation/save path.
enum Action { SETTINGS, FRAME, DUPLICATE, REVERT, REMOVE, BUILD, UNDO, REDO, TEST, SAVE, PROTECTED, ADD, FLIP, LAYER_BACK, LAYER_FORWARD }
var designer: CanvasLayer
var _protected_reason := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prefer_native_menu = false
	add_theme_font_size_override("font_size", 17)
	add_theme_constant_override("v_separation", 10)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("10202c")
	background.border_color = Color("53778b")
	background.set_border_width_all(1)
	background.set_corner_radius_all(6)
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 8
	background.content_margin_bottom = 8
	add_theme_stylebox_override("panel", background)
	id_pressed.connect(_activate)

func open_at(point: Vector2, protected_id := "") -> void:
	if designer.mode != designer.Mode.EDITING or designer.dialog_open(): return
	clear()
	_protected_reason = ""
	if not protected_id.is_empty():
		var record: Dictionary = designer.locked[protected_id]
		add_separator(record.name)
		_protected_reason = record.reason
		add_item("Why is this protected?", Action.PROTECTED)
	elif not designer.selection.is_empty():
		var count: int = designer.selection.size()
		add_separator(designer.document.working[designer.selection[0]].name if count == 1 else "%d selected objects" % count)
		add_item("Edit settings…", Action.SETTINGS)
		add_item("Frame selection", Action.FRAME, KEY_F)
		_item("Flip horizontally", Action.FLIP, designer.can_flip_selected(),
			"Flip chests, scenery, blocks or enemy starting direction without moving them.")
		_item("Move back one layer", Action.LAYER_BACK, designer.can_layer_selected(), "Decorations: lower numbers appear behind higher numbers.")
		_item("Move forward one layer", Action.LAYER_FORWARD, designer.can_layer_selected(), "Decorations: higher numbers appear in front.")
		add_separator()
		_item("Duplicate" if count == 1 else "Duplicate selection", Action.DUPLICATE,
			designer.can_duplicate_selected(), "Added objects and approved independent platforms can be duplicated.", KEY_MASK_CTRL | KEY_D)
		_item("Revert to last save", Action.REVERT, designer.can_revert_selected(),
			"Restore only this selection's saved settings. New unsaved objects can be removed or undone.")
		_item("Remove" if count == 1 else "Remove selection", Action.REMOVE,
			designer.can_remove_selected(), "Existing protected objects cannot be removed.", KEY_DELETE)
	else:
		add_separator("Level actions")
		add_item("Add objects…", Action.ADD)
		add_item("Build with blocks…", Action.BUILD)
	add_separator()
	_item("Undo", Action.UNDO, designer.history.has_undo(), "", KEY_MASK_CTRL | KEY_Z)
	_item("Redo", Action.REDO, designer.history.has_redo(), "", KEY_MASK_CTRL | KEY_Y)
	add_separator()
	add_item("Test layout", Action.TEST)
	_item("Save layout", Action.SAVE, designer.document.has_changes(), "", KEY_MASK_CTRL | KEY_S)
	# Input and embedded popup coordinates share the game's viewport, including
	# canvas stretch. Godot clamps the popup to its parent window at the edges.
	var popup_point := point
	if not is_embedded():
		popup_point = designer.canvas.get_screen_transform() * point
	reset_size()
	popup(Rect2i(Vector2i(popup_point), Vector2i.ZERO))

func _item(label: String, id: int, enabled: bool, explanation := "", accelerator: Key = KEY_NONE) -> void:
	add_item(label, id, accelerator)
	set_item_disabled(item_count - 1, not enabled)
	if not explanation.is_empty(): set_item_tooltip(item_count - 1, explanation)

func _activate(id: int) -> void:
	var index := get_item_index(id)
	if index < 0 or is_item_disabled(index) or designer.mode != designer.Mode.EDITING: return
	hide()
	match id:
		Action.SETTINGS: designer.panel.focus_selected_settings()
		Action.FRAME: designer.frame_selection()
		Action.FLIP: designer.flip_selected()
		Action.LAYER_BACK: designer.shift_decoration_layer(-1)
		Action.LAYER_FORWARD: designer.shift_decoration_layer(1)
		Action.DUPLICATE: designer.duplicate_selected()
		Action.REVERT: designer.revert_selected()
		Action.REMOVE: designer.remove_selected()
		Action.BUILD: designer.panel.show_build_palette()
		Action.ADD: designer.object_browser.open()
		Action.UNDO: designer.undo()
		Action.REDO: designer.redo()
		Action.TEST: designer.test_layout()
		Action.SAVE: designer.save_layout()
		Action.PROTECTED: designer.app.show_developer_message("Protected object", _protected_reason)
