extends SceneTree
## Contract check for the baked Arrival aerial dressing proof.

const PALETTE_PATH := "res://resources/dressing/arrival_green_zone_palette.tres"
const LEVEL_PATH := "res://scenes/levels/arrival_shoreline.tscn"
const CONTACT_TOLERANCE := 0.041
const HORIZONTAL_SUPPORT_MARGIN := 0.039


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors := PackedStringArray()
	var palette := load(PALETTE_PATH) as DressingPalette
	if palette == null:
		errors.append("Arrival dressing palette did not load.")
	else:
		errors.append_array(palette.validation_errors())

	var packed_level := load(LEVEL_PATH) as PackedScene
	if packed_level == null:
		errors.append("Arrival level did not load for dressing validation.")
		_finish(errors)
		return
	var level := packed_level.instantiate()
	root.add_child(level)
	await process_frame

	var props := level.get_node_or_null("Props")
	var zone_root := level.get_node_or_null("Props/AerialDressingZones")
	if props == null or zone_root == null:
		errors.append("Arrival requires Props/AerialDressingZones.")
	else:
		var zone_ids := {}
		for child in zone_root.get_children():
			if not child is DressingZone3D:
				errors.append("Aerial dressing zone '%s' is not typed." % child.name)
				continue
			var zone := child as DressingZone3D
			errors.append_array(zone.validation_errors())
			if zone_ids.has(zone.zone_id):
				errors.append("Duplicate aerial dressing zone '%s'." % zone.zone_id)
			zone_ids[zone.zone_id] = true
		if zone_ids.size() != 3:
			errors.append("Arrival aerial proof requires exactly three authored zones.")

		var validated_sprites := 0
		for child in props.get_children():
			if not child.name.begins_with("Aerial") or not child is Sprite3D:
				continue
			_validate_sprite(child as Sprite3D, palette, level, errors)
			validated_sprites += 1
		if validated_sprites != 17:
			errors.append(
				"Arrival requires 17 reviewed aerial and exit dressing sprites; found %d."
				% validated_sprites
			)

	root.remove_child(level)
	level.free()
	_finish(errors)


func _validate_sprite(
	sprite: Sprite3D,
	palette: DressingPalette,
	level: Node,
	errors: PackedStringArray
) -> void:
	if not sprite.has_meta("dressing_asset_id"):
		errors.append("%s is missing its approved dressing asset id." % sprite.name)
		return
	var asset_id: StringName = sprite.get_meta("dressing_asset_id")
	var definition := palette.asset(asset_id)
	if definition == null:
		errors.append("%s uses unapproved dressing asset '%s'." % [sprite.name, asset_id])
		return
	if sprite.texture != definition.texture:
		errors.append("%s texture does not match '%s'." % [sprite.name, asset_id])
	if sprite.get_child_count() != 0:
		errors.append("%s must remain visual-only and childless." % sprite.name)
	if not sprite.has_meta("support_y") or not sprite.has_meta("contact_anchor"):
		errors.append("%s is missing its support contact contract." % sprite.name)
		return
	var footprint := definition.footprint(absf(sprite.scale.y))
	var support_y: float = sprite.get_meta("support_y")
	var anchor: StringName = sprite.get_meta("contact_anchor")
	if anchor != &"bottom":
		errors.append("%s violates the clean-platform-underside rule." % sprite.name)
		return
	var contact_y := sprite.position.y - footprint.y * 0.5
	if absf(contact_y - support_y) > CONTACT_TOLERANCE:
		errors.append(
			"%s floats by %.3f m from its declared support."
			% [sprite.name, contact_y - support_y]
		)
	if not sprite.has_meta("support_platform"):
		return
	var support_name: StringName = sprite.get_meta("support_platform")
	var support := level.get_node_or_null("Platforms/%s" % support_name) as PixelPlatform3D
	if support == null:
		errors.append("%s names missing support platform '%s'." % [sprite.name, support_name])
		return
	var support_left := support.position.x - support.size.x * 0.5
	var support_right := support.position.x + support.size.x * 0.5
	var visual_left := sprite.position.x - footprint.x * 0.5
	var visual_right := sprite.position.x + footprint.x * 0.5
	if visual_left < support_left + HORIZONTAL_SUPPORT_MARGIN:
		errors.append(
			"%s overhangs the left edge of %s by %.3f m."
			% [sprite.name, support_name, support_left + HORIZONTAL_SUPPORT_MARGIN - visual_left]
		)
	if visual_right > support_right - HORIZONTAL_SUPPORT_MARGIN:
		errors.append(
			"%s overhangs the right edge of %s by %.3f m."
			% [sprite.name, support_name, visual_right - support_right + HORIZONTAL_SUPPORT_MARGIN]
		)


func _finish(errors: PackedStringArray) -> void:
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("Arrival dressing validation passed.")
	quit(0)
