extends Node3D
## A short, dense burst built from the catalog's animated pixel smoke puffs.
const SHEETS := [
	preload("res://assets/art/vfx/boss/smoke_puff_a.png"),
	preload("res://assets/art/vfx/boss/smoke_puff_b.png"),
	preload("res://assets/art/vfx/boss/smoke_puff_c.png"),
]
const SHADES := [Color("#39474a"), Color("#59696a"), Color("#7c8e8b"), Color("#a0afaa")]
var maximum_duration := 2.7
var _elapsed := 0.0
var _emission_timer := 0.0
var _fade_remaining := -1.0
var _fade_duration := 0.6
var _follow_target: PlayerCharacter
var _particles: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _textures: Array[AtlasTexture] = []

static func spawn(parent: Node, origin: Vector3, duration: float, follow_target: PlayerCharacter = null) -> Node3D:
	var effect := new()
	effect.maximum_duration = duration
	effect._follow_target = follow_target
	parent.add_child(effect)
	effect.global_position = origin
	return effect

func _ready() -> void:
	add_to_group("boss_smoke")
	add_to_group("run_resettable")
	_random.randomize()
	for index in SHEETS.size():
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEETS[index]
		# Trim transparent rows at runtime; promoted PNGs remain unmodified.
		atlas.region = Rect2(0, 18 if index == 2 else 30, SHEETS[index].get_width(), 21 if index == 2 else 18)
		_textures.append(atlas)
	# Multiple lobes bloom outward from the player's grounded body.
	for index in 32:
		_emit_puff(true)

func _emit_puff(initial: bool) -> void:
	var variant := _random.randi_range(0, 2)
	var sprite := Sprite3D.new()
	sprite.texture = _textures[variant]
	sprite.hframes = 6 if variant == 2 else 4
	sprite.pixel_size = _random.randf_range(0.08, 0.11)
	sprite.offset.x = 6.0 if variant < 2 else 0.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = 14
	var angle := _random.randf_range(0.0, TAU)
	var radius := sqrt(_random.randf())
	var origin := Vector3(cos(angle) * radius * 1.35,
		1.15 + sin(angle) * radius * 0.95, 1.5 + _random.randf_range(0.0, 0.08))
	sprite.position = origin
	sprite.flip_h = _random.randf() > 0.5
	sprite.modulate = SHADES[_random.randi_range(0, SHADES.size() - 1)]
	add_child(sprite)
	_particles.append({"sprite": sprite, "age": _random.randf_range(0.05, 0.18) if initial else 0.0,
		"life": _random.randf_range(0.6, 0.9), "origin": origin,
		"drift": Vector3(origin.x * 0.55, _random.randf_range(0.25, 0.65), 0)})

func _process(delta: float) -> void:
	if is_instance_valid(_follow_target):
		if _follow_target.is_dead() or _follow_target.is_developer_inspection_enabled():
			queue_free()
			return
		global_position = Vector3(_follow_target.global_position.x, _follow_target.feet_world_y(), 0)
	_elapsed += delta
	if _elapsed >= maximum_duration and _fade_remaining < 0.0:
		finish()
	if _fade_remaining >= 0.0:
		_fade_remaining -= delta
		if _fade_remaining <= 0.0:
			queue_free()
			return
	var opacity := clampf(_fade_remaining / _fade_duration, 0.0, 1.0) if _fade_remaining >= 0.0 else 1.0
	# Thin the cloud gradually; keeping a few new puffs avoids an abrupt gap
	# when the original short-lived animation frames run out.
	_emission_timer -= delta
	while _emission_timer <= 0.0:
		_emit_puff(false)
		_emission_timer += lerpf(0.22, 0.045, opacity)
	for index in range(_particles.size() - 1, -1, -1):
		var puff := _particles[index]
		puff.age += delta
		if puff.age >= puff.life:
			puff.sprite.queue_free()
			_particles.remove_at(index)
			continue
		var sprite := puff.sprite as Sprite3D
		var age: float = puff.age / puff.life
		sprite.position = puff.origin + puff.drift * puff.age
		sprite.scale = Vector3.ONE * (0.9 + age * 0.35)
		# Hold the solid puff longer before its authored fragments disperse.
		sprite.frame = mini(sprite.hframes - 1, int(pow(age, 1.7) * sprite.hframes))
		sprite.modulate.a = opacity

func finish(duration := 0.6) -> void:
	if _fade_remaining < 0.0:
		_fade_duration = maxf(duration, 0.01)
		_fade_remaining = _fade_duration

func reset_run() -> void:
	queue_free()
