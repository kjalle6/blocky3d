class_name PlayerAbility
extends RefCounted
## Stable identifiers for permanent player abilities.
##
## String identifiers are intentionally used at the save-data boundary. Enum
## ordinals would make old saves change meaning when the ability list changes.

const DOUBLE_JUMP := &"double_jump"
const WALL_JUMP := &"wall_jump"
const DASH := &"dash"

const ALL := [
	DOUBLE_JUMP,
	WALL_JUMP,
	DASH,
]

## Abilities with a complete runtime implementation. The Animation Lab
## definition must expose this exact set so new mechanics cannot omit tooling.
const IMPLEMENTED := [
	DOUBLE_JUMP,
	WALL_JUMP,
]


static func is_known(ability_id: StringName) -> bool:
	return ability_id in ALL


static func display_name(ability_id: StringName) -> String:
	match ability_id:
		DOUBLE_JUMP:
			return "DOUBLE JUMP"
		WALL_JUMP:
			return "WALL JUMP"
		DASH:
			return "DASH"
		_:
			return String(ability_id).to_upper()


static func instruction(ability_id: StringName) -> String:
	match ability_id:
		DOUBLE_JUMP:
			return "JUMP AGAIN WHILE AIRBORNE"
		WALL_JUMP:
			return "JUMP AWAY FROM A WALL"
		DASH:
			return "DASH THROUGH THE AIR"
		_:
			return ""
