extends SceneTree
## Guards native scale and level-ground contact for the cave entrance approach.

const SCENE_PATH := "res://scenes/dev/cave_entrance_mockup_lab.tscn"
## The scene renders the native export; the 4x enlargement is kept only as the
## art source, and the two must stay pixel-identical under that scale.
const CAVE_PATH := (
	"res://assets/library/environment/structures/cave_entrances/"
	+ "cave_entrance_green_zone_native.png"
)
const CAVE_SOURCE_PATH := (
	"res://assets/library/environment/structures/cave_entrances/"
	+ "cave_entrance_green_zone.png"
)
const EXPECTED_TEXTURE_SIZE := Vector2i(128, 128)
const EXPECTED_SOURCE_SIZE := Vector2i(512, 512)
const EXPECTED_SOURCE_SCALE := 4
const EPSILON := 0.001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cave_texture := load(CAVE_PATH) as Texture2D
	assert(cave_texture != null, "Cave-entrance native texture is missing.")
	assert(cave_texture.get_size() == Vector2(EXPECTED_TEXTURE_SIZE))
	var image := cave_texture.get_image()
	assert(image != null)
	var alpha_bounds := _alpha_bounds(image)

	var source_texture := load(CAVE_SOURCE_PATH) as Texture2D
	assert(source_texture != null, "Cave-entrance art source is missing.")
	assert(source_texture.get_size() == Vector2(EXPECTED_SOURCE_SIZE))
	var source_image := source_texture.get_image()
	assert(source_image != null)
	assert(_alpha_bounds(source_image) == Rect2i(40, 84, 424, 332))
	_assert_exact_nearest_enlargement(source_image, EXPECTED_SOURCE_SCALE)
	_assert_lossless_downscale(source_image, image, EXPECTED_SOURCE_SCALE)

	var packed_scene := load(SCENE_PATH) as PackedScene
	assert(packed_scene != null)
	var room := packed_scene.instantiate() as LevelSession3D
	assert(room != null)
	var definition := LevelDefinition.new()
	definition.level_id = &"dev_cave_entrance_mockups"
	definition.available_abilities = []
	room.configure(definition)
	root.add_child(room)
	await process_frame

	var entrances := room.get_node("Props").find_children(
		"CaveEntrance",
		"Sprite3D",
		true,
		false
	)
	assert(entrances.size() == 1, "Expected one level-end cave entrance.")
	for entrance_node in entrances:
		var entrance := entrance_node as Sprite3D
		assert(entrance != null)
		assert(
			entrance.texture != null and entrance.texture.resource_path == CAVE_PATH,
			"The scene must render the native export, not the 4x art source."
		)
		assert(
			is_equal_approx(entrance.pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE),
			"The entrance must render on the shared pixel grid, or it shimmers."
		)
		assert(entrance.get_meta("source_native_scale") == 1)
		var support_y := float(entrance.get_meta("support_y"))
		var bury_logical_pixels := int(entrance.get_meta("bury_logical_pixels"))
		var opaque_bottom_offset := (
			float(alpha_bounds.end.y) - float(image.get_height()) * 0.5
		) * entrance.pixel_size
		var opaque_bottom_y := entrance.position.y - opaque_bottom_offset
		var expected_opaque_bottom_y := (
			support_y
			- float(bury_logical_pixels) * PixelPlatform3D.TILE_PIXEL_SIZE
		)
		assert(
			absf(opaque_bottom_y - expected_opaque_bottom_y) <= EPSILON,
			"%s floats above or sinks below its authored support."
			% entrance.get_parent().name
		)

	var ground := room.get_node("Platforms/Ground") as PixelPlatform3D
	assert(ground != null)
	assert(is_equal_approx(ground.size.x, 38.4))
	assert(is_equal_approx(ground.size.y, 6.4))
	assert(is_equal_approx(ground.position.y + ground.size.y * 0.5, -0.64))
	assert(is_equal_approx(ground.position.x + ground.size.x * 0.5, 38.4))
	var cave := entrances[0] as Sprite3D
	var opaque_right_offset := (
		float(alpha_bounds.end.x) - float(image.get_width()) * 0.5
	) * cave.pixel_size
	var cave_right_edge := cave.position.x + opaque_right_offset
	assert(
		is_equal_approx(cave_right_edge - 38.4, 0.8),
		"The cave's rear edge must extend beyond the level and be cropped away."
	)

	print("Cave entrance approach passed: native export on full-depth level ground.")
	quit(0)


func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	assert(maximum.x >= minimum.x and maximum.y >= minimum.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _assert_exact_nearest_enlargement(image: Image, scale_factor: int) -> void:
	assert(image.get_width() % scale_factor == 0)
	assert(image.get_height() % scale_factor == 0)
	for block_y in range(0, image.get_height(), scale_factor):
		for block_x in range(0, image.get_width(), scale_factor):
			var reference := image.get_pixel(block_x, block_y)
			for y in range(block_y, block_y + scale_factor):
				for x in range(block_x, block_x + scale_factor):
					assert(
						image.get_pixel(x, y) == reference,
						"Cave entrance is no longer an exact nearest-neighbour export."
					)


## The native export must be recoverable from the enlarged source exactly, so
## that going back to the art file can never quietly change what ships.
##
## Colour is compared only where the pixel is actually visible. The importer's
## fix_alpha_border rewrites the colour of fully transparent pixels, and it does
## that at each file's own resolution, so those pixels legitimately differ.
func _assert_lossless_downscale(
	source_image: Image, native_image: Image, scale_factor: int
) -> void:
	assert(source_image.get_width() == native_image.get_width() * scale_factor)
	assert(source_image.get_height() == native_image.get_height() * scale_factor)
	var alpha_mismatches := 0
	var colour_mismatches := 0
	var first_mismatch := ""
	for y in native_image.get_height():
		for x in native_image.get_width():
			var source_pixel := source_image.get_pixel(x * scale_factor, y * scale_factor)
			var native_pixel := native_image.get_pixel(x, y)
			if not is_equal_approx(source_pixel.a, native_pixel.a):
				alpha_mismatches += 1
			elif native_pixel.a > 0.0 and Vector3(
				source_pixel.r, source_pixel.g, source_pixel.b
			).distance_to(Vector3(native_pixel.r, native_pixel.g, native_pixel.b)) > 0.001:
				colour_mismatches += 1
			else:
				continue
			if first_mismatch.is_empty():
				first_mismatch = "(%d, %d) source %s native %s" % [
					x, y, source_pixel, native_pixel
				]
	assert(
		alpha_mismatches == 0 and colour_mismatches == 0,
		"Native cave entrance no longer matches its 4x art source: %d alpha and %d colour mismatches, first at %s."
		% [alpha_mismatches, colour_mismatches, first_mismatch]
	)
