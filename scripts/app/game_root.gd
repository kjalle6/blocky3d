extends Node

const LEVEL_SCENES := {
	1: preload("res://scenes/levels/level_01_pixel.tscn"),
	2: preload("res://scenes/levels/level_02_gaps_and_spikes.tscn"),
}
const LEVEL_TITLES := {
	1: "LEVEL 1 - FUNDAMENTALS",
	2: "LEVEL 2 - GAPS & SPIKES",
}

var current_level: LevelSession3D
var current_level_number := 0

@onready var world: Node3D = %World
@onready var instructions: PanelContainer = %Instructions
@onready var level_label: Label = %LevelLabel
@onready var menu_hint: Label = %MenuHint
@onready var completion_label: Label = %CompletionLabel
@onready var level_select: Control = %LevelSelect
@onready var level_01_button: Button = %Level01Button
@onready var level_02_button: Button = %Level02Button


func _ready() -> void:
	level_01_button.pressed.connect(load_level.bind(1))
	level_02_button.pressed.connect(load_level.bind(2))
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
			KEY_1:
				load_level(1)
			KEY_2:
				load_level(2)
			_:
				return
	elif event.physical_keycode == KEY_ESCAPE:
		show_level_select()
	else:
		return
	get_viewport().set_input_as_handled()


func load_level(level_number: int) -> void:
	var packed_scene := LEVEL_SCENES.get(level_number) as PackedScene
	assert(packed_scene != null, "Unknown level number: %d" % level_number)
	_free_current_level()
	current_level = packed_scene.instantiate() as LevelSession3D
	current_level_number = level_number
	current_level.name = "Level%02d" % level_number
	world.add_child(current_level)
	current_level.run_completed.connect(_on_run_completed)
	current_level.run_reset.connect(_on_run_reset)
	level_label.text = (
		LEVEL_TITLES[level_number]
		+ "\nMove: A / D or left stick    Jump: SPACE / gamepad A"
		+ "    Attack: LEFT CLICK / J / gamepad X    Reset: R"
	)
	level_select.visible = false
	instructions.visible = true
	menu_hint.visible = true
	completion_label.visible = false


func show_level_select() -> void:
	_free_current_level()
	current_level_number = 0
	level_select.visible = true
	instructions.visible = false
	menu_hint.visible = false
	completion_label.visible = false
	level_01_button.grab_focus()


func _move_level_focus(direction: int) -> void:
	var level_buttons := [level_01_button, level_02_button]
	var focused_index := level_buttons.find(get_viewport().gui_get_focus_owner())
	if focused_index < 0:
		focused_index = 0
	var next_index := wrapi(focused_index + direction, 0, level_buttons.size())
	level_buttons[next_index].grab_focus()


func _load_focused_level() -> void:
	if level_02_button.has_focus():
		load_level(2)
	else:
		load_level(1)


func _free_current_level() -> void:
	if current_level == null:
		return
	world.remove_child(current_level)
	current_level.free()
	current_level = null


func _on_run_completed() -> void:
	completion_label.visible = true


func _on_run_reset() -> void:
	completion_label.visible = false
