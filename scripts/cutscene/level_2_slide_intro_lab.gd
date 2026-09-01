class_name Level2SlideIntroLab
extends LevelSession3D
## Disposable host for reviewing the real Level 2 cave-slide cutscene.

@onready var cave_slide_intro: Level2CaveSlideIntro3D = %CaveSlideIntro
@onready var lab_status: Label = %LabStatus


func _ready() -> void:
	super._ready()
	player.visible = false
	player.set_physics_process(false)
	camera.current = false
	if background != null:
		background.visible = false
	cave_slide_intro.finished.connect(_on_cutscene_finished)
	_update_status(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		cave_slide_intro.play_from_start()
		_update_status(false)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _on_cutscene_finished(_skipped: bool) -> void:
	_update_status(true)


func _update_status(complete: bool) -> void:
	lab_status.text = (
		"CAVE RUN-IN HANDOFF READY    R: REPLAY"
		if complete
		else "LEVEL 2 SLIDE INTRO LAB    SPACE / A: SKIP    R: REPLAY"
	)
