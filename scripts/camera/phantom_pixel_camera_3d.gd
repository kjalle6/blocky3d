extends PixelSideCamera3D
## Phantom owns the authored path and damping. This adapter retains our pixel
## grid, inspection controls, and the camera API used by saves and cutscenes.

@export var phantom_camera: PhantomCamera3D
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
	_sync_phantom_follow()
	phantom_camera.teleport_position()
	# The host initializes one frame late. Spawn/save framing cannot wait for it.
	global_transform = phantom_camera.get_transform_output()
	_snap_render_output()
	_initialized = true


func _sync_phantom_follow() -> void:
	# Remember editor/live tuning only while normal route framing owns it.
	if _framing_mode == &"route":
		_route_offset = phantom_camera.follow_offset
		_route_damping = phantom_camera.follow_damping_value
	var point := target.global_position
	if not upper_follow_enabled or point.y <= upper_follow_return_y:
		_upper_follow_active = false
	elif point.x > upper_follow_entry_x.y and point.y <= upper_route_return_y:
		_upper_follow_active = false
	elif point.y >= upper_follow_start_y and point.x >= upper_follow_entry_x.x and point.x <= upper_follow_entry_x.y:
		_upper_follow_active = true
	var next_mode: StringName = &"cinematic" if cinematic_override_enabled else &"upper" if _upper_follow_active else &"route"
	if next_mode != _framing_mode:
		phantom_camera.follow_mode = PhantomCamera3D.FollowMode.PATH if next_mode == &"route" else PhantomCamera3D.FollowMode.SIMPLE
		phantom_camera.follow_offset = upper_follow_offset if next_mode == &"upper" else _route_offset
		phantom_camera.follow_damping_value = _route_damping
		_framing_mode = next_mode
	if cinematic_override_enabled:
		phantom_camera.follow_offset = Vector3(look_ahead, camera_height - target.global_position.y, side_distance)
		phantom_camera.follow_damping_value = Vector3.ONE * (2.0 / maxf(follow_response, 0.1))
	phantom_camera.follow_target = target


func _snap_render_output() -> void:
	global_position.x = snap_world_x(global_position.x)
	global_position.y = camera_height + snap_world_y(global_position.y - camera_height)
