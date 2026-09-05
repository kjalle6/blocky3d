class_name PlayerWeapon
extends RefCounted
## Stable identifiers for the deliberately small player loadout. Weapons stay
## separate from permanent movement abilities until campaign persistence is an
## explicit design decision.

const KNIFE: StringName = &"knife"
const HANDGUN: StringName = &"handgun"

const ALL: Array[StringName] = [
	KNIFE,
	HANDGUN,
]


static func is_known(weapon_id: StringName) -> bool:
	return weapon_id in ALL
