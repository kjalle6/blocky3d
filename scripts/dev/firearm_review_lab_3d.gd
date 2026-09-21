class_name FirearmReviewLab3D
extends Node
## Keeps the starting loadout and firing-pattern comparison local to the lab.
## Production weapon-slot inputs remain available for switching knife/gun.

const HEALTH_PRESETS := [100, 110, 120, 150, 200, 300]
var _preview_maximum_hp := 100
var _health_size_buttons: Dictionary = {}

@export var shooter_path: NodePath
@export var mode_label_path: NodePath

@onready var shooter := get_node(shooter_path) as HandgunEnemy3D
@onready var mode_label := get_node(mode_label_path) as Label
@onready var session := get_parent() as LevelSession3D


func _ready() -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self):
		return
	assert(shooter != null, "FirearmReviewLab3D requires its shooter.")
	assert(mode_label != null, "FirearmReviewLab3D requires its mode label.")
	assert(session != null, "FirearmReviewLab3D requires its level session.")
	# Child ready runs before the session's initial reset. The same signal
	# restores the lab gun after Reset lab; ordinary respawns retain ownership.
	_build_health_preview_tools()
	session.run_reset.connect(_on_run_reset)
	_update_mode_label()
	# Review fixtures only; production supply rates/placements remain undecided.
	var chest := ItemReward3D.new()
	chest.name = "HealingChestFixture"
	chest.presentation = ItemReward3D.Presentation.CHEST
	chest.position = Vector3(6.4, 0, 0)
	chest.additional_items = {&"handgun_ammo": 30}
	session.add_child.call_deferred(chest)
	var drop := ItemReward3D.new()
	drop.name = "HealingDropFixture"
	drop.presentation = ItemReward3D.Presentation.ENEMY_DROP
	drop.source_enemy_path = NodePath("../" + String(shooter.name))
	session.add_child.call_deferred(drop)


func _on_run_reset() -> void:
	session.acquire_weapon(PlayerWeapon.HANDGUN)
	session.player.inventory.reset()
	session.player.player_handgun.set_loaded_rounds(12)
	session.player.inventory.add(&"handgun_ammo", 30)
	session.player.inventory.add(&"basic_heal", 5)
	session.player.inventory.add(&"large_heal_test", 3)
	session.player.inventory.add(&"medical_bag", 2)
	session.player.inventory.equip(1, &"large_heal_test")
	_set_preview_maximum(_preview_maximum_hp)


func _build_health_preview_tools() -> void:
	var panel := PanelContainer.new()
	panel.name = "HealthBarPreview"
	mode_label.get_parent().add_child(panel)
	panel.add_to_group("developer_lab_tools")
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -680
	panel.offset_right = -330
	panel.offset_top = 440
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.075, 0.94)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "HEALTH BAR PREVIEW"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#ffcb70"))
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "Max HP · 110 = 10% wider"
	hint.add_theme_font_size_override("font_size", 15)
	rows.add_child(hint)
	var sizes := GridContainer.new()
	sizes.name = "Sizes"
	sizes.columns = 3
	rows.add_child(sizes)
	var group := ButtonGroup.new()
	for maximum in HEALTH_PRESETS:
		var button := Button.new()
		button.name = "HP%d" % maximum
		button.text = "%d HP" % maximum
		button.custom_minimum_size = Vector2(104, 36)
		button.add_theme_font_size_override("font_size", 17)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_preview_maximum.bind(maximum))
		sizes.add_child(button)
		_health_size_buttons[maximum] = button
	var fills := HBoxContainer.new()
	fills.name = "Fill"
	rows.add_child(fills)
	for entry in [["Full", 1.0], ["Half", 0.5], ["Low", 0.25]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[0]
		button.custom_minimum_size = Vector2(104, 36)
		button.add_theme_font_size_override("font_size", 17)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_preview_fill.bind(float(entry[1])))
		fills.add_child(button)
	var note := Label.new()
	note.text = "Size changes refill lab HP."
	note.add_theme_font_size_override("font_size", 14)
	rows.add_child(note)
	var reset_button := Button.new()
	reset_button.name = "ResetLab"
	reset_button.text = "Reset lab"
	reset_button.custom_minimum_size.y = 36
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(func() -> void:
		session._reset_run()
		session.camera.snap_to_target()
		if session.background != null:
			session.background.snap_to_camera()
	)
	rows.add_child(reset_button)
	panel.hide()


func _set_preview_maximum(maximum: int) -> void:
	if maximum not in HEALTH_PRESETS or session.player.is_dead():
		return
	_preview_maximum_hp = maximum
	session.player.health.reset(maximum)
	for value in _health_size_buttons:
		(_health_size_buttons[value] as Button).set_pressed_no_signal(value == maximum)


func _set_preview_fill(ratio: float) -> void:
	if not session.player.is_dead():
		session.player.health.reset(_preview_maximum_hp,
			maxi(1, roundi(_preview_maximum_hp * clampf(ratio, 0.0, 1.0))))


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_T:
		toggle_fire_pattern()
		get_viewport().set_input_as_handled()


func toggle_fire_pattern() -> void:
	var next_pattern := (
		HandgunEnemy3D.FirePattern.TRIPLE
		if shooter.current_fire_pattern() == HandgunEnemy3D.FirePattern.TWIN
		else HandgunEnemy3D.FirePattern.TWIN
	)
	shooter.set_fire_pattern(next_pattern)
	_update_mode_label()


func _update_mode_label() -> void:
	mode_label.add_to_group("developer_lab_readout")
	mode_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mode_label.offset_left = -680
	mode_label.offset_right = -20
	mode_label.offset_top = 64
	mode_label.offset_bottom = 244
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_label.text = (
		"FIREARM REVIEW LAB\n"
		+ "T: SWITCH PATTERN     R: RELOAD\n"
		+ "F1: RESET LAB / REFILL AMMO\n"
		+ "Q / E: HEAL     TAB: INVENTORY\n"
		+ "MODE: %s\n" % shooter.pattern_display_name()
		+ "%s\n" % shooter.pattern_description()
		+ "Dodge the rounds or use the rock as real cover."
	)
