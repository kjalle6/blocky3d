extends SceneTree
const CATALOG := preload("res://scripts/scanner/scanner_catalog.gd")


func _init() -> void:
	call_deferred("_run")
	create_timer(45.0, true).timeout.connect(func() -> void: quit(1))


func _run() -> void:
	# Same load order as the existing combat report; nothing enters the live tree.
	var player: Node = load("res://scenes/player/pixel_player_character.tscn").instantiate()
	var catalog := CATALOG.new()
	assert(catalog.validation_errors().is_empty(), str(catalog.validation_errors()))
	assert(catalog.entry_ids().size() == 16)
	var report := {"schema_version": 1, "numeric_discovery": "TBD", "entries": []}
	for id in catalog.entry_ids():
		var result: Dictionary = catalog.resolve_stats(id)
		assert(result.errors.is_empty(), id + ": " + str(result.errors))
		var entry: Dictionary = catalog.definition(id)
		assert(result.values.size() == entry.stats.size(), "Every binding must resolve: " + id)
		for stat in result.values.values():
			assert(typeof(stat.value) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL])
		var first_scan: Dictionary = catalog.learned_entry(id, [], true)
		if entry.status == "implemented":
			assert(first_scan.keys().size() == 3 and first_scan.facts.is_empty())
			assert(not first_scan.has("stats") and not first_scan.has("kind"))
		else:
			assert(first_scan.is_empty())
		report.entries.append({"id": id, "game_name": entry.game_name,
			"status": entry.status, "stats": result.values, "facts": catalog.fact_definitions(id)})
	_check_discovery(catalog)
	_check_overrides(catalog)
	_check_coverage(catalog)
	# Convenient developer snapshot. This is never loaded as player knowledge.
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	var file := FileAccess.open("res://build/reports/scanner_catalog.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	player.free()
	print("Scanner catalog PASS: 16 entries, live/default stat bindings, isolated discoveries, no first-scan stat leakage.")
	quit()


func _check_discovery(catalog: RefCounted) -> void:
	var missile := {"entry_id": "green_zone_launcher", "event": "attack_received",
		"attack": "missile", "confirmed": true, "after_scan": true}
	assert(catalog.qualifying_fact_ids("green_zone_launcher", missile) == PackedStringArray(["missile"]))
	var known: Dictionary = catalog.learned_entry("green_zone_launcher", ["missile", "maximum_hp", "made_up_fact"], true)
	assert(known.facts.size() == 1 and known.facts[0].id == "missile")
	assert(not known.has("stats") and not known.facts[0].has("evidence"))
	assert(catalog.learned_entry("green_zone_launcher", ["missile"], false).is_empty())
	missile.after_scan = false
	assert(catalog.qualifying_fact_ids("green_zone_launcher", missile).is_empty())
	missile.after_scan = true
	missile.confirmed = false
	assert(catalog.qualifying_fact_ids("green_zone_launcher", missile).is_empty())
	missile.confirmed = true
	assert(catalog.qualifying_fact_ids("green_zone_tank", missile).is_empty())
	var knife := {"entry_id": "green_zone_tank", "event": "weapon_result", "weapon": "knife",
		"outcome": "miss", "confirmed": true, "after_scan": true}
	for outcome in ["miss", "blocked_by_cover", "out_of_range", "cancelled"]:
		knife.outcome = outcome
		assert(catalog.qualifying_fact_ids("green_zone_tank", knife).is_empty())
	knife.outcome = "reduced"
	assert(catalog.qualifying_fact_ids("green_zone_tank", knife) == PackedStringArray(["knife_reduced"]))
	var spark := {"entry_id": "flyer_vertical", "event": "lethal_contact", "attack": "spark", "confirmed": true, "after_scan": true}
	assert(catalog.qualifying_fact_ids("flyer_vertical", spark) == PackedStringArray(["spark_lethal"]))
	var hurt := {"entry_id": "green_zone_launcher", "event": "hurt_animation_seen", "confirmed": true, "after_scan": true}
	assert(catalog.qualifying_fact_ids("green_zone_launcher", hurt).is_empty())
	var observation := {"entry_id": "green_zone_launcher", "event": "behavior_confirmed", "attack": "smoke_escape",
		"behavior": "counterattack", "confirmed": true, "after_scan": true}
	assert(catalog.qualifying_fact_ids("green_zone_launcher", observation).is_empty())
	assert(catalog.learned_entry("green_zone_launcher", ["counterattack"], true).facts.is_empty())
	var external: Dictionary = catalog.definition("green_zone_tank")
	external.game_name = "Player alias"
	assert(catalog.definition("green_zone_tank").game_name == "Green Zone tank")
	assert(catalog.definition("unknown").is_empty())
	assert(not catalog.resolve_stats("unknown").errors.is_empty())


func _check_overrides(catalog: RefCounted) -> void:
	var tank: Node = load("res://scenes/enemies/green_zone_tank.tscn").instantiate()
	tank.combat = tank.combat.duplicate()
	tank.combat.maximum_hp = 432
	tank.combat.knife_damage_multiplier = 0.25
	tank.projectile_distance = 48.0
	var resolved: Dictionary = catalog.resolve_stats("green_zone_tank", tank)
	assert(resolved.errors.is_empty())
	assert(resolved.origin == "live_target")
	assert(resolved.values.maximum_hp.value == 432)
	assert(is_equal_approx(resolved.values.knife_multiplier.value, 0.25))
	assert(resolved.values.shell_range.value == 48.0)
	assert(not catalog.resolve_stats("bat_patrol", tank).errors.is_empty())
	tank.free()
	var defaults: Dictionary = catalog.resolve_stats("green_zone_tank")
	assert(defaults.values.maximum_hp.value == 200 and defaults.values.shell_range.value == 22.0)
	var boss: Dictionary = catalog.resolve_stats("green_zone_launcher")
	assert(boss.values.maximum_hp.balance_status == "TBD")
	assert(boss.values.maximum_hp.target_value == null)
	assert(boss.values.maximum_hp.current_role == "inadequate_lab_placeholder")
	assert(boss.values.missiles_per_salvo.value == 6)
	assert(boss.values.missile_cooldown.value == 5.0)
	var guard: Dictionary = catalog.resolve_stats("gunner_guard")
	assert(guard.values.mobile.value == false and guard.values.detection_y.value == 14.0)
	var flyer: Dictionary = catalog.resolve_stats("flyer_patrol")
	assert(is_equal_approx(flyer.values.horizontal_amplitude.value, 20.4))
	assert(flyer.values.horizontal_speed.value == 4.0)
	# A broken binding must remain an error, never silently become zero/default.
	catalog._entries.green_zone_tank.stats.shell_range.property = "missing_property"
	var missing: Dictionary = catalog.resolve_stats("green_zone_tank")
	assert(not missing.errors.is_empty() and not missing.values.has("shell_range"))
	catalog._entries.green_zone_tank.stats.shell_range.property = "projectile_distance"


func _check_coverage(catalog: RefCounted) -> void:
	var covered := {}
	for id in catalog.entry_ids():
		var source: Dictionary = catalog.definition(id).get("default_source", {})
		if source.has("scene"):
			covered[source.scene] = true
	for filename in DirAccess.get_files_at("res://scenes/enemies"):
		if filename.ends_with(".tscn"):
			assert(covered.has("res://scenes/enemies/" + filename), "Uncatalogued enemy scene: " + filename)
