extends Area3D
## The warhead the Green Zone boss, S.T.O.M.P., drops when it is destroyed:
## the only way through the pit's blast door. It falls from the wreck to the
## surface below, then bobs there until the player takes it. A run reset
## removes it with the rest of the fight.

signal collected

const SHEET := preload("res://assets/art/vfx/boss/warhead.png")
const PIXEL := 0.04
const GRAVITY := 30.0
## The drawn warhead's lowest row sits this far below the cell's centre.
const ART_BASE := 0.32

var ground_y := 0.0
var _time := 0.0
var _fall_speed := 0.0
var _visual: Sprite3D


static func spawn(parent: Node, point: Vector3, surface_y: float) -> Area3D:
	var pickup = new()
	pickup.ground_y = minf(surface_y, point.y)
	parent.add_child(pickup)
	pickup.global_position = Vector3(point.x, point.y, 0)
	return pickup


func _ready() -> void:
	add_to_group("run_resettable")
	collision_layer = 0
	collision_mask = 3
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.4, 1.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.7
	add_child(collision)
	_visual = Sprite3D.new()
	_visual.texture = SHEET
	_visual.hframes = 4
	_visual.pixel_size = PIXEL
	_visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_visual.shaded = false
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.render_priority = 12
	add_child(_visual)
	body_entered.connect(_on_body_entered)
	_place_visual()


func is_landed() -> bool:
	return global_position.y <= ground_y


func reset_run() -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	_time += delta
	if not is_landed():
		_fall_speed += GRAVITY * delta
		global_position.y = maxf(ground_y, global_position.y - _fall_speed * delta)
	_visual.frame = int(_time * 8.0) % _visual.hframes
	_place_visual()
	for body in get_overlapping_bodies():
		if body is PlayerCharacter:
			_on_body_entered(body)
			return


func _place_visual() -> void:
	# Bob on whole pixels once it rests, so the art stays on the grid.
	var bob := roundf((1.0 - cos(_time * 3.0)) * 2.0) * PIXEL if is_landed() else 0.0
	_visual.position = Vector3(0, ART_BASE + 0.12 + bob, 1.1)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter and not is_queued_for_deletion() and not body.is_dead():
		collected.emit()
		queue_free()
