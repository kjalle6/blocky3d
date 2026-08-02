class_name PixelPlatformStyle
extends Resource
## Visual skin for a collision-first pixel platform. Gameplay dimensions stay
## on PixelPlatform3D's shared 1.28 m grid; this resource changes art only.

@export var top_left: Texture2D
@export var top: Texture2D
@export var top_right: Texture2D
@export var body_left: Texture2D
@export var body: Texture2D
@export var body_right: Texture2D
@export_category("Optional deep terrain")
@export var deep_left: Texture2D
@export var deep: Texture2D
@export var deep_right: Texture2D
@export var bottom_left: Texture2D
@export var bottom: Texture2D
@export var bottom_right: Texture2D
@export_range(0, 31, 1) var crop_top_pixels := 1


func has_deep_row() -> bool:
	return deep_left != null and deep != null and deep_right != null


func has_bottom_row() -> bool:
	return bottom_left != null and bottom != null and bottom_right != null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var required_textures: Array[Texture2D] = [
		top_left,
		top,
		top_right,
		body_left,
		body,
		body_right,
	]
	for texture in required_textures:
		if texture == null:
			errors.append("Platform style requires all six tile textures.")
			break
	var optional_triplets: Array = [
		["deep", deep_left, deep, deep_right],
		["bottom", bottom_left, bottom, bottom_right],
	]
	for triplet in optional_triplets:
		var supplied := 0
		for index in range(1, 4):
			if triplet[index] != null:
				supplied += 1
		if supplied != 0 and supplied != 3:
			errors.append(
				"Optional %s terrain row requires left, center, and right textures."
				% triplet[0]
			)
	var textures: Array[Texture2D] = required_textures.duplicate()
	for texture in [
		deep_left,
		deep,
		deep_right,
		bottom_left,
		bottom,
		bottom_right,
	]:
		if texture != null:
			textures.append(texture)
	for texture in textures:
		if texture != null and (
			texture.get_width() != 32 or texture.get_height() != 32
		):
			errors.append(
				"Platform tile '%s' must be 32 x 32 px." % texture.resource_path
			)
	return errors
