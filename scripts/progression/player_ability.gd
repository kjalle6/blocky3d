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


static func is_known(ability_id: StringName) -> bool:
	return ability_id in ALL
