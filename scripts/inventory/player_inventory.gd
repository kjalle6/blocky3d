class_name PlayerInventory
extends RefCounted
## Unlimited owned quantities; two quick references never duplicate a stack.

signal changed
var quantities: Dictionary = {}
var quick_slots: Array[StringName] = [&"basic_heal", &""]


func count(item_id: StringName) -> int:
	return int(quantities.get(String(item_id), 0))


func add(item_id: StringName, amount: int) -> bool:
	if ItemCatalog.definition(item_id) == null or amount <= 0:
		return false
	quantities[String(item_id)] = count(item_id) + amount
	changed.emit()
	return true


func consume(item_id: StringName, amount := 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	quantities[String(item_id)] = count(item_id) - amount
	if count(item_id) == 0:
		quantities.erase(String(item_id))
	changed.emit()
	return true


func equip(slot: int, item_id: StringName) -> bool:
	if slot < 0 or slot >= quick_slots.size():
		return false
	if not item_id.is_empty():
		var item := ItemCatalog.definition(item_id)
		if item == null or not item.quick_usable:
			return false
	quick_slots[slot] = item_id
	changed.emit()
	return true


func reset() -> void:
	quantities.clear()
	quick_slots.assign([&"basic_heal", &""])
	changed.emit()


func to_dictionary() -> Dictionary:
	return {"quantities": quantities.duplicate(), "quick_slots": Array(quick_slots)}


func restore(data: Dictionary) -> void:
	quantities = data.get("quantities", {}).duplicate()
	quick_slots.assign(data.get("quick_slots", ["basic_heal", ""]))
	changed.emit()
