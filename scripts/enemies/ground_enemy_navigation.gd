extends RefCounted
## Ground-only pursuit queries. Hazards deliberately have no physics layer,
## so inspect their enabled authored boxes without changing player collision.

static func can_step(enemy: CharacterBody3D, direction: float, distance := 0.72) -> bool:
	var ahead := enemy.global_position + Vector3.RIGHT * direction * distance
	return _floor_at(enemy, ahead, _excluded_bodies(enemy)) and not _hazard_between(enemy, ahead)


static func can_reach(enemy: CharacterBody3D, target_x: float, ignore_breakable_cover := false) -> bool:
	var destination := Vector3(target_x, enemy.global_position.y, enemy.global_position.z)
	if _hazard_between(enemy, destination):
		return false
	var exclude := _excluded_bodies(enemy)
	if ignore_breakable_cover:
		for cover in enemy.get_tree().get_nodes_in_group("breakable_cover"):
			if cover is CollisionObject3D: exclude.append(cover.get_rid())
	var query := PhysicsRayQueryParameters3D.create(enemy.global_position, destination, 1, exclude)
	if not enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return false
	var distance := absf(target_x - enemy.global_position.x)
	var steps := maxi(1, ceili(distance / 0.5))
	for index in range(1, steps + 1):
		var sample := enemy.global_position.lerp(destination, float(index) / steps)
		if not _floor_at(enemy, sample, exclude):
			return false
	return true


static func is_on_camera(enemy: Node3D) -> bool:
	var camera := enemy.get_viewport().get_camera_3d()
	if camera == null:
		return true # Standalone physics fixtures need no rendering camera.
	var visual := enemy.get_node_or_null("PixelVisual") as Sprite3D
	if visual == null or visual.texture == null:
		return false
	if camera.is_position_behind(visual.global_position):
		return false
	var half_size := Vector2(
		float(visual.texture.get_width()) / visual.hframes,
		float(visual.texture.get_height()) / visual.vframes
	) * visual.pixel_size * 0.5
	var screen_bounds := Rect2(camera.unproject_position(visual.global_position), Vector2.ZERO)
	for corner in [
		Vector3(-half_size.x, -half_size.y, 0), Vector3(half_size.x, -half_size.y, 0),
		Vector3(-half_size.x, half_size.y, 0), Vector3(half_size.x, half_size.y, 0),
	]:
		screen_bounds = screen_bounds.expand(camera.unproject_position(visual.to_global(corner)))
	return enemy.get_viewport().get_visible_rect().intersects(screen_bounds)


static func _excluded_bodies(enemy: CharacterBody3D) -> Array[RID]:
	var exclude: Array[RID] = [enemy.get_rid()]
	# Another character is neither a ledge support nor a terrain barrier.
	for group in [&"player_character", &"melee_target"]:
		for body in enemy.get_tree().get_nodes_in_group(group):
			if body is CharacterBody3D and body != enemy:
				exclude.append(body.get_rid())
	return exclude


static func _floor_at(enemy: CharacterBody3D, point: Vector3, exclude: Array[RID]) -> bool:
	var start := point + Vector3.UP * 0.15
	var query := PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * 1.35, 1, exclude)
	return not enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _hazard_between(enemy: CharacterBody3D, destination: Vector3) -> bool:
	var body := enemy.get_node("BodyCollision") as CollisionShape3D
	var half_size := (body.shape as BoxShape3D).size * 0.5
	var head_height: float = enemy.get("stomp_head_height")
	var minimum := enemy.global_position - half_size
	var size := Vector3(half_size.x * 2.0, head_height + half_size.y, half_size.z * 2.0)
	var travel := destination.x - enemy.global_position.x
	minimum.x += minf(0.0, travel)
	size.x += absf(travel)
	var swept_body := AABB(minimum, size).grow(0.08)
	for node in enemy.get_tree().get_nodes_in_group("ground_enemy_hazard"):
		var hazard := node as Area3D
		if hazard == null or not hazard.monitoring:
			continue
		for child in hazard.get_children():
			var collision := child as CollisionShape3D
			if collision == null or collision.disabled or not collision.shape is BoxShape3D:
				continue
			var box := collision.shape as BoxShape3D
			var bounds: AABB = collision.global_transform * AABB(-box.size * 0.5, box.size)
			if swept_body.intersects(bounds):
				return true
	return false
