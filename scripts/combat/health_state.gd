class_name HealthState
extends RefCounted
## Mutable, actor-owned health. Authored resources never hold current HP.

signal changed(current: int, maximum: int)
signal depleted

var maximum := 100
var current := 100
var has_taken_damage := false
# Keep sub-point damage so integer HP does not round every armored hit.
var _damage_remainder := 0.0


func reset(maximum_hp: int, current_hp := -1) -> void:
	has_taken_damage = false
	_damage_remainder = 0.0
	maximum = maxi(1, maximum_hp)
	current = maximum if current_hp < 0 else clampi(current_hp, 0, maximum)
	changed.emit(current, maximum)


func damage(hit: CombatHit, defense: CombatProfile = null) -> bool:
	if hit == null or hit.amount <= 0 or current <= 0:
		return false
	var multiplier := defense.knife_damage_multiplier if defense != null and hit.kind == &"knife" else 1.0
	if multiplier <= 0.0 or not hit.claim_target(get_instance_id()):
		return false
	has_taken_damage = true
	# Scale per recipient without mutating the shared hit or its target ledger.
	var accumulated := float(hit.amount) * multiplier + _damage_remainder
	var whole_damage := floori(accumulated)
	_damage_remainder = accumulated - whole_damage
	current = maxi(0, current - whole_damage)
	if current == 0:
		_damage_remainder = 0.0
	changed.emit(current, maximum)
	if current == 0:
		depleted.emit()
	return true


func heal(amount: int) -> bool:
	if amount <= 0 or current <= 0 or current >= maximum:
		return false
	current = mini(maximum, current + amount)
	if current == maximum:
		_damage_remainder = 0.0
	changed.emit(current, maximum)
	return true


func to_dictionary() -> Dictionary:
	return {"current": current, "maximum": maximum}
