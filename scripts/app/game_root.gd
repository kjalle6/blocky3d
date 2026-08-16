extends Node
## Application composition root. Campaign content comes from typed resources;
## this node owns presentation and transitions, not level-specific behavior.

@export var campaign: CampaignCatalog
@export var developer_room_definition: LevelDefinition
@export var developer_level_definitions: Array[LevelDefinition] = []
@export var level_button_style: StyleBox
@export var persist_progression := true
@export var developer_fresh_level_runs := true
@export var developer_tools_enabled := true

var current_level: LevelSession3D
var current_level_definition: LevelDefinition
var current_world_definition: WorldDefinition
var _level_buttons: Array[Button] = []
var _gameplay_tools_visible := false
var _developer_ability_panel_available := false
var _developer_inspection_enabled := false
var _developer_measurement_grid_enabled := false
var _developer_collision_overlay_enabled := false

@onready var world: Node3D = %World
@onready var instructions: PanelContainer = %Instructions
@onready var level_label: Label = %LevelLabel
@onready var menu_hint: Label = %MenuHint
@onready var completion_label: Label = %CompletionLabel
@onready var ability_tutorial: PanelContainer = %AbilityTutorial
@onready var ability_tutorial_label: Label = %AbilityTutorialLabel
@onready var ability_tutorial_timer: Timer = %AbilityTutorialTimer
@onready var level_select: Control = %LevelSelect
@onready var world_list: VBoxContainer = %WorldList
@onready var developer_mode_label: Label = %DeveloperModeLabel
@onready var developer_ability_panel: PanelContainer = %DeveloperAbilityPanel
@onready var developer_ability_toggles: VBoxContainer = %DeveloperAbilityToggles
@onready var developer_inspection_label: Label = %DeveloperInspectionLabel
@onready var developer_measurement_label: Label = %DeveloperMeasurementLabel
@onready var developer_cursor_coordinate_label: Label = %DeveloperCursorCoordinateLabel
@onready var developer_collision_legend: Label = %DeveloperCollisionLegend
@onready var completion_fade: ColorRect = %CompletionFade

var _completion_fade_tween: Tween


func _ready() -> void:
	assert(campaign != null, "GameRoot requires a CampaignCatalog.")
	var catalog_errors := campaign.validation_errors()
	assert(
		catalog_errors.is_empty(),
		"Campaign catalog is invalid:\n%s" % "\n".join(catalog_errors)
	)
	ability_tutorial_timer.timeout.connect(_hide_ability_tutorial)
	developer_mode_label.visible = developer_fresh_level_runs
	_build_world_list()
	show_level_select()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if (
		not level_select.visible
		and (
			event.physical_keycode == KEY_F1
			or event.keycode == KEY_F1
		)
	):
		_set_gameplay_tools_visible(not _gameplay_tools_visible)
		get_viewport().set_input_as_handled()
		return
	if (
		developer_tools_enabled
		and not level_select.visible
		and current_level != null
		and (
			event.physical_keycode == KEY_F7
			or event.keycode == KEY_F7
		)
	):
		_set_developer_collision_overlay_enabled(
			not _developer_collision_overlay_enabled
		)
		get_viewport().set_input_as_handled()
		return
	if (
		developer_tools_enabled
		and not level_select.visible
		and current_level != null
		and (
			event.physical_keycode == KEY_F11
			or event.keycode == KEY_F11
		)
	):
		_set_developer_inspection_enabled(not _developer_inspection_enabled)
		get_viewport().set_input_as_handled()
		return
	if (
		developer_tools_enabled
		and not level_select.visible
		and current_level != null
		and (
			event.physical_keycode == KEY_F10
			or event.keycode == KEY_F10
		)
	):
		_set_developer_measurement_grid_enabled(
			not _developer_measurement_grid_enabled
		)
		get_viewport().set_input_as_handled()
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


func load_level(level_id: StringName) -> void:
	var definition := campaign.find_by_id(level_id)
	var world_definition := campaign.find_world_for_level(level_id)
	assert(definition != null, "Unknown campaign level: %s" % level_id)
	assert(world_definition != null, "Campaign level has no owning world: %s" % level_id)
	var initial_session_abilities: Array[StringName] = []
	if developer_fresh_level_runs or not persist_progression:
		initial_session_abilities = definition.assumed_owned_abilities.duplicate()
	_start_session(definition, world_definition, initial_session_abilities)


func load_developer_room() -> void:
	assert(developer_tools_enabled, "Developer tools are disabled.")
	assert(developer_room_definition != null, "GameRoot requires a developer room definition.")
	load_developer_level(developer_room_definition)


func load_developer_level(definition: LevelDefinition) -> void:
	assert(developer_tools_enabled, "Developer tools are disabled.")
	assert(definition != null, "A developer level definition is required.")
	assert(
		definition in _ordered_developer_definitions(),
		"Unknown developer level: %s" % definition.level_id
	)
	var room_errors := definition.validation_errors()
	assert(
		room_errors.is_empty(),
		"Developer level definition is invalid:\n%s" % "\n".join(room_errors)
	)
	var initial_abilities := definition.assumed_owned_abilities.duplicate()
	if definition == developer_room_definition:
		initial_abilities = definition.available_abilities.duplicate()
	_start_session(
		definition,
		null,
		initial_abilities
	)


func _start_session(
	definition: LevelDefinition,
	world_definition: WorldDefinition,
	initial_session_abilities: Array[StringName] = []
) -> void:
	_free_current_level()
	current_level = definition.scene.instantiate() as LevelSession3D
	assert(
		current_level != null,
		"%s must instantiate a LevelSession3D." % definition.scene.resource_path
	)
	current_level_definition = definition
	current_world_definition = world_definition
	if world_definition == null:
		current_level.name = (
			"Developer"
			+ String(definition.level_id).trim_prefix("dev_").to_pascal_case()
		)
	else:
		current_level.name = (
			"World%02dLevel%02d"
			% [world_definition.display_number, definition.display_number]
		)
	var session_store := _progression_store() if world_definition != null else null
	current_level.configure(definition, session_store, initial_session_abilities)
	world.add_child(current_level)
	current_level.run_completed.connect(_on_run_completed)
	current_level.transition_requested.connect(_on_transition_requested)
	current_level.run_reset.connect(_on_run_reset)
	current_level.ability_unlocked.connect(_on_ability_unlocked)
	var session_heading := definition.heading()
	if world_definition == null:
		session_heading = "DEVELOPER TOOLS / %s" % definition.title.to_upper()
	else:
		session_heading = world_definition.menu_heading() + " / " + definition.heading()
	level_label.text = (
		session_heading
		+ "\nMove: A / D or left stick    Jump: SPACE / gamepad A"
		+ "    Dash: SHIFT / gamepad B"
		+ "    Attack: LEFT CLICK / J / gamepad X    Reset: R"
	)
	level_select.visible = false
	menu_hint.visible = true
	completion_label.visible = false
	_reset_completion_fade()
	_hide_ability_tutorial()
	_configure_developer_ability_panel(world_definition == null)
	_set_gameplay_tools_visible(false)
	_set_developer_inspection_enabled(false)
	_set_developer_measurement_grid_enabled(false)
	_set_developer_collision_overlay_enabled(false)


func show_level_select() -> void:
	_free_current_level()
	current_level_definition = null
	current_world_definition = null
	_gameplay_tools_visible = false
	_developer_inspection_enabled = false
	_developer_measurement_grid_enabled = false
	_developer_collision_overlay_enabled = false
	level_select.visible = true
	instructions.visible = false
	menu_hint.visible = false
	completion_label.visible = false
	_reset_completion_fade()
	developer_inspection_label.visible = false
	developer_measurement_label.visible = false
	developer_cursor_coordinate_label.visible = false
	developer_collision_legend.visible = false
	_hide_ability_tutorial()
	_configure_developer_ability_panel(false)
	if not _level_buttons.is_empty():
		_level_buttons.front().grab_focus()


func _build_world_list() -> void:
	for child in world_list.get_children():
		child.queue_free()
	_level_buttons.clear()
	for world_definition in campaign.ordered_worlds():
		var heading := Label.new()
		heading.name = "World%02dHeading" % world_definition.display_number
		heading.add_theme_color_override("font_color", Color(0.43, 1.0, 0.72, 1.0))
		heading.add_theme_font_size_override("font_size", 19)
		heading.text = world_definition.menu_heading()
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		world_list.add_child(heading)

		for definition in world_definition.ordered_levels():
			var button := Button.new()
			button.name = (
				"World%02dLevel%02dButton"
				% [world_definition.display_number, definition.display_number]
			)
			button.custom_minimum_size = Vector2(0.0, 64.0)
			button.add_theme_font_size_override("font_size", 22)
			if level_button_style != null:
				button.add_theme_stylebox_override("normal", level_button_style)
			button.text = definition.menu_label()
			button.set_meta(&"level_id", definition.level_id)
			button.pressed.connect(_load_button_level.bind(button))
			world_list.add_child(button)
			_level_buttons.append(button)

	var developer_definitions := _ordered_developer_definitions()
	if developer_tools_enabled and not developer_definitions.is_empty():
		var heading := Label.new()
		heading.name = "DeveloperToolsHeading"
		heading.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32, 1.0))
		heading.add_theme_font_size_override("font_size", 17)
		heading.text = "DEVELOPER TOOLS"
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		world_list.add_child(heading)

		for definition in developer_definitions:
			var button := Button.new()
			button.name = (
				"%sButton"
				% String(definition.level_id).trim_prefix("dev_").to_pascal_case()
			)
			button.custom_minimum_size = Vector2(0.0, 58.0)
			button.add_theme_font_size_override("font_size", 20)
			if level_button_style != null:
				button.add_theme_stylebox_override("normal", level_button_style)
			button.text = definition.title.to_upper()
			button.set_meta(&"developer_level_definition", definition)
			if definition == developer_room_definition:
				button.set_meta(&"developer_room", true)
			button.pressed.connect(_load_button_level.bind(button))
			world_list.add_child(button)
			_level_buttons.append(button)


func _ordered_developer_definitions() -> Array[LevelDefinition]:
	var definitions: Array[LevelDefinition] = []
	for definition in developer_level_definitions:
		if definition != null and definition not in definitions:
			definitions.append(definition)
	if developer_room_definition != null and developer_room_definition not in definitions:
		definitions.append(developer_room_definition)
	return definitions


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
	var developer_definition: LevelDefinition
	if button.has_meta(&"developer_level_definition"):
		developer_definition = button.get_meta(
			&"developer_level_definition"
		) as LevelDefinition
	if developer_definition != null:
		load_developer_level(developer_definition)
	else:
		load_level(button.get_meta(&"level_id") as StringName)


func _configure_developer_ability_panel(enabled: bool) -> void:
	for child in developer_ability_toggles.get_children():
		child.queue_free()
	_developer_ability_panel_available = (
		enabled
		and developer_tools_enabled
		and current_level != null
		and current_level_definition == developer_room_definition
	)
	developer_ability_panel.visible = false
	if not _developer_ability_panel_available:
		return
	for ability_id in developer_room_definition.available_abilities:
		var toggle := CheckButton.new()
		toggle.name = "%sToggle" % String(ability_id).to_pascal_case()
		toggle.add_theme_font_size_override("font_size", 17)
		toggle.text = PlayerAbility.display_name(ability_id)
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.button_pressed = current_level.player.has_ability(ability_id)
		toggle.toggled.connect(_on_developer_ability_toggled.bind(ability_id))
		developer_ability_toggles.add_child(toggle)
	_apply_gameplay_tools_visibility()


func _set_gameplay_tools_visible(visible: bool) -> void:
	_gameplay_tools_visible = (
		visible
		and current_level != null
		and not level_select.visible
	)
	_apply_gameplay_tools_visibility()


func _apply_gameplay_tools_visibility() -> void:
	instructions.visible = _gameplay_tools_visible
	developer_ability_panel.visible = (
		_gameplay_tools_visible
		and _developer_ability_panel_available
	)
	if menu_hint.visible:
		_update_menu_hint()


func _set_developer_inspection_enabled(enabled: bool) -> void:
	_developer_inspection_enabled = (
		enabled
		and developer_tools_enabled
		and current_level != null
		and not level_select.visible
	)
	if current_level != null:
		current_level.set_developer_inspection_enabled(_developer_inspection_enabled)
	developer_inspection_label.visible = _developer_inspection_enabled
	if menu_hint.visible:
		_update_menu_hint()


func _set_developer_measurement_grid_enabled(enabled: bool) -> void:
	_developer_measurement_grid_enabled = (
		enabled
		and developer_tools_enabled
		and current_level != null
		and not level_select.visible
	)
	if current_level != null:
		current_level.set_developer_measurement_grid_enabled(
			_developer_measurement_grid_enabled
		)
	developer_measurement_label.visible = _developer_measurement_grid_enabled
	developer_cursor_coordinate_label.visible = _developer_measurement_grid_enabled
	if menu_hint.visible:
		_update_menu_hint()


func _set_developer_collision_overlay_enabled(enabled: bool) -> void:
	_developer_collision_overlay_enabled = (
		enabled
		and developer_tools_enabled
		and current_level != null
		and not level_select.visible
	)
	if current_level != null:
		current_level.set_developer_collision_overlay_enabled(
			_developer_collision_overlay_enabled
		)
	developer_collision_legend.visible = _developer_collision_overlay_enabled
	if menu_hint.visible:
		_update_menu_hint()


func _process(_delta: float) -> void:
	if not _developer_measurement_grid_enabled or current_level == null:
		return
	developer_measurement_label.text = (
		"GRID 1.28 m / 0.64 m    PLAYER FEET  X %.2f    Y %.2f"
		% [
			current_level.player.global_position.x,
			current_level.player.feet_world_y(),
		]
	)
	_update_developer_cursor_coordinate()


func developer_world_position_at_screen_position(screen_position: Vector2) -> Vector2:
	if current_level == null or current_level.camera == null:
		return Vector2.ZERO
	var ray_origin: Vector3 = current_level.camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = current_level.camera.project_ray_normal(screen_position)
	if is_zero_approx(ray_direction.z):
		return Vector2(ray_origin.x, ray_origin.y)
	var distance_to_gameplay_plane: float = -ray_origin.z / ray_direction.z
	var world_position: Vector3 = ray_origin + ray_direction * distance_to_gameplay_plane
	return Vector2(world_position.x, world_position.y)


func _update_developer_cursor_coordinate() -> void:
	_update_developer_cursor_coordinate_at(get_viewport().get_mouse_position())


func _update_developer_cursor_coordinate_at(mouse_position: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if not Rect2(Vector2.ZERO, viewport_size).has_point(mouse_position):
		developer_cursor_coordinate_label.visible = false
		return
	developer_cursor_coordinate_label.visible = true
	var world_position := developer_world_position_at_screen_position(mouse_position)
	developer_cursor_coordinate_label.text = (
		"X %.2f    Y %.2f" % [world_position.x, world_position.y]
	)
	developer_cursor_coordinate_label.reset_size()
	var desired_position := mouse_position + Vector2(18.0, 20.0)
	var maximum_position := (
		viewport_size
		- developer_cursor_coordinate_label.size
		- Vector2(8.0, 8.0)
	)
	developer_cursor_coordinate_label.position = Vector2(
		clampf(desired_position.x, 8.0, maxf(8.0, maximum_position.x)),
		clampf(desired_position.y, 8.0, maxf(8.0, maximum_position.y))
	)


func _update_menu_hint() -> void:
	var collision_hint := (
		"F7: HIDE HITBOXES"
		if _developer_collision_overlay_enabled
		else "F7: HITBOXES"
	)
	var grid_hint := (
		"F10: HIDE GRID"
		if _developer_measurement_grid_enabled
		else "F10: GRID"
	)
	if _developer_inspection_enabled:
		menu_hint.text = (
			"%s    %s    F11: EXIT INSPECTION    ESC: SELECT"
			% [collision_hint, grid_hint]
		)
	elif not developer_tools_enabled:
		menu_hint.text = (
			"F1: HIDE TOOLS    ESC: LEVEL SELECT"
			if _gameplay_tools_visible
			else "F1: TOOLS    ESC: LEVEL SELECT"
		)
	elif _gameplay_tools_visible:
		menu_hint.text = (
			"F1: HIDE    %s    %s    F11: INSPECT    ESC: SELECT"
			% [collision_hint, grid_hint]
		)
	else:
		menu_hint.text = (
			"F1: TOOLS    %s    %s    F11: INSPECT    ESC: SELECT"
			% [collision_hint, grid_hint]
		)


func _on_developer_ability_toggled(enabled: bool, ability_id: StringName) -> void:
	if current_level == null or current_world_definition != null:
		return
	current_level.set_session_ability_enabled(ability_id, enabled)


func _progression_store() -> ProgressionStore:
	if developer_fresh_level_runs or not persist_progression:
		return null
	return get_node_or_null("/root/GameProgression") as ProgressionStore


func _free_current_level() -> void:
	if current_level == null:
		return
	world.remove_child(current_level)
	current_level.free()
	current_level = null
	_developer_inspection_enabled = false
	_developer_measurement_grid_enabled = false
	_developer_collision_overlay_enabled = false
	developer_inspection_label.visible = false
	developer_measurement_label.visible = false
	developer_cursor_coordinate_label.visible = false
	developer_collision_legend.visible = false


func _on_run_completed() -> void:
	completion_label.visible = true
	_reset_completion_fade()
	completion_fade.visible = true
	_completion_fade_tween = create_tween()
	_completion_fade_tween.set_trans(Tween.TRANS_SINE)
	_completion_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_completion_fade_tween.tween_property(
		completion_fade,
		"modulate:a",
		1.0,
		0.55
	)
	var store := _progression_store()
	if (
		store != null
		and current_level_definition != null
		and current_world_definition != null
	):
		store.mark_level_completed(current_level_definition.level_id)


func _on_run_reset() -> void:
	completion_label.visible = false
	_reset_completion_fade()


## Running into a threshold fades out, swaps the scene behind the black, and
## fades back in. The player never sees two terrain grammars meet, which is the
## whole reason a doorway is a fade rather than a seam.
func _on_transition_requested(target: LevelDefinition) -> void:
	if target == null:
		return
	await _fade_to_black(0.45)
	if target in _ordered_developer_definitions():
		load_developer_level(target)
	else:
		load_level(target.level_id)
	await _fade_from_black(0.45)


func _fade_to_black(duration: float) -> void:
	_reset_completion_fade()
	completion_fade.visible = true
	completion_fade.modulate.a = 0.0
	_completion_fade_tween = create_tween()
	_completion_fade_tween.set_trans(Tween.TRANS_SINE)
	_completion_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_completion_fade_tween.tween_property(completion_fade, "modulate:a", 1.0, duration)
	await _completion_fade_tween.finished


## Held opaque across the load, then lifted, so the new scene never pops in.
func _fade_from_black(duration: float) -> void:
	if _completion_fade_tween != null and _completion_fade_tween.is_valid():
		_completion_fade_tween.kill()
	completion_fade.visible = true
	completion_fade.modulate.a = 1.0
	_completion_fade_tween = create_tween()
	_completion_fade_tween.set_trans(Tween.TRANS_SINE)
	_completion_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_completion_fade_tween.tween_property(completion_fade, "modulate:a", 0.0, duration)
	await _completion_fade_tween.finished
	_reset_completion_fade()


func _reset_completion_fade() -> void:
	if _completion_fade_tween != null and _completion_fade_tween.is_valid():
		_completion_fade_tween.kill()
	_completion_fade_tween = null
	if completion_fade == null:
		return
	completion_fade.modulate.a = 0.0
	completion_fade.visible = false


func _on_ability_unlocked(ability_id: StringName) -> void:
	ability_tutorial_label.text = (
		"%s UNLOCKED\n%s"
		% [
			PlayerAbility.display_name(ability_id),
			PlayerAbility.instruction(ability_id),
		]
	)
	ability_tutorial.visible = true
	ability_tutorial_timer.start()


func _hide_ability_tutorial() -> void:
	ability_tutorial_timer.stop()
	ability_tutorial.visible = false
