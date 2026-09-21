class_name CombatProfile
extends Resource
## Immutable authored values; each actor owns its HealthState separately.

@export_range(1, 10000, 1) var maximum_hp := 50
@export_range(0, 1000, 1) var attack_damage := 25
@export_range(0.0, 1.0, 0.01) var hurt_duration := 0.18
@export var provisional := false
