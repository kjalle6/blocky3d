extends RefCounted
## Tool-only loader for the production Level 2 interior section.
##
## The cave is not a developer level: it keeps Overgrown Coastal Ascent's
## campaign and world identity while tools skip the approach and slide intro.

const LEVEL_ID: StringName = &"overgrown_coastal_ascent"
const WORLD_ID: StringName = &"green_zone"
const DEFINITION_PATH := "res://resources/campaign/level_02.tres"
const INTERIOR_SCENE: PackedScene = preload(
	"res://scenes/levels/overgrown_coastal_ascent_interior.tscn"
)


static func production_definition() -> LevelDefinition:
	var definition := load(DEFINITION_PATH) as LevelDefinition
	assert(definition != null, "Production Level 2 definition must load.")
	assert(definition.level_id == LEVEL_ID)
	return definition


static func instantiate_session() -> LevelSession3D:
	var definition := production_definition()
	var session := INTERIOR_SCENE.instantiate() as LevelSession3D
	assert(session != null, "Production Level 2 interior must instantiate.")
	var initial_abilities: Array[StringName] = (
		definition.assumed_owned_abilities.duplicate()
	)
	session.configure(
		definition,
		null,
		initial_abilities
	)
	return session


static func load_into(game_root) -> LevelSession3D:
	assert(game_root != null)
	var definition := game_root.campaign.find_by_id(LEVEL_ID) as LevelDefinition
	var world_definition := (
		game_root.campaign.find_world_for_level(LEVEL_ID) as WorldDefinition
	)
	assert(definition != null, "Production Level 2 must be in the campaign.")
	assert(world_definition != null and world_definition.world_id == WORLD_ID)
	var initial_abilities: Array[StringName] = (
		definition.assumed_owned_abilities.duplicate()
	)
	game_root._start_session(
		definition,
		world_definition,
		initial_abilities,
		INTERIOR_SCENE
	)
	assert(game_root.current_level_definition == definition)
	assert(game_root.current_world_definition == world_definition)
	var session := game_root.current_level as LevelSession3D
	assert(session != null, "Production Level 2 interior must load into GameRoot.")
	return session
