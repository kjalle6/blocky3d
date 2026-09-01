extends SceneTree
## Machine check for the two pixel-art rules that dressing keeps breaking.
##
## 1. Authored scenery renders at PixelPlatform3D.TILE_PIXEL_SIZE. Any other
##    pixel size puts the art on a sub-pixel grid, and it shimmers against the
##    terrain whenever the snapped camera lands between its pixels.
## 2. Overlapping props do not share a render_priority. Godot is free to order
##    a tie either way, so the pair flickers as the camera moves. Terrain faces
##    sit at 0: negative beds a prop into the ground, positive lifts it on top.
##
## Actors are deliberately exempt from rule 1. The player, enemies, pickups and
## the goal chest are authored at their own scales so they read at the right
## size against the tiles; they are self-contained and never sit still beside
## static art, so the sub-pixel cost never shows.

const CHECKED_LEVELS: Array[StringName] = [
	&"arrival_shoreline",
	&"overgrown_coastal_ascent",
]
const CHECKED_DEVELOPER_LEVELS: Array[StringName] = [
	&"dev_enclosed_terrain_lab",
	&"dev_overgrown_coastal_ascent_interior_review",
	&"dev_animation_lab",
]
## Props that merely share an edge are not overlapping.
const EDGE_TOLERANCE := 0.01
const ACTOR_GROUPS: PackedStringArray = [
	"player_character",
	"ability_pickup",
	"level_goal",
	"melee_target",
	"level_checkpoint",
]

var _failures: PackedStringArray = []
var _scenery_seen := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_root := (load("res://scenes/app/game_root.tscn") as PackedScene).instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame

	_assert_every_scene_is_accounted_for(game_root)

	for level_id in CHECKED_LEVELS:
		game_root.load_level(level_id)
		await process_frame
		_audit(game_root.current_level as LevelSession3D, level_id)
	for level_id in CHECKED_DEVELOPER_LEVELS:
		game_root.load_developer_level(_developer_definition(game_root, level_id))
		await process_frame
		_audit(game_root.current_level as LevelSession3D, level_id)

	assert(_scenery_seen > 0, "No authored scenery was reached at all; the walk is broken.")
	if not _failures.is_empty():
		push_error("Pixel-art invariants violated:\n%s" % "\n".join(_failures))
		printerr("Pixel-art invariants violated:\n%s" % "\n".join(_failures))
		quit(1)
		return
	print("Pixel-art invariants passed: %d authored sprites across %d levels." % [
		_scenery_seen,
		CHECKED_LEVELS.size() + CHECKED_DEVELOPER_LEVELS.size(),
	])
	quit(0)


## A new level scene must opt in to the rules or be named as legacy, so that
## dressing cannot quietly land somewhere the validator does not look.
func _assert_every_scene_is_accounted_for(game_root: Node) -> void:
	var covered := PackedStringArray()
	for definition in game_root.campaign.ordered_levels() + game_root._known_developer_definitions():
		if definition.level_id in CHECKED_LEVELS or definition.level_id in CHECKED_DEVELOPER_LEVELS:
			covered.append(definition.scene.resource_path)
	for directory in ["res://scenes/levels", "res://scenes/dev"]:
		for file_name in DirAccess.get_files_at(directory):
			if not file_name.ends_with(".tscn"):
				continue
			var path := "%s/%s" % [directory, file_name]
			if path in covered:
				continue
			_failures.append(
				"%s is not covered. Add it to CHECKED_LEVELS or "
				% path
				+ "CHECKED_DEVELOPER_LEVELS so its scenery is held to the rules."
			)


func _developer_definition(game_root: Node, level_id: StringName) -> LevelDefinition:
	for definition in game_root._known_developer_definitions():
		if definition.level_id == level_id:
			return definition
	assert(false, "Unknown developer level: %s" % level_id)
	return null


func _audit(session: LevelSession3D, level_id: StringName) -> void:
	assert(session != null, "Level %s failed to load." % level_id)
	var scenery: Array[Sprite3D] = []
	_collect_scenery(session, scenery)
	_scenery_seen += scenery.size()
	for sprite in scenery:
		if not is_equal_approx(sprite.pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE):
			_failures.append(
				"%s: %s renders at pixel_size %s, not the native %s."
				% [
					level_id,
					session.get_path_to(sprite),
					sprite.pixel_size,
					PixelPlatform3D.TILE_PIXEL_SIZE,
				]
			)
	_audit_render_priorities(session, scenery, level_id)


## Authored scenery is what the level file places by hand: props, dressing and
## structures. Generated tiles, background layers and water are built in code
## that already reads TILE_PIXEL_SIZE, and actors are exempt by design.
func _collect_scenery(node: Node, into: Array[Sprite3D]) -> void:
	for child in node.get_children():
		if _is_actor(child) or _is_generated_presentation(child):
			continue
		if child is Sprite3D and child.owner != null:
			into.append(child)
		_collect_scenery(child, into)


func _is_actor(node: Node) -> bool:
	for group in ACTOR_GROUPS:
		if node.is_in_group(group):
			return true
	return node is PixelSpikeRow3D


func _is_generated_presentation(node: Node) -> bool:
	return (
		node is PixelPlatform3D
		or node is PixelInteriorTerrain3D
		or node is PixelBackgroundRig3D
		or node is PixelWaterStrip3D
		or node is PixelShoreWave3D
		or node is Level2CaveSlideIntro3D
	)


func _audit_render_priorities(
	session: LevelSession3D, scenery: Array[Sprite3D], level_id: StringName
) -> void:
	for first_index in scenery.size():
		for second_index in range(first_index + 1, scenery.size()):
			var first := scenery[first_index]
			var second := scenery[second_index]
			if first.render_priority != second.render_priority:
				continue
			if not is_equal_approx(first.global_position.z, second.global_position.z):
				continue
			if not _overlaps(first, second):
				continue
			_failures.append(
				"%s: %s and %s overlap at depth %.3f and share render_priority %d."
				% [
					level_id,
					session.get_path_to(first),
					session.get_path_to(second),
					first.global_position.z,
					first.render_priority,
				]
			)


func _overlaps(first: Sprite3D, second: Sprite3D) -> bool:
	var first_rect := _world_rect(first)
	var second_rect := _world_rect(second)
	if first_rect.size == Vector2.ZERO or second_rect.size == Vector2.ZERO:
		return false
	# Shrink both rects so that props merely sharing an edge do not count.
	return first_rect.grow(-EDGE_TOLERANCE).intersects(second_rect.grow(-EDGE_TOLERANCE))


func _world_rect(sprite: Sprite3D) -> Rect2:
	if sprite.texture == null:
		return Rect2()
	var frame_size := Vector2(
		sprite.texture.get_width() / float(maxi(sprite.hframes, 1)),
		sprite.texture.get_height() / float(maxi(sprite.vframes, 1))
	)
	if sprite.region_enabled:
		frame_size = sprite.region_rect.size
	var size := frame_size * sprite.pixel_size
	var centre := Vector2(sprite.global_position.x, sprite.global_position.y)
	centre += sprite.offset * sprite.pixel_size
	if not sprite.centered:
		centre += Vector2(size.x, -size.y) * 0.5
	return Rect2(centre - size * 0.5, size)
