extends SceneTree
## Focused row-selection contract for PixelPlatform3D. The test protects old
## six-tile styles while proving that deeper terrain uses authored fill and
## bottom rows instead of repeating the first body texture.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy := _style(false)
	assert(legacy.validation_errors().is_empty())
	var legacy_platform := await _platform(legacy, 5)
	_assert_row(legacy_platform, 0, legacy.top)
	for row in range(1, 5):
		_assert_row(legacy_platform, row, legacy.body)
	legacy_platform.queue_free()
	await process_frame

	var enhanced := _style(true)
	assert(enhanced.validation_errors().is_empty())
	var deep_platform := await _platform(enhanced, 5)
	_assert_row(deep_platform, 0, enhanced.top)
	_assert_row(deep_platform, 1, enhanced.body)
	_assert_row(deep_platform, 2, enhanced.deep)
	_assert_row(deep_platform, 3, enhanced.deep)
	_assert_row(deep_platform, 4, enhanced.bottom)
	deep_platform.queue_free()
	await process_frame

	var open_bottom := await _platform(enhanced, 5, true, false)
	_assert_tile(open_bottom, 4, 0, enhanced.deep_left)
	_assert_tile(open_bottom, 4, 1, enhanced.deep)
	_assert_tile(open_bottom, 4, 2, enhanced.deep_right)
	open_bottom.queue_free()
	await process_frame

	var shallow_platform := await _platform(enhanced, 2)
	_assert_row(shallow_platform, 0, enhanced.top)
	_assert_row(shallow_platform, 1, enhanced.body)
	shallow_platform.queue_free()
	await process_frame

	var uncapped := await _platform(enhanced, 4, false)
	_assert_tile(uncapped, 2, 0, enhanced.deep)
	_assert_tile(uncapped, 3, 0, enhanced.bottom)
	uncapped.queue_free()
	await process_frame

	var partial := _style(false)
	partial.deep_left = _texture(Color.RED)
	assert(
		_contains_error(partial.validation_errors(), "requires left, center, and right")
	)
	var wrong_size := _style(false)
	wrong_size.bottom_left = _texture(Color.RED, Vector2i(16, 32))
	wrong_size.bottom = _texture(Color.GREEN)
	wrong_size.bottom_right = _texture(Color.BLUE)
	assert(_contains_error(wrong_size.validation_errors(), "must be 32 x 32"))

	print("Pixel platform renderer validation passed.")
	quit(0)


func _platform(
	platform_style: PixelPlatformStyle,
	rows: int,
	capped := true,
	bottom_capped := true
) -> PixelPlatform3D:
	var platform := PixelPlatform3D.new()
	platform.name = "RendererProbe"
	platform.style = platform_style
	platform.size = Vector3(
		PixelPlatform3D.TILE_WORLD_SIZE * 3.0,
		PixelPlatform3D.TILE_WORLD_SIZE * rows,
		2.0
	)
	platform.collision_enabled = false
	platform.cap_left_edge = capped
	platform.cap_right_edge = capped
	platform.cap_bottom_edge = bottom_capped
	root.add_child(platform)
	await process_frame
	return platform


func _style(enhanced: bool) -> PixelPlatformStyle:
	var platform_style := PixelPlatformStyle.new()
	platform_style.crop_top_pixels = 0
	platform_style.top_left = _texture(Color("ff6666"))
	platform_style.top = _texture(Color("ff8888"))
	platform_style.top_right = _texture(Color("ffaa88"))
	platform_style.body_left = _texture(Color("66ff66"))
	platform_style.body = _texture(Color("88ff88"))
	platform_style.body_right = _texture(Color("aaff88"))
	if enhanced:
		platform_style.deep_left = _texture(Color("6666ff"))
		platform_style.deep = _texture(Color("8888ff"))
		platform_style.deep_right = _texture(Color("aaaaff"))
		platform_style.bottom_left = _texture(Color("ffff66"))
		platform_style.bottom = _texture(Color("ffff88"))
		platform_style.bottom_right = _texture(Color("ffffaa"))
	return platform_style


func _texture(color: Color, dimensions := Vector2i(32, 32)) -> Texture2D:
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _assert_row(
	platform: PixelPlatform3D,
	row: int,
	expected_center: Texture2D
) -> void:
	_assert_tile(platform, row, 1, expected_center)


func _assert_tile(
	platform: PixelPlatform3D,
	row: int,
	column: int,
	expected: Texture2D
) -> void:
	var sprite := platform.get_node("Tile_%02d_%02d" % [row, column]) as Sprite3D
	assert(sprite.texture == expected)


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false
