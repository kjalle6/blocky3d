extends CanvasLayer
## Production front end. Save/confirmation operations remain in CampaignMenu.
const LOGO := preload("res://scripts/ui/protocol_logo.gd")
const MENU_BUTTON := preload("res://scripts/ui/protocol_menu_button.gd")
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
enum Phase { ENTRANCE, READY, TRANSITION, MENU }
var phase := Phase.ENTRANCE
var elapsed := 0.0
var transition_elapsed := 0.0
var app: Node
var surface: Control
var background: Control
var stage: Control
var logo: Control
var prompt: Label
var menu: Control
var buttons: Array[Button] = []
var development: Button
var _gate_event: InputEvent
var _dialog_was_visible := false
var _last_button: Button
var _menu_effect_time := 0.0
var _menu_effect_step := 0.0

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_parent()
	surface = Control.new()
	surface.name = "Surface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	background = preload("res://scripts/ui/neon_junction_background.gd").new()
	background.name = "NeonJunction"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(background)
	stage = Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(1920, 1080)
	surface.add_child(stage)
	logo = LOGO.new()
	logo.name = "ProtocolLogo"
	logo.effects_enabled = app.title_entrance_effects
	stage.add_child(logo)
	prompt = _label("PRESS ANY BUTTON", Vector2(610, 730), Vector2(700, 54), 29)
	prompt.name = "PressAnyButton"
	menu = Control.new()
	menu.name = "Selection"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.size = Vector2(1920, 1080)
	stage.add_child(menu)
	for title in ["CONTINUE", "NEW CAMPAIGN", "LOAD SAVE", "SETTINGS", "QUIT"]:
		var button := MENU_BUTTON.new()
		button.name = title.to_pascal_case()
		button.text = title
		button.position = Vector2(700, 440 + buttons.size() * 82)
		button.size = Vector2(520, 68)
		menu.add_child(button)
		button.pressed.connect(_activate.bind(buttons.size()))
		button.focus_entered.connect(func() -> void: _last_button = button)
		buttons.append(button)
	buttons[3].disabled = true
	buttons[3].tooltip_text = "Settings are not available yet."
	development = Button.new()
	development.name = "Development"
	development.text = "DEVELOPMENT"
	development.position = Vector2(1600, 993)
	development.size = Vector2(270, 44)
	development.add_theme_font_override("font", FONT)
	development.add_theme_font_size_override("font_size", 20)
	development.add_theme_color_override("font_color", Color("#8fa9bf"))
	for state in ["normal", "hover", "pressed", "focus"]:
		development.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	development.add_theme_color_override("font_focus_color", Color("#ffcd82"))
	menu.add_child(development)
	development.pressed.connect(func() -> void: app.show_level_select())
	surface.resized.connect(_fit)
	_fit()
	present(true)

func _label(text: String, position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#d6e5ee"))
	label.add_theme_color_override("font_outline_color", Color("#081026"))
	label.add_theme_constant_override("outline_size", 8)
	stage.add_child(label)
	return label

func _fit() -> void:
	var factor := minf(surface.size.x / 1920.0, surface.size.y / 1080.0)
	stage.scale = Vector2.ONE * factor
	stage.position = ((surface.size - Vector2(1920, 1080) * factor) * 0.5).round()

func present(play_entrance := false) -> void:
	show()
	surface.show()
	phase = Phase.ENTRANCE if play_entrance else Phase.MENU
	elapsed = 0.0 if play_entrance else LOGO.ENTRANCE_DURATION
	transition_elapsed = 0.0 if play_entrance else 0.38
	_gate_event = null
	logo.set_neon_time(0.0)
	_menu_effect_time = 0.0
	_menu_effect_step = 0.0
	_dialog_was_visible = false
	_refresh_availability()
	menu.visible = not play_entrance
	prompt.visible = false
	_update_composition()
	if not play_entrance:
		_focus_default()

func dismiss() -> void:
	hide()
	# CanvasLayer visibility alone does not hide descendant Controls for
	# is_visible_in_tree(), used by the background's animation clock.
	surface.hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and surface.is_ancestor_of(focused):
		focused.release_focus()
	_gate_event = null

func _refresh_availability() -> void:
	var store := get_node("/root/GameProgression") as ProgressionStore
	buttons[0].disabled = store.newest_save().is_empty() and store.progress.completed_level_ids.is_empty() and store.progress.unlocked_ability_ids.is_empty()
	development.visible = app.developer_tools_enabled
	development.disabled = not app.developer_tools_enabled
	# Explicit neighbors avoid focus escaping to invisible developer controls.
	var active: Array[Button] = []
	for button in buttons:
		if not button.disabled: active.append(button)
	if development.visible: active.append(development)
	for i in active.size():
		active[i].focus_neighbor_top = active[i].get_path_to(active[posmod(i - 1, active.size())])
		active[i].focus_neighbor_bottom = active[i].get_path_to(active[(i + 1) % active.size()])
		active[i].focus_next = active[i].focus_neighbor_bottom
		active[i].focus_previous = active[i].focus_neighbor_top

func _focus_default() -> void:
	if not visible or phase != Phase.MENU or app.campaign_menu.overlay.visible:
		return
	if is_instance_valid(_last_button) and _last_button.is_visible_in_tree() and not _last_button.disabled:
		_last_button.grab_focus()
	else:
		(buttons[1] if buttons[0].disabled else buttons[0]).grab_focus()

func _process(delta: float) -> void:
	if not visible:
		return
	var dialog_visible: bool = app.campaign_menu.overlay.visible
	if _dialog_was_visible and not dialog_visible:
		_refresh_availability()
		_focus_default()
	_dialog_was_visible = dialog_visible
	if dialog_visible:
		return
	if menu.visible:
		_menu_effect_time += delta
		_menu_effect_step += delta
		if _menu_effect_step >= 1.0 / 30.0:
			for button in buttons:
				button.update_presentation(_menu_effect_time, _menu_effect_step)
			_menu_effect_step = 0.0
	if phase == Phase.ENTRANCE:
		elapsed = minf(elapsed + delta, LOGO.ENTRANCE_DURATION)
		if elapsed >= LOGO.ENTRANCE_DURATION:
			phase = Phase.READY
	elif phase == Phase.TRANSITION:
		transition_elapsed = minf(transition_elapsed + delta, 0.38)
		if transition_elapsed >= 0.38 and _gate_event == null:
			phase = Phase.MENU
			_update_composition()
			_focus_default()
	_update_composition()

func _update_composition() -> void:
	logo.set_entrance_time(elapsed)
	var blend := smoothstep(0.0, 0.38, transition_elapsed)
	logo.position = Vector2(260, 285).lerp(Vector2(414, 85), blend).round()
	logo.scale = Vector2.ONE * lerpf(1.0, 0.78, blend)
	prompt.visible = phase == Phase.READY
	menu.visible = phase in [Phase.TRANSITION, Phase.MENU]
	menu.modulate.a = blend
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if phase == Phase.MENU else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if phase == Phase.MENU else Control.FOCUS_NONE
	development.mouse_filter = Control.MOUSE_FILTER_STOP if phase == Phase.MENU else Control.MOUSE_FILTER_IGNORE
	development.focus_mode = Control.FOCUS_ALL if phase == Phase.MENU and development.visible else Control.FOCUS_NONE

func _is_button(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton:
		return true
	return event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]

func _same_button(event: InputEvent, original: InputEvent) -> bool:
	if event is InputEventKey and original is InputEventKey:
		return event.keycode == original.keycode and event.physical_keycode == original.physical_keycode
	if event is InputEventJoypadButton and original is InputEventJoypadButton:
		return event.device == original.device and event.button_index == original.button_index
	if event is InputEventMouseButton and original is InputEventMouseButton:
		return event.button_index == original.button_index
	return false

func _input(event: InputEvent) -> void:
	if not visible or app.campaign_menu.overlay.visible:
		return
	if phase != Phase.MENU:
		# Consume the opening gesture through release, even if held longer than
		# the transition. It must never trigger a newly visible campaign button.
		if _gate_event != null and not event.is_pressed() and _same_button(event, _gate_event):
			_gate_event = null
		elif _is_button(event) and event.is_pressed() and not event.is_echo() and _gate_event == null:
			if phase == Phase.ENTRANCE:
				elapsed = LOGO.ENTRANCE_DURATION
				phase = Phase.READY
				_gate_event = event
			elif phase == Phase.READY:
				phase = Phase.TRANSITION
				transition_elapsed = 0.0
				_gate_event = event
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code in [KEY_W, KEY_S]:
			var owner := get_viewport().gui_get_focus_owner()
			if owner != null:
				var path: NodePath = owner.focus_neighbor_top if code == KEY_W else owner.focus_neighbor_bottom
				if not path.is_empty(): owner.get_node(path).grab_focus()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		var owner := get_viewport().gui_get_focus_owner()
		if owner is Button and surface.is_ancestor_of(owner):
			owner.pressed.emit()
		get_viewport().set_input_as_handled()

func _activate(index: int) -> void:
	if phase != Phase.MENU or not visible or app.campaign_menu.overlay.visible:
		return
	match index:
		0: app.campaign_menu.continue_latest()
		1: app.campaign_menu._confirm_new_campaign()
		2: app.campaign_menu.show_load("title")
		4: app.campaign_menu.confirm_title_quit()
