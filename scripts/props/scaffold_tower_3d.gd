extends StaticBody3D
## A Bridge Constructor scaffold frame for the boss arena. Its one-way decks are
## the only solid parts: the player and the boss jump up through a deck, stand on
## it, and the player drops back through with move_down. Posts and braces are a
## passable frame behind the decks. A frame stands on the floor, or hangs from
## the ceiling when its posts start at its lowest deck. Same art and pixel size
## as the wall-jump scaffold; that prop stays untouched because its source is
## part of every saved layout's structural fingerprint.
@export_range(2.56, 20.48, 0.32) var width := 12.8
## Local Y range of the two posts. A hung frame starts at its lowest deck and
## ends at the ceiling.
@export var post_bottom := 0.0
@export var post_top := 33.28
## Local Y range filled with cross-braces.
@export var brace_bottom := 3.84
@export var brace_top := 33.28
## One-way decks: (top height, extension past the left post, past the right post).
## An extension makes a balcony with a strut under it.
@export var decks: PackedVector3Array = PackedVector3Array()
## Lets the boss leap up through the decks; see GreenZoneBoss3D.
@export var boss_pass_up := true

const ART := "res://assets/art/world_scenery/environment/structures/bridges/1 Tiles/"
const POST := preload(ART + "Bridge_tile_133.png")
const BRACE_UP := preload(ART + "Bridge_tile_111.png")
const BRACE_DOWN := preload(ART + "Bridge_tile_112.png")
const DECK_LEFT := preload(ART + "Bridge_tile_145.png")
const DECK_MIDDLE := preload(ART + "Bridge_tile_146.png")
const DECK_RIGHT := preload(ART + "Bridge_tile_147.png")
const PIXEL := 0.04
const TILE := 32 * PIXEL
const DECK_THICKNESS := 0.32
const FRAME_TINT := Color(0.64, 0.70, 0.80)
const POST_TINT := Color(0.78, 0.83, 0.92)
## Physics layer 7 holds only one-way decks: the player and bosses stand on it;
## bullets and rockets, which query layers 1-3, pass through.
const ONE_WAY_LAYER := 64
const DROP_TIME := 0.3
## Feet this far below a deck top still count as standing on it.
const SUPPORT_TOLERANCE := 0.02
var _generated: Array[Node] = []
var _deck_bodies: Array[StaticBody3D] = []
var _passing: Dictionary = {}
var _drop_deck: StaticBody3D
var _drop_remaining := 0.0


func _ready() -> void:
	rebuild_geometry()


func rebuild_geometry() -> void:
	for child in _generated:
		if is_instance_valid(child):
			remove_child(child)
			child.free()
	_generated.clear()
	_deck_bodies.clear()
	_passing.clear()
	var left := -width * 0.5
	var right := width * 0.5
	if brace_top > brace_bottom:
		_build_truss(left, brace_bottom, brace_top)
	_post(left, post_bottom, post_top, 0.9, POST_TINT)
	_post(right - 0.28, post_bottom, post_top, 0.9, POST_TINT)
	for deck in decks:
		var start := left - deck.y
		var length := width + deck.y + deck.z
		_deck(start, deck.x, length, 1.08, Color.WHITE)
		_deck_body(start, deck.x, length)
		# A strut under each balcony, from the post out to the deck's tip.
		if deck.y >= TILE:
			_piece(BRACE_DOWN, Rect2i(0, 0, 32, 32), Vector2(left - TILE, deck.x - DECK_THICKNESS - TILE), 0.95, FRAME_TINT)
		if deck.z >= TILE:
			_piece(BRACE_UP, Rect2i(0, 0, 32, 32), Vector2(right, deck.x - DECK_THICKNESS - TILE), 0.95, FRAME_TINT)


## Deck spans in world space as (left x, top y, right x), lowest first.
func deck_spans() -> Array[Vector3]:
	var spans: Array[Vector3] = []
	for body in _deck_bodies:
		spans.append(Vector3(body.get_meta(&"deck_left"), body.get_meta(&"deck_top"), body.get_meta(&"deck_right")))
	spans.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	return spans


func _physics_process(delta: float) -> void:
	if _deck_bodies.is_empty():
		return
	for actor in get_tree().get_nodes_in_group("boss_enemy"):
		if actor is CollisionObject3D:
			actor.collision_mask |= ONE_WAY_LAYER
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	if player == null:
		return
	player.collision_mask |= ONE_WAY_LAYER
	var feet := player.feet_world_y()
	_drop_remaining = maxf(0.0, _drop_remaining - delta)
	if InputMap.has_action(&"move_down") and Input.is_action_just_pressed(&"move_down") \
			and player.is_on_floor() and not player.is_control_locked():
		var standing := _deck_under(player, feet)
		if standing != null:
			_drop_deck = standing
			_drop_remaining = DROP_TIME
	for deck in _deck_bodies:
		var top: float = deck.get_meta(&"deck_top")
		var dropping := _drop_remaining > 0.0 and deck == _drop_deck
		var passing := dropping or feet < top - SUPPORT_TOLERANCE
		if passing == _passing.get(deck, false):
			continue
		_passing[deck] = passing
		if passing:
			player.add_collision_exception_with(deck)
		else:
			player.remove_collision_exception_with(deck)


func _deck_under(player: PlayerCharacter, feet: float) -> StaticBody3D:
	for deck in _deck_bodies:
		if absf(feet - float(deck.get_meta(&"deck_top"))) <= 0.12 \
				and player.global_position.x >= float(deck.get_meta(&"deck_left")) - 0.36 \
				and player.global_position.x <= float(deck.get_meta(&"deck_right")) + 0.36:
			return deck
	return null


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
				Vector2(left + column * TILE, bottom + row * TILE), 0.66, FRAME_TINT)
			if rise > 0:
				var joint_x := left + (column if direction == 0 else column + 1) * TILE
				_piece(POST, Rect2i(1, 1, 5, 6), Vector2(joint_x - 0.10, bottom + row * TILE - 0.12),
					0.67, FRAME_TINT)


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


func _deck_body(left: float, top: float, length: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Deck%d" % _deck_bodies.size()
	body.collision_layer = ONE_WAY_LAYER
	body.collision_mask = 0
	body.position = Vector3(left + length * 0.5, top - DECK_THICKNESS * 0.5, 0)
	var origin := global_position if is_inside_tree() else position
	body.set_meta(&"deck_top", origin.y + top)
	body.set_meta(&"deck_left", origin.x + left)
	body.set_meta(&"deck_right", origin.x + left + length)
	body.set_meta(&"footstep_surface", "silent")
	if boss_pass_up:
		body.add_to_group("boss_pass_up")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, DECK_THICKNESS, 1.2)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_generated.append(body)
	_deck_bodies.append(body)
