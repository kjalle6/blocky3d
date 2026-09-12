extends Control
const CATALOG := preload("res://scripts/developer/level_object_catalog.gd")
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
var catalog_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func _draw() -> void:
	if not CATALOG.ENTRIES.has(catalog_id): return
	var entry: Dictionary = CATALOG.ENTRIES[catalog_id]
	if entry.kind == "platform":
		var tile := minf(size.x / 3.5, size.y / 2.4)
		var start := (size - Vector2(tile * 3, tile * 2)) * 0.5
		var style: Resource = REGISTRY.STYLES[entry.style]
		var lower: Array = [style.bottom_left, style.bottom, style.bottom_right] if style.has_bottom_row() else [style.body_left, style.body, style.body_right]
		var tiles := [style.top_left, style.top, style.top_right] + lower
		for index in 6: draw_texture_rect(tiles[index], Rect2(start + Vector2(index % 3, index / 3) * tile, Vector2.ONE * tile), false)
	elif entry.kind == "checkpoint":
		var center := size * 0.5
		var height := minf(size.y * 0.7, 100)
		draw_line(center + Vector2(-height * 0.3, height * 0.5), center + Vector2(-height * 0.3, -height * 0.5), Color("73ffbc"), 4)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-height * 0.28, -height * 0.5), center + Vector2(height * 0.4, -height * 0.5), center + Vector2(height * 0.16, -height * 0.22), center + Vector2(-height * 0.28, -height * 0.22)]), Color("73ffbc"))
	else:
		var image := CATALOG.icon(catalog_id)
		if image == null: return
		var scale_factor := minf((size.x - 12) / image.get_width(), (size.y - 12) / image.get_height())
		var extent := image.get_size() * maxf(scale_factor, 0.1)
		draw_texture_rect(image, Rect2((size - extent) * 0.5, extent), false)
