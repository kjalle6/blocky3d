class_name ItemCatalog
extends RefCounted

const ITEMS := {
	&"basic_heal": preload("res://resources/items/basic_heal.tres"),
	&"large_heal_test": preload("res://resources/items/large_heal_test.tres"),
	&"medical_bag": preload("res://resources/items/medical_bag.tres"),
	&"handgun_ammo": preload("res://resources/items/handgun_ammo.tres"),
}


static func definition(item_id: StringName) -> ItemDefinition:
	return ITEMS.get(item_id) as ItemDefinition
