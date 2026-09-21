class_name ItemReward3D
extends Area3D
## Carried-item reward. Claim IDs are saved with inventory; ordinary
## enemy resets cannot grant an already claimed reward a second time.
enum Presentation { PICKUP, CHEST, ENEMY_DROP }
const LOOT := preload("res://scripts/items/chest_loot.gd")
const PREVIEW := preload("res://scripts/developer/level_layout_preview.gd")
@export var loot_pool: StringName = &"fixed"
const CHEST := preload("res://assets/art/green_zone/goal/chest_open.png")
@export var item_id: StringName = &"basic_heal"
@export_range(1, 999, 1) var quantity := 1
@export var additional_items: Dictionary[StringName, int] = {}
@export var presentation := Presentation.PICKUP
@export var source_enemy_path: NodePath
var session: LevelSession3D
var visual: Sprite3D
var _available := false
var _opening_time := -1.0
var _source: Node3D


func _ready() -> void:
	add_to_group("item_reward")
	add_to_group("run_resettable")
	collision_layer = 0
	collision_mask = 1
	var parent := get_parent()
	while parent != null and not parent is LevelSession3D:
		parent = parent.get_parent()
	session = parent as LevelSession3D
	assert(PREVIEW.is_preview(self) or (session != null and ItemCatalog.definition(item_id) != null))
	var trigger := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.25, 0.9, 1.2) if presentation == Presentation.CHEST else Vector3(1.5, 1.3, 1.2)
	trigger.shape = shape
	trigger.position.y = shape.size.y * 0.5
	add_child(trigger)
	visual = Sprite3D.new()
	visual.name = "Visual"
	visual.position = Vector3(0, 0.44 if presentation == Presentation.CHEST else 0.66, 0.9)
	visual.pixel_size = 0.04 if presentation == Presentation.CHEST else 0.035
	visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	visual.shaded = false
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	if PREVIEW.is_preview(self):
		collision_mask = 0
		monitoring = false
		monitorable = false
		if presentation == Presentation.CHEST: _chest_frame(0)
		else: visual.texture = ItemCatalog.definition(item_id).icon
		return
	body_entered.connect(_on_body_entered)
	if presentation == Presentation.ENEMY_DROP:
		_source = get_node(source_enemy_path) as Node3D
		assert(_source != null and _source.has_signal("defeated"))
		_source.defeated.connect(_on_source_defeated)
	reset_run()


func _process(delta: float) -> void:
	if _opening_time < 0:
		return
	_opening_time += delta
	_chest_frame(mini(6, int(_opening_time * 10)))
	if _opening_time >= 0.6:
		_opening_time = -1


func reset_run() -> void:
	_opening_time = -1
	var claimed: bool = session.save_state != null and session.save_state.rewards.get(session.save_state.source_id(self), false)
	_available = not claimed and presentation != Presentation.ENEMY_DROP
	visible = presentation == Presentation.CHEST or _available
	if presentation == Presentation.CHEST:
		_chest_frame(6 if claimed else 0)
	else:
		visual.texture = ItemCatalog.definition(item_id).icon
	set_deferred("monitoring", _available)


func _on_source_defeated(_position: Vector3) -> void:
	if session.save_state.rewards.get(session.save_state.source_id(self), false):
		return
	global_position = _source.global_position - Vector3(0, 0.55, 0)
	_available = true
	visible = true
	set_deferred("monitoring", true)


func _on_body_entered(body: Node3D) -> void:
	if body == session.player:
		collect()


func collect() -> bool:
	if not _available or session == null or session.player.is_dead() or session.player.is_developer_inspection_enabled():
		return false
	var contents := reward_contents()
	if not session.save_state.claim_rewards(self, contents):
		return false
	_available = false
	for received_id in contents:
		session.item_received.emit(StringName(received_id), int(contents[received_id]))
	set_deferred("monitoring", false)
	if presentation == Presentation.CHEST:
		_opening_time = 0
	else:
		hide()
	return true


func reward_contents() -> Dictionary:
	if loot_pool != &"fixed":
		var pool_id := str(loot_pool)
		if loot_pool == &"level":
			pool_id = LOOT.pool_for_level(session.level_definition().level_id)
		return LOOT.roll(pool_id, session.save_state.loot_seed(), session.save_state.source_id(self), session.player.owned_weapon_ids())
	var contents := {}
	if quantity > 0: contents[item_id] = quantity
	for extra_id in additional_items:
		if additional_items[extra_id] > 0:
			contents[extra_id] = int(contents.get(extra_id, 0)) + additional_items[extra_id]
	return contents


func _chest_frame(index: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = CHEST
	atlas.region = Rect2(index * 32, 0, 32, 22)
	visual.texture = atlas
