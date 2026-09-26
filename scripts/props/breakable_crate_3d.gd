class_name BreakableCrate3D
extends CharacterBody3D
## One box, one receiver. Upper boxes fall naturally when support is removed.
const TEXTURE := preload("res://assets/art/green_zone/catalog/props/other/Box.png")
const BOX_SIZE := Vector3(1.28, 0.96, 1.0)
@export_range(1, 500, 1) var maximum_hp := 50
@export var flip_art := false
var health := HealthState.new()
var _broken := false
var _session: LevelSession3D
var _pieces: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _visual: Sprite3D
var _collision: CollisionShape3D
var _initial_transform: Transform3D

func _ready() -> void:
	_random.randomize()
	_initial_transform = global_transform
	var face := AtlasTexture.new()
	face.atlas = TEXTURE
	face.region = Rect2(0, 1, 32, 24)
	_visual = Sprite3D.new()
	_visual.name = "Visual"
	_visual.texture = face
	_visual.pixel_size = 0.04
	_visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_visual.shaded = false
	_visual.position.z = 1.2
	_visual.render_priority = 10
	_visual.flip_h = flip_art
	add_child(_visual)
	_collision = CollisionShape3D.new()
	_collision.name = "BodyCollision"
	var box := BoxShape3D.new()
	box.size = BOX_SIZE
	_collision.shape = box
	add_child(_collision)
	health.reset(maximum_hp)
	var ancestor := get_parent()
	while ancestor != null and not ancestor is LevelSession3D:
		ancestor = ancestor.get_parent()
	_session = ancestor as LevelSession3D
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self): return
	add_to_group("breakable_cover")
	add_to_group("run_resettable")
	reset_run()

func _physics_process(delta: float) -> void:
	if _broken: return
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = maxf(velocity.y - 38.0 * delta, -25.0)
	move_and_slide()

func combat_hurt_bounds() -> Rect2:
	return Rect2(Vector2(global_position.x - 0.64, global_position.y - 0.48), Vector2(1.28, 0.96))

func receive_projectile_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	if _broken or hit == null: return false
	if not health.damage(hit): return false
	if hit.kind == &"tank_shell" or health.current == 0:
		_break(source_position)
	else:
		_visual.modulate = Color(1.6, 0.9, 0.6)
		create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.12)
	return true

func receive_melee_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	return receive_projectile_hit(source_position, hit)

func is_defeated() -> bool:
	return _broken

func _flag_id() -> String:
	return "broken/" + _session.save_state.source_id(self)

func _break(source_position: Vector3) -> void:
	_broken = true
	_visual.hide()
	_collision.set_deferred("disabled", true)
	if _session != null and _session.save_state != null:
		_session.save_state.mark_world_flag(_flag_id())
		_session.save_state.note_combat(global_position)
		if _session.combat_feedback != null:
			_session.combat_feedback.combat_audio.play_event("world/crate_break", global_position)
	for index in 9:
		var atlas := AtlasTexture.new()
		atlas.atlas = TEXTURE
		atlas.region = Rect2((index % 3) * 10, 1 + (index / 3) * 8, 10, 8)
		var piece := Sprite3D.new()
		piece.texture = atlas
		piece.pixel_size = 0.04
		piece.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		piece.shaded = false
		piece.render_priority = 12
		piece.position = Vector3(_random.randf_range(-0.4, 0.4), _random.randf_range(-0.35, 0.35), 1.3)
		add_child(piece)
		var direction := signf(global_position.x - source_position.x)
		_pieces.append({"sprite": piece, "velocity": Vector2(_random.randf_range(-2.0, 2.0) + direction, _random.randf_range(2.0, 4.5)), "age": 0.0, "spin": _random.randf_range(-8.0, 8.0)})

func _process(delta: float) -> void:
	for index in range(_pieces.size() - 1, -1, -1):
		var piece: Dictionary = _pieces[index]
		piece.age += delta
		piece.velocity.y -= 15.0 * delta
		piece.sprite.position += Vector3(piece.velocity.x, piece.velocity.y, 0) * delta
		piece.sprite.rotation.z += piece.spin * delta
		piece.sprite.modulate.a = clampf((0.7 - piece.age) / 0.25, 0.0, 1.0)
		if piece.age >= 0.7:
			piece.sprite.queue_free()
			_pieces.remove_at(index)

func reset_run() -> void:
	for piece in _pieces: piece.sprite.queue_free()
	_pieces.clear()
	global_transform = _initial_transform
	velocity = Vector3.ZERO
	health.reset(maximum_hp)
	_broken = _session != null and _session.save_state != null and _session.save_state.world_flags.get(_flag_id(), false)
	_visual.visible = not _broken
	_collision.set_deferred("disabled", _broken)
