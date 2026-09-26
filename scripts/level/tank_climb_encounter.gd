extends Node3D
## The clearing retains its ground leash; the climb lasts while it is on camera.
@export var encounter_left_x := 44.8
@export var sheltered_exit_x := 75.52
@export var climb_start_x := 66.56
@export var climb_start_y := 1.6
@export var encounter_top_y := 15.36
@onready var _scaffold: StaticBody3D = get_node("../../Platforms/TankClimbScaffold")
@onready var _upper_ground: PixelPlatform3D = get_node("../../Platforms/TankClimbUpperGround")

func contains_player(player: PlayerCharacter) -> bool:
	var point := to_local(player.global_position)
	if point.x < encounter_left_x or point.y <= -3.2: return false
	return (point.x < sheltered_exit_x and point.y < encounter_top_y) or is_climb_visible()

func is_climbing(player: PlayerCharacter) -> bool:
	var point := to_local(player.global_position)
	return contains_player(player) and point.y >= climb_start_y and (point.x >= climb_start_x or point.y >= encounter_top_y)

func is_climb_visible() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return false
	var frame := _scaffold.global_position
	var half_width := float(_scaffold.get("width")) * 0.5
	var roof := frame.y + float(_scaffold.get("height"))
	var wall := _upper_ground.global_position
	# Separate rectangles avoid retaining the fight for empty sky beside the
	# higher scaffold after the actual climb has left the screen.
	return _visible_rect(camera, Vector2(frame.x - half_width, frame.y),
		Vector2(frame.x + half_width, roof), frame.z) or _visible_rect(camera,
		Vector2(frame.x + half_width, frame.y),
		Vector2(wall.x - _upper_ground.size.x * 0.5, wall.y + _upper_ground.size.y * 0.5), frame.z)

func _visible_rect(camera: Camera3D, low: Vector2, high: Vector2, depth: float) -> bool:
	var center := Vector3((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, depth)
	if camera.is_position_behind(center): return false
	var projected := Rect2(camera.unproject_position(Vector3(low.x, low.y, depth)), Vector2.ZERO)
	for corner in [Vector3(low.x, high.y, depth), Vector3(high.x, low.y, depth), Vector3(high.x, high.y, depth)]:
		projected = projected.expand(camera.unproject_position(corner))
	return get_viewport().get_visible_rect().intersects(projected)

func firing_position() -> Vector3:
	return $FiringPosition.global_position
