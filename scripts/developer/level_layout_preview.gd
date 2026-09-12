extends RefCounted
## Frozen presentation for the registered campaign sections and developer labs.

static func is_preview(node: Node) -> bool:
	while node != null:
		if node.get_meta("layout_preview", false): return true
		node = node.get_parent()
	return false

static func prepare(level: Node) -> void:
	level.set_meta("layout_preview", true)
	_suppress(level)
	for node in level.find_children("*", "", true, false):
		_suppress(node)
		if node is WorldEnvironment and node.environment != null:
			node.environment = node.environment.duplicate()

static func finish(level: Node) -> void:
	# Builders can create voices, labels and collision nodes during ready.
	_suppress(level)
	for node in level.find_children("*", "", true, false): _suppress(node)

static func _suppress(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Area3D:
		node.monitoring = false
		node.monitorable = false
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.autoplay = false
		if node.is_inside_tree(): node.stop()
	if node is CanvasLayer: node.visible = false
	if node is AnimationPlayer:
		node.autoplay = ""
		if node.is_inside_tree(): node.stop()
