extends HBoxContainer
## Keep large asset libraries to a bounded number of live picture cards.
signal page_changed(step: int)
var _previous: Button
var _next: Button
var _label: Label

func _init() -> void:
	_previous = Button.new()
	_previous.text = "‹"
	_previous.custom_minimum_size = Vector2(36, 30)
	_previous.tooltip_text = "Previous page"
	add_child(_previous)
	_previous.pressed.connect(func() -> void: page_changed.emit(-1))
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
	_next = Button.new()
	_next.text = "›"
	_next.custom_minimum_size = Vector2(36, 30)
	_next.tooltip_text = "Next page"
	add_child(_next)
	_next.pressed.connect(func() -> void: page_changed.emit(1))

func update_page(page: int, count: int, page_size: int) -> void:
	var pages := maxi(1, ceili(float(count) / page_size))
	_label.text = "%d objects · %d / %d" % [count, page + 1, pages]
	_previous.disabled = page <= 0
	_next.disabled = page >= pages - 1
