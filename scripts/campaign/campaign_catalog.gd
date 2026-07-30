class_name CampaignCatalog
extends Resource
## Ordered source of truth for campaign worlds and level-select presentation.

@export var worlds: Array[WorldDefinition] = []


func ordered_worlds() -> Array[WorldDefinition]:
	var ordered: Array[WorldDefinition] = []
	for world in worlds:
		if world != null:
			ordered.append(world)
	ordered.sort_custom(
		func(left: WorldDefinition, right: WorldDefinition) -> bool:
			return left.display_number < right.display_number
	)
	return ordered


func ordered_levels() -> Array[LevelDefinition]:
	var ordered: Array[LevelDefinition] = []
	for world in ordered_worlds():
		if world != null:
			ordered.append_array(world.ordered_levels())
	return ordered


func find_by_id(level_id: StringName) -> LevelDefinition:
	for world in worlds:
		if world == null:
			continue
		var definition := world.find_level_by_id(level_id)
		if definition != null:
			return definition
	return null


func find_world_by_id(world_id: StringName) -> WorldDefinition:
	for world in worlds:
		if world != null and world.world_id == world_id:
			return world
	return null


func find_world_for_level(level_id: StringName) -> WorldDefinition:
	for world in worlds:
		if world != null and world.find_level_by_id(level_id) != null:
			return world
	return null


func find_level(world_id: StringName, level_number: int) -> LevelDefinition:
	var world := find_world_by_id(world_id)
	if world == null:
		return null
	return world.find_level_by_number(level_number)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if worlds.is_empty():
		errors.append("Campaign catalog must contain at least one world.")
	var seen_world_ids := {}
	var seen_world_numbers := {}
	var seen_level_ids := {}
	for world in worlds:
		if world == null:
			errors.append("Campaign catalog contains an empty world entry.")
			continue
		errors.append_array(world.validation_errors())
		if seen_world_ids.has(world.world_id):
			errors.append("Duplicate world_id '%s'." % world.world_id)
		else:
			seen_world_ids[world.world_id] = true
		if seen_world_numbers.has(world.display_number):
			errors.append("Duplicate world display number %d." % world.display_number)
		else:
			seen_world_numbers[world.display_number] = true
		for definition in world.levels:
			if definition == null:
				continue
			if seen_level_ids.has(definition.level_id):
				errors.append("Duplicate campaign level_id '%s'." % definition.level_id)
			else:
				seen_level_ids[definition.level_id] = true

	for definition in ordered_levels():
		for prerequisite_id in definition.prerequisite_level_ids:
			if not seen_level_ids.has(prerequisite_id):
				errors.append(
					"%s requires unknown level '%s'."
					% [definition.level_id, prerequisite_id]
				)
	return errors
