extends SceneTree
const OBJECTS = preload("res://scripts/developer/level_layout_objects.gd")
const REGISTRY = preload("res://scripts/developer/level_layout_registry.gd")
const DOCUMENT = preload("res://scripts/developer/level_layout_document.gd")
const RESOLVER = preload("res://scripts/developer/level_layout_resolver.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void: quit(1))
	var checked := 0
	for section in OBJECTS.authored_scenery:
		var packed: PackedScene = load(REGISTRY.SECTIONS[section])
		var base: Node = packed.instantiate()
		var snapshots := {}
		for path in OBJECTS.authored_scenery[section]:
			var sprite := base.get_node(path) as Sprite3D
			assert(sprite != null)
			snapshots[path] = [sprite.transform,sprite.render_priority,sprite.texture,sprite.pixel_size,sprite.flip_h]
		var document := DOCUMENT.new()
		assert(document.open(base,{}).is_empty())
		assert(RESOLVER.apply_layout(base,document.serialize()).is_empty())
		for path in snapshots:
			var sprite := base.get_node(path) as Sprite3D
			assert([sprite.transform,sprite.render_priority,sprite.texture,sprite.pixel_size,sprite.flip_h] == snapshots[path], "Scenery changed on registration: " + path)
			var id: String = OBJECTS.authored_scenery[section][path].id
			var record: Dictionary = document.working[id]
			assert(record.removable and record.kind == "decoration")
			assert(OBJECTS.bounds(record).has_area())
			var duplicate := OBJECTS.instantiate_record(record) as Sprite3D
			assert(duplicate != null and duplicate.basis.is_equal_approx(sprite.basis))
			assert(duplicate.texture.get_size() == sprite.texture.get_size())
			assert(duplicate.modulate == sprite.modulate and duplicate.render_priority == sprite.render_priority)
			assert(duplicate.pixel_size == sprite.pixel_size)
			var values: Dictionary = record.values.duplicate(true)
			values.flip_h = not values.flip_h
			OBJECTS.apply(duplicate,"decoration",values)
			assert(duplicate.flip_h == values.flip_h)
			duplicate.free()
			checked += 1
		# Removal and a moved/flipped duplicate must survive a saved-layout round trip.
		if not snapshots.is_empty():
			var path: String = snapshots.keys()[0]
			var id: String = OBJECTS.authored_scenery[section][path].id
			var record: Dictionary = document.working[id].duplicate(true)
			document.working.erase(id)
			record.values.x += record.offset.x + 1.28
			record.values.y += record.offset.y
			record.values.flip_h = not record.values.flip_h
			document.working["object_scenery_copy"] = OBJECTS.new_record(record.template,record.values)
			var fresh := packed.instantiate()
			var error: String = RESOLVER.apply_layout(fresh,document.serialize())
			assert(error.is_empty(), error)
			assert(fresh.get_node_or_null(path) == null)
			var result: Dictionary = OBJECTS.inspect(fresh)
			assert(result.error.is_empty() and result.nodes.has("object_scenery_copy"))
			assert(result.nodes.object_scenery_copy is Sprite3D)
			fresh.free()
		base.free()
	print("Authored scenery passed: %d editable originals retain presentation; duplicates, flips, removal and layout reload work." % checked)
	quit()
