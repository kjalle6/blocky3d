extends SceneTree
## Runtime contact contract for the indestructible Green Zone flyer.
##
## Route validators prove that the player can avoid it. This focused check proves
## the other half of the rule: touching its body or active discharge is lethal,
## including when the discharge activates around a player already underneath it.

const PLAYER_SCENE := preload("res://scenes/player/pixel_player_character.tscn")
const FLYER_SCENE := preload("res://scenes/enemies/green_zone_flyer.tscn")
const FLYER_POSITION := Vector3(0.0, 4.0, 0.0)
const SAFE_POSITION := Vector3(4.0, 4.0, 0.0)
const BODY_CONTACT_OFFSET := Vector3(0.0, 0.1, 0.0)
const SPARK_CONTACT_OFFSET := Vector3(0.0, -1.0, 0.0)

var _completed := false


func _init() -> void:
	create_timer(10.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	if _completed:
		return
	printerr("Hovering-hazard runtime validation timed out.")
	quit(1)


func _run() -> void:
	var flyer := FLYER_SCENE.instantiate() as HoveringHazard3D
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	assert(flyer != null)
	assert(player != null)
	flyer.position = FLYER_POSITION
	root.add_child(flyer)
	root.add_child(player)
	for frame in 3:
		await physics_frame
	flyer.set_physics_process(false)

	# The body remains lethal even while the electrical discharge is off.
	flyer._set_spark(false)
	player.reset_at(Transform3D(Basis.IDENTITY, FLYER_POSITION + BODY_CONTACT_OFFSET))
	player.set_physics_process(false)
	for frame in 2:
		await physics_frame
	assert(player.is_dead(), "Touching the flyer body must kill the player.")

	# Entering an already-active discharge is lethal without touching the body.
	player.reset_at(Transform3D(Basis.IDENTITY, SAFE_POSITION))
	player.set_physics_process(false)
	flyer._set_spark(true)
	player.reset_at(Transform3D(Basis.IDENTITY, FLYER_POSITION + SPARK_CONTACT_OFFSET))
	player.set_physics_process(false)
	for frame in 2:
		await physics_frame
	assert(player.is_dead(), "Entering an active flyer discharge must kill the player.")

	# Monitoring was deliberately off before the player entered this time. The
	# transition to the attack frames must still kill an occupant already inside.
	player.reset_at(Transform3D(Basis.IDENTITY, SAFE_POSITION))
	player.set_physics_process(false)
	flyer._set_spark(false)
	for frame in 2:
		await physics_frame
	player.reset_at(Transform3D(Basis.IDENTITY, FLYER_POSITION + SPARK_CONTACT_OFFSET))
	player.set_physics_process(false)
	for frame in 2:
		await physics_frame
	assert(not player.is_dead(), "An inactive discharge must leave its lane safe.")
	flyer._set_spark(true)
	for frame in 2:
		await physics_frame
	assert(
		player.is_dead(),
		"A discharge activating around an existing occupant must kill the player."
	)

	print("Hovering-hazard body and discharge runtime validation passed.")
	_completed = true
	quit(0)
