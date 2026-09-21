extends PanelContainer
## Resizable window assembled from the pack's original corner and edge tiles.
const STYLE := preload("res://scripts/ui/cyberpunk_ui_style.gd")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	STYLE.draw_pack_window(self)
