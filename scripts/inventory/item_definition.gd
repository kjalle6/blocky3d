class_name ItemDefinition
extends Resource

@export var item_id: StringName
@export var display_name := ""
@export var icon: Texture2D
@export_range(0, 1000, 1) var healing := 25
@export_range(0.05, 1.0, 0.01) var use_duration := 0.22
@export var development_only := false
@export var quick_usable := true
