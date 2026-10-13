extends HoveringHazard3D
## The shootable flying machine, first met in the Green Zone boss's second
## phase: the first time the player meets flyers with a gun in hand. Its body
## and discharge stay lethal, and it still stays outside melee_target and the
## stomp contract, so bullets are the only answer. A separate script and scene
## leave the indestructible machines, part of saved layouts' structural
## fingerprints, unchanged.
##
## An encounter can keep it dormant (hidden and harmless) until activate().
## It then blinks harmlessly for arming_time, so it can never appear on top of
## the player, before its hazards switch on.

signal defeated(impact_position: Vector3)
signal health_changed(current: int, maximum: int)

const EFFECT := preload("res://scripts/presentation/boss_pixel_effect_3d.gd")
const EXPLOSION := preload("res://assets/art/vfx/boss/explosion.png")
const HIT_FLASH := 0.1

@export var combat: CombatProfile = preload("res://resources/combat/destructible_flyer.tres")
## Dormant flyers wait for activate(); reset returns them to this state.
@export var starts_active := true
@export_range(0.0, 3.0, 0.05) var arming_time := 1.0

var health := HealthState.new()
var _state := &"dormant"
var _arming_remaining := 0.0
var _flash_remaining := 0.0

@onready var _body_hazard: Area3D = $BodyHazard
@onready var _hurtbox: Area3D = $ProjectileHurtbox


func _ready() -> void:
	super()
	add_to_group("mechanical")
	health.changed.connect(func(current: int, maximum: int) -> void:
		health_changed.emit(current, maximum))
	health.reset(combat.maximum_hp)
	if starts_active:
		_set_state(&"active")
	else:
		_set_state(&"dormant")


func reset_run() -> void:
	super()
	health.reset(combat.maximum_hp)
	_set_state(&"active" if starts_active else &"dormant")
	# The hurtbox restores its authored layer on reset; settle it afterwards.
	_sync_hurtbox.call_deferred()


func activate() -> void:
	if _state != &"dormant":
		return
	_elapsed = 0.0
	health.reset(combat.maximum_hp)
	_set_state(&"arming")


func destroy() -> void:
	if _state == &"dormant" or _state == &"destroyed":
		return
	EFFECT.spawn(get_parent(), global_position, EXPLOSION, 48, 0.04)
	_set_state(&"destroyed")
	defeated.emit(global_position)


func is_active() -> bool:
	return _state == &"arming" or _state == &"active"


func is_lethal() -> bool:
	return _state == &"active"


func is_destroyed() -> bool:
	return _state == &"destroyed"


func receive_projectile_hit(source_position: Vector3, hit: CombatHit = null) -> bool:
	if not is_active():
		return false
	if hit == null:
		hit = CombatHit.new(25, &"bullet", source_position)
	if not health.damage(hit, combat):
		return false
	_flash_remaining = HIT_FLASH
	if health.current == 0:
		destroy()
	return true


func _physics_process(delta: float) -> void:
	super(delta)
	if _state == &"arming":
		_arming_remaining -= delta
		if _arming_remaining <= 0.0:
			_set_state(&"active")


func _process(delta: float) -> void:
	if _visual == null or not is_active():
		return
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	var alpha := 1.0
	if _state == &"arming":
		alpha = 0.35 if fmod(_arming_remaining, 0.25) < 0.125 else 1.0
	_visual.modulate = Color(1.0, 0.45, 0.45, alpha) if _flash_remaining > 0.0 else Color(1, 1, 1, alpha)


func _set_spark(active: bool) -> void:
	# The discharge is lethal only once the machine is armed.
	super(active and is_lethal())


func _set_state(next: StringName) -> void:
	_state = next
	var present := is_active()
	visible = present
	set_physics_process(present)
	set_process(present)
	if next == &"arming":
		_arming_remaining = arming_time
	if _visual != null and not present:
		_visual.modulate = Color.WHITE
	_set_spark(_spark_lethal and is_lethal())
	if _body_hazard != null:
		_body_hazard.monitoring = is_lethal()
		if is_lethal():
			# Re-enabling an area does not report bodies already inside it.
			for body in _body_hazard.get_overlapping_bodies():
				if body is PlayerCharacter:
					body.kill(_body_hazard.death_kind)
	_sync_hurtbox()


func _sync_hurtbox() -> void:
	if _hurtbox != null:
		_hurtbox.collision_layer = 4 if is_active() else 0
