class_name TraversalRail3D
extends Node3D
## Defines the horizontal route through the 3D world. The player can move and
## jump normally, but lateral drift is projected back onto the vertical plane
## formed by this rail. Smooth handles are generated from authored points.

@export var control_points := PackedVector3Array([
	Vector3.ZERO,
	Vector3(10.0, 0.0, 0.0),
])
@export_range(0.05, 2.0, 0.05) var bake_interval := 0.2
@export_range(0.0, 0.45, 0.01) var handle_strength := 0.22

var _curve := Curve3D.new()


func _ready() -> void:
	_rebuild_curve()


func _rebuild_curve() -> void:
	_curve = Curve3D.new()
	_curve.bake_interval = bake_interval
	if control_points.size() < 2:
		push_error("TraversalRail3D requires at least two control points.")
		return
	for index in control_points.size():
		var point := control_points[index]
		var previous := control_points[maxi(0, index - 1)]
		var following := control_points[mini(control_points.size() - 1, index + 1)]
		var direction := (following - previous).normalized()
		var previous_distance := point.distance_to(previous) if index > 0 else point.distance_to(following)
		var following_distance := point.distance_to(following) if index + 1 < control_points.size() else previous_distance
		var handle_length := minf(previous_distance, following_distance) * handle_strength
		var incoming := -direction * handle_length if index > 0 else Vector3.ZERO
		var outgoing := direction * handle_length if index + 1 < control_points.size() else Vector3.ZERO
		_curve.add_point(point, incoming, outgoing)


func length() -> float:
	return _curve.get_baked_length()


func closest_offset(world_position: Vector3) -> float:
	return _curve.get_closest_offset(to_local(world_position))


func world_point_at_offset(offset: float) -> Vector3:
	return to_global(_curve.sample_baked(clampf(offset, 0.0, length())))


func world_tangent_at_offset(offset: float) -> Vector3:
	var sample_distance := maxf(0.05, bake_interval)
	var before := world_point_at_offset(maxf(0.0, offset - sample_distance))
	var after := world_point_at_offset(minf(length(), offset + sample_distance))
	var tangent := after - before
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		return global_transform.basis.x.normalized()
	return tangent.normalized()


func tangent_at_world_position(world_position: Vector3) -> Vector3:
	return world_tangent_at_offset(closest_offset(world_position))


func constrain_world_position(world_position: Vector3) -> Vector3:
	var offset := closest_offset(world_position)
	var rail_point := world_point_at_offset(offset)
	var tangent := world_tangent_at_offset(offset)
	var lateral_axis := tangent.cross(Vector3.UP).normalized()
	var lateral_error := (world_position - rail_point).dot(lateral_axis)
	return world_position - lateral_axis * lateral_error
