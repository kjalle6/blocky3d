class_name PixelPlatform3D
extends StaticBody3D
## Collision-first platform with a curated 32 px tile face. Dimensions are in
## metres; the source art is displayed at 4 cm per pixel (1.28 m per tile).

const TILE_WORLD_SIZE := 1.28
const TILE_PIXEL_SIZE := TILE_WORLD_SIZE / 32.0

const TOP_LEFT := preload("res://assets/art/green_zone/tiles/top_left.png")
const TOP := preload("res://assets/art/green_zone/tiles/top.png")
const TOP_RIGHT := preload("res://assets/art/green_zone/tiles/top_right.png")
const BODY_LEFT := preload("res://assets/art/green_zone/tiles/body_left.png")
const BODY := preload("res://assets/art/green_zone/tiles/body.png")
const BODY_RIGHT := preload("res://assets/art/green_zone/tiles/body_right.png")

@export var size := Vector3(5.12, 2.56, 2.0)
@export var face_depth := 1.04


func _ready() -> void:
	assert(
		absf(size.x / TILE_WORLD_SIZE - roundf(size.x / TILE_WORLD_SIZE)) < 0.001
		and absf(size.y / TILE_WORLD_SIZE - roundf(size.y / TILE_WORLD_SIZE)) < 0.001,
		"%s must stay aligned to the 1.28 m presentation grid." % name
	)
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
			sprite.texture = _without_top_outline(texture) if row == 0 else texture
			sprite.pixel_size = TILE_PIXEL_SIZE
			if row == 0:
				# The source tiles contain a solid black first row. In a 3D
				# side view that reads as empty space between grounded props
				# and the grass. Crop it and expand the remaining 31 rows back
				# to one tile so collision and presentation still agree.
				sprite.scale.y = 32.0 / 31.0
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.shaded = false
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sprite.position = Vector3(
				-size.x * 0.5 + (column + 0.5) * TILE_WORLD_SIZE,
				size.y * 0.5 - (row + 0.5) * TILE_WORLD_SIZE,
				face_depth
			)
			add_child(sprite)


func _without_top_outline(texture: Texture2D) -> AtlasTexture:
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2(0, 1, 32, 31)
	return cropped


func _tile_for(row: int, column: int, _rows: int, columns: int) -> Texture2D:
	if row == 0:
		if column == 0:
			return TOP_LEFT
		if column == columns - 1:
			return TOP_RIGHT
		return TOP
	if column == 0:
		return BODY_LEFT
	if column == columns - 1:
		return BODY_RIGHT
	return BODY
