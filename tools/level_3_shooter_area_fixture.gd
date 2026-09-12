extends RefCounted
## Tool fixture for Level 3 WIP's second authored section.
##
## The shooter area is not another developer level. It keeps Green Zone
## Finale's definition and movement kit, using the same entry as the menu.

const LEVEL_ID: StringName = &"dev_green_zone_finale_wip"
const DEFINITION_PATH := "res://resources/dev/green_zone_finale_wip.tres"
const SHOOTER_SCENE: PackedScene = preload(
	"res://scenes/dev/green_zone_finale_shooter_area_wip.tscn"
)


static func developer_definition() -> LevelDefinition:
	var definition := load(DEFINITION_PATH) as LevelDefinition
	assert(definition != null, "Level 3 WIP definition must load.")
	assert(definition.level_id == LEVEL_ID)
	return definition


static func instantiate_session() -> LevelSession3D:
	var definition := developer_definition()
	var session := SHOOTER_SCENE.instantiate() as LevelSession3D
	assert(session != null, "Level 3 WIP shooter area must instantiate.")
	var initial_abilities: Array[StringName] = (
		definition.assumed_owned_abilities.duplicate()
	)
	session.configure(definition, null, initial_abilities)
	return session


static func load_into(game_root) -> LevelSession3D:
	assert(game_root != null)
	var definition := developer_definition()
	game_root.load_developer_level(definition, &"gun_encounter")
	assert(game_root.current_level_definition == definition)
	assert(game_root.current_world_definition == null)
	var session := game_root.current_level as LevelSession3D
	assert(session != null, "Level 3 WIP shooter area must load into GameRoot.")
	return session
