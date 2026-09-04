class_name FirearmReviewLab3D
extends Node
## Keeps comparison controls local to the lab. Production weapon-slot inputs
## remain free for the later knife/gun implementation.

@export var shooter_path: NodePath
@export var mode_label_path: NodePath

@onready var shooter := get_node(shooter_path) as HandgunEnemy3D
@onready var mode_label := get_node(mode_label_path) as Label


func _ready() -> void:
	assert(shooter != null, "FirearmReviewLab3D requires its shooter.")
	assert(mode_label != null, "FirearmReviewLab3D requires its mode label.")
	_update_mode_label()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_T:
		toggle_fire_pattern()
		get_viewport().set_input_as_handled()


func toggle_fire_pattern() -> void:
	var next_pattern := (
		HandgunEnemy3D.FirePattern.TRIPLE
		if shooter.current_fire_pattern() == HandgunEnemy3D.FirePattern.TWIN
		else HandgunEnemy3D.FirePattern.TWIN
	)
	shooter.set_fire_pattern(next_pattern)
	_update_mode_label()


func _update_mode_label() -> void:
	mode_label.text = (
		"FIREARM REVIEW LAB\n"
		+ "T: SWITCH PATTERN     R: RESET\n"
		+ "MODE: %s\n" % shooter.pattern_display_name()
		+ "%s\n" % shooter.pattern_description()
		+ "Dodge the rounds or use the rock as real cover."
	)
