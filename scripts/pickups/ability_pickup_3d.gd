class_name AbilityPickup3D
extends Area3D
## Reusable permanent-ability pickup. The level session owns progression;
## this actor owns only collection and its deliberately restrained presentation.

@export var ability_id: StringName = PlayerAbility.DOUBLE_JUMP
@export_range(0.0, 0.5, 0.01) var bob_height := 0.12
@export_range(0.1, 5.0, 0.1) var bob_speed := 2.2

var _session: LevelSession3D
var _claimed := false
var _base_icon_y := 0.0
var _elapsed := 0.0

@onready var icon: Sprite3D = %Icon
@onready var collection_shape: CollisionShape3D = %CollectionShape


func _ready() -> void:
	assert(PlayerAbility.is_known(ability_id), "%s uses an unknown ability." % name)
	add_to_group("ability_pickup")
	add_to_group("run_resettable")
	body_entered.connect(_on_body_entered)
	_base_icon_y = icon.position.y


func _process(delta: float) -> void:
	if _claimed:
		return
	_elapsed += delta
	icon.position.y = _base_icon_y + sin(_elapsed * bob_speed) * bob_height


func bind_to_level_session(session: LevelSession3D) -> void:
	_session = session
	if not session.ability_unlocked.is_connected(_on_ability_unlocked):
		session.ability_unlocked.connect(_on_ability_unlocked)
	if session.player.has_ability(ability_id):
		_set_claimed()


func is_claimed() -> bool:
	return _claimed


func reset_run() -> void:
	if _session != null and _session.player.has_ability(ability_id):
		_set_claimed()


func _on_body_entered(body: Node3D) -> void:
	if _claimed or _session == null or body != _session.player:
		return
	if _session.unlock_ability(ability_id):
		_set_claimed()


func _on_ability_unlocked(unlocked_id: StringName) -> void:
	if unlocked_id == ability_id:
		_set_claimed()


func _set_claimed() -> void:
	_claimed = true
	icon.visible = false
	collection_shape.set_deferred("disabled", true)
	set_process(false)
