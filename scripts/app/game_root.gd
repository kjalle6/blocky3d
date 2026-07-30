extends Node
## Application composition root. Campaign content comes from typed resources;
## this node owns presentation and transitions, not level-specific behavior.

@export var campaign: CampaignCatalog
@export var level_button_style: StyleBox
@export var persist_progression := true

var current_level: LevelSession3D
var current_level_definition: LevelDefinition
var _level_buttons: Array[Button] = []

@onready var world: Node3D = %World
@onready var instructions: PanelContainer = %Instructions
@onready var level_label: Label = %LevelLabel
@onready var menu_hint: Label = %MenuHint
@onready var completion_label: Label = %CompletionLabel
@onready var level_select: Control = %LevelSelect
@onready var level_buttons: VBoxContainer = %LevelButtons


func _ready() -> void:
	assert(campaign != null, "GameRoot requires a CampaignCatalog.")
	var catalog_errors := campaign.validation_errors()
	assert(
		catalog_errors.is_empty(),
		"Campaign catalog is invalid:\n%s" % "\n".join(catalog_errors)
	)
	_build_level_buttons()
	show_level_select()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if level_select.visible:
		match event.physical_keycode:
			KEY_W:
				_move_level_focus(-1)
			KEY_S:
				_move_level_focus(1)
			KEY_ENTER, KEY_KP_ENTER:
				_load_focused_level()
			_:
				var shortcut_index := int(event.physical_keycode) - int(KEY_1)
				if shortcut_index < 0 or shortcut_index >= mini(9, _level_buttons.size()):
					return
				_load_button_level(_level_buttons[shortcut_index])
	elif event.physical_keycode == KEY_ESCAPE:
		show_level_select()
	else:
		return
	get_viewport().set_input_as_handled()


func load_level(level_key: Variant) -> void:
	var definition := _resolve_level(level_key)
	assert(definition != null, "Unknown campaign level: %s" % level_key)
	_free_current_level()
	current_level = definition.scene.instantiate() as LevelSession3D
	assert(
		current_level != null,
		"%s must instantiate a LevelSession3D." % definition.scene.resource_path
	)
	current_level_definition = definition
	current_level.name = "Level%02d" % definition.display_number
	current_level.configure(definition, _progression_store())
	world.add_child(current_level)
	current_level.run_completed.connect(_on_run_completed)
	current_level.run_reset.connect(_on_run_reset)
	level_label.text = (
		definition.heading()
		+ "\nMove: A / D or left stick    Jump: SPACE / gamepad A"
		+ "    Attack: LEFT CLICK / J / gamepad X    Reset: R"
	)
	level_select.visible = false
	instructions.visible = true
	menu_hint.visible = true
	completion_label.visible = false


func show_level_select() -> void:
	_free_current_level()
	current_level_definition = null
	level_select.visible = true
	instructions.visible = false
	menu_hint.visible = false
	completion_label.visible = false
	if not _level_buttons.is_empty():
		_level_buttons.front().grab_focus()


func _build_level_buttons() -> void:
	for child in level_buttons.get_children():
		child.queue_free()
	_level_buttons.clear()
	for definition in campaign.ordered_levels():
		var button := Button.new()
		button.name = "Level%02dButton" % definition.display_number
		button.custom_minimum_size = Vector2(0.0, 64.0)
		button.add_theme_font_size_override("font_size", 22)
		if level_button_style != null:
			button.add_theme_stylebox_override("normal", level_button_style)
		button.text = definition.menu_label()
		button.set_meta(&"level_id", definition.level_id)
		button.pressed.connect(_load_button_level.bind(button))
		level_buttons.add_child(button)
		_level_buttons.append(button)


func _move_level_focus(direction: int) -> void:
	if _level_buttons.is_empty():
		return
	var focused_index := _level_buttons.find(get_viewport().gui_get_focus_owner())
	if focused_index < 0:
		focused_index = 0
	var next_index := wrapi(focused_index + direction, 0, _level_buttons.size())
	_level_buttons[next_index].grab_focus()


func _load_focused_level() -> void:
	var focused_button := get_viewport().gui_get_focus_owner() as Button
	if focused_button in _level_buttons:
		_load_button_level(focused_button)
	elif not _level_buttons.is_empty():
		_load_button_level(_level_buttons.front())


func _load_button_level(button: Button) -> void:
	load_level(button.get_meta(&"level_id") as StringName)


func _resolve_level(level_key: Variant) -> LevelDefinition:
	if typeof(level_key) == TYPE_INT:
		return campaign.find_by_number(int(level_key))
	return campaign.find_by_id(StringName(level_key))


func _progression_store() -> ProgressionStore:
	if not persist_progression:
		return null
	return get_node_or_null("/root/GameProgression") as ProgressionStore


func _free_current_level() -> void:
	if current_level == null:
		return
	world.remove_child(current_level)
	current_level.free()
	current_level = null


func _on_run_completed() -> void:
	completion_label.visible = true
	var store := _progression_store()
	if store != null and current_level_definition != null:
		store.mark_level_completed(current_level_definition.level_id)


func _on_run_reset() -> void:
	completion_label.visible = false
