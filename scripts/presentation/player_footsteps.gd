extends Node
## Marker -> supporting surface -> selected recording -> independent voice.
signal step_played(surface: String)
signal footfall_played(event: Dictionary)
const MIX := preload("res://scripts/audio/movement_audio_mix.gd")
const SURFACES := preload("res://scripts/audio/footstep_surface_resolver.gd")
const VOICE_COUNT := 4
const MAX_EVENT_AGE := 0.10
static var diagnostics_enabled := false

var _voices: Array[AudioStreamPlayer] = []
var _previous_choices: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _last_position := Vector3.ZERO
var _last_contact_id := -1
var _last_play_time := -1.0
var _clock := 0.0
var _debug_label: Label
var contact_count := 0
var played_count := 0
var rejected_count := 0
var last_event: Dictionary = {}
var history: Array[Dictionary] = []
@onready var player := get_parent() as PlayerCharacter

func _ready() -> void:
	_random.randomize()
	_last_position = player.global_position
	(player.get_node("PixelVisual") as PixelPlayerVisual3D).footstep_contact.connect(_on_footstep_contact)
	player.death_started.connect(_on_death)
	add_to_group("run_resettable")
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "FootfallVoice%d" % index
		voice.max_polyphony = 1
		add_child(voice)
		_voices.append(voice)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_debug_label = _make_label(canvas, Vector2(-920, 530))
	_debug_label.add_theme_font_size_override("font_size", 16)
	_update_diagnostics()

func _make_label(canvas: CanvasLayer, at: Vector2) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.position = at
	label.size.x = 900
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	return label

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_F9:
		return
	diagnostics_enabled = not diagnostics_enabled
	_update_diagnostics()
	get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_clock += delta
	if player.is_developer_inspection_enabled():
		_stop_voices()
	_last_position = player.global_position
	_update_diagnostics()

func _on_footstep_contact(contact: Dictionary) -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self): return
	contact_count += 1
	if int(contact.id) <= _last_contact_id:
		_reject(contact, "duplicate")
		return
	_last_contact_id = int(contact.id)
	if not player.is_on_floor() or absf(player.horizontal_speed) <= 0.15 or player.is_dead() or player.is_dashing() or player.is_transition_running() or player.is_developer_inspection_enabled():
		_reject(contact, "inactive")
		return
	var distance := absf(player.global_position.x - _last_position.x)
	if distance < 0.0001 or distance > 1.0:
		_reject(contact, "blocked/teleport")
		return
	if float(contact.age_seconds) > MAX_EVENT_AGE:
		_reject(contact, "late marker")
		return
	var ground := SURFACES.sample(player)
	var event := contact.duplicate()
	event.merge(ground)
	play_step(str(ground.surface), str(contact.gait), event)

func surface_at(collider: Object, world_position: Vector3) -> String:
	return SURFACES.surface_at(collider, world_position)

func play_step(surface: String, gait := "run", event: Dictionary = {}) -> void:
	var key := MIX.step_key(surface, gait)
	var bank := MIX.bank_for(key)
	if bank == null:
		_reject(event, "no bank: " + surface)
		return
	var selected: int = bank.choose_clip(_random, int(_previous_choices.get(key, -1)), str(event.get("foot", "left")))
	if selected < 0:
		_reject(event, "no enabled recording")
		return
	var voice: AudioStreamPlayer
	for available in _voices:
		if not available.playing:
			voice = available
			break
	if voice == null:
		_reject(event, "voice limit")
		return
	_previous_choices[key] = selected
	voice.stream = bank.clips[selected]
	voice.pitch_scale = 1.0
	voice.volume_db = bank.volume_db
	voice.bus = MIX.bus_for_source(player)
	voice.play()
	played_count += 1
	last_event = event.duplicate()
	last_event.merge({"surface": surface, "gait": gait, "clip": voice.stream.resource_path.get_file(),
		"voice": voice.get_index(), "time": _clock,
		"interval": _clock - _last_play_time if _last_play_time >= 0.0 else 0.0,
		"status": "played"}, true)
	_last_play_time = _clock
	_record(last_event)
	step_played.emit(surface)
	footfall_played.emit(last_event.duplicate())

func _reject(event: Dictionary, reason: String) -> void:
	rejected_count += 1
	last_event = event.duplicate()
	last_event["status"] = reason
	_record(last_event)

func _record(event: Dictionary) -> void:
	history.append(event.duplicate())
	if history.size() > 8:
		history.pop_front()
	_update_diagnostics()

func active_voice_count() -> int:
	var count := 0
	for voice in _voices:
		if voice.playing:
			count += 1
	return count

func _update_diagnostics() -> void:
	if _debug_label == null:
		return
	_debug_label.visible = diagnostics_enabled
	if not diagnostics_enabled:
		return
	var lines := PackedStringArray(["Footsteps: contacts %d | played %d | suppressed %d | voices %d/%d" % [contact_count, played_count, rejected_count, active_voice_count(), VOICE_COUNT]])
	for event in history:
		lines.append("#%s %s f%s %s/%s on %s | %s | %s | dt %.3fs" % [str(event.get("id", "-")), str(event.get("foot", "-")), str(event.get("frame", "-")), str(event.get("surface", "-")), str(event.get("gait", "-")), str(event.get("collider", "-")), str(event.get("clip", "-")), str(event.status), float(event.get("interval", 0.0))])
	_debug_label.text = "\n".join(lines)

func _stop_voices() -> void:
	for voice in _voices:
		voice.stop()

func _on_death(_kind: StringName, _position: Vector3) -> void:
	_stop_voices()

func reset_run() -> void:
	_stop_voices()
	_last_play_time = -1.0
	_last_position = player.global_position
