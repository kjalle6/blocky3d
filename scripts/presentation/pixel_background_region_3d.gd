class_name PixelBackgroundRegion3D
extends Node3D
## Scene-authored volume that selects which background zones are visible.
##
## Cave presentation is spatially zoned rather than keyed to progress: enclosed
## tunnels and shafts show the restrained base treatment, and the full layered
## composition belongs to the open upper floor. Because the zoning is a volume
## in the world, descending returns to the base and climbing restores the upper
## treatment without any state to get out of sync.
##
## Influence is a pure function of camera position, so checkpoint respawn,
## death, restart, and direct level loads all reproduce the same background.
## It follows the rendered camera rather than the player for the same reason
## the height fades do: an ordinary jump must not flash a new treatment into
## view, and the camera's vertical follow is already clamped by its own region.
##
## A region's influence extends `blend_margin` metres past each face, so two
## regions that merely touch still cross-fade across their shared edge. Author
## that edge where terrain fills the screen - inside a shaft, or around the turn
## onto the upper floor - and the handoff is masked rather than merely gradual.

@export var size := Vector2(64.0, 32.0)
## Zone tags this region shows. A layer with an empty tag is unzoned and always
## drawn, which is how the base stays as continuous fallback coverage.
@export var visible_zones: Array[StringName] = []
## Metres beyond each face across which this region's influence falls to zero.
@export_range(0.0, 64.0, 0.1, "or_greater") var blend_margin := 6.0
## Shapes the ramp across the blend. 1.0 is a plain smoothstep; higher values
## keep the region faint through most of the approach and bring it in near the
## face, so a long climb stays in the old treatment until it actually arrives.
@export_range(0.25, 6.0, 0.05) var blend_exponent := 1.0


## 1.0 well inside the volume, easing to 0.0 `blend_margin` metres beyond it.
func weight_at(world_position: Vector3) -> float:
	var local_position := to_local(world_position)
	return minf(
		_axis_weight(absf(local_position.x), size.x * 0.5),
		_axis_weight(absf(local_position.y), size.y * 0.5)
	)


func shows_zone(zone: StringName) -> bool:
	return zone in visible_zones


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if size.x <= 0.0 or size.y <= 0.0:
		errors.append("Background region size must be positive.")
	if visible_zones.is_empty():
		errors.append(
			"A background region that shows no zones has no effect; remove it "
			+ "or name the zones it reveals."
		)
	return errors


func _axis_weight(distance: float, half_extent: float) -> float:
	if distance <= half_extent:
		return 1.0
	if blend_margin <= 0.0:
		return 0.0
	var ramp := 1.0 - smoothstep(half_extent, half_extent + blend_margin, distance)
	return pow(ramp, blend_exponent)
