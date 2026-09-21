extends CanvasLayer
## Pause/recovery UI owns input while the world is paused. Saving is a domain
## operation on the session/store; button text never determines save identity.
const MENU_PANEL := preload("res://scripts/ui/cyberpunk_menu_panel.gd")
const STYLE := preload("res://scripts/ui/cyberpunk_ui_style.gd")
var app: Node
var store: ProgressionStore
var overlay: ColorRect
var rows: VBoxContainer
var menu_panel: PanelContainer
var inventory_panel: PanelContainer
var options_panel: PanelContainer
var _inventory_return_page := ""
var launcher: VBoxContainer
var notice: Label
var page := ""
var _return_page := "pause"
var _notice_remaining := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	app = get_parent()
	store = get_node("/root/GameProgression") as ProgressionStore
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.04, 0.075, 0.62)
	overlay.theme = STYLE.make_theme()
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	menu_panel = MENU_PANEL.new()
	menu_panel.name = "DialogPanel"
	center.add_child(menu_panel)
	rows = menu_panel.content
	menu_panel.close_requested.connect(func() -> void:
		if page == "save":
			show_pause()
		else:
			_return())
	options_panel = preload("res://scripts/ui/options_panel.gd").new()
	center.add_child(options_panel)
	options_panel.action_requested.connect(_options_action)
	options_panel.hide()
	inventory_panel = preload("res://scripts/ui/inventory_panel.gd").new()
	center.add_child(inventory_panel)
	inventory_panel.close_requested.connect(_leave_inventory)
	inventory_panel.hide()
	overlay.hide()
	launcher = VBoxContainer.new()
	launcher.theme = STYLE.make_theme()
	launcher.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	launcher.position = Vector2(20, 330)
	launcher.custom_minimum_size.x = 285
	launcher.add_theme_constant_override("separation", 10)
	add_child(launcher)
	_button_on(launcher, "New campaign", _confirm_new_campaign)
	_button_on(launcher, "Continue", continue_latest)
	_button_on(launcher, "Load save", func() -> void: show_load("title"))
	notice = Label.new()
	notice.position = Vector2(440, 1000)
	notice.custom_minimum_size.x = 1040
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 22)
	add_child(notice)
	store.save_written.connect(func(kind: String, slot: int) -> void: notify_user("%s %d saved" % ["Autosave" if kind == "auto" else "Manual save", slot]))
	store.save_failed.connect(notify_user)
	if not store.last_error.is_empty():
		notify_user(store.last_error)


func _process(delta: float) -> void:
	launcher.visible = app.level_select.visible and not overlay.visible
	_notice_remaining = maxf(0, _notice_remaining - delta)
	notice.visible = _notice_remaining > 0


func notify_user(message: String) -> void:
	notice.text = message
	_notice_remaining = 5.0


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("inventory"):
		if overlay.visible and page == "inventory":
			_leave_inventory()
		elif (not overlay.visible or page == "pause") and _can_open_inventory():
			show_inventory()
		get_viewport().set_input_as_handled()
		return
	if overlay.visible and page == "inventory":
		for slot in 2:
			if event.is_action_pressed("quick_item_1" if slot == 0 else "quick_item_2"):
				inventory_panel.assign_selected(slot)
				get_viewport().set_input_as_handled()
				return
	var start_pressed: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if not event.is_action_pressed("ui_cancel") and not start_pressed:
		return
	if overlay.visible:
		if page == "pause":
			close()
		elif page == "inventory":
			_leave_inventory()
		elif page == "save":
			show_pause()
		elif page in ["load", "confirm"]:
			_return()
		# Death screen cannot dismiss into a dead character.
		get_viewport().set_input_as_handled()
	elif app.current_level != null and app._developer_tool_owner.is_empty() and not app.current_level.player.is_transition_running() and not app.current_level._completed:
		show_pause()
		get_viewport().set_input_as_handled()


func _can_open_inventory() -> bool:
	return app.current_level != null and app._developer_tool_owner.is_empty() \
		and not app.current_level.player.is_dead() and not app.current_level.player.is_transition_running() \
		and not app.current_level._completed and (not get_tree().paused or overlay.visible)


func _leave_inventory() -> void:
	if _inventory_return_page == "pause":
		show_pause()
	else:
		close()


func _begin(title: String, next_page: String) -> void:
	inventory_panel.unbind()
	options_panel.hide()
	menu_panel.show()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	page = next_page
	get_tree().paused = true
	overlay.show()
	menu_panel.configure(title, 720 if next_page in ["save", "load"] else 560, next_page != "death")


func _label(message: String, font_size := 21) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = rows.custom_minimum_size.x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	rows.add_child(label)
	return label


func _button_on(parent: Node, title: String, action: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 21)
	button.disabled = disabled
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _button(title: String, action: Callable, disabled := false) -> void:
	var button := _button_on(rows, title, action, disabled)
	MENU_PANEL.style_button(button, 22 if "\n" in title else 28)
	button.clip_text = true
	button.tooltip_text = title
	if "\n" in title:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 92


func close() -> void:
	inventory_panel.unbind()
	page = ""
	overlay.hide()
	get_tree().paused = false


func show_pause() -> void:
	var session: LevelSession3D = app.current_level
	if session == null:
		return
	if session.player.is_dead():
		show_death()
		return
	_begin("OPTIONS", "pause")
	menu_panel.hide()
	var error := "Saves are available in a campaign." if session._progression_store == null else session.save_state.safety_error()
	options_panel.set_save_error(error)
	options_panel.show()
	options_panel.focus_resume()


func _options_action(action: StringName) -> void:
	match action:
		&"resume": close()
		&"inventory": show_inventory()
		&"save": show_save()
		&"load": show_load("pause")
		&"main_menu": _confirm_main_menu()
		&"quit": _confirm_quit()


func show_death() -> void:
	_begin("YOU DIED", "death")
	var newest := store.newest_save()
	if not newest.is_empty():
		_label("Continue: " + _describe(newest))
	_button("Continue from last save", continue_latest, newest.is_empty())
	_button("Load save", func() -> void: show_load("death"))
	_button("Quit to main menu", _main_menu)
	_button("Quit game", _quit_game)
	_focus_first()


func show_inventory() -> void:
	if not _can_open_inventory():
		return
	_inventory_return_page = "pause" if page == "pause" else ""
	_begin("INVENTORY", "inventory")
	menu_panel.hide()
	inventory_panel.bind_inventory(app.current_level.player.inventory)


func show_save() -> void:
	_begin("SAVE GAME", "save")
	for slot in range(1, ProgressionStore.SLOT_COUNT + 1):
		var entry := store.read_slot("manual", slot)
		var title := "Manual %d — Empty" % slot
		if entry.has("data"):
			title = _describe(entry.data)
		elif not entry.get("empty", false):
			title = "Manual %d — Unreadable save (preserved)" % slot
		_button(title, _choose_save.bind(slot, not entry.get("empty", false)))
	_button("Back", show_pause)
	_focus_first()


func _choose_save(slot: int, occupied: bool) -> void:
	if occupied:
		_return_page = "save"
		_begin("REPLACE MANUAL SAVE %d?" % slot, "confirm")
		_label("This replaces this slot. Autosaves and other manual saves stay available.")
		_button("Replace save", _write_manual.bind(slot))
		_button("Cancel", show_save)
		_focus_first()
	else:
		_write_manual(slot)


func _write_manual(slot: int) -> void:
	if app.current_level.save_state.manual_save(slot):
		show_pause()
	else:
		_label(store.last_error)


func show_load(return_page := "title") -> void:
	_return_page = return_page
	_begin("LOAD SAVE", "load")
	for entry in store.list_slots():
		if entry.has("data"):
			_button(_describe(entry.data) + ("  (recovered backup)" if entry.recovered else ""), _load.bind(entry.data, false))
		elif not entry.get("empty", false):
			_button("%s %d — %s" % [entry.kind.capitalize(), entry.slot, entry.error], func() -> void: pass, true)
	_label("Manual saves restore all progression to when they were made.", 17)
	_button("Back", _return)
	_focus_first()


func _return() -> void:
	match _return_page:
		"death": show_death()
		"pause": show_pause()
		"save": show_save()
		_: close()


func _describe(data: Dictionary) -> String:
	var stamp := Time.get_datetime_string_from_unix_time(int(data.saved_at)).replace("T", "  ") + " UTC"
	var area := str(data.section).replace("_", " ").capitalize()
	var supplies := 0
	for amount in data.player.inventory.quantities.values():
		supplies += int(amount)
	return "%s %d  ·  %d/%d HP\n%s\n%s  ·  %d healing items" % ["Autosave" if data.kind == "auto" else "Manual", int(data.slot), int(data.player.health.current), int(data.player.health.maximum), area, stamp, supplies]


func continue_latest() -> void:
	var snapshot := store.newest_save()
	if snapshot.is_empty():
		if app.continue_legacy_campaign():
			close()
			return
		notify_user("No valid save yet. Start a new campaign.")
		return
	_load(snapshot, true)


func _load(snapshot: Dictionary, ordinary_retry: bool) -> void:
	var error: String = app.load_snapshot(snapshot, ordinary_retry)
	if not error.is_empty():
		notify_user(error)
		return
	close()


func _confirm_new_campaign() -> void:
	_return_page = "title"
	_begin("NEW CAMPAIGN", "confirm")
	_label("Start with 100 HP and no supplies. Existing manual saves stay available; autosaves rotate as you play.")
	_button("Start", _new_campaign)
	_button("Cancel", close)
	_focus_first()


func _new_campaign() -> void:
	if app.start_campaign():
		close()
	else:
		notify_user(store.last_error)


func _confirm_main_menu() -> void:
	_return_page = "pause"
	_begin("RETURN TO MAIN MENU?", "confirm")
	_label("Changes since your last save will be lost.")
	_button("Return to main menu", _main_menu)
	_button("Cancel", show_pause)
	_focus_first()


func _main_menu() -> void:
	close()
	app.show_level_select()


func _confirm_quit() -> void:
	_return_page = "pause"
	_begin("QUIT GAME?", "confirm")
	_label("Changes since your last save will be lost.")
	_button("Quit", _quit_game)
	_button("Cancel", show_pause)
	_focus_first()


func _quit_game() -> void:
	get_tree().quit()


func _focus_first() -> void:
	for child in rows.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return
