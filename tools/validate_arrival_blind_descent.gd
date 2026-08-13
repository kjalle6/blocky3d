extends SceneTree
## Focused contract for Level 1's cruel reminder. The landing spikes always
## exist, sit below the peak camera composition, and punish a vertical drop.
## The full Arrival playthrough separately proves the forward Double Jump clear.

const OUTPUT_SIZE := Vector2i(1920, 1080)
const FORWARD_DROP_POSITION := Vector3(164.0, 8.23, 0.0)
const MAXIMUM_DROP_FRAMES := 180


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = OUTPUT_SIZE
	root.size = OUTPUT_SIZE
	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	if packed_scene == null:
		_fail("The application root could not be loaded.")
		return
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	var definition := load(
		"res://resources/campaign/level_01.tres"
	) as LevelDefinition
	game_root.load_level(definition.level_id)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	if level == null:
		_fail("Arrival / Shoreline did not instantiate.")
		return
	level.unlock_ability(PlayerAbility.DOUBLE_JUMP)
	var player := level.player
	var camera := level.camera as PixelSideCamera3D
	var spikes := level.get_node(
		"Hazards/BlindLandingSpikes"
	) as PixelSpikeRow3D
	if spikes == null:
		_fail("The blind-descent spike row is missing.")
		return
	_release_inputs()
	player.reset_at(Transform3D(Basis.IDENTITY, FORWARD_DROP_POSITION))
	camera.snap_to_target()
	for frame in 3:
		await process_frame

	if camera.active_vertical_region() == null:
		_fail("The peak did not activate its authored vertical camera region.")
		return
	var spike_tip_world := Vector3(
		spikes.global_position.x,
		spikes.global_position.y + spikes.spike_height,
		1.18
	)
	var launch_screen_position := camera.unproject_position(spike_tip_world)
	if launch_screen_position.y <= OUTPUT_SIZE.y:
		_fail(
			"The blind-descent spikes are visible from the peak launch composition."
		)
		return

	var death_count := [0]
	player.died.connect(func() -> void: death_count[0] += 1)
	var first_visible_frame := -1
	for frame in MAXIMUM_DROP_FRAMES:
		await physics_frame
		if first_visible_frame < 0:
			var screen_position := camera.unproject_position(spike_tip_world)
			if screen_position.y <= OUTPUT_SIZE.y:
				first_visible_frame = frame
		if death_count[0] > 0:
			break

	if death_count[0] != 1:
		_fail("An ordinary forward drop from the peak did not hit the concealed spikes.")
		return
	if first_visible_frame < 0:
		_fail("The spike row never entered frame during the descent.")
		return
	print(
		"Arrival blind descent passed: spike reveal frame %d, vertical drop punished."
		% first_visible_frame
	)
	_release_inputs()
	quit(0)


func _fail(message: String) -> void:
	_release_inputs()
	push_error(message)
	quit(1)


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("attack")
