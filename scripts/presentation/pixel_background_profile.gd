class_name PixelBackgroundProfile
extends Resource
## Reusable authored composition for PixelBackgroundRig3D.

@export var profile_id: StringName
@export_range(0.001, 1.0, 0.001) var pixel_size := 0.04
@export var layers: Array[PixelBackgroundLayerProfile] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile_id.is_empty():
		errors.append("Background profile requires a stable profile_id.")
	if not is_equal_approx(pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE):
		errors.append(
			"Background pixel size must match the foreground pixel scale of %.3f."
			% PixelPlatform3D.TILE_PIXEL_SIZE
		)
	if layers.is_empty():
		errors.append("Background profile requires at least one layer.")
	var previous_depth := -INF
	for index in layers.size():
		var layer := layers[index]
		if layer == null:
			errors.append("Background layer %d is missing." % (index + 1))
			continue
		for layer_error in layer.validation_errors():
			errors.append("Layer %d: %s" % [index + 1, layer_error])
		if layer.texture == null:
			continue
		if layer.depth <= previous_depth:
			errors.append(
				"Layers must be ordered back-to-front by increasing Z depth."
			)
		previous_depth = layer.depth
	return errors


func panel_size_world() -> Vector2:
	for layer in layers:
		if layer != null and layer.texture != null and layer.cover_viewport_width:
			return Vector2(
				layer.texture.get_width(),
				layer.texture.get_height()
			) * pixel_size
	return Vector2.ZERO
