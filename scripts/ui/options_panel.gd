extends "res://scripts/ui/cyberpunk_menu_panel.gd"
## Compact pause presentation; CampaignMenu continues to own every action.
signal action_requested(action: StringName)
const ACTIONS := [
	[&"resume", "RESUME", preload("res://assets/art/ui/options/resume.png")],
	[&"inventory", "INVENTORY", preload("res://assets/art/ui/options/inventory.png")],
	[&"save", "SAVE GAME", preload("res://assets/art/ui/options/save.png")],
	[&"load", "LOAD SAVE", preload("res://assets/art/ui/options/load.png")],
	[&"settings", "SETTINGS", preload("res://assets/art/ui/options/settings.png")],
	[&"main_menu", "MAIN MENU", preload("res://assets/art/ui/options/main_menu.png")],
	[&"quit", "QUIT GAME", preload("res://assets/art/ui/options/quit.png")],
]
var _buttons: Dictionary = {}


func _ready() -> void:
	super._ready()
	name = "OptionsPanel"
	configure("OPTIONS", 396)
	close_button.tooltip_text = "Resume · Esc"
	close_requested.connect(func() -> void: action_requested.emit(&"resume"))
	for entry in ACTIONS:
		var id: StringName = entry[0]
		var button := Button.new()
		button.name = String(id).to_pascal_case()
		button.text = entry[1]
		button.icon = entry[2]
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(340, 56)
		button.add_theme_constant_override("icon_max_width", 28)
		button.add_theme_constant_override("h_separation", 12)
		style_button(button, 32)
		button.pressed.connect(func() -> void: action_requested.emit(id))
		content.add_child(button)
		_buttons[id] = button
	_buttons[&"inventory"].tooltip_text = "Open inventory · Tab"
	_buttons[&"settings"].disabled = true
	_buttons[&"settings"].tooltip_text = "Settings are not available yet."


func set_save_error(save_error: String) -> void:
	_buttons[&"save"].disabled = not save_error.is_empty()
	_buttons[&"save"].tooltip_text = save_error if not save_error.is_empty() else "Make a manual save."


func focus_resume() -> void:
	_buttons[&"resume"].grab_focus()
