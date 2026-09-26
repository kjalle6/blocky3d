extends RefCounted
## Shared damage silhouette. Navigation bodies deliberately remain compact.


static func hurt_bounds(enemy: Node3D) -> Rect2:
	if enemy.has_method("combat_hurt_bounds"):
		return enemy.combat_hurt_bounds()
	var collision := enemy.get_node("ProjectileHurtbox/Collision") as CollisionShape3D
	var half_size := (collision.shape as BoxShape3D).size * 0.5
	var transform := collision.global_transform
	var lower := transform * -half_size
	var upper := transform * half_size
	var bounds := Rect2(Vector2(lower.x, lower.y), Vector2(upper.x - lower.x, upper.y - lower.y))
	# These native 48px enemy strips centre the torso near source X=14,
	# not the canvas centre at X=24. Include the skater's authored recentering
	# and mirror the source offset with the sprite, without moving navigation.
	var visual := enemy.get_node("PixelVisual") as Sprite3D
	var facing := -1.0 if visual.flip_h else 1.0
	var center_pixels := float(enemy.get_meta("combat_center_x_pixels", -10.0))
	var body_x := visual.global_position.x + center_pixels * visual.pixel_size * facing
	bounds.position.x = body_x - bounds.size.x * 0.5
	return bounds


static func stomp_bounds(enemy: Node3D) -> Rect2:
	var bounds := hurt_bounds(enemy)
	var head_y: float = enemy.global_position.y + enemy.stomp_head_height
	bounds.size.y = head_y - bounds.position.y
	return bounds


## Return the time along the feet's motion at which they cross the head.
## Interpolating X at contact avoids false hits from a diagonal motion's AABB.
static func stomp_crossing(start: Vector2, end: Vector2, bounds: Rect2, half_width: float) -> float:
	var descent := start.y - end.y
	if descent <= 0.0 or start.y < bounds.end.y - 0.04 or end.y > bounds.end.y:
		return -1.0
	var fraction := clampf((start.y - bounds.end.y) / descent, 0.0, 1.0)
	var contact_x := lerpf(start.x, end.x, fraction)
	# Require a small amount of overlap, rather than counting a grazing edge.
	var reach := maxf(0.0, half_width - 0.06)
	if contact_x + reach <= bounds.position.x or contact_x - reach >= bounds.end.x:
		return -1.0
	return fraction
