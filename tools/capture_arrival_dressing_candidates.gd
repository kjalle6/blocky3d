extends SceneTree
## Deterministic visual audition for the accepted open-air Double Jump route.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://build/previews/dressing_candidates"
const PALETTE_PATH := "res://resources/dressing/arrival_green_zone_palette.tres"
const AERIAL_PROP_PREFIX := "Aerial"

const ZONES := {
	&"takeoff": Rect2(129.4, 2.4, 4.8, 3.2),
	&"mid_rise": Rect2(139.6, 2.6, 22.8, 7.2),
	&"landing": Rect2(167.4, 0.5, 16.8, 3.2),
}

const PROTECTED_RECTS := [
	Rect2(131.62, 3.82, 1.0, 2.0),
	Rect2(141.19, 6.38, 1.0, 2.0),
	Rect2(150.98, 4.46, 1.0, 2.0),
	Rect2(159.77, 7.66, 1.0, 2.0),
	Rect2(171.26, 0.62, 1.0, 2.0),
	Rect2(149.0, 4.46, 4.1, 1.9),
	Rect2(167.75, 0.62, 16.0, 1.9),
]

const CANDIDATES := {
	&"a_sparse_edges": [
		{&"zone": &"takeoff", &"asset": &"bush_low", &"x": 130.85, &"surface": 3.84},
		{&"zone": &"takeoff", &"asset": &"grass_sparse", &"x": 133.05, &"surface": 3.84},
		{&"zone": &"mid_rise", &"asset": &"grass_thin", &"x": 140.65, &"surface": 6.4},
		{&"zone": &"mid_rise", &"asset": &"stone_cluster", &"x": 143.1, &"surface": 6.4},
		{&"zone": &"mid_rise", &"asset": &"bush_small", &"x": 149.7, &"surface": 4.48},
		{&"zone": &"mid_rise", &"asset": &"grass_small", &"x": 152.5, &"surface": 4.48},
		{&"zone": &"mid_rise", &"asset": &"grass_thin", &"x": 158.75, &"surface": 7.68},
		{&"zone": &"mid_rise", &"asset": &"bush_low", &"x": 160.95, &"surface": 7.68},
		{&"zone": &"landing", &"asset": &"bush_low", &"x": 169.0, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"grass_sparse", &"x": 176.0, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"bush_small", &"x": 182.6, &"surface": 0.64},
	],
	&"b_crown_landmark": [
		{&"zone": &"takeoff", &"asset": &"bush_wild_left", &"x": 131.08, &"surface": 3.84},
		{&"zone": &"takeoff", &"asset": &"stone_small", &"x": 133.2, &"surface": 3.84},
		{&"zone": &"mid_rise", &"asset": &"grass_small", &"x": 140.55, &"surface": 6.4},
		{&"zone": &"mid_rise", &"asset": &"tree_small", &"x": 142.7, &"surface": 6.4},
		{&"zone": &"mid_rise", &"asset": &"bush_small", &"x": 149.7, &"surface": 4.48},
		{&"zone": &"mid_rise", &"asset": &"grass_small", &"x": 152.5, &"surface": 4.48},
		{&"zone": &"mid_rise", &"asset": &"grass_thin", &"x": 158.75, &"surface": 7.68},
		{&"zone": &"mid_rise", &"asset": &"bush_low", &"x": 160.95, &"surface": 7.68},
		{&"zone": &"landing", &"asset": &"bush_low", &"x": 169.0, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"stone_small", &"x": 176.0, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"grass_sparse", &"x": 179.7, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"bush_small", &"x": 182.65, &"surface": 0.64},
	],
	&"c_wild_islands": [
		{&"zone": &"takeoff", &"asset": &"stone_flat", &"x": 130.55, &"surface": 3.84},
		{&"zone": &"takeoff", &"asset": &"bush_small", &"x": 133.2, &"surface": 3.84},
		{&"zone": &"mid_rise", &"asset": &"grass_small", &"x": 140.55, &"surface": 6.4},
		{&"zone": &"mid_rise", &"asset": &"bush_wild_right", &"x": 142.8, &"surface": 6.4},
		{&"zone": &"mid_rise", &"asset": &"bush_low", &"x": 150.08, &"surface": 4.48},
		{&"zone": &"mid_rise", &"asset": &"grass_sparse", &"x": 152.6, &"surface": 4.48},
		{&"zone": &"mid_rise", &"asset": &"bush_wild_left", &"x": 159.15, &"surface": 7.68},
		{&"zone": &"mid_rise", &"asset": &"grass_small", &"x": 161.35, &"surface": 7.68},
		{&"zone": &"landing", &"asset": &"bush_low", &"x": 168.75, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"stone_small", &"x": 175.6, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"grass_thin", &"x": 179.6, &"surface": 0.64},
		{&"zone": &"landing", &"asset": &"bush_small", &"x": 182.7, &"surface": 0.64},
	],
}

const REVIEW_POSITIONS := [
	Vector3(131.84, 4.54, 0.0),
	Vector3(151.04, 5.18, 0.0),
	Vector3(160.0, 8.38, 0.0),
	Vector3(171.0, 1.34, 0.0),
]

var _palette: DressingPalette


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	_palette = load(PALETTE_PATH) as DressingPalette
	assert(_palette != null, "Arrival dressing palette must load.")
	var palette_errors := _palette.validation_errors()
	assert(palette_errors.is_empty(), "; ".join(palette_errors))

	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	for frame in 8:
		await process_frame
	var definition := load("res://resources/campaign/level_01.tres") as LevelDefinition
	game_root.load_level(definition.level_id)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	game_root.get_node("Interface").visible = false
	for frame in 8:
		await physics_frame
	_freeze_enemies(level)
	_hide_existing_aerial_dressing(level)

	for candidate_id in CANDIDATES:
		var preview := _build_candidate(level, candidate_id, CANDIDATES[candidate_id])
		for view_index in REVIEW_POSITIONS.size():
			await _capture_at(
				level,
				"%s_%02d" % [candidate_id, view_index + 1],
				REVIEW_POSITIONS[view_index]
			)
		preview.queue_free()
		await process_frame

	root.remove_child(game_root)
	game_root.free()
	await process_frame
	quit(0)


func _build_candidate(level: LevelSession3D, candidate_id: StringName, placements: Array) -> Node3D:
	var parent := Node3D.new()
	parent.name = "Preview_%s" % candidate_id
	level.get_node("Props").add_child(parent)
	for index in placements.size():
		var placement: Dictionary = placements[index]
		var definition := _palette.asset(placement[&"asset"])
		assert(definition != null, "Unknown dressing asset '%s'." % placement[&"asset"])
		var zone_rect: Rect2 = ZONES[placement[&"zone"]]
		var anchor: StringName = placement.get(&"anchor", &"bottom")
		assert(anchor == &"bottom", "Arrival forbids prop dressing beneath platforms.")
		var scale_factor: float = placement.get(&"scale", 1.0)
		var footprint := definition.footprint(scale_factor)
		var x: float = placement[&"x"]
		var support_y: float = placement[&"surface"]
		var visual_rect := _visual_rect(x, support_y, footprint, anchor)
		assert(zone_rect.intersects(visual_rect), "%s must remain inside its authored zone." % definition.asset_id)
		if definition.clearance_class != DressingAssetDefinition.ClearanceClass.LOW:
			for protected_rect in PROTECTED_RECTS:
				assert(
					not visual_rect.intersects(protected_rect),
					"%s overlaps a protected gameplay silhouette." % definition.asset_id
				)
		var sprite := Sprite3D.new()
		sprite.name = "%s_%02d" % [definition.asset_id, index + 1]
		sprite.texture = definition.texture
		sprite.pixel_size = definition.pixel_size
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.render_priority = 0
		sprite.scale = Vector3(scale_factor, scale_factor, 1.0)
		sprite.position = Vector3(
			x,
			support_y + footprint.y * (0.5 if anchor == &"bottom" else -0.5),
			0.90 if definition.depth_band == DressingAssetDefinition.DepthBand.REAR else 0.96
		)
		parent.add_child(sprite)
	return parent


func _visual_rect(x: float, support_y: float, footprint: Vector2, anchor: StringName) -> Rect2:
	var bottom := support_y if anchor == &"bottom" else support_y - footprint.y
	return Rect2(Vector2(x - footprint.x * 0.5, bottom), footprint)


func _hide_existing_aerial_dressing(level: LevelSession3D) -> void:
	for child in level.get_node("Props").get_children():
		if child.name.begins_with(AERIAL_PROP_PREFIX):
			(child as Node3D).visible = false


func _freeze_enemies(level: LevelSession3D) -> void:
	for node in get_nodes_in_group("melee_target"):
		if not level.is_ancestor_of(node):
			continue
		if node.has_method("reset_run"):
			node.call("reset_run")
		if node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
		node.set_physics_process(false)


func _capture_at(level: LevelSession3D, file_name: String, position: Vector3) -> void:
	level.player.reset_at(Transform3D(Basis.IDENTITY, position))
	level.player.set_physics_process(false)
	level.camera.snap_to_target()
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null, "Dressing candidate capture requires a renderer.")
	assert(image.get_size() == OUTPUT_SIZE)
	var error := image.save_png("%s/%s.png" % [OUTPUT_DIRECTORY, file_name])
	assert(error == OK, "Could not save dressing preview '%s'." % file_name)
