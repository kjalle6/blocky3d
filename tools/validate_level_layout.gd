extends SceneTree
const DOCUMENT := preload("res://scripts/developer/level_layout_document.gd")
const RESOLVER := preload("res://scripts/developer/level_layout_resolver.gd")
const STORE := preload("res://scripts/developer/level_layout_store.gd")
const OBJECTS := preload("res://scripts/developer/level_layout_objects.gd")
const FIXTURE := "res://scenes/dev/level_designer_fixture.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(25.0).timeout.connect(func() -> void: quit(1))
	var packed := load(FIXTURE) as PackedScene
	var base := packed.instantiate()
	var document := DOCUMENT.new()
	assert(document.open(base, {}).is_empty())
	base.free()
	document.working.fixture_platform.values.x += 6.4
	document.working.fixture_platform.values.width = 7.68
	document.working.fixture_skater.values.x += 5.12
	document.working.fixture_skater.values.left = 1.28
	document.working.fixture_checkpoint.values.x += 2.56
	document.working.fixture_checkpoint.values.width = 3.2
	var layout := document.serialize()
	var level := packed.instantiate() as LevelSession3D
	level.name = "RenamedRoot"
	var application_error := RESOLVER.apply_layout(level, layout)
	assert(application_error.is_empty(), application_error)
	root.add_child(level)
	await physics_frame
	assert(is_equal_approx(level.get_node("Platforms/Platform/Collision").shape.size.x, 7.68), str(level.get_node("Platforms/Platform/Collision").shape.size))
	var enemy := level.get_node("Skater") as StompableEnemy3D
	assert(is_equal_approx(enemy.authored_patrol_bounds_x().x, 37.12))
	enemy.position.x += 1.0
	enemy.reset_run()
	assert(is_equal_approx(enemy.position.x, 38.4))
	var checkpoint := level.get_node("Checkpoints/Checkpoint") as LevelCheckpoint3D
	assert(is_equal_approx(checkpoint.respawn_transform().origin.x, 30.72))
	var other := packed.instantiate()
	assert(is_equal_approx(other.get_node("Checkpoints/Checkpoint/Trigger").shape.size.x, 2.4))
	other.free()
	var platform := level.get_node("Platforms/Platform") as PixelPlatform3D
	var authored := Marker3D.new()
	authored.name = "AuthoredChild"
	platform.add_child(authored)
	var child_count := platform.get_child_count()
	platform.rebuild_geometry()
	platform.rebuild_geometry()
	assert(platform.get_child_count() == child_count and is_instance_valid(authored))
	var invalid := layout.duplicate(true)
	invalid.overrides.fixture_platform.values.width = -1.0
	var rejected := packed.instantiate()
	assert(not RESOLVER.apply_layout(rejected, invalid).is_empty())
	assert(is_equal_approx(rejected.get_node("Platforms/Platform").position.x, 20.48))
	rejected.free()
	# Removed base nodes must not remain in the later decoration-ordering pass.
	var removal := layout.duplicate(true)
	removal.overrides.erase("fixture_platform")
	removal.removed = ["fixture_platform"]
	removal.created["object_bush"] = {"template": "bush", "values": OBJECTS.CATALOG.defaults("bush")}
	removal.catalog = OBJECTS.CATALOG.signatures(["bush"])
	var reduced := packed.instantiate()
	var removal_error := RESOLVER.apply_layout(reduced, removal)
	assert(removal_error.is_empty(), removal_error)
	assert(reduced.get_node_or_null("Platforms/Platform") == null)
	assert(OBJECTS.inspect(reduced).nodes.object_bush.get_node("Visual").texture != null)
	reduced.free()
	# Real Windows replacement, stale saves, backup, and a fresh disk document.
	var path := "user://layout_test_%d.json" % Time.get_ticks_usec()
	var save_error := STORE.save(document, path)
	assert(save_error.is_empty(), save_error)
	var first_hash := document.disk_hash
	document.working.fixture_platform.values.y += 1.28
	save_error = STORE.save(document, path)
	assert(save_error.is_empty(), save_error)
	assert(STORE.read(path + ".bak").hash == first_hash)
	var fresh := DOCUMENT.new()
	var clean := packed.instantiate()
	var on_disk := STORE.read(path)
	assert(fresh.open(clean, on_disk.data, on_disk.hash).is_empty())
	assert(fresh.working == document.working)
	clean.free()
	document.disk_hash = first_hash
	assert(not STORE.save(document, path).is_empty())
	assert(STORE.read(path).hash == on_disk.hash)
	STORE._write(path + ".lock", "blocked")
	assert(not STORE.save(fresh, path).is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock"))
	var lock := ProjectSettings.globalize_path(path + ".lock")
	assert(STORE._acquire_lock(lock).is_empty())
	assert(not STORE.save(fresh, path).is_empty(), "A live owner must retain its exclusive save lock.")
	STORE._release_lock(lock)
	# A failed temporary write must leave both the saved file and its backup intact.
	var backup_hash: String = STORE.read(path + ".bak").hash
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	assert(not STORE.save(fresh, path).is_empty())
	assert(STORE.read(path).hash == on_disk.hash)
	assert(STORE.read(path + ".bak").hash == backup_hash)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	assert(STORE.keep_recovery(fresh).is_empty())
	assert(STORE.recover(fresh) == fresh.working)
	fresh.fingerprint = "stale"
	assert(not STORE.save(fresh, path).is_empty())
	assert(STORE.recover(fresh).is_empty(), "A recovery draft must match the source scene.")
	STORE.clear_recovery(fresh.section)
	var duplicate_ids := packed.instantiate()
	duplicate_ids.get_node("Skater").set_meta("layout_id", "fixture_platform")
	assert(not OBJECTS.inspect(duplicate_ids).error.is_empty())
	duplicate_ids.free()
	invalid = layout.duplicate(true)
	invalid.section = "sandbox"
	assert(not document.resolve(invalid).error.is_empty())
	invalid = layout.duplicate(true)
	invalid.overrides.fixture_platform.values.script = "arbitrary.gd"
	assert(not document.resolve(invalid).error.is_empty())
	invalid = layout.duplicate(true)
	invalid.removed = ["fixture_checkpoint"]
	assert(not document.resolve(invalid).error.is_empty())
	for suffix in ["", ".bak", ".tmp", ".lock"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	level.free()
	print("Level layouts passed: early application, resets, isolated geometry, rejected edits, verified replacement and stale saves.")
	quit(0)
