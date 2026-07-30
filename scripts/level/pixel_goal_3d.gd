class_name PixelGoal3D
extends LevelGoal3D

const CHEST_TEXTURE := preload("res://assets/art/green_zone/goal/chest_open.png")
const FRAME_COUNT := 7
const FRAME_WIDTH := 32

@export var animation_fps := 10.0

var _opening := false
var _elapsed := 0.0

@onready var sprite: Sprite3D = %Sprite


func _ready() -> void:
	super()
	add_to_group("run_resettable")
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_frame(0)
	reached.connect(_on_reached)


func _process(delta: float) -> void:
	if not _opening:
		return
	_elapsed += delta
	_set_frame(mini(FRAME_COUNT - 1, floori(_elapsed * animation_fps)))


func _on_reached(_body: PlayerCharacter) -> void:
	_opening = true
	_elapsed = 0.0


func _set_frame(frame_index: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = CHEST_TEXTURE
	atlas.region = Rect2(frame_index * FRAME_WIDTH, 0, FRAME_WIDTH, 22)
	sprite.texture = atlas


func reset_run() -> void:
	_opening = false
	_elapsed = 0.0
	_set_frame(0)
