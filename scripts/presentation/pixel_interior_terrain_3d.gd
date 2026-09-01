class_name PixelInteriorTerrain3D
extends StaticBody3D
## Builds a connected enclosed room from one collision/presentation grid.
## Rows are authored top-to-bottom using '#' for rock and '.' for open space.

const TILE_WORLD_SIZE := 1.28
const TILE_PIXEL_SIZE := TILE_WORLD_SIZE / 32.0

@export var solid_rows := PackedStringArray()
@export var style: PixelInteriorTerrainStyle
@export var face_depth := 1.04
@export var collision_depth := 2.0
@export var hidden_face_region := Rect2i()
@export_range(0, 4, 1) var visual_extension_rows_below := 0

var _row_count := 0
var _column_count := 0
var _collision_rectangle_count := 0


func _ready() -> void:
	var errors := validation_errors()
	assert(
		errors.is_empty(),
		"%s has invalid interior terrain:\n%s" % [name, "\n".join(errors)]
	)
	_row_count = solid_rows.size()
	_column_count = solid_rows[0].length()
	_build_collision_rectangles()
	_build_face()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if style == null:
		errors.append("Interior terrain requires a presentation style.")
	else:
		errors.append_array(style.validation_errors())
	if solid_rows.is_empty():
		errors.append("Interior terrain requires at least one grid row.")
		return errors
	if hidden_face_region.size.x < 0 or hidden_face_region.size.y < 0:
		errors.append("The hidden face region cannot have negative dimensions.")
	var expected_width := solid_rows[0].length()
	if expected_width <= 0:
		errors.append("Interior terrain rows cannot be empty.")
	for row_index in solid_rows.size():
		var row := solid_rows[row_index]
		if row.length() != expected_width:
			errors.append(
				"Interior row %d has width %d; expected %d."
				% [row_index, row.length(), expected_width]
			)
		for column in row.length():
			var cell := row.substr(column, 1)
			if cell != "#" and cell != ".":
				errors.append(
					"Interior row %d column %d uses '%s'; only '#' and '.' are valid."
					% [row_index, column, cell]
				)
	return errors


func row_count() -> int:
	return _row_count if _row_count > 0 else solid_rows.size()


func column_count() -> int:
	if _column_count > 0:
		return _column_count
	return 0 if solid_rows.is_empty() else solid_rows[0].length()


func collision_rectangle_count() -> int:
	return _collision_rectangle_count


func solid_cell_count() -> int:
	var total := 0
	for row in solid_rows:
		total += row.count("#")
	return total


func is_solid_cell(row: int, column: int) -> bool:
	return (
		row >= 0
		and row < solid_rows.size()
		and column >= 0
		and column < solid_rows[row].length()
		and solid_rows[row].substr(column, 1) == "#"
	)


func cell_center(row: int, column: int) -> Vector3:
	return Vector3(
		(column + 0.5) * TILE_WORLD_SIZE,
		(row_count() - row - 0.5) * TILE_WORLD_SIZE,
		0.0
	)


func _build_face() -> void:
	for row in _row_count + visual_extension_rows_below:
		for column in _column_count:
			if (
				not _is_face_solid_cell(row, column)
				or _is_face_hidden(row, column)
			):
				continue
			var sprite := Sprite3D.new()
			sprite.name = "Tile_%02d_%02d" % [row, column]
			sprite.texture = _texture_for_cell(row, column)
			sprite.pixel_size = TILE_PIXEL_SIZE
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.shaded = false
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sprite.position = cell_center(row, column) + Vector3(0, 0, face_depth)
			add_child(sprite)


func _is_face_solid_cell(row: int, column: int) -> bool:
	if is_solid_cell(row, column):
		return true
	return (
		visual_extension_rows_below > 0
		and row >= _row_count
		and row < _row_count + visual_extension_rows_below
		and column >= 0
		and column < _column_count
		and is_solid_cell(_row_count - 1, column)
	)


func _is_face_hidden(row: int, column: int) -> bool:
	return (
		hidden_face_region.size.x > 0
		and hidden_face_region.size.y > 0
		and hidden_face_region.has_point(Vector2i(column, row))
	)


func _texture_for_cell(row: int, column: int) -> Texture2D:
	var exposed_top := not _is_face_solid_cell(row - 1, column)
	var exposed_bottom := not _is_face_solid_cell(row + 1, column)
	var exposed_left := not _is_face_solid_cell(row, column - 1)
	var exposed_right := not _is_face_solid_cell(row, column + 1)
	# A concave room corner belongs to the diagonally adjacent solid cell. Its
	# four direct neighbours remain solid, so ordinary exposed-edge selection
	# cannot see it. The source tiles cut the open quadrant into that solid cell
	# and make the adjoining ceiling/wall or wall/floor art turn continuously.
	if (
		_is_face_solid_cell(row, column + 1)
		and _is_face_solid_cell(row + 1, column)
		and not _is_face_solid_cell(row + 1, column + 1)
	):
		return style.inner_top_left
	if (
		_is_face_solid_cell(row, column - 1)
		and _is_face_solid_cell(row + 1, column)
		and not _is_face_solid_cell(row + 1, column - 1)
	):
		return style.inner_top_right
	if (
		_is_face_solid_cell(row, column + 1)
		and _is_face_solid_cell(row - 1, column)
		and not _is_face_solid_cell(row - 1, column + 1)
	):
		return style.inner_bottom_left
	if (
		_is_face_solid_cell(row, column - 1)
		and _is_face_solid_cell(row - 1, column)
		and not _is_face_solid_cell(row - 1, column - 1)
	):
		return style.inner_bottom_right
	if exposed_top and exposed_left:
		return style.top_left
	if exposed_top and exposed_right:
		return style.top_right
	if exposed_bottom and exposed_left:
		return style.bottom_left
	if exposed_bottom and exposed_right:
		return style.bottom_right
	if exposed_top:
		return _subtle_variant(style.top, style.top_variants, row, column, 5)
	if exposed_bottom:
		return _subtle_variant(style.bottom, style.bottom_variants, row, column, 5)
	if exposed_left:
		return style.left
	if exposed_right:
		return style.right
	return _subtle_variant(style.fill, style.fill_variants, row, column, 17)


func _subtle_variant(
	primary: Texture2D,
	variants: Array[Texture2D],
	row: int,
	column: int,
	frequency: int
) -> Texture2D:
	if variants.is_empty():
		return primary
	var key := absi(
		(row + 3) * 37
		+ (column + 5) * 61
		+ row * column * 17
	)
	if key % frequency != 0:
		return primary
	return variants[(key / frequency) % variants.size()]


func _build_collision_rectangles() -> void:
	var claimed: Array[PackedByteArray] = []
	for row in _row_count:
		var claimed_row := PackedByteArray()
		claimed_row.resize(_column_count)
		claimed.append(claimed_row)
	_collision_rectangle_count = 0
	for row in _row_count:
		for column in _column_count:
			if not is_solid_cell(row, column) or claimed[row][column] != 0:
				continue
			var width := 1
			while (
				column + width < _column_count
				and is_solid_cell(row, column + width)
				and claimed[row][column + width] == 0
			):
				width += 1
			var height := 1
			while row + height < _row_count:
				var can_extend := true
				for offset in width:
					if (
						not is_solid_cell(row + height, column + offset)
						or claimed[row + height][column + offset] != 0
					):
						can_extend = false
						break
				if not can_extend:
					break
				height += 1
			for claimed_row in range(row, row + height):
				for claimed_column in range(column, column + width):
					claimed[claimed_row][claimed_column] = 1
			_add_collision_rectangle(row, column, width, height)


func _add_collision_rectangle(
	row: int,
	column: int,
	width: int,
	height: int
) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision_%02d" % _collision_rectangle_count
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		width * TILE_WORLD_SIZE,
		height * TILE_WORLD_SIZE,
		collision_depth
	)
	collision.shape = shape
	var top_left_center := cell_center(row, column)
	collision.position = Vector3(
		top_left_center.x + (width - 1) * TILE_WORLD_SIZE * 0.5,
		top_left_center.y - (height - 1) * TILE_WORLD_SIZE * 0.5,
		0.0
	)
	add_child(collision)
	_collision_rectangle_count += 1
