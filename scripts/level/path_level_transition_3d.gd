extends LevelTransition3D
## A section transition that loads its destination scene by path when the game
## starts. Saved designer layouts fingerprint their section scene together with
## every scene it links as a resource; naming the destination by path keeps the
## destination out of that fingerprint, so tuning the destination never forces
## a review of the source section's saved layout.

@export_file("*.tscn") var target_scene_path := ""


func _ready() -> void:
	if target_scene == null and not target_scene_path.is_empty():
		target_scene = load(target_scene_path) as PackedScene
	super()
