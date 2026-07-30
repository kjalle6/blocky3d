extends SceneTree
## Save-data and ability-policy regression without touching user progress.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(PlayerAbility.is_known(PlayerAbility.DOUBLE_JUMP))
	assert(PlayerAbility.is_known(PlayerAbility.WALL_JUMP))
	assert(PlayerAbility.is_known(PlayerAbility.DASH))
	assert(not PlayerAbility.is_known(&"legacy_super_jump"))

	var progress := GameProgress.new()
	assert(progress.complete_level(&"fundamentals"))
	assert(not progress.complete_level(&"fundamentals"))
	assert(progress.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not progress.unlock_ability(PlayerAbility.DOUBLE_JUMP))
	var serialized := progress.to_dictionary()
	var restored := GameProgress.from_dictionary(serialized)
	assert(restored.has_completed(&"fundamentals"))
	assert(restored.owns_ability(PlayerAbility.DOUBLE_JUMP))

	var test_save_path := "user://campaign_progress_validation.json"
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	var first_store := ProgressionStore.new()
	first_store.save_path = test_save_path
	first_store.mark_level_completed(&"fundamentals")
	first_store.unlock_ability(PlayerAbility.DOUBLE_JUMP)
	assert(FileAccess.file_exists(test_save_path))
	var second_store := ProgressionStore.new()
	second_store.save_path = test_save_path
	second_store.load_progress()
	assert(second_store.has_completed(&"fundamentals"))
	assert(second_store.owns_ability(PlayerAbility.DOUBLE_JUMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	first_store.free()
	second_store.free()

	var future_save := serialized.duplicate(true)
	future_save["version"] = GameProgress.SAVE_VERSION + 1
	var rejected_future := GameProgress.from_dictionary(future_save)
	assert(
		rejected_future.completed_level_ids.is_empty(),
		"Unknown save versions must fail closed instead of changing meaning."
	)

	var dirty_save := serialized.duplicate(true)
	dirty_save["unlocked_abilities"] = ["double_jump", "legacy_super_jump"]
	var sanitized := GameProgress.from_dictionary(dirty_save)
	assert(sanitized.owns_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not sanitized.owns_ability(&"legacy_super_jump"))

	var player_scene := load("res://scenes/player/pixel_player_character.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerCharacter
	root.add_child(player)
	player.configure_abilities(
		[PlayerAbility.DOUBLE_JUMP],
		[]
	)
	assert(
		not player.has_ability(PlayerAbility.DOUBLE_JUMP),
		"Owned abilities must remain disabled in levels that do not offer them."
	)
	player.configure_abilities(
		[PlayerAbility.DOUBLE_JUMP],
		[PlayerAbility.DOUBLE_JUMP]
	)
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))

	var catalog := load("res://resources/campaign/main_campaign.tres") as CampaignCatalog
	assert(catalog != null)
	assert(catalog.validation_errors().is_empty())
	assert(catalog.ordered_worlds().size() == 1)
	var green_zone := catalog.find_world_by_id(&"green_zone")
	assert(green_zone != null)
	assert(green_zone.display_number == 1)
	assert(green_zone.title == "Green Zone")
	assert(green_zone.theme_id == &"green_zone")
	assert(green_zone.ordered_levels().size() == 4)
	assert(catalog.ordered_levels().size() == 4)
	assert(catalog.ordered_levels()[0].level_id == &"fundamentals")
	assert(catalog.ordered_levels()[1].level_id == &"gaps_and_spikes")
	assert(catalog.ordered_levels()[2].level_id == &"double_jump")
	assert(catalog.ordered_levels()[3].level_id == &"wall_jump")
	assert(catalog.find_level(&"green_zone", 1).available_abilities.is_empty())
	assert(catalog.find_level(&"green_zone", 2).available_abilities.is_empty())
	assert(
		catalog.find_level(&"green_zone", 3).available_abilities
		== [PlayerAbility.DOUBLE_JUMP]
	)
	assert(
		catalog.find_level(&"green_zone", 3).required_abilities
		== [PlayerAbility.DOUBLE_JUMP]
	)
	assert(
		catalog.find_level(&"green_zone", 4).assumed_owned_abilities
		== [PlayerAbility.DOUBLE_JUMP]
	)
	assert(
		catalog.find_level(&"green_zone", 4).required_abilities
		== [PlayerAbility.DOUBLE_JUMP, PlayerAbility.WALL_JUMP]
	)
	assert(catalog.find_world_for_level(&"double_jump") == green_zone)
	assert(catalog.find_world_for_level(&"wall_jump") == green_zone)

	print("Campaign progression and ability-policy validation passed.")
	quit(0)
