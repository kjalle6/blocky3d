extends SceneTree
## Enlarged source poses in playback order, with the current audio markers.
## Run through run_godot_tool.ps1 -Visual -Width 1440 -Height 1080.

func _init() -> void:
	call_deferred("_run")

func _label(parent: Node, words: String, at: Vector2, size: int = 20) -> void:
	var label := Label.new()
	label.text = words
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func _run() -> void:
	root.content_scale_size = Vector2i(1440, 1080)
	root.size = Vector2i(1440, 1080)
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("18232d")
	background.size = Vector2(1440, 1080)
	canvas.add_child(background)
	_label(canvas, "Foot contact review | source frames, shown in playback order", Vector2(24, 12), 26)
	_label(canvas, "Green labels = current sound markers. Horizontal line = bottom of the 48px source canvas.", Vector2(24, 48), 18)
	var rows := [
		["Knife run", "player_run.png", "player_run.tres"],
		["Knife run-attack", "player_run_attack.png", "player_run.tres"],
		["Handgun run", "player_handgun_run_one_hand.png", "player_run.tres"],
		["Handgun backpedal (reverse Walk1)", "player_handgun_walk_one_hand.png", "player_backpedal.tres"],
	]
	for row in rows.size():
		var top := 78 + row * 235
		var texture: Texture2D = load("res://assets/art/green_zone/characters/" + rows[row][1])
		var track = load("res://resources/audio/markers/" + rows[row][2])
		_label(canvas, rows[row][0], Vector2(24, top), 22)
		for slot in 6:
			var frame: int = 5 - slot if track.reverse else slot
			var left := 24 + slot * 232
			var panel := ColorRect.new()
			panel.position = Vector2(left, top + 34)
			panel.size = Vector2(216, 144)
			panel.color = Color("34434b")
			canvas.add_child(panel)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame * 48, 0, 48, 48)
			var sprite := TextureRect.new()
			sprite.texture = atlas
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(left + 36, top + 34)
			sprite.size = Vector2(144, 144)
			canvas.add_child(sprite)
			var baseline := ColorRect.new()
			baseline.position = Vector2(left, top + 178)
			baseline.size = Vector2(216, 2)
			baseline.color = Color("7d959f")
			canvas.add_child(baseline)
			var marker: int = track.frames.find(frame)
			var caption := "Frame %d" % frame
			if marker >= 0:
				caption += " | " + track.feet[marker] + " STEP"
			_label(canvas, caption, Vector2(left, top + 184), 18)
			if marker >= 0:
				canvas.get_child(canvas.get_child_count() - 1).add_theme_color_override("font_color", Color("74f4b5"))
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/previews")
	var error := root.get_texture().get_image().save_png("res://build/previews/player_foot_contacts.png")
	assert(error == OK)
	print("Saved enlarged foot-contact review to build/previews/player_foot_contacts.png")
	quit()
