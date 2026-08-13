extends SceneTree
## Proves the PowerShell runner isolates Godot automation from the interactive
## Windows AppData profile while keeping `user://` writable.

const PROBE_PATH := "user://automation_environment_validation.tmp"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var project_root := _normalized(ProjectSettings.globalize_path("res://"))
	var profile_root := _normalized(
		"%s/build/godot_automation_profile" % project_root
	)
	var expected_appdata := _normalized("%s/Roaming" % profile_root)
	var expected_local_appdata := _normalized("%s/Local" % profile_root)
	var actual_appdata := _normalized(OS.get_environment("APPDATA"))
	var actual_local_appdata := _normalized(OS.get_environment("LOCALAPPDATA"))
	var user_data_dir := _normalized(OS.get_user_data_dir())

	if actual_appdata != expected_appdata:
		_fail("APPDATA escaped the automation profile: %s" % actual_appdata)
		return
	if actual_local_appdata != expected_local_appdata:
		_fail(
			"LOCALAPPDATA escaped the automation profile: %s"
			% actual_local_appdata
		)
		return
	if not user_data_dir.begins_with(expected_appdata + "/"):
		_fail("user:// escaped the automation profile: %s" % user_data_dir)
		return
	if OS.has_feature("mono"):
		_fail("Godot automation launched the .NET build instead of Standard.")
		return

	var probe := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	if probe == null:
		_fail("Godot could not write to isolated user:// (error %s)." % FileAccess.get_open_error())
		return
	probe.store_string("godot-automation-profile")
	probe.close()
	if not FileAccess.file_exists(PROBE_PATH):
		_fail("The isolated user:// write probe was not created.")
		return
	var remove_error := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(PROBE_PATH)
	)
	if remove_error != OK:
		_fail("The isolated user:// write probe could not be removed.")
		return

	print("Godot automation profile validation passed.")
	print("  APPDATA: %s" % actual_appdata)
	print("  LOCALAPPDATA: %s" % actual_local_appdata)
	print("  user://: %s" % user_data_dir)
	print("  engine: Godot Standard (non-.NET)")
	quit(0)


func _normalized(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
