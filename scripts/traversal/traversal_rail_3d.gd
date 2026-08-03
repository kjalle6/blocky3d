class_name TraversalRail3D
extends Node3D
## The authored extent of a level's route.
##
## This was once a baked curve that could bend through Z, so a route could turn
## toward or away from the camera. The game is 2D and stays 2D, so the route is
## a straight line along X and none of that machinery survives: every query it
## answered reduced to "forward is +X" and "Z is zero", which callers now state
## directly instead of walking a thousand baked points to rediscover.
##
## What remains is the authored length, which levels and their tests use as the
## route's extent.

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
