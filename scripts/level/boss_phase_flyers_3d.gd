extends Node
## The Green Zone boss's second phase: dormant shootable flying machines arrive
## one after another when the boss first falls to half health, and any still
## flying are destroyed with the boss. A run reset returns them to dormant.

@export var boss_path: NodePath
@export var flyer_paths: Array[NodePath] = []
## Seconds between one machine's arrival and the next.
@export_range(0.0, 3.0, 0.05) var arrival_stagger := 0.5

var _boss: Node
var _flyers: Array[Node] = []
# Bumped by resets and defeat so a pending staggered arrival never resumes.
var _arrival_generation := 0


func _ready() -> void:
	if preload("res://scripts/developer/level_layout_preview.gd").is_preview(self):
		return
	add_to_group("run_resettable")
	_boss = get_node(boss_path)
	for path in flyer_paths:
		_flyers.append(get_node(path))
	_boss.connect("phase_changed", _on_phase_changed)
	_boss.connect("defeated", _on_boss_defeated)


func reset_run() -> void:
	_arrival_generation += 1


func flyers() -> Array[Node]:
	return _flyers


func _on_phase_changed(new_phase: int) -> void:
	if new_phase != 2:
		return
	var generation := _arrival_generation
	for index in _flyers.size():
		if index > 0 and arrival_stagger > 0.0:
			await get_tree().create_timer(arrival_stagger, false, true).timeout
		if generation != _arrival_generation or _boss.is_defeated():
			return
		_flyers[index].activate()


func _on_boss_defeated(_impact_position: Vector3) -> void:
	_arrival_generation += 1
	for flyer in _flyers:
		if flyer.is_active():
			flyer.destroy()
