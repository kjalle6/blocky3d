extends RefCounted
## Verified writes with a cooperative directory lock. A failed replacement
## leaves the old file in place; backups/recovery are deliberately not exports.
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const MAX_BYTES := 4 * 1024 * 1024

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "", "data": {}, "hash": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "Cannot read the saved layout.", "data": {}, "hash": ""}
	if file.get_length() > MAX_BYTES: return {"error": "Layout file is too large.", "data": {}, "hash": ""}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"error": "Layout JSON is damaged or incomplete.", "data": {}, "hash": text.sha256_text()}
	return {"error": "", "data": json.data, "hash": text.sha256_text()}

static func save(document: RefCounted, path_override := "") -> String:
	if not REGISTRY.can_author(): return "Project layout saving is available in the development checkout only."
	var path: String = path_override if not path_override.is_empty() else REGISTRY.save_path(document.section)
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return "Cannot create the layout directory."
	var lock := ProjectSettings.globalize_path(path + ".lock")
	var locked := _acquire_lock(lock)
	if not locked.is_empty(): return locked
	var result := _save_locked(document, path)
	_release_lock(lock)
	return result

static func _save_locked(document: RefCounted, path: String) -> String:
	var current := read(path)
	if not current.error.is_empty(): return current.error
	if current.hash != document.disk_hash: return "Another window changed this layout. Reload saved or keep your draft for review."
	if REGISTRY.fingerprint(document.section) != document.fingerprint:
		return "The base scene changed. Keep your draft for review with Codex."
	var data: Dictionary = document.serialize(document.revision + 1)
	var validation := _validate_fresh(data)
	if not validation.is_empty(): return validation
	var text := JSON.stringify(data, "\t", true, true) + "\n"
	var temporary := path + ".tmp"
	var result := _write(temporary, text)
	if not result.is_empty(): return result
	var verification := read(temporary)
	if not verification.error.is_empty() or verification.hash != text.sha256_text():
		return "The temporary save could not be verified. The previous layout is unchanged."
	validation = _validate_fresh(verification.data)
	if not validation.is_empty(): return validation
	if read(path).hash != current.hash or REGISTRY.fingerprint(document.section) != document.fingerprint:
		return "The saved layout or base changed while saving. Your draft is intact."
	if current.hash != "missing":
		var original := FileAccess.get_file_as_string(path)
		result = _write(path + ".bak", original)
		if not result.is_empty() or read(path + ".bak").hash != current.hash:
			return "Could not verify the backup. The previous layout is unchanged."
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if rename_error != OK: return "Could not replace the layout file. Close any file lock and try Save again."
	var final := read(path)
	if not final.error.is_empty() or final.hash != text.sha256_text():
		return "The final file could not be verified. Keep this draft; a backup is beside the layout."
	document.mark_saved(final.hash, int(data.revision))
	return ""

static func _validate_fresh(data: Dictionary) -> String:
	var section := str(data.get("section", ""))
	if not REGISTRY.SECTIONS.has(section): return "Unknown layout section."
	var packed := ResourceLoader.load(REGISTRY.SECTIONS[section], "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed == null: return "Cannot load the structural scene."
	var base := packed.instantiate()
	var document := DOCUMENT.new()
	var error: String = document.open(base, data)
	base.free()
	return error

static func _write(path: String, text: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return "Cannot write " + path.get_file() + ". Your draft is intact."
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return "" if error == OK else "The disk write failed. Your draft is intact."

static func _acquire_lock(path: String) -> String:
	if DirAccess.dir_exists_absolute(path):
		var owner := read(path.path_join("owner.json"))
		if owner.error.is_empty() and owner.data.has("pid") and not OS.is_process_running(int(owner.data.pid)):
			_release_lock(path)
	if DirAccess.make_dir_absolute(path) != OK: return "Another window is saving this section. Try again shortly."
	var error := _write(path.path_join("owner.json"), JSON.stringify({"pid": OS.get_process_id()}))
	if not error.is_empty(): _release_lock(path)
	return error

static func _release_lock(path: String) -> void:
	DirAccess.remove_absolute(path.path_join("owner.json"))
	DirAccess.remove_absolute(path)

static func recovery_path(section: String) -> String:
	return "user://level_designer/%s.recovery.json" % section

static func recover(document: RefCounted) -> Dictionary:
	var stored := read(recovery_path(document.section))
	if not stored.error.is_empty() or stored.data.is_empty(): return {}
	if stored.data.get("disk_hash", "") != document.disk_hash: return {}
	var resolved: Dictionary = document.resolve(stored.data.get("layout", {}))
	return resolved.records if resolved.error.is_empty() else {}

static func keep_recovery(document: RefCounted) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://level_designer"))
	var path := recovery_path(document.section)
	var text := JSON.stringify({"disk_hash": document.disk_hash, "layout": document.serialize()}, "\t", true, true) + "\n"
	return _replace_draft(path, text)

static func _replace_draft(path: String, text: String) -> String:
	var result := _write(path + ".tmp", text)
	if not result.is_empty(): return result
	if read(path + ".tmp").hash != text.sha256_text(): return "Could not verify the local draft."
	return "" if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK else "Could not replace the local draft."

static func clear_recovery(section: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_path(section)))

static func keep_review(document: RefCounted) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://level_designer"))
	var path := "user://level_designer/%s.%d.review.json" % [document.section, OS.get_process_id()]
	return _replace_draft(path, JSON.stringify({"disk_hash": document.disk_hash, "layout": document.serialize()}, "\t", true, true) + "\n")
