extends Node3D
## Local effects only: neither the tank nor the world clock is paused.
const PULSE_SHADER := preload("res://scripts/presentation/psychic_pulse.gdshader")
const FONT := preload("res://assets/art/ui/health/cyberpunk_pixel.otf")
var _player: PlayerCharacter
var _elapsed := 0.0
var _duration := 0.7
var _burst: MeshInstance3D
var _cage: MeshInstance3D
var _label: Label3D

func _ready() -> void:
	add_to_group("run_resettable")
	add_to_group("psychic_pulse_effect")
	set_process(false)

func play(origin: Vector3, player: PlayerCharacter, duration: float) -> void:
	global_position = origin
	_player = player
	_duration = duration
	_elapsed = 0.0
	if _burst == null:
		_burst = _make_ring(Vector2(3.6, 3.6), false)
		_cage = _make_ring(Vector2(1.8, 2.2), true)
		_label = Label3D.new()
		_label.text = "PSYCHIC PULSE"
		_label.font = FONT
		_label.font_size = 20
		_label.pixel_size = 0.007
		_label.modulate = Color("e9a8ff")
		_label.outline_modulate = Color("250634")
		_label.outline_size = 5
		_label.no_depth_test = true
		add_child(_label)
	_update_effect()
	set_process(true)

func _make_ring(size: Vector2, cage: bool) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	ring.mesh = quad
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = PULSE_SHADER
	material.set_shader_parameter("cage", cage)
	ring.material_override = material
	add_child(ring)
	ring.position.z = 1.6
	return ring

func _process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(_player) or _player.is_dead() or _elapsed >= _duration + 0.35:
		queue_free()
		return
	_update_effect()

func _update_effect() -> void:
	var phase := clampf(_elapsed / _duration, 0, 1)
	_burst.material_override.set_shader_parameter("phase", phase)
	_burst.material_override.set_shader_parameter("opacity", 1.0 - phase)
	_cage.global_position = _player.global_position + Vector3(0, 0.12, 1.65)
	_cage.visible = _player.is_psychically_frozen()
	_cage.material_override.set_shader_parameter("phase", phase)
	_label.global_position = _player.global_position + Vector3(0, 1.12 + _elapsed * 0.15, 1.7)
	_label.modulate.a = 1.0 - clampf((_elapsed - _duration) / 0.35, 0, 1)

func reset_run() -> void:
	queue_free()
