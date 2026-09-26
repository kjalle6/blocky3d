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

var campaign_menu: CanvasLayer
var _campaign_mode := false
var health_inventory_hud: Control
var loot_receipt: Control
var current_level: LevelSession3D
var current_level_definition: LevelDefinition
var current_world_definition: WorldDefinition
var _active_interstitial: LevelInterstitial3D
var _transition_serial := 0
var _level_buttons: Array[Button] = []
var _gameplay_tools_visible := false
var _developer_ability_panel_available := false
var _developer_inspection_enabled := false
var _developer_measurement_grid_enabled := false
var _developer_collision_overlay_enabled := false
var audio_tuning_panel: CanvasLayer
var cave_ambience: AudioStreamPlayer
var event_audio: Node
var _audio_tools_button: Button
var _designer_tools_button: Button
var _restart_tools_button: Button
var level_designer: CanvasLayer
var _developer_tool_owner := ""

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
@onready var weapon_status_hud: WeaponStatusHUD = %WeaponStatusHUD
@onready var completion_fade: ColorRect = %CompletionFade

var _completion_fade_tween: Tween

const TRANSITION_FADE_DURATION := 0.45
const INTERSTITIAL_EXIT_FADE_DURATION := 0.22


func _ready() -> void:
	if not preload("res://scripts/developer/level_layout_registry.gd").can_author():
		developer_tools_enabled = false
	assert(campaign != null, "GameRoot requires a CampaignCatalog.")
	var catalog_errors := campaign.validation_errors()
	assert(
		catalog_errors.is_empty(),
		"Campaign catalog is invalid:\n%s" % "\n".join(catalog_errors)
	)
	ability_tutorial_timer.timeout.connect(_hide_ability_tutorial)
	developer_mode_label.visible = developer_fresh_level_runs
	_build_world_list()
	_build_audio_tools()
	campaign_menu = preload("res://scripts/ui/campaign_menu.gd").new()
	campaign_menu.name = "CampaignMenu"
	add_child(campaign_menu)
	health_inventory_hud = preload("res://scripts/ui/health_inventory_hud.gd").new()
	health_inventory_hud.name = "HealthInventoryHUD"
	get_node("Interface").add_child(health_inventory_hud)
	loot_receipt = preload("res://scripts/ui/loot_receipt.gd").new()
	get_node("Interface").add_child(loot_receipt)
	event_audio = preload("res://scripts/audio/app_event_audio.gd").new()
	event_audio.name = "EventAudio"
	add_child(event_audio)
	level_designer = preload("res://scripts/developer/level_designer.gd").new()
	level_designer.name = "LevelDesigner"
	add_child(level_designer)
	_designer_tools_button = Button.new()
	_designer_tools_button.text = "Level designer…"
	_designer_tools_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_designer_tools_button.position = Vector2(-220, 156)
	_designer_tools_button.custom_minimum_size = Vector2(200, 44)
	_designer_tools_button.add_theme_font_size_override("font_size", 20)
	get_node("Interface").add_child(_designer_tools_button)
	_designer_tools_button.pressed.connect(level_designer.open_panel)
	_restart_tools_button = Button.new()
	_restart_tools_button.name = "RestartLevel"
	_restart_tools_button.text = "Restart level"
	_restart_tools_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_restart_tools_button.position = Vector2(-640, 156)
	_restart_tools_button.custom_minimum_size = Vector2(200, 44)
	_restart_tools_button.add_theme_font_size_override("font_size", 20)
	_restart_tools_button.focus_mode = Control.FOCUS_NONE
	get_node("Interface").add_child(_restart_tools_button)
	_restart_tools_button.pressed.connect(_restart_developer_level)
	cave_ambience = preload("res://scripts/audio/cave_ambience_player.gd").new()
	cave_ambience.name = "CaveAmbience"
	add_child(cave_ambience)
	show_level_select()


func _restart_developer_level() -> void:
	if current_level == null or _campaign_mode:
		return
	if not _developer_tool_owner.is_empty() and not (_developer_tool_owner == "designer" and not level_designer.is_editing()):
		return
	current_level._reset_run()
	current_level.camera.snap_to_target()
	if current_level.background != null:
		current_level.background.snap_to_camera()


func _build_audio_tools() -> void:
	audio_tuning_panel = preload("res://scripts/developer/audio_tuning_panel.gd").new()
	add_child(audio_tuning_panel)
	audio_tuning_panel.closed.connect(func() -> void: _set_gameplay_tools_visible(false))
	_audio_tools_button = Button.new()
	_audio_tools_button.text = "Audio tuning…"
	_audio_tools_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_audio_tools_button.position = Vector2(-430, 156)
	_audio_tools_button.custom_minimum_size = Vector2(200, 44)
	_audio_tools_button.add_theme_font_size_override("font_size", 20)
	get_node("Interface").add_child(_audio_tools_button)
	_audio_tools_button.pressed.connect(audio_tuning_panel.open_panel)


func _unhandled_input(event: InputEvent) -> void:
	if level_designer != null and level_designer.is_editing(): return
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
		campaign_menu.show_pause()
	else:
		return
	get_viewport().set_input_as_handled()


func load_level(level_id: StringName) -> void:
	var definition := campaign.find_by_id(level_id)
	var world_definition := campaign.find_world_for_level(level_id)
	assert(definition != null, "Unknown campaign level: %s" % level_id)
	assert(world_definition != null, "Campaign level has no owning world: %s" % level_id)
	var initial_session_abilities: Array[StringName] = []
	if not _campaign_mode and (developer_fresh_level_runs or not persist_progression):
		initial_session_abilities = definition.assumed_owned_abilities.duplicate()
	_start_session(definition, world_definition, initial_session_abilities)


func load_developer_room() -> void:
	assert(developer_tools_enabled, "Developer tools are disabled.")
	assert(developer_room_definition != null, "GameRoot requires a developer room definition.")
	load_developer_level(developer_room_definition)


func load_developer_level(definition: LevelDefinition, entry_id: StringName = &"") -> void:
	_campaign_mode = false
	assert(developer_tools_enabled, "Developer tools are disabled.")
	assert(definition != null, "A developer level definition is required.")
	assert(
		definition in _known_developer_definitions(),
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
	var entry := definition.find_developer_entry_point(entry_id)
	assert(entry_id.is_empty() or entry != null, "Unknown level entry point: %s" % entry_id)
	_start_session(
		definition,
		null,
		initial_abilities,
		entry.scene if entry != null else null
	)


func _start_session(
	definition: LevelDefinition,
	world_definition: WorldDefinition,
	initial_session_abilities: Array[StringName] = [],
	scene_override: PackedScene = null,
	layout_override: Variant = null,
	preview_mode := false,
	preview_fingerprint := ""
) -> bool:
	var session_scene := scene_override if scene_override != null else definition.scene
	var candidate := session_scene.instantiate() as LevelSession3D
	if candidate == null:
		show_developer_message("Could not load the level", "The scene is not a level session.")
		return false
	var resolver := preload("res://scripts/developer/level_layout_resolver.gd")
	var layout_error: String = resolver.apply_saved(candidate) if layout_override == null else resolver.apply_layout(candidate, layout_override, preview_fingerprint if preview_mode else "")
	if not layout_error.is_empty():
		candidate.free()
		show_developer_message("Could not load the level layout", layout_error)
		return false
	_free_current_level()
	_free_active_interstitial()
	current_level = candidate
	assert(
		current_level != null,
		"%s must instantiate a LevelSession3D." % session_scene.resource_path
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
	var session_store := _progression_store() if world_definition != null or _campaign_mode else null
	current_level.configure(definition, session_store, initial_session_abilities)
	if preview_mode:
		preload("res://scripts/developer/level_layout_preview.gd").prepare(current_level)
	world.add_child(current_level)
	if preview_mode:
		preload("res://scripts/developer/level_layout_preview.gd").finish(current_level)
	else:
		current_level.death_menu_requested.connect(campaign_menu.show_death)
		current_level.retry_requested.connect(campaign_menu.show_pause)
		current_level.run_completed.connect(_on_run_completed)
		current_level.transition_requested.connect(_on_transition_requested)
		current_level.run_reset.connect(_on_run_reset)
		current_level.ability_unlocked.connect(_on_ability_unlocked)
		weapon_status_hud.bind_session(current_level)
		health_inventory_hud.bind_session(current_level)
		loot_receipt.bind_session(current_level)
	var session_heading := definition.heading()
	if world_definition == null:
		session_heading = "DEVELOPER TOOLS / %s" % definition.title.to_upper()
	else:
		session_heading = world_definition.menu_heading() + " / " + definition.heading()
	level_label.text = (
		session_heading
		+ "\nMove: A / D or left stick    Jump: SPACE / gamepad A"
		+ "    Dash: SHIFT / gamepad B"
		+ "    Attack: LEFT CLICK / J / gamepad X    Reload: R / gamepad Y"
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
	return true


func show_level_select() -> void:
	if level_designer != null and level_designer.is_active():
		level_designer.request_close(true)
		return
	_campaign_mode = false
	_transition_serial += 1
	_free_current_level()
	_free_active_interstitial()
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
	if _audio_tools_button != null: _audio_tools_button.visible = developer_tools_enabled
	if _designer_tools_button != null: _designer_tools_button.visible = false
	if _restart_tools_button != null: _restart_tools_button.visible = false
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
			_add_developer_level_button(definition)
			for entry in definition.developer_entry_points:
				_add_developer_level_button(definition, entry)


func _add_developer_level_button(definition: LevelDefinition, entry: LevelEntryPoint = null) -> void:
	var button := Button.new()
	var level_name := String(definition.level_id).trim_prefix("dev_").to_pascal_case()
	var entry_name := String(entry.entry_id).to_pascal_case() if entry != null else ""
	button.name = level_name + entry_name + "Button"
	button.custom_minimum_size = Vector2(0.0, 58.0)
	button.add_theme_font_size_override("font_size", 20)
	if level_button_style != null:
		button.add_theme_stylebox_override("normal", level_button_style)
	button.text = (entry.title if entry != null else definition.title).to_upper()
	button.set_meta(&"developer_level_definition", definition)
	if entry != null:
		button.set_meta(&"developer_entry_id", entry.entry_id)
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


func _known_developer_definitions() -> Array[LevelDefinition]:
	return _ordered_developer_definitions()


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
		load_developer_level(developer_definition, button.get_meta(&"developer_entry_id", &""))
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
	if _restart_tools_button != null:
		_restart_tools_button.visible = _gameplay_tools_visible and developer_tools_enabled and not _campaign_mode
	if _audio_tools_button != null:
		_audio_tools_button.visible = _gameplay_tools_visible and developer_tools_enabled
	if _designer_tools_button != null:
		_designer_tools_button.visible = _gameplay_tools_visible and developer_tools_enabled and preload("res://scripts/developer/level_layout_registry.gd").can_author()
	developer_ability_panel.visible = (
		_gameplay_tools_visible
		and _developer_ability_panel_available
	)
	for panel in get_tree().get_nodes_in_group("developer_lab_tools"):
		(panel as Control).visible = _gameplay_tools_visible and developer_tools_enabled
	for readout in get_tree().get_nodes_in_group("developer_lab_readout"):
		(readout as CanvasItem).visible = not _gameplay_tools_visible
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
	if _gameplay_tools_visible:
		# Let wrapped instructions determine the dock height before placing tools.
		var tools_y := instructions.get_rect().end.y + 12.0
		_audio_tools_button.position.y = tools_y
		_designer_tools_button.position.y = tools_y
		_restart_tools_button.position.y = tools_y
		developer_ability_panel.position.y = tools_y + 56.0
		var lab_tools_y := tools_y + 56.0
		for panel in get_tree().get_nodes_in_group("developer_lab_tools"):
			(panel as Control).position.y = lab_tools_y
			lab_tools_y = (panel as Control).get_rect().end.y + 12.0
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
			"%s    %s    F11: EXIT INSPECTION    ESC: PAUSE"
			% [collision_hint, grid_hint]
		)
	elif not developer_tools_enabled:
		menu_hint.text = (
			"F1: HIDE TOOLS    ESC: PAUSE"
			if _gameplay_tools_visible
			else "TAB: INVENTORY    F1: TOOLS    ESC: PAUSE"
		)
	elif _gameplay_tools_visible:
		menu_hint.text = (
			"F1: HIDE    %s    %s    F11: INSPECT    ESC: PAUSE"
			% [collision_hint, grid_hint]
		)
	else:
		menu_hint.text = "TAB: INVENTORY    F1: TOOLS    ESC: PAUSE"


func _on_developer_ability_toggled(enabled: bool, ability_id: StringName) -> void:
	if current_level == null or current_world_definition != null:
		return
	current_level.set_session_ability_enabled(ability_id, enabled)


func continue_legacy_campaign() -> bool:
	var store := get_node("/root/GameProgression") as ProgressionStore
	if store.progress.completed_level_ids.is_empty() and store.progress.unlocked_ability_ids.is_empty():
		return false
	var definition: LevelDefinition = campaign.ordered_levels().back()
	for candidate in campaign.ordered_levels():
		if not store.has_completed(candidate.level_id):
			definition = candidate
			break
	_campaign_mode = true
	if not _start_session(definition, campaign.find_world_for_level(definition.level_id)):
		return false
	current_level.player.health.reset(store.progress.maximum_hp)
	current_level._session_owned_weapon_ids.assign(store.progress.owned_weapon_ids)
	current_level.player.configure_weapon_ownership(store.progress.owned_weapon_ids)
	current_level.save_state.queue_entry()
	campaign_menu.notify_user("Legacy progress restored at the level entrance with 100 HP and no supplies.")
	return true


func start_campaign() -> bool:
	var store := get_node("/root/GameProgression") as ProgressionStore
	if not store.start_new_campaign():
		return false
	_campaign_mode = true
	var first: LevelDefinition = campaign.ordered_levels().front()
	if not _start_session(first, campaign.find_world_for_level(first.level_id)):
		return false
	current_level.save_state.queue_entry()
	return true


func load_snapshot(snapshot: Dictionary, ordinary_retry := false) -> String:
	var returning_from_death := is_instance_valid(current_level) and current_level.player.is_dead()
	var error := SaveSnapshot.validation_error(snapshot)
	if not error.is_empty():
		return error
	var registry := preload("res://scripts/developer/level_layout_registry.gd")
	var definition := campaign.find_by_id(StringName(snapshot.level_id))
	if definition == null:
		for candidate in _known_developer_definitions():
			if String(candidate.level_id) == snapshot.level_id:
				definition = candidate
	if definition == null:
		return "This saved level is unavailable."
	var scene := load(registry.SECTIONS[snapshot.section]) as PackedScene
	var candidate := scene.instantiate() as LevelSession3D
	if candidate == null:
		return "The saved section could not be created."
	error = preload("res://scripts/developer/level_layout_resolver.gd").apply_saved(candidate)
	candidate.free()
	if not error.is_empty():
		return error
	var store := get_node("/root/GameProgression") as ProgressionStore
	var previous := store.progress.to_dictionary()
	# Explicit load always rolls back. Ordinary Continue may retain permanent
	# unlocks after an autosave, but never later unlocks from a manual save.
	if not store.restore_progress(snapshot, ordinary_retry and snapshot.kind == "auto"):
		return store.last_error
	_campaign_mode = true
	if not _start_session(definition, campaign.find_world_for_level(definition.level_id), [], scene):
		store.progress = GameProgress.from_dictionary(previous)
		store.save_progress()
		return "The saved section could not be loaded."
	current_level.save_state.apply_state(snapshot, true)
	if returning_from_death:
		current_level.get_node("EventAudio").play("combat/player_respawn", current_level.player)
	return ""


func _progression_store() -> ProgressionStore:
	if level_designer != null and level_designer.is_active(): return null
	if not _campaign_mode and (developer_fresh_level_runs or not persist_progression):
		return null
	return get_node_or_null("/root/GameProgression") as ProgressionStore


func _free_current_level() -> void:
	if audio_tuning_panel != null:
		audio_tuning_panel.close_panel()
	weapon_status_hud.unbind_session()
	if health_inventory_hud != null:
		health_inventory_hud.bind_session(null)
	if loot_receipt != null:
		loot_receipt.bind_session(null)
	if current_level == null:
		return
	world.remove_child(current_level)
	current_level.free()
	current_level = null
	preload("res://scripts/audio/movement_audio_mix.gd").clear_gameplay_tails()
	_developer_inspection_enabled = false
	_developer_measurement_grid_enabled = false
	_developer_collision_overlay_enabled = false
	developer_inspection_label.visible = false
	developer_measurement_label.visible = false
	developer_cursor_coordinate_label.visible = false
	developer_collision_legend.visible = false


func _free_active_interstitial() -> void:
	if _active_interstitial == null:
		return
	world.remove_child(_active_interstitial)
	_active_interstitial.free()
	_active_interstitial = null


func active_interstitial() -> LevelInterstitial3D:
	return _active_interstitial


func _on_run_completed() -> void:
	completion_label.visible = true
	_reset_completion_fade()
	completion_fade.visible = true
	_completion_fade_tween = create_tween()
	_completion_fade_tween.set_trans(Tween.TRANS_SINE)
	_completion_fade_tween.set_ease(Tween.EASE_IN_OUT)
	var fade_duration := 0.55
	if current_level != null:
		fade_duration = current_level.completion_fade_duration
	_completion_fade_tween.tween_property(
		completion_fade,
		"modulate:a",
		1.0,
		fade_duration
	)
	_mark_campaign_level_completed(
		current_level_definition,
		current_world_definition
	)


func _on_run_reset() -> void:
	completion_label.visible = false
	_reset_completion_fade()


## Running into a threshold fades out, swaps the scene behind the black, and
## fades back in. The player never sees two terrain grammars meet, which is the
## whole reason a doorway is a fade rather than a seam.
func _on_transition_requested(
	target_level: LevelDefinition,
	target_scene: PackedScene,
	run_direction: float,
	run_speed: float,
	run_duration: float,
	interstitial_scene: PackedScene,
	completes_source_level: bool,
	session_abilities: Array[StringName]
) -> void:
	if target_level == null and target_scene == null:
		return
	var carried_state := current_level.save_state.transfer_state()
	var source_definition := current_level_definition
	var source_world := current_world_definition
	if completes_source_level:
		if current_level.has_node("EventAudio"):
			current_level.get_node("EventAudio").play("pickups/level_complete", current_level.player)
		event_audio.level_completed()
		_mark_campaign_level_completed(source_definition, source_world)
	_transition_serial += 1
	var transition_serial := _transition_serial
	await _fade_to_black(TRANSITION_FADE_DURATION)
	if transition_serial != _transition_serial:
		return
	if interstitial_scene != null:
		_free_current_level()
		var interstitial := (
			interstitial_scene.instantiate() as LevelInterstitial3D
		)
		assert(
			interstitial != null,
			"Transition interstitial must instantiate a LevelInterstitial3D."
		)
		var interstitial_finished := [false]
		interstitial.finished.connect(
			func(_skipped: bool) -> void:
				interstitial_finished[0] = true
		)
		_active_interstitial = interstitial
		world.add_child(interstitial)
		await _fade_from_black(TRANSITION_FADE_DURATION)
		if transition_serial != _transition_serial:
			return
		while not interstitial_finished[0]:
			if (
				transition_serial != _transition_serial
				or _active_interstitial != interstitial
			):
				return
			await get_tree().process_frame
		await _fade_to_black(INTERSTITIAL_EXIT_FADE_DURATION)
		if transition_serial != _transition_serial:
			return
		_free_active_interstitial()
	if target_scene != null:
		assert(
			source_definition != null,
			"A same-level scene transition requires an active level definition."
		)
		_start_session(
			source_definition,
			source_world,
			_transition_entry_abilities(source_definition, session_abilities),
			target_scene
		)
	elif target_level in _known_developer_definitions():
		_start_session(
			target_level,
			null,
			_transition_entry_abilities(target_level, session_abilities)
		)
	else:
		var target_world := campaign.find_world_for_level(target_level.level_id)
		assert(
			target_world != null,
			"Transition target has no campaign world: %s" % target_level.level_id
		)
		_start_session(
			target_level,
			target_world,
			_transition_entry_abilities(target_level, session_abilities)
		)
	if current_level != null:
		current_level.save_state.apply_state(carried_state)
		if current_level._progression_store != null:
			current_level.save_state.queue_entry()
	if current_level != null and run_duration > 0.0:
		current_level.player.begin_transition_run(
			run_direction,
			run_speed,
			run_duration
		)
	await _fade_from_black(TRANSITION_FADE_DURATION)


func _mark_campaign_level_completed(
	definition: LevelDefinition,
	world_definition: WorldDefinition
) -> void:
	var store := _progression_store()
	if store != null and definition != null and world_definition != null:
		store.mark_level_completed(definition.level_id)


func _transition_entry_abilities(
	definition: LevelDefinition,
	carried_abilities: Array[StringName]
) -> Array[StringName]:
	var abilities := definition.assumed_owned_abilities.duplicate()
	for ability_id in carried_abilities:
		if ability_id in definition.available_abilities and ability_id not in abilities:
			abilities.append(ability_id)
	return abilities


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


func claim_developer_tool(owner: String) -> bool:
	if owner == "designer" and audio_tuning_panel != null: audio_tuning_panel.close_panel()
	if not _developer_tool_owner.is_empty() and _developer_tool_owner != owner: return false
	_developer_tool_owner = owner
	return true


func release_developer_tool(owner: String) -> void:
	if _developer_tool_owner == owner: _developer_tool_owner = ""


func show_developer_message(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(600, 180))
