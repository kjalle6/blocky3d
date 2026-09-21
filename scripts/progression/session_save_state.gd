class_name SessionSaveState
extends RefCounted
## Logical save state for one live section. Scene nodes and projectiles are
## rebuilt, never serialized. Stable source IDs also prevent reward farming.
const REGISTRY := preload("res://scripts/developer/level_layout_registry.gd")
var session: LevelSession3D
var rewards: Dictionary = {}
var world_flags: Dictionary = {}
var _loot_seed := 1
var _pending_point: LevelCheckpoint3D
var _entry_pending := false
var _quiet_time := 0.0


func _init(owner_session: LevelSession3D) -> void:
	session = owner_session


func tick(delta: float) -> void:
	if session.player.is_dead() or session.player.is_attacking() or session.player.is_transition_running():
		_quiet_time = 0.0
	else:
		_quiet_time += delta
	if session._progression_store == null:
		return
	if not _entry_pending and not is_instance_valid(_pending_point):
		return
	if not safety_error(false).is_empty():
		return
	var position := session.player.global_position
	var point_id := "entry"
	if is_instance_valid(_pending_point):
		# Capture the stable grounded position that actually activated the point.
		# Never teleport to the center of a wide area or into edited geometry.
		point_id = source_id(_pending_point)
	_pending_point = null
	_entry_pending = false
	session._progression_store.write_snapshot(capture(position, point_id), "auto")


func queue_point(point: LevelCheckpoint3D) -> void:
	_pending_point = point


func queue_entry() -> void:
	_entry_pending = true


func note_combat(_position: Vector3) -> void:
	_quiet_time = 0.0


func source_id(node: Node) -> String:
	return REGISTRY.section_for(session) + "/" + str(node.get_meta("layout_id", session.get_path_to(node)))


func claim_reward(node: Node, item_id: StringName, amount: int) -> bool:
	return claim_rewards(node, {item_id: amount})


func claim_rewards(node: Node, contents: Dictionary) -> bool:
	var id := source_id(node)
	if rewards.get(id, false) or contents.is_empty():
		return false
	# Validate the complete bundle before claiming or granting any of it.
	for item_id in contents:
		if ItemCatalog.definition(StringName(item_id)) == null or not SaveSnapshot.whole(contents[item_id], 1, 2147483647):
			return false
		if session.player.inventory.count(StringName(item_id)) > 2147483647 - int(contents[item_id]):
			return false
	rewards[id] = true
	for item_id in contents:
		session.player.inventory.add(StringName(item_id), int(contents[item_id]))
	return true


func mark_world_flag(id: String) -> void:
	world_flags[id] = true


func capture(position: Vector3, point_id := "") -> Dictionary:
	var store := session._progression_store
	var progress := store.progress if store != null else GameProgress.new()
	if store == null: progress.loot_seed = _loot_seed
	return {
		"level_id": String(session.level_definition().level_id),
		"section": REGISTRY.section_for(session),
		"position": [position.x, position.y, 0.0],
		"point_id": point_id,
		"player": session.player.capture_state(),
		"progress": progress.to_dictionary(),
		"rewards": rewards.duplicate(true),
		"world_flags": world_flags.duplicate(true),
	}


func loot_seed() -> int:
	return session._progression_store.progress.loot_seed if session._progression_store != null else _loot_seed


func transfer_state() -> Dictionary:
	return {"player": session.player.capture_state(), "rewards": rewards.duplicate(true), "world_flags": world_flags.duplicate(true), "loot_seed": loot_seed()}


func apply_state(data: Dictionary, restore_position := false) -> void:
	_loot_seed = int(data.get("loot_seed", data.get("progress", {}).get("loot_seed", 1)))
	rewards = data.get("rewards", {}).duplicate(true)
	world_flags = data.get("world_flags", {}).duplicate(true)
	_entry_pending = false
	_pending_point = null
	_quiet_time = 0.0
	var player_state: Dictionary = data.player.duplicate(true)
	var abilities: Array[StringName] = []
	abilities.assign(player_state.abilities)
	var store := session._progression_store
	if store == null and not restore_position:
		# Fresh developer destinations keep their level-defined entry kit.
		for ability in session._session_unlocked_abilities:
			if ability not in abilities:
				abilities.append(ability)
	if store != null:
		abilities = store.unlocked_abilities()
		player_state.weapons = Array(store.progress.owned_weapon_ids)
		player_state.health.maximum = store.progress.maximum_hp
	session._session_unlocked_abilities.assign(abilities)
	session._session_owned_weapon_ids.assign(player_state.weapons)
	session._apply_ability_policy()
	if restore_position:
		var saved: Array = data.position
		session._active_respawn_transform = Transform3D(Basis.IDENTITY, Vector3(saved[0], saved[1], 0))
		session._reset_world()
	session.player.restore_state(player_state)
	if restore_position:
		# A load is not a new save-point visit. Mark overlapping triggers earned
		# before their next physics update, including a manual save on a trigger.
		for point in session.get_tree().get_nodes_in_group("level_checkpoint"):
			if not session.is_ancestor_of(point):
				continue
			var shape := point.get_node("Trigger") as CollisionShape3D
			var local_player: Vector3 = shape.to_local(session.player.global_position)
			var bounds := (shape.shape as BoxShape3D).size * 0.5 + Vector3(0.4, 0.1, 0.1)
			if absf(local_player.x) <= bounds.x and absf(local_player.y) <= bounds.y:
				point.set("_activated", true)
	# Pickups and logical intro controllers see restored ownership/flags, after
	# fresh actors have been reset. Ordinary enemies always restart at full HP.
	for group in ["ability_pickup", "weapon_pickup", "item_reward"]:
		for node in session.get_tree().get_nodes_in_group(group):
			if session.is_ancestor_of(node) and node.has_method("reset_run"):
				node.reset_run()
	for node in session.find_children("*", "GreenZoneShooterIntro3D", true, false):
		node._on_level_session_run_reset()
	session.camera.snap_to_target()
	if session.background != null:
		session.background.snap_to_camera(true)


func safety_error(manual := true) -> String:
	var player := session.player
	if player.is_dead() or session._completed or player.is_transition_running():
		return "Wait until you are back in control."
	if session.is_developer_inspection_enabled():
		return "Leave inspection mode before saving."
	if not player.can_save_state(manual) or not player.is_on_floor():
		return "Stand still on safe ground before saving."
	var stable_floor := false
	for index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		if collision.get_normal().y > 0.7 and collision.get_collider() is StaticBody3D:
			stable_floor = true
	if not stable_floor:
		return "Move onto solid ground before saving."
	if manual and _quiet_time < 2.0:
		return "Wait a moment after combat before saving."
	if not manual:
		return ""
	for enemy in session.get_tree().get_nodes_in_group("melee_target"):
		if not session.is_ancestor_of(enemy):
			continue
		if enemy is StompableEnemy3D and not enemy.is_defeated() and enemy.is_pursuing():
			return "Lose pursuing enemies before saving."
		var radius := float(enemy.detection_range) + 1.0 if enemy is HandgunEnemy3D else 5.0
		# Dead actors return on load, so their initial positions matter too.
		var locations: Array[Vector3] = [enemy.global_position, enemy._initial_transform.origin]
		for location in locations:
			var offset := location - player.global_position
			if absf(offset.x) < radius and absf(offset.y) < 3.5:
				return "Move away from enemies before saving."
	for flyer in session.find_children("*", "HoveringHazard3D", true, false):
		var local_player := (flyer.get_parent() as Node3D).to_local(player.global_position)
		if local_player.x >= flyer.leftmost_body_x() - 2.0 and local_player.x <= flyer.rightmost_body_x() + 2.0 and local_player.y >= flyer.lowest_body_y() - 3.0 and local_player.y <= flyer.highest_body_y() + 2.0:
			return "Move clear of moving hazards before saving."
	for group in ["enemy_projectile", "player_projectile"]:
		for bullet in session.get_tree().get_nodes_in_group(group):
			if session.is_ancestor_of(bullet) and bullet.global_position.distance_to(player.global_position) < 24.0:
				return "Wait for nearby gunfire to clear."
	return ""


func manual_save(slot: int) -> bool:
	if session._progression_store == null:
		return false
	var error := safety_error()
	if not error.is_empty():
		return session._progression_store._fail(error)
	return session._progression_store.write_snapshot(capture(session.player.global_position), "manual", slot)
