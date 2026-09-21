class_name ProgressionStore
extends Node
## Sole disk owner. Manual slots, rotating autosaves and permanent progress are
## separate; loading a snapshot never rewrites that snapshot.
signal level_completed(level_id: StringName)
signal ability_unlocked(ability_id: StringName)
signal save_written(kind: String, slot: int)
signal save_failed(message: String)

const DEFAULT_SAVE_PATH := "user://campaign_progress.json"
const SLOT_COUNT := 3
@export var save_path := DEFAULT_SAVE_PATH
var progress := GameProgress.new()
var last_error := ""
var _progress_writable := true
var _last_timestamp := 0.0


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


func unlock_weapon(weapon_id: StringName) -> void:
	if PlayerWeapon.is_known(weapon_id) and weapon_id not in progress.owned_weapon_ids:
		progress.owned_weapon_ids.append(weapon_id)
		save_progress()


func has_completed(level_id: StringName) -> bool:
	return progress.has_completed(level_id)


func owns_ability(ability_id: StringName) -> bool:
	return progress.owns_ability(ability_id)


func unlocked_abilities() -> Array[StringName]:
	return progress.unlocked_ability_ids.duplicate()


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return null
	var parser := JSON.new()
	return parser.data if parser.parse(file.get_as_text()) == OK else null


func load_progress() -> void:
	progress = GameProgress.new()
	last_error = ""
	_progress_writable = true
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak"):
		return
	var parsed: Variant = _read(save_path)
	if not SaveSnapshot.progress_error(parsed).is_empty():
		_progress_writable = not FileAccess.file_exists(save_path)
		parsed = _read(save_path + ".bak")
		if not SaveSnapshot.progress_error(parsed).is_empty():
			_progress_writable = false
			last_error = "Campaign progress could not be read. The original files have been preserved."
			return
		last_error = "Recovered campaign progress from its backup."
	progress = GameProgress.from_dictionary(parsed)
	if int(parsed.version) == 1 and FileAccess.file_exists(save_path):
		var legacy_path := save_path + ".v1.bak"
		if not FileAccess.file_exists(legacy_path):
			if DirAccess.copy_absolute(save_path, legacy_path) != OK:
				_progress_writable = false
				last_error = "Could not preserve the legacy progress backup."


func save_progress() -> bool:
	if not _progress_writable:
		return _fail("Existing campaign progress is unreadable; it has not been overwritten.")
	return _atomic_write(save_path, progress.to_dictionary(), false)


func start_new_campaign() -> bool:
	# Explicit New Game permits a fresh active profile, preserving the old file
	# and every manual slot. No implicit fresh profile on a failed read.
	if FileAccess.file_exists(save_path):
		var archive := save_path + ".before_new_" + str(Time.get_ticks_usec())
		if DirAccess.copy_absolute(save_path, archive) != OK:
			return _fail("Could not preserve the previous campaign profile.")
	var previous := progress
	var previous_writable := _progress_writable
	progress = GameProgress.new()
	progress.loot_seed = randi_range(1, 2147483647)
	_progress_writable = true
	if save_progress():
		return true
	progress = previous
	_progress_writable = previous_writable
	return false


func slots_directory() -> String:
	return save_path.get_basename() + "_saves"


func slot_path(kind: String, slot: int) -> String:
	if kind not in ["manual", "auto"] or slot < 1 or slot > SLOT_COUNT:
		return ""
	return slots_directory().path_join("%s_%d.json" % [kind, slot])


func read_slot(kind: String, slot: int) -> Dictionary:
	var path := slot_path(kind, slot)
	if path.is_empty():
		return {"error": "Unknown save slot."}
	var exists := FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	for candidate in [path, path + ".bak"]:
		var data: Variant = _read(candidate)
		if SaveSnapshot.validation_error(data).is_empty() and data.kind == kind and int(data.slot) == slot:
			return {"data": data, "recovered": candidate != path, "error": ""}
	return {"error": "Save is damaged or uses an unsupported version." if exists else "", "empty": not exists}


func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind in ["manual", "auto"]:
		for slot in range(1, SLOT_COUNT + 1):
			var entry := read_slot(kind, slot)
			entry["kind"] = kind
			entry["slot"] = slot
			result.append(entry)
	return result


func newest_save() -> Dictionary:
	var newest := {}
	for entry in list_slots():
		if entry.has("data") and (newest.is_empty() or float(entry.data.saved_at) > float(newest.saved_at)):
			newest = entry.data
	return newest.duplicate(true)


func write_snapshot(snapshot: Dictionary, kind: String, slot := 0) -> bool:
	if kind == "auto":
		slot = 1
		var oldest_time := INF
		for candidate in range(1, SLOT_COUNT + 1):
			var entry := read_slot("auto", candidate)
			if not entry.has("data"):
				slot = candidate
				break
			if float(entry.data.saved_at) < oldest_time:
				oldest_time = float(entry.data.saved_at)
				slot = candidate
	var path := slot_path(kind, slot)
	if path.is_empty():
		return _fail("Unknown save slot.")
	var data: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	data["version"] = SaveSnapshot.VERSION
	data["kind"] = kind
	data["slot"] = slot
	var newest := newest_save()
	_last_timestamp = maxf(_last_timestamp, float(newest.get("saved_at", 0.0)))
	data["saved_at"] = maxf(Time.get_unix_time_from_system(), _last_timestamp + 0.001)
	var error := SaveSnapshot.validation_error(data)
	if not error.is_empty():
		return _fail(error)
	if not _atomic_write(path, data, true):
		return false
	_last_timestamp = float(data.saved_at)
	save_written.emit(kind, slot)
	return true


func restore_progress(snapshot: Dictionary, keep_newer_unlocks: bool) -> bool:
	var error := SaveSnapshot.validation_error(snapshot)
	if not error.is_empty():
		return _fail(error)
	var restored := GameProgress.from_dictionary(snapshot.progress)
	if keep_newer_unlocks:
		for id in progress.unlocked_ability_ids:
			restored.unlock_ability(id)
		for id in progress.completed_level_ids:
			restored.complete_level(id)
		for id in progress.owned_weapon_ids:
			if id not in restored.owned_weapon_ids:
				restored.owned_weapon_ids.append(id)
		for id in progress.completed_boss_ids:
			if id not in restored.completed_boss_ids:
				restored.completed_boss_ids.append(id)
		restored.maximum_hp = maxi(restored.maximum_hp, progress.maximum_hp)
	var previous := progress
	var previous_writable := _progress_writable
	progress = restored
	# An explicitly loaded valid snapshot can repair an unreadable active profile.
	# Atomic replacement preserves that unreadable file separately.
	_progress_writable = true
	if not save_progress():
		progress = previous
		_progress_writable = previous_writable
		return false
	return true


func _atomic_write(path: String, data: Dictionary, snapshot: bool) -> bool:
	last_error = ""
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return _fail("Could not create the save directory.")
	var pending := path + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return _fail("Could not open the temporary save.")
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	var check: Variant = _read(pending)
	var validation := SaveSnapshot.validation_error(check) if snapshot else SaveSnapshot.progress_error(check)
	if write_error != OK or not validation.is_empty() or check != JSON.parse_string(JSON.stringify(data)):
		return _fail("The new save could not be verified (%s; write %d; content match %s). The previous save is still available." % [validation, write_error, check == JSON.parse_string(JSON.stringify(data))])
	if FileAccess.file_exists(path):
		var previous: Variant = _read(path)
		var previous_error := SaveSnapshot.validation_error(previous) if snapshot else SaveSnapshot.progress_error(previous)
		var backup := path + ".bak" if previous_error.is_empty() else path + ".unreadable_" + str(Time.get_ticks_usec())
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return _fail("Could not rotate the save backup.")
		if DirAccess.rename_absolute(path, backup) != OK:
			return _fail("Could not preserve the previous save.")
	if DirAccess.rename_absolute(pending, path) != OK:
		return _fail("Could not finish saving. The previous save remains in its backup.")
	return true


func _fail(message: String) -> bool:
	last_error = message
	save_failed.emit(message)
	return false
