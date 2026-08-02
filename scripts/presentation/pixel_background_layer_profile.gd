class_name PixelBackgroundLayerProfile
extends Resource
## One independently moving track in a pixel-art background composition.
## Tracks repeat only across X. Coverage tracks tile continuously while
## decorative tracks may leave authored gaps for the environment sky.
## Camera coupling is explicit on both axes, so decorative and climbing-level
## behavior never has to be encoded as a misleading parallax value.

enum VerticalPolicy {
	SCREEN_LOCKED,
	PARALLAX,
	WORLD_LOCKED,
}

enum HorizontalPolicy {
	SCREEN_LOCKED,
	PARALLAX,
	WORLD_LOCKED,
}

enum HorizontalRepeat {
	LOOP,
	MIRROR,
}

@export var texture: Texture2D
@export var horizontal_policy := HorizontalPolicy.PARALLAX
@export_range(0.0, 1.0, 0.01) var horizontal_parallax := 0.2
@export var vertical_policy := VerticalPolicy.SCREEN_LOCKED
@export_range(0.0, 1.0, 0.01) var vertical_parallax := 0.0
@export var depth := -5.0
@export var offset_pixels := Vector2.ZERO
@export var tint := Color.WHITE
@export_category("Horizontal layout")
@export var horizontal_repeat := HorizontalRepeat.MIRROR
## Coverage tracks tile without gaps. Decorative tracks, such as clouds, may
## deliberately leave the solid environment sky visible between copies.
@export var cover_viewport_width := true
## Zero uses the texture width. Larger values create authored spacing for
## decorative tracks while preserving deterministic recycling.
@export_range(0.0, 2048.0, 1.0) var repeat_spacing_pixels := 0.0
@export_category("Camera-position visibility")
@export var fade_in_enabled := false
@export var fade_in_start_x := 0.0
@export var fade_in_end_x := 0.0
@export var fade_out_enabled := false
@export var fade_out_start_x := 0.0
@export var fade_out_end_x := 0.0


func opacity_at(camera_x: float) -> float:
	var opacity := tint.a
	if fade_in_enabled:
		opacity *= smoothstep(fade_in_start_x, fade_in_end_x, camera_x)
	if fade_out_enabled:
		opacity *= 1.0 - smoothstep(
			fade_out_start_x,
			fade_out_end_x,
			camera_x
		)
	return clampf(opacity, 0.0, 1.0)


func repeat_step_pixels() -> float:
	if repeat_spacing_pixels > 0.0:
		return repeat_spacing_pixels
	if texture == null:
		return 0.0
	return float(texture.get_width())


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if texture == null:
		errors.append("Background layer requires a texture.")
	if depth >= 0.0:
		errors.append("Background layer depth must remain behind gameplay at Z < 0.")
	if vertical_policy == VerticalPolicy.PARALLAX and (
		vertical_parallax < 0.0 or vertical_parallax > 1.0
	):
		errors.append("Vertical parallax must stay between zero and one.")
	if fade_in_enabled and fade_in_end_x <= fade_in_start_x:
		errors.append("Fade-in end must be after fade-in start.")
	if fade_out_enabled and fade_out_end_x <= fade_out_start_x:
		errors.append("Fade-out end must be after fade-out start.")
	if texture != null and repeat_step_pixels() <= 0.0:
		errors.append("Background repeat spacing must be positive.")
	if cover_viewport_width and texture != null and (
		repeat_step_pixels() > float(texture.get_width())
	):
		errors.append(
			"Viewport-covering layers cannot repeat farther apart than their texture width."
		)
	return errors
