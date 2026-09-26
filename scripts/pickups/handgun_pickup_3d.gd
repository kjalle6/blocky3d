class_name HandgunPickup3D
extends Area3D
## One authored handgun reward with a deterministic presentation arc. The
## weapon never becomes a RigidBody: it may look kicked loose, but it always
## settles on the level designer's safe pickup anchor.

signal drop_started
signal settled
signal collection_requested(pickup: HandgunPickup3D, player: PlayerCharacter)
signal collected(world_position: Vector3)

enum DropState { LOCKED, KICKING, BOUNCING, AVAILABLE, CLAIMED }

@export var source_enemy_path: NodePath
@export var collection_enabled := false
@export_range(0, 9999, 1) var ammunition_rounds := 30
@export var grounded_texture: Texture2D
@export var airborne_texture: Texture2D
@export var source_offset := Vector3(0.0, 0.82, 0.0)
@export_range(0.1, 1.5, 0.01) var kick_duration := 0.46
@export_range(0.0, 2.0, 0.01) var kick_height := 0.58
@export_range(0.05, 0.6, 0.01) var bounce_duration := 0.18
@export_range(0.0, 0.5, 0.01) var bounce_height := 0.1

var _source_enemy: HandgunEnemy3D
var _session: LevelSession3D
var _landing_transform: Transform3D
var _kick_start := Vector3.ZERO
var _elapsed := 0.0
var _state := DropState.LOCKED
var _collection_active := false

@onready var visual: Sprite3D = %Visual
@onready var collection_shape: CollisionShape3D = %CollectionShape


func _ready() -> void:
	_landing_transform = global_transform
	add_to_group("weapon_pickup")
	add_to_group("run_resettable")
	body_entered.connect(_on_body_entered)
	_source_enemy = get_node_or_null(source_enemy_path) as HandgunEnemy3D
	assert(_source_enemy != null, "%s requires a HandgunEnemy3D source." % name)
	if not _source_enemy.defeated.is_connected(_on_source_defeated):
		_source_enemy.defeated.connect(_on_source_defeated)
	_reset_presentation()


func _physics_process(delta: float) -> void:
	match _state:
		DropState.KICKING:
			_tick_kick(delta)
		DropState.BOUNCING:
			_tick_bounce(delta)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var source := get_node_or_null(source_enemy_path) as HandgunEnemy3D
	if source == null:
		errors.append("source_enemy_path must resolve to HandgunEnemy3D.")
	if visual == null or visual.texture == null:
		errors.append("Visual must have the grounded handgun texture.")
	if grounded_texture == null or airborne_texture == null:
		errors.append("Both authored handgun poses must be assigned.")
	if collection_shape == null or not collection_shape.shape is BoxShape3D:
		errors.append("CollectionShape must use BoxShape3D.")
	if kick_duration <= 0.0 or bounce_duration <= 0.0:
		errors.append("Drop timing must stay positive.")
	return errors


func current_state() -> DropState:
	return _state


func is_locked() -> bool:
	return _state == DropState.LOCKED


func is_airborne() -> bool:
	return _state in [DropState.KICKING, DropState.BOUNCING]


func is_available() -> bool:
	return _state == DropState.AVAILABLE


func is_claimed() -> bool:
	return _state == DropState.CLAIMED


func collection_is_active() -> bool:
	return _collection_active


func landing_position() -> Vector3:
	return _landing_transform.origin


func set_collection_enabled(enabled: bool) -> void:
	collection_enabled = enabled
	_set_collection_active(enabled and _state == DropState.AVAILABLE)


func bind_to_level_session(session: LevelSession3D) -> void:
	_session = session
	set_collection_enabled(true)
	if _session.owns_weapon(PlayerWeapon.HANDGUN):
		mark_claimed()


func mark_claimed() -> void:
	_state = DropState.CLAIMED
	visible = false
	_set_collection_active(false)
	set_physics_process(false)


func reset_run() -> void:
	if _session != null and _session.owns_weapon(PlayerWeapon.HANDGUN):
		mark_claimed()
	else:
		_reset_presentation()


func _on_source_defeated(_impact_position: Vector3) -> void:
	if _state != DropState.LOCKED:
		return
	_state = DropState.KICKING
	_elapsed = 0.0
	_kick_start = _source_enemy.global_position + source_offset
	_kick_start.z = _landing_transform.origin.z
	global_position = _kick_start
	visual.texture = airborne_texture
	visual.flip_h = _source_enemy.facing_direction() > 0.0
	visual.rotation.z = 0.0
	visible = true
	_set_collection_active(false)
	set_physics_process(true)
	drop_started.emit()


func _tick_kick(delta: float) -> void:
	_elapsed += delta
	var progress := minf(_elapsed / kick_duration, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var next_position := _kick_start.lerp(_landing_transform.origin, eased)
	next_position.y += sin(progress * PI) * kick_height
	global_position = next_position
	if progress < 1.0:
		return
	_state = DropState.BOUNCING
	_elapsed = 0.0
	global_position = _landing_transform.origin
	visual.texture = grounded_texture
	visual.rotation.z = 0.0


func _tick_bounce(delta: float) -> void:
	_elapsed += delta
	var progress := minf(_elapsed / bounce_duration, 1.0)
	var next_position := _landing_transform.origin
	next_position.y += sin(progress * PI) * bounce_height
	global_position = next_position
	if progress < 1.0:
		return
	_state = DropState.AVAILABLE
	global_transform = _landing_transform
	_set_collection_active(collection_enabled)
	set_physics_process(false)
	settled.emit()


func _on_body_entered(body: Node3D) -> void:
	if (
		not _collection_active
		or _state != DropState.AVAILABLE
		or not body is PlayerCharacter
		or _session == null
		or body != _session.player
	):
		return
	var player := body as PlayerCharacter
	collection_requested.emit(self, player)
	if _session.acquire_weapon(PlayerWeapon.HANDGUN, ammunition_rounds):
		mark_claimed()
		collected.emit(player.global_position)
	elif _session.owns_weapon(PlayerWeapon.HANDGUN):
		mark_claimed()


func _reset_presentation() -> void:
	_state = DropState.LOCKED
	_elapsed = 0.0
	global_transform = _landing_transform
	visual.texture = grounded_texture
	visual.flip_h = false
	visual.rotation.z = 0.0
	visible = false
	_set_collection_active(false)
	set_physics_process(false)


func _set_collection_active(active: bool) -> void:
	_collection_active = active
	set_deferred("monitoring", active)
	collection_shape.set_deferred("disabled", not active)
