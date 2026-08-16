class_name PixelInteriorTerrainStyle
extends Resource
## Nine-slice presentation skin for a connected grid of solid interior cells.
## Gameplay collision is generated from the same grid by PixelInteriorTerrain3D.

@export var top_left: Texture2D
@export var top: Texture2D
@export var top_right: Texture2D
@export var left: Texture2D
@export var fill: Texture2D
@export var right: Texture2D
@export var bottom_left: Texture2D
@export var bottom: Texture2D
@export var bottom_right: Texture2D
@export_category("Inside corners")
@export var inner_top_left: Texture2D
@export var inner_top_right: Texture2D
@export var inner_bottom_left: Texture2D
@export var inner_bottom_right: Texture2D
@export_category("Subtle variation")
@export var top_variants: Array[Texture2D] = []
@export var fill_variants: Array[Texture2D] = []
@export var bottom_variants: Array[Texture2D] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var named_textures := {
		"top_left": top_left,
		"top": top,
		"top_right": top_right,
		"left": left,
		"fill": fill,
		"right": right,
		"bottom_left": bottom_left,
		"bottom": bottom,
		"bottom_right": bottom_right,
		"inner_top_left": inner_top_left,
		"inner_top_right": inner_top_right,
		"inner_bottom_left": inner_bottom_left,
		"inner_bottom_right": inner_bottom_right,
	}
	for role: String in named_textures:
		var texture := named_textures[role] as Texture2D
		if texture == null:
			errors.append("Interior style requires a '%s' texture." % role)
		elif texture.get_width() != 32 or texture.get_height() != 32:
				errors.append(
				"Interior %s tile '%s' must be 32 x 32 px."
				% [role, texture.resource_path]
			)
	var optional_groups := {
		"top variant": top_variants,
		"fill variant": fill_variants,
		"bottom variant": bottom_variants,
	}
	for role: String in optional_groups:
		for texture: Texture2D in optional_groups[role]:
			if texture == null:
				errors.append("Interior %s cannot be null." % role)
			elif texture.get_width() != 32 or texture.get_height() != 32:
				errors.append(
					"Interior %s tile '%s' must be 32 x 32 px."
					% [role, texture.resource_path]
				)
	return errors
