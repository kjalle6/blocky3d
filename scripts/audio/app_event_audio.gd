extends Node
## Menu sounds and context-selected music/ambience. Banks remain the only mix.
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const PLAYBACK := preload("res://scripts/audio/sound_event_voice.gd")
const LOOP := preload("res://scripts/audio/gameplay_event_loop.gd")
signal event_played(event: Dictionary)
var _game: Node
var _voices: Array[AudioStreamPlayer] = []
var _music: Node
var _ambience: Node
var _slide: Node
var _random := RandomNumberGenerator.new()
var _previous: Dictionary = {}
var _session_id := 0
var _music_id := "music/menu"
var _complete := false
var _last_focus_id := 0
var _last_focus_ms := 0
var _slide_id := 0
var last_event: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_random.randomize()
	for index in 12:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_music = _new_loop()
	_ambience = _new_loop()
	_slide = _new_loop()
	for node in _game.find_children("*", "BaseButton", true, false): _bind_button(node)
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is BaseButton and _game.is_ancestor_of(node): _bind_button.call_deferred(node))

func _new_loop() -> Node:
	var loop := LOOP.new()
	loop.positional = false
	add_child(loop)
	return loop

func _tools_open() -> bool:
	return not str(_game._developer_tool_owner).is_empty()

func play_event(id: String, source: Node3D = null) -> bool:
	if _tools_open(): return false
	var bank: Resource = MIX.event_bank_for(id)
	if bank == null: return false
	var index: int = bank.choose_clip(_random, int(_previous.get(id, -1)))
	if index < 0: return false
	var voice: AudioStreamPlayer
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null: return false
	_previous[id] = index
	voice.stream = PLAYBACK.playback_copy(bank.clips[index], false)
	voice.volume_db = bank.volume_db
	voice.pitch_scale = bank.choose_pitch(_random)
	if source == null and _game.current_level != null: source = _game.current_level.player
	voice.bus = MIX.bus_for_source(source) if bank.use_room_reverb and is_instance_valid(source) else &"Master"
	voice.play()
	last_event = {"id": id, "clip_index": index, "volume_db": voice.volume_db, "pitch": voice.pitch_scale}
	event_played.emit(last_event.duplicate())
	return true

func _bind_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta("event_audio_bound"): return
	button.set_meta("event_audio_bound", true)
	button.mouse_entered.connect(func() -> void: _focus(button))
	button.focus_entered.connect(func() -> void: _focus(button))
	button.pressed.connect(func() -> void:
		var label := str(button.get("text")).to_lower()
		var back := label.contains("back") or label.contains("close") or label.contains("resume") or label.contains("cancel") or label == "no" or str(button.name) == "CornerClose"
		play_event("interface/back" if back else "interface/confirm"))
	button.gui_input.connect(func(event: InputEvent) -> void:
		if button.disabled and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept")):
			play_event("interface/unavailable"))

func _focus(button: BaseButton) -> void:
	if not button.is_visible_in_tree() or button.disabled: return
	var now := Time.get_ticks_msec()
	if _last_focus_id == button.get_instance_id() and now - _last_focus_ms < 100: return
	_last_focus_id = button.get_instance_id()
	_last_focus_ms = now
	play_event("interface/focus")

func menu_back() -> void:
	play_event("interface/back")

func level_completed() -> void:
	if _complete: return
	_complete = true
	_music.stop()
	play_event("music/completion")

func _process(_delta: float) -> void:
	if _tools_open():
		_music.stop()
		_ambience.stop()
		_slide.stop()
		for voice in _voices: voice.stop()
		return
	var level: LevelSession3D = _game.current_level
	var interstitial: LevelInterstitial3D = _game.active_interstitial()
	if is_instance_valid(level):
		if level.get_instance_id() != _session_id:
			_session_id = level.get_instance_id()
			_complete = false
			var id := str(_game.current_level_definition.level_id)
			_music_id = "music/level_1" if id == "arrival_shoreline" else "music/level_2" if id == "overgrown_coastal_ascent" else "music/level_3" if id == "dev_green_zone_finale_wip" else ""
			level.run_completed.connect(level_completed)
			level.run_reset.connect(func() -> void: _complete = false)
	elif interstitial == null:
		_session_id = 0
		_complete = false
		_music_id = "music/menu"
	_music.sync(_music_id, not _complete, level.player if is_instance_valid(level) else interstitial)
	var ambience_id := ""
	if is_instance_valid(level) and MIX.environment_for(level.player) == &"outdoors":
		var id := str(_game.current_level_definition.level_id)
		if id == "arrival_shoreline":
			var anchor := level.get_node_or_null("BackgroundTransitionAnchor") as Node3D
			ambience_id = "ambience/beach" if anchor == null or level.player.global_position.x < anchor.global_position.x else "ambience/forest"
		elif id == "overgrown_coastal_ascent": ambience_id = "ambience/level_2_forest"
		elif id == "dev_green_zone_finale_wip": ambience_id = "ambience/level_3_outdoors"
	_ambience.sync(ambience_id, not ambience_id.is_empty(), level.player if is_instance_valid(level) else null)
	var sliding: bool = interstitial is Level2CaveSlideIntro3D and interstitial.current_phase() == Level2CaveSlideIntro3D.Phase.SLIDING
	if interstitial is Level2CaveSlideIntro3D and interstitial.get_instance_id() != _slide_id:
		_slide_id = interstitial.get_instance_id()
		interstitial.set_meta("audio_environment", &"cave")
		interstitial.finished.connect(func(skipped: bool) -> void:
			_slide.stop()
			if not skipped: play_event("world/cave_slide_exit", interstitial))
	_slide.sync("world/cave_slide", sliding, interstitial)
