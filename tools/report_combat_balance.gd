extends SceneTree
## Derive matchups/cadence from runtime resources and authored actor defaults.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Load the player composition first, matching the game's resource dependency
	# order (the firearm and projectile scripts refer back to PlayerCharacter).
	var player := (load("res://scenes/player/pixel_player_character.tscn") as PackedScene).instantiate() as PlayerCharacter
	var gun: FirearmDefinition = player.get_node("PlayerHandgun").definition
	var knife := player.knife_attack
	var stomp := player.stomp_attack
	var lines := PackedStringArray(["# Runtime combat balance", "",
		"Player starts at %d HP. Bat/skater hits deal 25: three survived, fourth lethal. No general damage invulnerability." % player.combat.maximum_hp,
		"", "| Enemy | HP | Attack damage | Knife hits | Stomps | Handgun hits | Status |",
		"| --- | ---: | ---: | ---: | ---: | ---: | --- |"])
	var cadence := PackedStringArray(["", "## Attack cadence", "",
		"Player knife animation: %.2f seconds. Handgun interval: %.2f seconds." % [player.attack_duration, gun.fire_interval]])
	var scenes := {"bat": "pixel_patrol_enemy", "skater": "pixel_skater_enemy", "gunner": "handgun_enemy",
		"tank": "green_zone_tank", "launcher boss": "green_zone_boss"}
	for id in scenes:
		var actor := (load("res://scenes/enemies/%s.tscn" % scenes[id]) as PackedScene).instantiate()
		var profile: CombatProfile = actor.combat
		var knife_damage := knife.damage * profile.knife_damage_multiplier
		var knife_hits := str(ceili(float(profile.maximum_hp) / knife_damage)) if knife_damage > 0.0 else "Immune"
		var stomp_hits := "Immune" if actor is TankEnemy3D or id == "launcher boss" else str(ceili(float(profile.maximum_hp) / stomp.damage))
		lines.append("| %s | %d | %d | %s | %s | %d | %s |" % [id, profile.maximum_hp, profile.attack_damage, knife_hits, stomp_hits, ceili(float(profile.maximum_hp) / gun.damage), "Provisional" if profile.provisional else "Starting baseline"])
		if actor is StompableEnemy3D:
			cadence.append("%s: %.2f-second attack, impact at %.2f seconds, %.2f-second cooldown; %.2f-second hurt interruption." % [id.capitalize(), actor.attack_duration, actor.attack_impact_time, actor.attack_cooldown, profile.hurt_duration])
		elif actor is TankEnemy3D:
			cadence.append("Tank: %.2f-second windup, %.2f-second recovery; knife damage %.1f, no nonlethal interruption." % [actor.telegraph_duration, actor.recovery_duration, knife_damage])
		elif actor is HandgunEnemy3D:
			cadence.append("Gunner: %.2f-second windup; twin/triple beat intervals %.2f/%.2f seconds; %.2f-second recovery. Two barrels share one damage event per target per beat." % [actor.telegraph_duration, actor.twin_shot_interval, actor.triple_shot_interval, actor.recovery_duration])
		else:
			cadence.append("Launcher boss: %.2f-second recovery, %.2f-second missile cooldown and %.2f-second jump cooldown; knife damage %.1f." % [actor.recovery_duration, actor.missile_cooldown, actor.jump_cooldown, knife_damage])
		actor.free()
	lines.append_array(cadence)
	lines.append("")
	lines.append("Handgun damage: %d (provisional). Basic medicine: %d HP; %.2f-second feedback/attack lock. Spikes, pits and indestructible flyers bypass HP. Separate attackers and separate firing beats remain separate hits." % [gun.damage, ItemCatalog.definition(&"basic_heal").healing, ItemCatalog.definition(&"basic_heal").use_duration])
	player.free()
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	var file := FileAccess.open("res://build/reports/combat_balance.md", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("\n".join(lines))
	quit()
