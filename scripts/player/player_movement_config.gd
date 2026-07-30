class_name PlayerMovementConfig
extends Resource
## All feel-critical values for the core controller. Keeping these in a
## Resource lets us tune movement without coupling level scenes to code values.

@export_category("Horizontal movement")
@export_range(1.0, 20.0, 0.1, "or_greater") var maximum_speed := 8.0
@export_range(1.0, 150.0, 0.5, "or_greater") var ground_acceleration := 65.0
@export_range(1.0, 150.0, 0.5, "or_greater") var ground_deceleration := 80.0
@export_range(1.0, 150.0, 0.5, "or_greater") var air_acceleration := 42.0

@export_category("Jump")
@export_range(1.0, 40.0, 0.1, "or_greater") var jump_velocity := 14.0
@export_range(1.0, 100.0, 0.5, "or_greater") var gravity := 38.0
@export_range(1.0, 100.0, 0.5, "or_greater") var maximum_fall_speed := 28.0
@export_range(0.1, 1.0, 0.01) var released_jump_multiplier := 0.48
@export_range(0.0, 0.3, 0.01) var coyote_time := 0.10
@export_range(0.0, 0.3, 0.01) var jump_buffer_time := 0.12

@export_category("Wall movement")
@export_range(0.0, 1.0, 0.01) var wall_slide_gravity_multiplier := 0.28
@export_range(1.0, 20.0, 0.1, "or_greater") var wall_slide_max_fall_speed := 4.5
@export_range(1.0, 40.0, 0.1, "or_greater") var wall_jump_vertical_speed := 16.5
@export_range(1.0, 20.0, 0.1, "or_greater") var wall_jump_horizontal_speed := 10.5
@export_range(0.0, 0.5, 0.01) var wall_jump_control_lock_time := 0.14
@export_range(0.0, 0.3, 0.01) var wall_coyote_time := 0.10

@export_category("Grounding")
@export_range(0.0, 1.0, 0.01) var floor_snap_length := 0.25
@export_range(0.0, 60.0, 0.5) var maximum_floor_angle_degrees := 46.0


func ideal_jump_height() -> float:
	return jump_velocity * jump_velocity / (2.0 * gravity)


func ideal_jump_air_time() -> float:
	return 2.0 * jump_velocity / gravity


func ideal_full_speed_jump_distance() -> float:
	return maximum_speed * ideal_jump_air_time()
