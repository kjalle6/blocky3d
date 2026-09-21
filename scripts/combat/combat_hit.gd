class_name CombatHit
extends RefCounted
## One attack's damage and target ledger. Paired projectiles may share a hit;
## separate attacks never share protection or an invulnerability timer.

var amount: int
var kind: StringName
var source_position: Vector3
var _targets: Dictionary = {}


func _init(damage := 0, attack_kind: StringName = &"unknown", origin := Vector3.ZERO) -> void:
	amount = damage
	kind = attack_kind
	source_position = origin


func claim_target(target_id: int) -> bool:
	if _targets.has(target_id):
		return false
	_targets[target_id] = true
	return true
