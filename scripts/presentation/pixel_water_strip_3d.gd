class_name PixelWaterStrip3D
extends Node3D
## Presentation-only water assembled on the same 32 px / 1.28 m grid as
## platforms. The source atlas is arranged as animation frames across columns
## and depth bands down rows. All tiles share one clock so adjacent crests stay
## seamless. Lethality remains owned by the level's explicit kill volume.

const TILE_WORLD_SIZE := PixelPlatform3D.TILE_WORLD_SIZE
const TILE_PIXEL_SIZE := PixelPlatform3D.TILE_PIXEL_SIZE
const TILE_TEXTURE_SIZE := 32

@export var width := 10.24
@export var face_depth := 0.86
@export var tile_sheet: Texture2D
@export_range(1, 12, 1) var frame_count := 4
@export_range(1.0, 24.0, 0.5) var frame_rate := 8.0
@export_range(1, 8, 1) var body_rows := 1

var _sprites: Array[Sprite3D] = []
var _sprite_bands := PackedInt32Array()
var _elapsed := 0.0
var _current_frame := 0


func _ready() -> void:
	assert(
		absf(width / TILE_WORLD_SIZE - roundf(width / TILE_WORLD_SIZE)) < 0.001,
		"%s must stay aligned to the 1.28 m presentation grid." % name
	)
	assert(tile_sheet != null, "%s requires a water animation atlas." % name)
	assert(
		tile_sheet.get_width() == frame_count * TILE_TEXTURE_SIZE,
		"%s atlas must contain exactly %d horizontal animation frames."
		% [name, frame_count]
	)
	assert(
		tile_sheet.get_height() >= (body_rows + 1) * TILE_TEXTURE_SIZE,
		"%s atlas does not contain enough depth bands for %d body rows."
		% [name, body_rows]
	)
	_build_face()
	_apply_frame(0)
	set_process(frame_count > 1)


func _process(delta: float) -> void:
	_elapsed += delta
	var next_frame := floori(_elapsed * frame_rate) % frame_count
	if next_frame == _current_frame:
		return
	_apply_frame(next_frame)


func current_frame() -> int:
	return _current_frame


func runtime_tile_count() -> int:
	return _sprites.size()


func _build_face() -> void:
	var columns := roundi(width / TILE_WORLD_SIZE)
	for column in columns:
		_add_tile(
			"Surface_%02d" % column,
			column,
			0,
			0
		)
		for row in range(1, body_rows + 1):
			_add_tile(
				"Body_%02d_%02d" % [row, column],
				column,
				row,
				row
			)


func _add_tile(
	tile_name: String,
	column: int,
	row: int,
	band: int
) -> void:
	var sprite := Sprite3D.new()
	sprite.name = tile_name
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
	_sprites.append(sprite)
	_sprite_bands.append(band)


func _apply_frame(frame: int) -> void:
	_current_frame = frame
	for sprite_index in _sprites.size():
		_sprites[sprite_index].texture = _atlas_tile(
			_sprite_bands[sprite_index],
			frame
		)


func _atlas_tile(band: int, frame: int) -> AtlasTexture:
	var tile := AtlasTexture.new()
	tile.atlas = tile_sheet
	tile.region = Rect2(
		frame * TILE_TEXTURE_SIZE,
		band * TILE_TEXTURE_SIZE,
		TILE_TEXTURE_SIZE,
		TILE_TEXTURE_SIZE
	)
	return tile
