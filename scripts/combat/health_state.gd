class_name HealthState
extends RefCounted
## Mutable, actor-owned health. Authored resources never hold current HP.

signal changed(current: int, maximum: int)
signal depleted

var maximum := 100
var current := 100
var has_taken_damage := false


func reset(maximum_hp: int, current_hp := -1) -> void:
	has_taken_damage = false
	maximum = maxi(1, maximum_hp)
	current = maximum if current_hp < 0 else clampi(current_hp, 0, maximum)
	changed.emit(current, maximum)


func damage(hit: CombatHit) -> bool:
	if hit == null or hit.amount <= 0 or current <= 0:
		return false
	if not hit.claim_target(get_instance_id()):
		return false
	has_taken_damage = true
	current = maxi(0, current - hit.amount)
	changed.emit(current, maximum)
	if current == 0:
		depleted.emit()
	return true


func heal(amount: int) -> bool:
	if amount <= 0 or current <= 0 or current >= maximum:
		return false
	current = mini(maximum, current + amount)
	changed.emit(current, maximum)
	return true


func to_dictionary() -> Dictionary:
	return {"current": current, "maximum": maximum}
