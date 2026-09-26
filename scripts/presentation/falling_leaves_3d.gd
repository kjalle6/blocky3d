extends Node
## Placed leaf props are spawn points; only their visuals move during play.
const PREFIX := "gz_prop_leaf_"
const MAX_FALL := 2.56
const GROUND_CLEARANCE := 0.04
const MIN_FALL := 0.16
var _leaves: Array[Dictionary] = []
var _time := 0.0
var _prepared := false

func _ready() -> void:
	var session := get_parent() as LevelSession3D
	if session.get_meta("layout_preview", false):
		set_physics_process(false)
		return
	for node in session.find_children("*", "Node3D", true, false):
		if not str(node.get_meta("layout_template", "")).begins_with(PREFIX): continue
		var visual := node.get_node("Visual") as Sprite3D
		var random := RandomNumberGenerator.new()
		random.seed = str(node.get_meta("layout_id", node.get_path())).hash()
		_leaves.append({"source": node, "visual": visual, "origin": visual.position,
			"color": visual.modulate, "speed": random.randf_range(0.20, 0.29),
			"sway": random.randf_range(0.10, 0.22), "phase": random.randf_range(0.0, TAU),
			"offset": random.randf(), "rest": random.randf_range(0.4, 0.9)})
	session.run_reset.connect(reset_run)
	set_physics_process(not _leaves.is_empty())

func _physics_process(delta: float) -> void:
	if not _prepared: _prepare_falls()
	_time += delta
	for leaf in _leaves:
		if not is_instance_valid(leaf.visual) or leaf.distance < MIN_FALL: continue
		var visual: Sprite3D = leaf.visual
		var duration: float = leaf.distance / leaf.speed
		var cycle: float = duration + leaf.rest
		var elapsed := fposmod(_time + leaf.offset * cycle, cycle)
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var sway: float = leaf.sway * sin(progress * TAU + leaf.phase) * sin(progress * PI)
		var origin: Vector3 = leaf.origin
		# Whole artwork pixels keep tiny leaves crisp; depth and facing stay authored.
		visual.position.x = origin.x + snappedf(sway * (-1.0 if visual.flip_h else 1.0), visual.pixel_size)
		visual.position.y = origin.y - snappedf(leaf.distance * progress, visual.pixel_size)
		visual.modulate.a = leaf.color.a * smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.78, 1.0, progress))

func _prepare_falls() -> void:
	_prepared = true
	# Ignore actors: walking underneath a leaf must not change its landing height.
	var ignored: Array[RID] = []
	for body in get_parent().find_children("*", "CollisionObject3D", true, false):
		if not body is StaticBody3D and not body is AnimatableBody3D: ignored.append(body.get_rid())
	for leaf in _leaves:
		var source: Node3D = leaf.source
		var anchor := source.global_position
		var query := PhysicsRayQueryParameters3D.create(anchor + Vector3.UP * GROUND_CLEARANCE,
			anchor + Vector3.DOWN * MAX_FALL, 1, ignored)
		var hit := source.get_world_3d().direct_space_state.intersect_ray(query)
		leaf.distance = MAX_FALL if hit.is_empty() else clampf(anchor.y - hit.position.y - GROUND_CLEARANCE, 0.0, MAX_FALL)

func reset_run() -> void:
	_time = 0.0
