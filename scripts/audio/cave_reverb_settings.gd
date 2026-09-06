extends Resource
## Shared room acoustics, independent of the floor's recording bank.
@export var enabled := true
@export_range(0.0, 1.0, 0.01) var amount := 0.16
@export_range(0.0, 1.0, 0.01) var room_size := 0.5
@export_range(0.0, 1.0, 0.01) var damping := 0.65
