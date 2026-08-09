class_name RouteExtent3D
extends Node3D
## The authored start and end of a level's 2D route.
##
## Movement is always horizontal along X. This node is deliberately metadata,
## not a movement path: levels and their validators use it to describe the
## route's authored extent without coupling gameplay to a movement path.

@export var route_start_x := 0.0
@export var route_end_x := 10.0


func _ready() -> void:
	assert(
		not is_equal_approx(route_start_x, route_end_x),
		"%s needs a route with length." % name
	)


func length() -> float:
	return absf(route_end_x - route_start_x)


## Distance travelled along the route from its start, for progress reporting.
func offset_of(world_x: float) -> float:
	return absf(world_x - (global_position.x + route_start_x))
