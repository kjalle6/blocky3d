extends Node
## Local fight controls and loadout; this session never writes campaign progress.
var no_ammo := false
var _bar: ProgressBar
var _title: Label
@onready var session := get_parent() as LevelSession3D
@onready var boss := get_parent().get_node("GreenZoneBoss")

func _ready() -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self):
		return
	_build_interface()
	boss.health_changed.connect(_update_health)
	session.run_reset.connect(_on_run_reset)

func _on_run_reset() -> void:
	session.acquire_weapon(PlayerWeapon.HANDGUN)
	session.player.inventory.reset()
	session.player.player_handgun.set_loaded_rounds(0 if no_ammo else 12)
	if not no_ammo:
		session.player.inventory.add(&"handgun_ammo", 60)
	_update_health(boss.health.current, boss.health.maximum)

func reset_fight() -> void:
	session._reset_run()
	session.camera.snap_to_target()
	if session.background != null:
		session.background.snap_to_camera()

func select_pattern(index: int) -> void:
	boss.set_pattern(index)
	reset_fight()

func set_no_ammo(value: bool) -> void:
	no_ammo = value
	reset_fight()

func set_boss_active(value: bool) -> void:
	boss.set_enabled(value)
	reset_fight()

func test_head_landing() -> void:
	reset_fight()
	session.player.global_position = boss.global_position + Vector3(0, boss.stomp_head_height + PlayerCharacter.FEET_OFFSET_Y + 0.2, 0)
	session.player.velocity.y = -5.0
	session.camera.snap_to_target()

func test_close_pressure(side := -1.0) -> void:
	boss.set_enabled(true)
	boss.set_pattern(1)
	reset_fight()
	$BossLabInterface/FightControls/Rows/Pattern.select(1)
	$BossLabInterface/FightControls/Rows/BossActive.set_pressed_no_signal(true)
	session.player.global_position = boss.global_position + Vector3(signf(side) * 2.8, PlayerCharacter.FEET_OFFSET_Y, 0)
	boss.phase_remaining = 0.15
	session.camera.snap_to_target()

func test_missile_ripple(side := -1.0) -> void:
	boss.set_enabled(true)
	boss.set_pattern(1)
	reset_fight()
	$BossLabInterface/FightControls/Rows/Pattern.select(1)
	$BossLabInterface/FightControls/Rows/BossActive.set_pressed_no_signal(true)
	session.player.global_position = boss.global_position + Vector3(signf(side) * 8.0, PlayerCharacter.FEET_OFFSET_Y, 0)
	boss.phase_remaining = 0.6
	session.camera.snap_to_target()

func test_salvo_pressure(side := -1.0) -> void:
	test_missile_ripple(side)
	session.player.global_position = boss.global_position + Vector3(signf(side) * 5.0, PlayerCharacter.FEET_OFFSET_Y, 0)
	boss._start_salvo(session.player)
	session.camera.snap_to_target()

func _update_health(current: int, maximum: int) -> void:
	_bar.max_value = maximum
	_bar.value = current
	_title.text = "LAUNCHER" if current > 0 else "LAUNCHER — DEFEATED"

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BossLabInterface"
	layer.layer = 5
	add_child(layer)
	var health_box := VBoxContainer.new()
	health_box.name = "BossHealth"
	layer.add_child(health_box)
	health_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	health_box.offset_left = -180
	health_box.offset_right = 180
	health_box.offset_top = -64
	health_box.offset_bottom = -24
	health_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 4)
	health_box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.name = "Health"
	_bar.custom_minimum_size = Vector2(360, 10)
	_bar.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#15252b")
	back.set_border_width_all(2)
	back.border_color = Color("#0a0f15")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#69bb6c")
	_bar.add_theme_stylebox_override("background", back)
	_bar.add_theme_stylebox_override("fill", fill)
	health_box.add_child(_bar)
	var hint := Label.new()
	hint.name = "LabHint"
	hint.text = "BOSS TEST LAB · F1: CONTROLS"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)
	hint.add_to_group("developer_lab_readout")
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -440
	hint.offset_right = -20
	hint.offset_top = 65
	var panel := PanelContainer.new()
	panel.name = "FightControls"
	layer.add_child(panel)
	panel.add_to_group("developer_lab_tools")
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -680
	panel.offset_right = -330
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.075, 0.96)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "BOSS TEST LAB"
	title.add_theme_font_size_override("font_size", 18)
	rows.add_child(title)
	var patterns := OptionButton.new()
	patterns.name = "Pattern"
	patterns.add_item("Mixed: missiles + jump")
	patterns.add_item("Missiles only")
	patterns.add_item("Jump + landing only")
	patterns.item_selected.connect(select_pattern)
	patterns.focus_mode = Control.FOCUS_NONE
	patterns.custom_minimum_size.y = 36
	rows.add_child(patterns)
	var ammo := CheckButton.new()
	ammo.name = "NoAmmo"
	ammo.text = "No ammo"
	ammo.focus_mode = Control.FOCUS_NONE
	ammo.toggled.connect(set_no_ammo)
	rows.add_child(ammo)
	var active := CheckButton.new()
	active.name = "BossActive"
	active.text = "Boss active"
	active.button_pressed = true
	active.focus_mode = Control.FOCUS_NONE
	active.toggled.connect(set_boss_active)
	rows.add_child(active)
	var reset := Button.new()
	reset.name = "ResetFight"
	reset.text = "Reset fight / refill"
	reset.custom_minimum_size.y = 36
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(reset_fight)
	rows.add_child(reset)
	var head_test := Button.new()
	head_test.text = "Test head landing / smoke escape"
	head_test.custom_minimum_size.y = 36
	head_test.focus_mode = Control.FOCUS_NONE
	head_test.pressed.connect(test_head_landing)
	rows.add_child(head_test)
	var charge_test := Button.new()
	charge_test.text = "Test close pressure / body charge"
	charge_test.custom_minimum_size.y = 36
	charge_test.focus_mode = Control.FOCUS_NONE
	charge_test.pressed.connect(test_close_pressure)
	rows.add_child(charge_test)
	for side in [-1.0, 1.0]:
		var ripple_test := Button.new()
		ripple_test.text = "Test rocket ripple / fire " + ("left" if side < 0.0 else "right")
		ripple_test.custom_minimum_size.y = 36
		ripple_test.focus_mode = Control.FOCUS_NONE
		ripple_test.pressed.connect(test_missile_ripple.bind(side))
		rows.add_child(ripple_test)
	var pressure_test := Button.new()
	pressure_test.text = "Test crowding during rocket fire"
	pressure_test.custom_minimum_size.y = 36
	pressure_test.focus_mode = Control.FOCUS_NONE
	pressure_test.pressed.connect(test_salvo_pressure)
	rows.add_child(pressure_test)
	var note := Label.new()
	note.text = "Changing a test option restarts the fight.\n1: knife · 2: handgun · R: reload"
	note.add_theme_font_size_override("font_size", 14)
	rows.add_child(note)
	panel.hide()
