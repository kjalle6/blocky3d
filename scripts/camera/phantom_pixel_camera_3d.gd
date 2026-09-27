extends PixelSideCamera3D
## Phantom owns the authored path and damping. This adapter retains our pixel
## grid, inspection controls, and the camera API used by saves and cutscenes.

@export var phantom_camera: PhantomCamera3D
@export_category("Branch rail")
## Optional overlapping route (upper cave / underground detour). Both rails use
## the same Phantom instance so changing branches retains its damping velocity.
@export var branch_rail: Path3D
@export var branch_follow_offset := Vector3(2.6, 2, 24)
## XY bounds relative to CameraDirection, not to the moving camera.
@export var branch_regions: Array[Rect2] = []
@export_range(0.0, 2.0, 0.05) var branch_exit_margin := 0.75
## Broad drops need free follow: a folded curve can choose a distant segment.
## This marker supplies a bounded composition; Phantom still owns all damping.
@export var branch_free_target: Marker3D
@export var branch_free_region := Rect2()
@export var branch_free_bounds := Rect2()
@export_category("Upper exploration")
## Optional climb above the rail. Phantom keeps its damping state when changing
## follow mode, so there is no separate timed camera transition to restart.
@export var upper_follow_enabled := false
@export var upper_follow_start_y := 11.0
@export var upper_follow_return_y := 9.0
@export var upper_follow_entry_x := Vector2(61.44, 80.64)
## Return to the rail after leaving the shaft along the raised right-hand ground.
@export var upper_route_return_y := 14.0
@export var upper_follow_offset := Vector3(4, -3, 24)
@onready var phantom_host: PhantomCameraHost = $PhantomCameraHost
@onready var _route_offset := phantom_camera.follow_offset
@onready var _route_damping := phantom_camera.follow_damping_value
@onready var _route_rail := phantom_camera.follow_path
var _branch_active := false
var _upper_follow_active := false
var _framing_mode: StringName = &"route"


func _ready() -> void:
	super._ready()
	assert(phantom_camera != null, "Assign an authored Phantom camera.")
	# Render-camera output must be ready before the background's -90 update.
	# Manual mode also prevents the host from fighting cutscenes or inspection.
	phantom_host.interpolation_mode = PhantomCameraHost.InterpolationMode.MANUAL


func _process(delta: float) -> void:
	if target == null:
		return
	if _developer_inspection_enabled:
		super._process(delta)
		return
	_sync_phantom_follow()
	if not _initialized:
		snap_to_target()
	elif phantom_host.get_active_pcam() != null:
		phantom_host.process(delta)
		_snap_render_output()


func snap_to_target() -> void:
	if target == null or phantom_camera == null:
		return
	if _developer_inspection_enabled:
		super.snap_to_target()
		return
	_upper_follow_active = false
	_sync_phantom_follow(true)
	phantom_camera.teleport_position()
	# The host initializes one frame late. Spawn/save framing cannot wait for it.
	global_transform = phantom_camera.get_transform_output()
	_snap_render_output()
	_initialized = true


func gameplay_look_ahead() -> float:
	# The authored Phantom offset owns gameplay composition, not the inherited
	# look_ahead property that cutscenes animate while using Simple follow.
	if _framing_mode == &"route":
		return phantom_camera.follow_offset.x
	if _upper_follow_active:
		return upper_follow_offset.x
	return branch_follow_offset.x if _branch_active else _route_offset.x


func _sync_phantom_follow(reset_branch := false) -> void:
	# Remember editor/live tuning only while normal route framing owns it.
	if _framing_mode == &"route" and not _branch_active:
		_route_offset = phantom_camera.follow_offset
		_route_damping = phantom_camera.follow_damping_value
	var point := target.global_position
	var free_branch := false
	if branch_rail != null:
		var local_point := branch_rail.get_parent_node_3d().to_local(point)
		var was_active := _branch_active and not reset_branch
		_branch_active = false
		for region in branch_regions:
			var bounds := region.grow(branch_exit_margin) if was_active else region
			_branch_active = _branch_active or bounds.has_point(Vector2(local_point.x, local_point.y))
		phantom_camera.follow_path = branch_rail if _branch_active else _route_rail
		if _branch_active and branch_free_target != null and branch_free_region.has_point(Vector2(local_point.x, local_point.y)):
			var composition := local_point + branch_follow_offset
			composition.x = clampf(composition.x, branch_free_bounds.position.x, branch_free_bounds.end.x)
			composition.y = clampf(composition.y, branch_free_bounds.position.y, branch_free_bounds.end.y)
			branch_free_target.position = composition
			free_branch = true
	if not upper_follow_enabled or point.y <= upper_follow_return_y:
		_upper_follow_active = false
	elif point.x > upper_follow_entry_x.y and point.y <= upper_route_return_y:
		_upper_follow_active = false
	elif point.y >= upper_follow_start_y and point.x >= upper_follow_entry_x.x and point.x <= upper_follow_entry_x.y:
		_upper_follow_active = true
	var next_mode: StringName = &"cinematic" if cinematic_override_enabled else &"upper" if _upper_follow_active else &"free_branch" if free_branch else &"route"
	if next_mode != _framing_mode:
		phantom_camera.follow_mode = PhantomCamera3D.FollowMode.PATH if next_mode == &"route" else PhantomCamera3D.FollowMode.SIMPLE
		phantom_camera.follow_offset = upper_follow_offset if next_mode == &"upper" else _route_offset
		phantom_camera.follow_damping_value = _route_damping
		_framing_mode = next_mode
	if next_mode == &"route":
		phantom_camera.follow_offset = branch_follow_offset if _branch_active else _route_offset
	elif next_mode == &"free_branch":
		phantom_camera.follow_offset = Vector3.ZERO
	if cinematic_override_enabled:
		phantom_camera.follow_offset = Vector3(look_ahead, camera_height - target.global_position.y, side_distance)
		phantom_camera.follow_damping_value = Vector3.ONE * (2.0 / maxf(follow_response, 0.1))
	phantom_camera.follow_target = branch_free_target if next_mode == &"free_branch" else target


func _snap_render_output() -> void:
	global_position.x = snap_world_x(global_position.x)
	global_position.y = camera_height + snap_world_y(global_position.y - camera_height)
