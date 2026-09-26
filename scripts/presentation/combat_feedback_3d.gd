class_name CombatFeedback3D
extends Node
## Restrained, replaceable combat feedback. Timing and visual readability live
## here; combat audio follows accepted actions and confirmed gameplay contacts.

signal audio_cue_requested(cue_name: StringName, world_position: Vector3)
signal projectile_impact_presented(world_position: Vector3, surface_normal: Vector3)

@export_range(0.0, 0.15, 0.005) var enemy_defeat_pause := 0.045
@export_range(0.0, 0.15, 0.005) var player_damage_pause := 0.06
@export_range(0.01, 1.0, 0.01) var pause_time_scale := 0.08
@export var projectile_impact_scene: PackedScene = preload(
	"res://scenes/projectiles/pixel_projectile_impact.tscn"
)

var _pause_serial := 0
var _active_projectile_impacts: Array[PixelProjectileImpact3D] = []
var combat_audio: Node3D
var _knife_hit_sound_played := false
var _psychic_effect: Node3D


func _ready() -> void:
	combat_audio = preload("res://scripts/audio/combat_audio_3d.gd").new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)


func bind_player(player: PlayerCharacter) -> void:
	var heal_callback := _on_healing_used.bind(player)
	if not player.healing_used.is_connected(heal_callback):
		player.healing_used.connect(heal_callback)
	var callback := _on_player_damage.bind(player)
	if not player.damage_received.is_connected(callback):
		player.damage_received.connect(callback)
	var projectile_callback := _on_handgun_projectile_fired
	if not player.projectile_fired.is_connected(projectile_callback):
		player.projectile_fired.connect(projectile_callback)
	if not player.handgun_empty_triggered.is_connected(_on_handgun_empty_triggered):
		player.handgun_empty_triggered.connect(_on_handgun_empty_triggered)
	if not player.melee_swung.is_connected(_on_melee_swung):
		player.melee_swung.connect(_on_melee_swung)
	if not player.attack_connected.is_connected(_on_melee_connected):
		player.attack_connected.connect(_on_melee_connected)
	if not player.stomp_bounced.is_connected(_on_stomp_bounced):
		player.stomp_bounced.connect(_on_stomp_bounced)


func bind_enemy(enemy: StompableEnemy3D) -> void:
	var callback := _on_enemy_defeated.bind(enemy)
	if not enemy.defeated.is_connected(callback):
		enemy.defeated.connect(callback)


func bind_handgun_enemy(enemy: HandgunEnemy3D) -> void:
	var callback := _on_handgun_projectile_fired
	if not enemy.shot_fired.is_connected(callback):
		enemy.shot_fired.connect(callback)
	var shot_callback := _on_enemy_dual_shot.bind(enemy.shot_sound_event)
	if not enemy.dual_shot_fired.is_connected(shot_callback):
		enemy.dual_shot_fired.connect(shot_callback)
	if enemy.has_signal("psychic_pulsed") and not enemy.is_connected("psychic_pulsed", _on_psychic_pulsed):
		enemy.connect("psychic_pulsed", _on_psychic_pulsed)


func reset_feedback() -> void:
	_pause_serial += 1
	Engine.time_scale = 1.0
	_knife_hit_sound_played = false
	if is_instance_valid(_psychic_effect):
		_psychic_effect.reset_run()
	_psychic_effect = null
	if is_instance_valid(combat_audio):
		combat_audio.reset_run()
	while not _active_projectile_impacts.is_empty():
		var impact: PixelProjectileImpact3D = _active_projectile_impacts.pop_back()
		if is_instance_valid(impact):
			impact.reset_run()


func active_projectile_impact_count() -> int:
	var active_count := 0
	for impact in _active_projectile_impacts:
		if is_instance_valid(impact) and not impact.is_queued_for_deletion():
			active_count += 1
	return active_count


func _exit_tree() -> void:
	reset_feedback()


func _on_player_damage(source_position: Vector3, player: PlayerCharacter) -> void:
	player.play_damage_flash()
	audio_cue_requested.emit(&"player_damage", source_position)
	if not player.is_psychically_frozen():
		_begin_impact_pause(player_damage_pause)


func _on_psychic_pulsed(origin: Vector3, player: PlayerCharacter, duration: float) -> void:
	combat_audio.play_event("combat/tank_psychic", origin)
	# A new hit refreshes the active presentation instead of stacking old cages.
	if not is_instance_valid(_psychic_effect) or _psychic_effect.is_queued_for_deletion():
		_psychic_effect = preload("res://scripts/presentation/psychic_pulse_3d.gd").new()
		get_parent().add_child(_psychic_effect)
	_psychic_effect.play(origin, player, duration)


func _on_enemy_defeated(impact_position: Vector3, enemy: StompableEnemy3D) -> void:
	enemy.play_impact_flash()
	audio_cue_requested.emit(&"enemy_defeat", impact_position)
	_begin_impact_pause(enemy_defeat_pause)


func _on_healing_used(_item_id: StringName, _amount: int, player: PlayerCharacter) -> void:
	combat_audio.play_event("combat/heal", player.global_position)


func _on_melee_swung(world_position: Vector3) -> void:
	_knife_hit_sound_played = false
	combat_audio.play_event("combat/knife_swing", world_position)


func _on_melee_connected(target: Node3D) -> void:
	# One swing may defeat several enemies. Keep all damage, but one contact cue.
	if _knife_hit_sound_played:
		return
	_knife_hit_sound_played = true
	combat_audio.play_event("combat/knife_hit", target.global_position)


func _on_stomp_bounced(world_position: Vector3) -> void:
	combat_audio.play_event("combat/stomp", world_position)


func _on_handgun_projectile_fired(projectile: HandgunProjectile3D) -> void:
	var callback := _on_handgun_projectile_impacted
	if not projectile.impacted.is_connected(callback):
		projectile.impacted.connect(callback)
	if projectile.is_player_owned():
		combat_audio.play_event("combat/player_gunshot", projectile.global_position)


func _on_handgun_empty_triggered(world_position: Vector3) -> void:
	combat_audio.play_event("combat/out_of_ammo", world_position)


func _on_enemy_dual_shot(world_position: Vector3, event_id := "combat/enemy_gunshot") -> void:
	combat_audio.play_event(event_id, world_position)


func _on_handgun_projectile_impacted(
	world_position: Vector3,
	surface_normal: Vector3,
	collider: Object
) -> void:
	var impact := projectile_impact_scene.instantiate() as PixelProjectileImpact3D
	assert(impact != null, "CombatFeedback3D requires a PixelProjectileImpact3D scene.")
	get_parent().add_child(impact)
	_active_projectile_impacts.append(impact)
	impact.finished.connect(_on_projectile_impact_finished.bind(impact))
	impact.play_impact(world_position, surface_normal)
	projectile_impact_presented.emit(world_position, surface_normal)
	audio_cue_requested.emit(&"projectile_impact", world_position)
	var character_hit: bool = collider is PlayerCharacter or collider is ProjectileHurtbox3D or (collider is Node and collider.is_in_group("melee_target"))
	combat_audio.play_event("combat/bullet_character" if character_hit else "combat/bullet_scenery", world_position)


func _on_projectile_impact_finished(impact: PixelProjectileImpact3D) -> void:
	_active_projectile_impacts.erase(impact)


func _begin_impact_pause(real_time_seconds: float) -> void:
	if real_time_seconds <= 0.0:
		return
	_pause_serial += 1
	var request_serial := _pause_serial
	Engine.time_scale = pause_time_scale
	await get_tree().create_timer(
		real_time_seconds,
		true,
		false,
		true
	).timeout
	if request_serial == _pause_serial:
		Engine.time_scale = 1.0
