extends StaticBody3D
## Bridge Constructor sprites at their native 4 cm pixel size. Only the outer
## uprights and the two decks are solid; the rear truss leaves the tank lane open.
@export_range(2.56, 20.48, 0.32) var width := 5.12
@export_range(2.56, 51.2, 0.32) var height := 11.52
@export_range(0.0, 49.92, 0.32) var underpass_height := 3.84
@export_range(0.0, 49.92, 0.32) var maintenance_ledge_y := 0.0

const ART := "res://assets/art/world_scenery/environment/structures/bridges/1 Tiles/"
const POST := preload(ART + "Bridge_tile_133.png")
const BRACE_UP := preload(ART + "Bridge_tile_111.png")
const BRACE_DOWN := preload(ART + "Bridge_tile_112.png")
const DECK_LEFT := preload(ART + "Bridge_tile_145.png")
const DECK_MIDDLE := preload(ART + "Bridge_tile_146.png")
const DECK_RIGHT := preload(ART + "Bridge_tile_147.png")
const PIXEL := 0.04
const TILE := 32 * PIXEL
const BEAM_WIDTH := 0.32
var _generated: Array[Node] = []


func _ready() -> void:
	rebuild_geometry()


func rebuild_geometry() -> void:
	for child in _generated:
		remove_child(child)
		child.free()
	_generated.clear()
	var low := underpass_height
	var left := -width * 0.5
	var right := width * 0.5
	# The rear legs reach the floor without closing the playable underpass.
	_post(left + 0.28, 0, height - 0.32, 0.58, Color(0.55, 0.61, 0.72))
	_post(right - 0.56, 0, height - 0.32, 0.58, Color(0.55, 0.61, 0.72))
	_build_truss(left, low + BEAM_WIDTH, height - BEAM_WIDTH)
	_post(left, low, height, 1.05, Color.WHITE)
	_post(right - 0.28, low, height, 1.05, Color.WHITE)
	# Keep the existing collision dimensions and outer wall-jump faces exact.
	for x in [left + BEAM_WIDTH * 0.5, right - BEAM_WIDTH * 0.5]:
		_solid(Vector2(x, (low + height) * 0.5), Vector2(BEAM_WIDTH, height - low))
	for top in [low + BEAM_WIDTH, height]:
		_deck(left, top, width, 1.08, Color.WHITE)
		_solid(Vector2(0, top - BEAM_WIDTH * 0.5), Vector2(width, BEAM_WIDTH))
	if maintenance_ledge_y > low and maintenance_ledge_y < height:
		var ledge_y := maintenance_ledge_y - BEAM_WIDTH * 0.5
		# Tuck the side ledge behind the upright so the column stays continuous.
		_deck(right - 0.32, maintenance_ledge_y, 1.6, 1.0, Color.WHITE)
		_solid(Vector2(right + 0.48, ledge_y), Vector2(1.6, BEAM_WIDTH))
		_piece(BRACE_UP, Rect2i(0, 0, 32, 32), Vector2(right, maintenance_ledge_y - 1.56), 0.9, Color(0.8, 0.85, 0.92))


func _build_truss(left: float, bottom: float, top: float) -> void:
	var columns := ceili(width / TILE)
	var rows := ceili((top - bottom) / TILE)
	for row in rows:
		var rise := row % columns
		for direction in 2:
			var column: int = rise if direction == 0 else columns - 1 - rise
			var pixels_x := mini(32, roundi((width - column * TILE) / PIXEL))
			var pixels_y := mini(32, roundi((top - bottom - row * TILE) / PIXEL))
			if pixels_x <= 0 or pixels_y <= 0: continue
			var texture: Texture2D = BRACE_UP if direction == 0 else BRACE_DOWN
			_piece(texture, Rect2i(0, 32 - pixels_y, pixels_x, pixels_y),
				Vector2(left + column * TILE, bottom + row * TILE), 0.66, Color(0.64, 0.70, 0.80))
			# The diagonal tiles end at their bolts. A source-art splice plate
			# covers each corner join instead of leaving two tips touching.
			if rise > 0:
				var joint_x := left + (column if direction == 0 else column + 1) * TILE
				_piece(POST, Rect2i(1, 1, 5, 6), Vector2(joint_x - 0.10, bottom + row * TILE - 0.12),
					0.67, Color(0.64, 0.70, 0.80))
		if row > 0 and rise == 0:
			_deck(left, bottom + row * TILE, width, 0.68, Color(0.6, 0.66, 0.76))


func _post(x: float, bottom: float, top: float, depth: float, tint: Color) -> void:
	for row in ceili((top - bottom) / TILE):
		var pixels := mini(32, roundi((top - bottom - row * TILE) / PIXEL))
		if pixels > 0:
			_piece(POST, Rect2i(0, 32 - pixels, 7, pixels), Vector2(x, bottom + row * TILE), depth, tint)


func _deck(left: float, top: float, length: float, depth: float, tint: Color) -> void:
	var columns := ceili(length / TILE)
	for column in columns:
		var pixels := mini(32, roundi((length - column * TILE) / PIXEL))
		var texture: Texture2D = DECK_LEFT if column == 0 else DECK_MIDDLE
		if column == columns - 1: texture = DECK_RIGHT
		var source_x := 32 - pixels if column == columns - 1 else 0
		_piece(texture, Rect2i(source_x, 0, pixels, 11), Vector2(left + column * TILE, top - 11 * PIXEL), depth, tint)


func _piece(texture: Texture2D, region: Rect2i, bottom_left: Vector2, depth: float, tint: Color) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	var sprite := Sprite3D.new()
	sprite.texture = atlas
	sprite.pixel_size = PIXEL
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.modulate = tint
	sprite.position = Vector3(bottom_left.x + region.size.x * PIXEL * 0.5,
		bottom_left.y + region.size.y * PIXEL * 0.5, depth)
	add_child(sprite)
	_generated.append(sprite)


func _solid(center: Vector2, dimensions: Vector2) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(dimensions.x, dimensions.y, 1.2)
	collision.shape = shape
	collision.position = Vector3(center.x, center.y, 0)
	add_child(collision)
	_generated.append(collision)
