class_name PixelPlatform3D
extends StaticBody3D
## Collision-first platform with a curated 32 px tile face. Dimensions are in
## metres; the source art is displayed at 4 cm per pixel (1.28 m per tile).

const TILE_WORLD_SIZE := 1.28
const TILE_PIXEL_SIZE := TILE_WORLD_SIZE / 32.0
const DEFAULT_STYLE: PixelPlatformStyle = preload(
	"res://resources/presentation/platform_styles/green_zone.tres"
)

@export var size := Vector3(5.12, 2.56, 2.0)
@export var face_depth := 1.04
@export var style: PixelPlatformStyle = DEFAULT_STYLE
@export_category("Physics")
@export var collision_enabled := true
@export_category("Joined terrain")
@export var cap_left_edge := true
@export var cap_right_edge := true


func _ready() -> void:
	assert(
		absf(size.x / TILE_WORLD_SIZE - roundf(size.x / TILE_WORLD_SIZE)) < 0.001
		and absf(size.y / TILE_WORLD_SIZE - roundf(size.y / TILE_WORLD_SIZE)) < 0.001,
		"%s must stay aligned to the 1.28 m presentation grid." % name
	)
	assert(style != null, "%s requires a PixelPlatformStyle." % name)
	var style_errors := style.validation_errors()
	assert(
		style_errors.is_empty(),
		"%s has an invalid platform style:\n%s" % [name, "\n".join(style_errors)]
	)
	if collision_enabled:
		_build_collision()
	_build_face()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)


func _build_face() -> void:
	var columns := roundi(size.x / TILE_WORLD_SIZE)
	var rows := roundi(size.y / TILE_WORLD_SIZE)
	for row in rows:
		for column in columns:
			var texture := _tile_for(row, column, rows, columns)
			var sprite := Sprite3D.new()
			sprite.name = "Tile_%02d_%02d" % [row, column]
			sprite.texture = _cropped_top(texture) if row == 0 else texture
			sprite.pixel_size = TILE_PIXEL_SIZE
			if row == 0 and style.crop_top_pixels > 0:
				# Some source tiles contain a solid outline above their walkable
				# surface. Crop style-specific padding and expand the remainder
				# so collision and presentation still agree exactly.
				sprite.scale.y = 32.0 / (32.0 - style.crop_top_pixels)
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.shaded = false
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sprite.position = Vector3(
				-size.x * 0.5 + (column + 0.5) * TILE_WORLD_SIZE,
				size.y * 0.5 - (row + 0.5) * TILE_WORLD_SIZE,
				face_depth
			)
			add_child(sprite)


func _cropped_top(texture: Texture2D) -> Texture2D:
	if style.crop_top_pixels <= 0:
		return texture
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2(
		0,
		style.crop_top_pixels,
		32,
		32 - style.crop_top_pixels
	)
	return cropped


func _tile_for(row: int, column: int, rows: int, columns: int) -> Texture2D:
	if row == 0:
		return _edge_tile(
			style.top_left,
			style.top,
			style.top_right,
			column,
			columns
		)
	if row == 1:
		return _edge_tile(
			style.body_left,
			style.body,
			style.body_right,
			column,
			columns
		)
	if row == rows - 1 and style.has_bottom_row():
		return _edge_tile(
			style.bottom_left,
			style.bottom,
			style.bottom_right,
			column,
			columns
		)
	if style.has_deep_row():
		return _edge_tile(
			style.deep_left,
			style.deep,
			style.deep_right,
			column,
			columns
		)
	return _edge_tile(
		style.body_left,
		style.body,
		style.body_right,
		column,
		columns
	)


func _edge_tile(
	left: Texture2D,
	center: Texture2D,
	right: Texture2D,
	column: int,
	columns: int
) -> Texture2D:
	if column == 0 and cap_left_edge:
		return left
	if column == columns - 1 and cap_right_edge:
		return right
	return center
