extends RefCounted
## Audio surface IDs are independent of physics friction/bounce materials.
## Explicit collider metadata wins over the platform/terrain style default.
static func surface_at(collider: Object, world_position: Vector3) -> String:
	if collider is Node3D and collider.has_meta("footstep_surface"):
		if collider.has_meta("footstep_split_x"):
			var local_position: Vector3 = collider.to_local(world_position)
			if local_position.x >= float(collider.get_meta("footstep_split_x")):
				return str(collider.get_meta("footstep_surface_right", "silent"))
		return str(collider.get_meta("footstep_surface"))
	if collider is PixelPlatform3D or collider is PixelInteriorTerrain3D:
		if collider.style != null:
			return collider.style.footstep_surface
	return "silent"

static func sample(player: PlayerCharacter) -> Dictionary:
	# Sample the supporting floor under the collision body. A decorative sprite
	# or weapon cannot change the surface, nor can geometry behind the player.
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position, player.global_position + Vector3.DOWN * 0.8, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"surface": "silent", "collider": "none"}
	return {"surface": surface_at(hit.collider, hit.position),
		"collider": str(hit.collider.name), "position": hit.position}
