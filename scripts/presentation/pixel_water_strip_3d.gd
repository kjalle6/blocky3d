class_name PixelWaterStrip3D
extends Node3D
## Presentation-only water assembled on the same 32 px / 1.28 m grid as
## platforms. Lethality remains owned by the level's explicit kill volume.

const TILE_WORLD_SIZE := PixelPlatform3D.TILE_WORLD_SIZE
const TILE_PIXEL_SIZE := PixelPlatform3D.TILE_PIXEL_SIZE

@export var width := 10.24
@export var face_depth := 0.86
@export var surface_tiles: Array[Texture2D] = []
@export var body_tiles: Array[Texture2D] = []
@export_range(1, 8, 1) var body_rows := 1


func _ready() -> void:
	assert(
		absf(width / TILE_WORLD_SIZE - roundf(width / TILE_WORLD_SIZE)) < 0.001,
		"%s must stay aligned to the 1.28 m presentation grid." % name
	)
	assert(not surface_tiles.is_empty(), "%s requires surface water tiles." % name)
	assert(not body_tiles.is_empty(), "%s requires body water tiles." % name)
	_build_face()


func _build_face() -> void:
	var columns := roundi(width / TILE_WORLD_SIZE)
	for column in columns:
		_add_tile(
			"Surface_%02d" % column,
			surface_tiles[column % surface_tiles.size()],
			column,
			0
		)
		for row in range(1, body_rows + 1):
			_add_tile(
				"Body_%02d_%02d" % [row, column],
				body_tiles[(column + row - 1) % body_tiles.size()],
				column,
				row
			)


func _add_tile(
	tile_name: String,
	texture: Texture2D,
	column: int,
	row: int
) -> void:
	assert(texture != null, "%s contains a missing water texture." % name)
	var sprite := Sprite3D.new()
	sprite.name = tile_name
	sprite.texture = texture
	sprite.pixel_size = TILE_PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(
		-width * 0.5 + (column + 0.5) * TILE_WORLD_SIZE,
		-(row + 0.5) * TILE_WORLD_SIZE,
		face_depth
	)
	add_child(sprite)
