class_name ProgressionStore
extends Node
## Sole owner of on-disk campaign progress. Gameplay systems request domain
## changes; they never read or write the save file themselves.

signal level_completed(level_id: StringName)
signal ability_unlocked(ability_id: StringName)

const DEFAULT_SAVE_PATH := "user://campaign_progress.json"

@export var save_path := DEFAULT_SAVE_PATH
var progress := GameProgress.new()


func _ready() -> void:
	load_progress()


func mark_level_completed(level_id: StringName) -> void:
	if progress.complete_level(level_id):
		save_progress()
		level_completed.emit(level_id)


func unlock_ability(ability_id: StringName) -> void:
	if progress.unlock_ability(ability_id):
		save_progress()
		ability_unlocked.emit(ability_id)


func has_completed(level_id: StringName) -> bool:
	return progress.has_completed(level_id)


func owns_ability(ability_id: StringName) -> bool:
	return progress.owns_ability(ability_id)


func unlocked_abilities() -> Array[StringName]:
	return progress.unlocked_ability_ids.duplicate()


func load_progress() -> void:
	progress = GameProgress.new()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open campaign progress for reading.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		progress = GameProgress.from_dictionary(parsed)
	else:
		push_warning("Campaign progress is invalid; starting with a clean profile.")


func save_progress() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open campaign progress for writing.")
		return
	file.store_string(JSON.stringify(progress.to_dictionary(), "\t"))
