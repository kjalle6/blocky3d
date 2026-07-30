class_name CombatFeedback3D
extends Node
## Restrained, replaceable combat feedback. Timing and visual readability live
## here; final audio can subscribe to the named cue signal later.

signal audio_cue_requested(cue_name: StringName, world_position: Vector3)

@export_range(0.0, 0.15, 0.005) var enemy_defeat_pause := 0.045
@export_range(0.0, 0.15, 0.005) var player_damage_pause := 0.06
@export_range(0.01, 1.0, 0.01) var pause_time_scale := 0.08

var _pause_serial := 0


func bind_player(player: PlayerCharacter) -> void:
	var callback := _on_player_damage.bind(player)
	if not player.damage_received.is_connected(callback):
		player.damage_received.connect(callback)


func bind_enemy(enemy: StompableEnemy3D) -> void:
	var callback := _on_enemy_defeated.bind(enemy)
	if not enemy.defeated.is_connected(callback):
		enemy.defeated.connect(callback)


func reset_feedback() -> void:
	_pause_serial += 1
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	reset_feedback()


func _on_player_damage(source_position: Vector3, player: PlayerCharacter) -> void:
	player.play_damage_flash()
	audio_cue_requested.emit(&"player_damage", source_position)
	_begin_impact_pause(player_damage_pause)


func _on_enemy_defeated(impact_position: Vector3, enemy: StompableEnemy3D) -> void:
	enemy.play_impact_flash()
	audio_cue_requested.emit(&"enemy_defeat", impact_position)
	_begin_impact_pause(enemy_defeat_pause)


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
