extends CanvasLayer
## Developer-only listening UI. The world pauses; these preview voices do not.
signal closed
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const EVENTS := preload("res://scripts/audio/sound_event_catalog.gd")
const EVENT_VOICE := preload("res://scripts/audio/sound_event_voice.gd")
const SOURCE_DIRECTORY := "D:/GodotProjects/blocky3dassets/audio/Sounds/Footsteps_Essentials_NOX_SOUND"
const SURFACES := ["grass", "sand", "cave", "underground"]
const SPACES := [&"outdoors", &"cave", &"underground"]
const RUN_STEP_INTERVAL: float = 3.0 / PixelPlayerVisual3D.FRAME_RATES["run"]
var surface := "grass"
var kind := "run"
var category := "movement"
var event_id := ""
var is_open := false
var _was_paused := false
var _gameplay_bus_mutes: Dictionary = {}
var _preview_environment: StringName = &"outdoors"
var _random := RandomNumberGenerator.new()
var _previous := -1
var _next_left := true
var _repeat := false
var _countdown := 0.0
var _voices: Array[AudioStreamPlayer] = []
var _event_voice: AudioStreamPlayer
var _overlay: Control
var _body: VBoxContainer
var _surface_picker: OptionButton
var _category_picker: OptionButton
var _kind_picker: OptionButton
var _status: Label
var _now_playing: Label
var _comparison: Button
var _save: Button
var _file_dialog: FileDialog
var _ambience_file_dialog: FileDialog
var _ambience_picker_environment: StringName = &"cave"
var _pace: OptionButton
var _space: OptionButton
var _repeat_button: Button
var _play_button: Button
var _stop_button: Button
var _scroll: ScrollContainer
var _rebuilding := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if MIX.working.is_empty():
		MIX.initialize()
	_random.randomize()
	for index in 4:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_event_voice = EVENT_VOICE.new()
	add_child(_event_voice)
	_build()
	_overlay.hide()

func open_panel() -> void:
	if is_open:
		return
	if get_parent().has_method("claim_developer_tool") and not get_parent().claim_developer_tool("audio"):
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_gameplay_bus_mutes = MIX.mute_gameplay_reverb()
	_overlay.show()
	_refresh()

func close_panel() -> void:
	if not is_open:
		return
	_stop_preview()
	_file_dialog.hide()
	_ambience_file_dialog.hide()
	_overlay.hide()
	is_open = false
	if get_parent().has_method("release_developer_tool"): get_parent().release_developer_tool("audio")
	MIX.restore_gameplay_reverb(_gameplay_bus_mutes)
	get_tree().paused = _was_paused
	closed.emit()

func _exit_tree() -> void:
	if is_open:
		MIX.clear_preview_tails()
		MIX.restore_gameplay_reverb(_gameplay_bus_mutes)
		get_tree().paused = _was_paused

func _input(event: InputEvent) -> void:
	if not is_open or _file_dialog.visible or _ambience_file_dialog.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_F1]:
			get_viewport().set_input_as_handled()
			close_panel()

func _process(delta: float) -> void:
	if is_open and category != "movement" and not _is_room_ambience() and _event_voice.playing:
		var bank := _bank()
		_event_voice.volume_db = bank.volume_db
		_event_voice.bus = MIX.preview_bus(_preview_environment) if bank.use_room_reverb else &"Master"
	if not is_open or not _repeat:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		if category != "movement":
			# Repetition never layers a recording over its own tail; loops run in
			# the mixer and are not restarted at each preview interval.
			if not _event_voice.playing:
				_preview_contact()
			_countdown = maxf(0.1, _bank().repeat_interval)
			return
		_preview_contact()
		# Keep the preview tied to the running animation's contact interval.
		_countdown = (RUN_STEP_INTERVAL if _pace.selected == 0 else 3.0 / 7.8) if kind in ["run", "walk", "step"] else 1.0

func _build() -> void:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.014, 0.025, 0.82)
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	_overlay.add_child(panel)
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.09
	panel.anchor_bottom = 0.91
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e2c")
	style.border_color = Color("426174")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	var theme := Theme.new()
	theme.default_font_size = 18
	panel.theme = theme
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _label(header, "AUDIO TUNING", 28)
	title.add_theme_color_override("font_color", Color("6fffc1"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Try in game  ·  F1 / Esc", close_panel)
	_label(layout, "Gameplay paused • Preview and compare recordings. Save your choices for future launches.", 16)
	var category_row := HBoxContainer.new()
	category_row.add_theme_constant_override("separation", 14)
	layout.add_child(category_row)
	_label(category_row, "Category", 16)
	_category_picker = OptionButton.new()
	_category_picker.name = "AudioCategory"
	_category_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in EVENTS.CATEGORIES:
		_category_picker.add_item(EVENTS.CATEGORIES[entry])
		_category_picker.set_item_metadata(_category_picker.item_count - 1, entry)
	category_row.add_child(_category_picker)
	_category_picker.item_selected.connect(func(index: int) -> void:
		_select_category(str(_category_picker.get_item_metadata(index))))
	var selectors := HBoxContainer.new()
	selectors.add_theme_constant_override("separation", 14)
	layout.add_child(selectors)
	_surface_picker = OptionButton.new()
	for item in SURFACES:
		_surface_picker.add_item("Underground · Level 3" if item == "underground" else item.capitalize())
	_surface_picker.custom_minimum_size.x = 160
	selectors.add_child(_surface_picker)
	_surface_picker.item_selected.connect(func(index: int) -> void:
		surface = SURFACES[index]
		kind = "run" if surface == "grass" else "step"
		_preview_environment = StringName(surface) if StringName(surface) in MIX.ENVIRONMENTS else &"outdoors"
		_select_bank())
	_kind_picker = OptionButton.new()
	_kind_picker.fit_to_longest_item = false
	_kind_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(_kind_picker)
	_kind_picker.item_selected.connect(func(index: int) -> void:
		if category == "movement":
			kind = str(_kind_picker.get_item_metadata(index))
		else:
			event_id = str(_kind_picker.get_item_metadata(index))
			if _is_room_ambience():
				_preview_environment = StringName(EVENTS.definition(event_id).room)
		_select_bank())
	_comparison = _button(selectors, "B · Current experiment", _toggle_comparison)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	var listening := HFlowContainer.new()
	listening.add_theme_constant_override("separation", 12)
	layout.add_child(listening)
	_play_button = _button(listening, "Play contact", _preview_contact)
	_repeat_button = _button(listening, "Repeat", func() -> void:
		_repeat = not _repeat
		_countdown = 0.0
		_repeat_button.text = "Stop repeat" if _repeat else "Repeat"
		if not _repeat:
			_stop_preview())
	_stop_button = _button(listening, "Stop", _stop_preview)
	_pace = OptionButton.new()
	_pace.add_item("Running · %.1f steps/sec" % (1.0 / RUN_STEP_INTERVAL))
	_pace.add_item("Backwards walking · 2.6 steps/sec")
	listening.add_child(_pace)
	_space = OptionButton.new()
	_space.add_item("Listen outdoors")
	_space.add_item("Listen in cave")
	_space.add_item("Listen underground")
	listening.add_child(_space)
	_space.item_selected.connect(func(index: int) -> void:
		_stop_preview()
		_preview_environment = SPACES[index]
		if _is_room_ambience():
			_preview_environment = StringName(EVENTS.definition(event_id).room)
		_refresh())
	_now_playing = _label(layout, "Choose a recording's Play button, or repeat the current mix.", 16)
	_now_playing.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status = _label(layout, "", 16)
	_status.add_theme_color_override("font_color", Color("f5cd7c"))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	_button(footer, "Revert all changes", func() -> void:
		_stop_preview()
		MIX.revert()
		_refresh())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_save = _button(footer, "Save defaults", _save_defaults)
	_file_dialog = FileDialog.new()
	_file_dialog.title = "Add recordings to this sound bank"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_file_dialog.filters = PackedStringArray(["*.wav,*.ogg,*.mp3 ; Audio recordings"])
	_file_dialog.min_size = Vector2i(850, 550)
	add_child(_file_dialog)
	_file_dialog.files_selected.connect(_add_files)
	if DirAccess.dir_exists_absolute(SOURCE_DIRECTORY):
		_file_dialog.current_dir = SOURCE_DIRECTORY
	else:
		_file_dialog.current_dir = ProjectSettings.globalize_path("res://assets/audio/footsteps")
	_ambience_file_dialog = FileDialog.new()
	_ambience_file_dialog.title = "Choose a looping ambience recording"
	_ambience_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_ambience_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_ambience_file_dialog.filters = _file_dialog.filters
	_ambience_file_dialog.min_size = Vector2i(850, 550)
	add_child(_ambience_file_dialog)
	_ambience_file_dialog.file_selected.connect(func(path: String) -> void:
		_set_ambience_recording(path, _ambience_picker_environment))
	var nature_directory := SOURCE_DIRECTORY.get_base_dir().path_join("Nature_Essentials_NOX_SOUND")
	_ambience_file_dialog.current_dir = nature_directory if DirAccess.dir_exists_absolute(nature_directory) else ProjectSettings.globalize_path("res://assets/audio/ambience")

func _label(parent: Node, text: String, font_size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _key() -> String:
	return surface + "/" + kind if category == "movement" else event_id

func _bank() -> Resource:
	return MIX.bank_for(_key()) if category == "movement" else MIX.event_bank_for(event_id)

func _is_room_ambience() -> bool:
	return category == "ambience" and EVENTS.definition(event_id).has("room")

func _select_category(next_category: String) -> void:
	category = next_category
	if category != "movement":
		event_id = EVENTS.entries_for(category)[0].id
		_preview_environment = StringName(EVENTS.definition(event_id).get("room", "outdoors"))
	_select_bank()

func select_event(next_event_id: String) -> void:
	if EVENTS.definition(next_event_id).is_empty():
		return
	category = next_event_id.get_slice("/", 0)
	event_id = next_event_id
	_preview_environment = StringName(EVENTS.definition(event_id).get("room", "outdoors"))
	_select_bank()

func listening_environment() -> StringName:
	return _preview_environment

func _select_bank() -> void:
	_stop_preview()
	_now_playing.text = "Choose a recording's Play button, or preview the selected mix."
	_pace.select(1 if kind == "walk" else 0)
	_previous = -1
	_next_left = true
	_scroll.scroll_vertical = 0
	_refresh()

func _refresh() -> void:
	_rebuilding = true
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_category_picker.select(EVENTS.CATEGORIES.keys().find(category))
	_surface_picker.visible = category == "movement"
	_surface_picker.select(SURFACES.find(surface))
	_kind_picker.clear()
	var kinds := ["run", "walk", "jump_start", "jump_land"] if surface == "grass" else ["step", "jump_start", "jump_land"]
	var titles := {"run": "Footsteps · running", "walk": "Footsteps · backwards walking", "step": "Footsteps · running & walking", "jump_start": "Jump · takeoff", "jump_land": "Jump · landing"}
	if category == "movement":
		for entry in kinds:
			_kind_picker.add_item(titles[entry])
			_kind_picker.set_item_metadata(_kind_picker.item_count - 1, entry)
		_kind_picker.select(kinds.find(kind))
	else:
		for entry in EVENTS.entries_for(category):
			_kind_picker.add_item(entry.title)
			_kind_picker.set_item_metadata(_kind_picker.item_count - 1, entry.id)
			if entry.id == event_id:
				_kind_picker.select(_kind_picker.item_count - 1)
	var read_only := MIX.listening_to_saved
	_space.select(SPACES.find(_preview_environment))
	_space.disabled = _is_room_ambience()
	_play_button.visible = not _is_room_ambience()
	_repeat_button.visible = not _is_room_ambience()
	_stop_button.visible = not _is_room_ambience()
	_pace.visible = category == "movement" and kind in ["step", "run", "walk"]
	_play_button.text = "Play contact" if category == "movement" else "Play event"
	_comparison.text = "A · Saved defaults" if read_only else "B · Current experiment"
	if _is_room_ambience():
		_label(_body, "Connected · shared with this room's existing gameplay ambience.", 16)
		_build_ambience_controls(read_only)
		_build_reverb_controls(read_only)
		_now_playing.text = "The selected room ambience plays continuously while enabled."
		_rebuilding = false
		_update_status()
		return
	var bank := _bank()
	if category != "movement":
		var connection := str(EVENTS.definition(event_id).get("gameplay", "Preview only · gameplay connection pending. Saved choices will be ready when this event is connected."))
		if EVENTS.definition(event_id).has("gameplay"):
			connection += " Live sounds play once; Loop and Repeat are preview controls."
		var hint := _label(_body, connection, 16)
		hint.name = "EventConnectionStatus"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Color("f5cd7c"))
		_build_event_controls(bank, read_only)
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 16)
	_body.add_child(volume_row)
	_label(volume_row, "Volume")
	var slider := HSlider.new()
	slider.name = "VolumeSlider"
	slider.min_value = -40
	slider.max_value = 0
	slider.step = 0.5
	slider.value = bank.volume_db
	slider.editable = not read_only
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(slider)
	var number := SpinBox.new()
	number.name = "VolumeValue"
	number.custom_minimum_size.x = 130
	number.min_value = -40
	number.max_value = 0
	number.step = 0.5
	number.suffix = "dB"
	number.value = bank.volume_db
	number.editable = not read_only
	volume_row.add_child(number)
	slider.value_changed.connect(func(value: float) -> void:
		bank.volume_db = value
		number.set_value_no_signal(value)
		_update_status())
	number.value_changed.connect(func(value: float) -> void:
		bank.volume_db = value
		slider.set_value_no_signal(value)
		_update_status())
	_space.select(SPACES.find(_preview_environment))
	if _preview_environment in MIX.ENVIRONMENTS:
		_build_reverb_controls(read_only)
		_build_ambience_controls(read_only)
	if category == "movement" and kind in ["step", "run", "walk"]:
		var mode_row := HBoxContainer.new()
		mode_row.add_theme_constant_override("separation", 12)
		_body.add_child(mode_row)
		var mode := OptionButton.new()
		mode.add_item("Random mix · avoid repeats")
		mode.add_item("Left / right foot pair")
		mode.select(0 if bank.foot_indices.is_empty() else 1)
		mode.disabled = read_only
		mode_row.add_child(mode)
		mode.item_selected.connect(func(index: int) -> void:
			bank.foot_indices = {} if index == 0 else {"left": 0, "right": mini(1, bank.clips.size() - 1)}
			bank.disabled_indices = PackedInt32Array()
			_refresh())
		if surface == "grass":
			var copy_button := _button(mode_row, "Use for both run & walk", func() -> void:
				var other := "grass/walk" if kind == "run" else "grass/run"
				MIX.working[other] = MIX.copy_banks({_key(): bank})[_key()]
				MIX.working[other].gait = StringName(other.get_file())
				_update_status())
			copy_button.disabled = read_only
		if not bank.foot_indices.is_empty():
			for foot in ["left", "right"]:
				var row := HBoxContainer.new()
				_body.add_child(row)
				_label(row, foot.capitalize() + " foot").custom_minimum_size.x = 105
				var picker := OptionButton.new()
				picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				picker.fit_to_longest_item = false
				picker.add_item("No recording")
				for clip: AudioStream in bank.clips:
					picker.add_item(MIX.clip_name(clip))
				picker.select(clampi(int(bank.foot_indices.get(foot, -1)) + 1, 0, bank.clips.size()))
				picker.disabled = read_only
				row.add_child(picker)
				picker.item_selected.connect(func(index: int) -> void:
					bank.foot_indices[foot] = index - 1
					bank.disabled_indices = PackedInt32Array()
					_update_status())
	var list_header := HBoxContainer.new()
	_body.add_child(list_header)
	var hint := _label(list_header, "RECORDINGS  ·  tick the sounds to include" if bank.foot_indices.is_empty() else "RECORDINGS  ·  assign each foot above", 16)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var add := _button(list_header, "Add recordings…", func() -> void: _file_dialog.popup_centered_ratio(0.7))
	add.disabled = read_only
	if bank.clips.is_empty():
		_label(_body, "No recordings yet. This slot is silent until you add and select sounds." if category != "movement" else "No recordings yet. Add sounds, then choose a left and right foot or a jump mix.", 16)
	for index in bank.clips.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_body.add_child(row)
		var enabled := CheckBox.new()
		enabled.button_pressed = not index in bank.disabled_indices
		enabled.disabled = read_only or not bank.foot_indices.is_empty()
		row.add_child(enabled)
		enabled.toggled.connect(func(value: bool) -> void:
			if category != "movement":
				_stop_preview()
			var disabled: Array = Array(bank.disabled_indices)
			disabled.erase(index)
			if not value:
				disabled.append(index)
			bank.disabled_indices = PackedInt32Array(disabled)
			_update_status())
		var label := _label(row, MIX.clip_name(bank.clips[index]), 17)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = label.text
		_button(row, "Play", func() -> void:
			_stop_preview()
			_play(bank, index))
		var remove := _button(row, "Remove", _remove_clip.bind(index))
		remove.disabled = read_only
	_rebuilding = false
	_update_status()

func _build_event_controls(bank: Resource, read_only: bool) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	_body.add_child(row)
	var enabled := CheckBox.new()
	enabled.name = "EventEnabled"
	enabled.text = "Enabled in mix"
	enabled.button_pressed = bank.enabled
	enabled.disabled = read_only
	row.add_child(enabled)
	enabled.toggled.connect(func(value: bool) -> void:
		bank.enabled = value
		_stop_preview()
		_update_status())
	var mode := OptionButton.new()
	mode.name = "EventSelection"
	mode.add_item("Random pool · avoid repeats")
	mode.add_item("Fixed recording")
	mode.select(bank.selection_mode)
	mode.disabled = read_only
	row.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void:
		_stop_preview()
		bank.selection_mode = index
		_refresh())
	var playback := OptionButton.new()
	playback.name = "EventPlayback"
	playback.add_item("Play once")
	playback.add_item("Loop until stopped")
	playback.select(1 if bank.looping else 0)
	playback.disabled = read_only
	row.add_child(playback)
	playback.item_selected.connect(func(index: int) -> void:
		_stop_preview()
		bank.looping = index == 1
		_refresh())
	if bank.selection_mode == 1:
		var fixed := OptionButton.new()
		fixed.name = "EventFixedRecording"
		fixed.fit_to_longest_item = false
		fixed.add_item("No recording · silent")
		for clip: AudioStream in bank.clips:
			fixed.add_item(MIX.clip_name(clip))
		fixed.select(clampi(bank.fixed_index + 1, 0, bank.clips.size()))
		fixed.disabled = read_only
		_body.add_child(fixed)
		fixed.item_selected.connect(func(index: int) -> void:
			_stop_preview()
			bank.fixed_index = index - 1
			_update_status())
	var tuning := HFlowContainer.new()
	tuning.add_theme_constant_override("h_separation", 20)
	_body.add_child(tuning)
	_event_number(tuning, bank, "pitch_scale", "Pitch", 0.5, 2.0, 0.01, read_only)
	_event_number(tuning, bank, "pitch_variation", "Pitch variation ±", 0.0, 0.2, 0.01, read_only)
	if not bank.looping:
		_event_number(tuning, bank, "repeat_interval", "Preview interval · seconds", 0.1, 10.0, 0.1, read_only)
	var reverb := CheckBox.new()
	reverb.name = "EventRoomReverb"
	reverb.text = "Use listening room's reverb"
	reverb.button_pressed = bank.use_room_reverb
	reverb.disabled = read_only
	_body.add_child(reverb)
	reverb.toggled.connect(func(value: bool) -> void:
		_stop_preview()
		bank.use_room_reverb = value
		_update_status())
	_label(_body, "Loops keep one recording playing until Stop. A new play chooses another from the pool." if bank.looping else "Repeat waits for each recording to finish if it is longer than the interval.", 15)

func _event_number(parent: Node, bank: Resource, property: String, title: String, minimum: float, maximum: float, increment: float, read_only: bool) -> void:
	var column := VBoxContainer.new()
	parent.add_child(column)
	_label(column, title, 16)
	var number := SpinBox.new()
	number.name = "Event" + property.to_pascal_case()
	number.custom_minimum_size.x = 150
	number.min_value = minimum
	number.max_value = maximum
	number.step = increment
	number.value = bank.get(property)
	number.editable = not read_only
	column.add_child(number)
	number.value_changed.connect(func(value: float) -> void:
		bank.set(property, value)
		if property.begins_with("pitch"):
			_stop_preview()
		_update_status())

func _build_reverb_controls(read_only: bool) -> void:
	var settings := MIX.reverb_settings(_preview_environment)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192d3c")
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	_body.add_child(card)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	card.add_child(layout)
	var enabled := CheckBox.new()
	enabled.name = str(_preview_environment).capitalize() + "ReverbEnabled"
	enabled.text = "%s REVERB · shared room settings" % str(_preview_environment).to_upper()
	enabled.button_pressed = settings.enabled
	enabled.disabled = read_only
	layout.add_child(enabled)
	enabled.toggled.connect(func(value: bool) -> void:
		settings.enabled = value
		MIX.refresh_reverb_buses()
		_refresh())
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 20)
	layout.add_child(controls)
	for property in ["amount", "room_size", "damping"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(column)
		var title := {"amount": "Amount", "room_size": "Room size", "damping": "Damping · softer reflections"}
		_label(column, title[property], 16)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var slider := HSlider.new()
		slider.name = "Reverb" + str(property).to_pascal_case()
		slider.max_value = 100
		slider.step = 1
		slider.value = float(settings.get(property)) * 100.0
		slider.editable = not read_only and settings.enabled
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var number := SpinBox.new()
		number.max_value = 100
		number.step = 1
		number.suffix = "%"
		number.custom_minimum_size.x = 105
		number.value = slider.value
		number.editable = slider.editable
		row.add_child(number)
		slider.value_changed.connect(func(value: float) -> void:
			settings.set(property, value / 100.0)
			number.set_value_no_signal(value)
			MIX.refresh_reverb_buses()
			_update_status())
		number.value_changed.connect(func(value: float) -> void:
			settings.set(property, value / 100.0)
			slider.set_value_no_signal(value)
			MIX.refresh_reverb_buses()
			_update_status())

func _build_ambience_controls(read_only: bool) -> void:
	var settings := MIX.ambience_settings(_preview_environment)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	var enabled := CheckBox.new()
	enabled.name = str(_preview_environment).capitalize() + "AmbienceEnabled"
	enabled.text = str(_preview_environment).capitalize() + " ambience"
	enabled.button_pressed = settings.enabled
	enabled.disabled = read_only
	row.add_child(enabled)
	var slider := HSlider.new()
	slider.name = "AmbienceVolume"
	slider.min_value = -50
	slider.max_value = 0
	slider.step = 0.5
	slider.value = settings.volume_db
	slider.editable = not read_only and settings.enabled
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var number := SpinBox.new()
	number.custom_minimum_size.x = 130
	number.min_value = -50
	number.max_value = 0
	number.step = 0.5
	number.suffix = "dB"
	number.value = slider.value
	number.editable = slider.editable
	row.add_child(number)
	enabled.toggled.connect(func(value: bool) -> void:
		settings.enabled = value
		_refresh())
	slider.value_changed.connect(func(value: float) -> void:
		settings.volume_db = value
		number.set_value_no_signal(value)
		_update_status())
	number.value_changed.connect(func(value: float) -> void:
		settings.volume_db = value
		slider.set_value_no_signal(value)
		_update_status())
	var recording_row := HBoxContainer.new()
	recording_row.add_theme_constant_override("separation", 12)
	_body.add_child(recording_row)
	var recording_name := _label(recording_row, MIX.clip_name(settings.recording) if settings.recording != null else "No ambience selected", 16)
	recording_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recording_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	recording_name.tooltip_text = recording_name.text
	var choose := _button(recording_row, "Choose ambience…", func() -> void:
		_ambience_picker_environment = _preview_environment
		_ambience_file_dialog.popup_centered(Vector2i(900, 600)))
	choose.disabled = read_only
	var remove := _button(recording_row, "Remove ambience", func() -> void:
		settings.recording = null
		_refresh())
	remove.disabled = read_only or settings.recording == null

func _set_ambience_recording(path: String, environment: StringName) -> void:
	if MIX.listening_to_saved:
		return
	var recording := MIX.load_recording(path)
	if recording == null or recording.get_length() <= 0.0:
		_status.text = "Could not read ambience: " + path.get_file()
		return
	MIX.ambience_settings(environment).recording = recording
	_refresh()

func _remove_clip(index: int) -> void:
	if MIX.listening_to_saved:
		return
	_stop_preview()
	var bank := _bank()
	bank.clips.remove_at(index)
	if index < bank.labels.size():
		bank.labels.remove_at(index)
	var disabled := PackedInt32Array()
	for entry in bank.disabled_indices:
		if entry != index:
			disabled.append(entry - 1 if entry > index else entry)
	bank.disabled_indices = disabled
	if category != "movement":
		bank.fixed_index = -1 if bank.fixed_index == index else bank.fixed_index - 1 if bank.fixed_index > index else bank.fixed_index
	for foot in bank.foot_indices:
		var mapped: int = bank.foot_indices[foot]
		bank.foot_indices[foot] = -1 if mapped == index else mapped - 1 if mapped > index else mapped
	_previous = -1
	_refresh()

func _add_files(paths: PackedStringArray) -> void:
	if MIX.listening_to_saved or _is_room_ambience():
		return
	_stop_preview()
	var bank := _bank()
	var failures := PackedStringArray()
	for path in paths:
		var clip := MIX.load_recording(path)
		if clip == null or clip.get_length() <= 0.0:
			failures.append(path.get_file())
			continue
		bank.clips.append(clip)
		bank.labels.append(path.get_file().get_basename())
	_refresh()
	if not failures.is_empty():
		_status.text = "Could not read: " + ", ".join(failures)

func _preview_contact() -> void:
	if _is_room_ambience():
		return
	var bank := _bank()
	var foot := "left" if _next_left else "right"
	var index: int = bank.choose_clip(_random, _previous, foot)
	_next_left = not _next_left
	if index < 0:
		_now_playing.text = "No enabled recording for this contact." if category == "movement" else "This event is silent · enable it and select a recording."
		return
	_previous = index
	_play(bank, index, foot if category == "movement" and kind in ["run", "walk", "step"] else "")

func _play(bank: Resource, index: int, foot := "") -> void:
	if category != "movement":
		var output_bus: StringName = MIX.preview_bus(_preview_environment) if bank.use_room_reverb else &"Master"
		_event_voice.play_recording(bank, index, _random, output_bus)
		_now_playing.text = "%s   ·   %.1f dB   ·   pitch %.2f%s" % [MIX.clip_name(bank.clips[index]), bank.volume_db, _event_voice.pitch_scale, "   ·   looping until Stop" if bank.looping else ""]
		return
	for voice in _voices:
		if not voice.playing:
			voice.stream = bank.clips[index]
			voice.volume_db = bank.volume_db
			voice.bus = MIX.preview_bus(_preview_environment)
			voice.play()
			_now_playing.text = "%s%s   ·   %.1f dB" % [foot.capitalize() + " · " if not foot.is_empty() else "", MIX.clip_name(voice.stream), bank.volume_db]
			return
	_now_playing.text = "Four recordings still playing. This contact was skipped, as in gameplay."

func _stop_preview() -> void:
	_repeat = false
	if _repeat_button != null:
		_repeat_button.text = "Repeat"
	for voice in _voices:
		voice.stop()
	if _event_voice != null:
		_event_voice.stop()
	MIX.clear_preview_tails()

func _toggle_comparison() -> void:
	for voice in _voices:
		voice.stop()
	_event_voice.stop()
	MIX.clear_preview_tails()
	MIX.listening_to_saved = not MIX.listening_to_saved
	_previous = -1
	_next_left = true
	_countdown = 0.0
	_refresh()

func _update_status() -> void:
	if _rebuilding:
		return
	var changed := MIX.has_changes()
	_status.text = "Unsaved changes · Save defaults to keep your choices." if changed else "Using saved project defaults."
	if MIX.listening_to_saved:
		_status.text = "Listening to A · saved defaults. Switch to B to edit; your experiment is retained."
	_save.disabled = MIX.listening_to_saved or not changed or not OS.has_feature("editor")
	if not OS.has_feature("editor"):
		_status.text += " Project saving is available when running from Godot."

func _save_defaults() -> void:
	_stop_preview()
	var error := MIX.save_defaults()
	_refresh()
	_status.text = "Saved to the project · future launches will use this mix." if error == OK else "Save failed (%s). Your experiment is still available; previous defaults were kept." % error_string(error)
