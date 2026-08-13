class_name DressingAssetDefinition
extends Resource
## One reviewed set-dressing asset and the rules for placing it safely.

enum DepthBand {
	REAR,
	GAMEPLAY_BEHIND,
	FOREGROUND,
}

enum ClearanceClass {
	LOW,
	MEDIUM,
	LANDMARK,
}

@export var asset_id: StringName
@export var texture: Texture2D
@export var pixel_size := 0.04
@export var depth_band := DepthBand.GAMEPLAY_BEHIND
@export var clearance_class := ClearanceClass.LOW
@export var tags: Array[StringName] = []
@export var allow_flip_h := true
@export_range(0.5, 1.5, 0.05) var minimum_scale := 1.0
@export_range(0.5, 1.5, 0.05) var maximum_scale := 1.0


func footprint(scale_factor := 1.0) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	return Vector2(texture.get_width(), texture.get_height()) * pixel_size * scale_factor


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if asset_id.is_empty():
		errors.append("Dressing asset requires an id.")
	if texture == null:
		errors.append("Dressing asset '%s' requires a texture." % asset_id)
	if pixel_size <= 0.0:
		errors.append("Dressing asset '%s' requires a positive pixel size." % asset_id)
	if minimum_scale <= 0.0 or maximum_scale < minimum_scale:
		errors.append("Dressing asset '%s' has an invalid scale range." % asset_id)
	return errors
