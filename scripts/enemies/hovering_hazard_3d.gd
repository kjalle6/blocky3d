class_name HoveringHazard3D
extends Node3D
## An indestructible flying machine that patrols a vertical line.
##
## It is a traversal hazard, not a combat target. It deliberately stays outside
## the melee_target and stomp contracts, so it cannot be stabbed or jumped on,
## and Dash grants no contact invulnerability. The only answers are spatial:
## go over it, or go under it.
##
## Its body is always lethal. It also discharges an electrical spark that hangs
## beneath it, and that spark is what makes the two routes asymmetric: passing
## above is safe but committed, passing beneath is fast and must be timed. The
## art carries this - the attack frames extend downward from the body, so the
## danger is legible before it is learned.
##
## Motion is driven by an accumulated local clock rather than engine time, so a
## death and respawn reproduces the same phase and the playthrough bot stays
## deterministic.

@export_category("Hover")
## Metres travelled above and below the authored rest height.
@export_range(0.0, 8.0, 0.01, "or_greater") var bob_amplitude := 1.2
## Seconds for one full down-up cycle.
@export_range(0.2, 20.0, 0.05, "or_greater") var bob_period := 3.0
## Starting point in the cycle, 0..1. Lets two machines run out of step.
@export_range(0.0, 1.0, 0.01) var bob_phase := 0.0

@export_category("Discharge")
## Seconds between the start of one discharge and the next.
@export_range(0.2, 30.0, 0.05, "or_greater") var spark_period := 2.4
## Seconds the spark stays lethal within each cycle.
@export_range(0.05, 10.0, 0.05, "or_greater") var spark_active := 0.6
@export_range(0.0, 1.0, 0.01) var spark_phase := 0.0

const IDLE_TEXTURE := preload("res://assets/art/green_zone/enemies/flyer_idle.png")
const ATTACK_TEXTURE := preload("res://assets/art/green_zone/enemies/flyer_attack.png")
const FRAME_COUNT := 4
const IDLE_FRAME_RATE := 6.0

@onready var _visual: Sprite3D = $Visual
@onready var _spark: Hazard3D = $SparkHazard

var _rest_y := 0.0
var _elapsed := 0.0
var _spark_lethal := false


func _ready() -> void:
	add_to_group("run_resettable")
	_rest_y = position.y
	_apply(0.0)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if spark_active >= spark_period:
		errors.append("A discharge that never ends removes the route beneath the machine.")
	if get_node_or_null("Visual") == null:
		errors.append("Hovering hazard requires a Visual sprite.")
	if get_node_or_null("BodyHazard") == null:
		errors.append("Hovering hazard requires an always-lethal BodyHazard.")
	if get_node_or_null("SparkHazard") == null:
		errors.append("Hovering hazard requires a SparkHazard.")
	return errors


func reset_run() -> void:
	_elapsed = 0.0
	_apply(0.0)


## Lowest point the body reaches, for authoring and validation against the
## clearance the route is supposed to leave.
func lowest_body_y() -> float:
	return _rest_y - bob_amplitude


func highest_body_y() -> float:
	return _rest_y + bob_amplitude


func is_discharging() -> bool:
	return _spark_lethal


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_apply(delta)


func _apply(delta: float) -> void:
	var bob := sin((_elapsed / bob_period + bob_phase) * TAU)
	position.y = _rest_y + bob * bob_amplitude

	var cycle := fmod(_elapsed + spark_phase * spark_period, spark_period)
	var discharging := cycle < spark_active
	if discharging != _spark_lethal:
		_set_spark(discharging)

	if _visual != null:
		_visual.texture = ATTACK_TEXTURE if _spark_lethal else IDLE_TEXTURE
		_visual.hframes = FRAME_COUNT
		if _spark_lethal:
			var through := clampf(cycle / maxf(spark_active, 0.001), 0.0, 0.999)
			_visual.frame = int(through * FRAME_COUNT)
		else:
			_visual.frame = int(_elapsed * IDLE_FRAME_RATE) % FRAME_COUNT


func _set_spark(active: bool) -> void:
	_spark_lethal = active
	if _spark == null:
		return
	_spark.monitoring = active
	if not active:
		return
	# Re-enabling an area does not report bodies that were already inside it, so
	# a player standing under the machine when it fires would otherwise survive.
	for body in _spark.get_overlapping_bodies():
		if body is PlayerCharacter:
			body.kill(_spark.death_kind)
