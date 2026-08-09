extends SceneTree
## Structural and session-state contract for the development-only replacement
## candidate. The six campaign prototypes remain untouched while this matures.

const EPSILON := 0.01


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := load(
		"res://resources/dev/arrival_shoreline_slice.tres"
	) as LevelDefinition
	assert(definition != null)
	assert(definition.validation_errors().is_empty())
	assert(definition.level_id == &"dev_arrival_shoreline_slice")
	assert(definition.available_abilities == [PlayerAbility.DOUBLE_JUMP])
	assert(definition.assumed_owned_abilities.is_empty())
	assert(definition.required_abilities == [PlayerAbility.DOUBLE_JUMP])

	var packed_scene := load("res://scenes/app/game_root.tscn") as PackedScene
	var game_root := packed_scene.instantiate()
	game_root.persist_progression = false
	root.add_child(game_root)
	await process_frame
	assert(game_root.campaign.find_by_id(definition.level_id) == null)
	assert(
		definition in game_root._ordered_developer_definitions(),
		"The candidate must be reachable only through Developer Tools."
	)

	game_root.load_developer_level(definition)
	await process_frame
	var level := game_root.current_level as LevelSession3D
	for frame in 10:
		await physics_frame
	assert(level != null)
	assert(game_root.current_world_definition == null)
	assert(game_root.current_level_definition == definition)
	assert(level.name == "DeveloperArrivalShorelineSlice")
	assert(
		not (game_root.get_node("Interface/DeveloperAbilityPanel") as Control).visible,
		"Only Animation Lab should expose developer ability toggles."
	)
	assert(is_equal_approx(level.route_extent.length(), 81.92))
	assert(is_equal_approx(level.camera.maximum_center_x, 67.77))
	assert(is_equal_approx(level.camera.camera_height, 3.98))
	assert(is_equal_approx(level.camera.target_height, 3.98))
	assert(is_zero_approx(level.camera.rotation.x))
	assert(level.get_node("Platforms").get_child_count() == 7)
	assert(level.get_node("Checkpoints").get_child_count() == 1)
	assert(_scoped_group_count(level, &"melee_target") == 1)
	assert(_scoped_group_count(level, &"level_goal") == 1)
	assert(level.get_node_or_null("Hazards/ShoreWater") is PixelWaterStrip3D)
	var instructions := game_root.get_node("Interface/Instructions") as Control
	var menu_hint := game_root.get_node("Interface/MenuHint") as Label
	assert(not instructions.visible)
	assert(menu_hint.visible)
	assert(menu_hint.text == "F1: TOOLS    ESC: LEVEL SELECT")
	_toggle_gameplay_tools(game_root)
	assert(instructions.visible)
	assert(menu_hint.text == "F1: HIDE TOOLS    ESC: LEVEL SELECT")
	assert(
		not (game_root.get_node("Interface/DeveloperAbilityPanel") as Control).visible,
		"Arrival has no ability-testing panel even when its tools are open."
	)
	_toggle_gameplay_tools(game_root)
	assert(not instructions.visible)
	assert(menu_hint.text == "F1: TOOLS    ESC: LEVEL SELECT")
	_validate_geometry(level)
	_validate_presentation(level)
	var water := level.get_node("Hazards/ShoreWater") as PixelWaterStrip3D
	var initial_water_frame := water.current_frame()
	for frame in 10:
		await physics_frame
	assert(
		water.current_frame() != initial_water_frame,
		"The shoreline atlas must advance instead of remaining a static pattern."
	)
	var shore_wave := level.get_node("ShoreWave") as PixelShoreWave3D
	assert(shore_wave.crest_count() == 3)
	assert(shore_wave.crest_offsets_x.size() == shore_wave.crest_delays.size())
	assert(
		is_equal_approx(
			shore_wave.crest_sprite(0).pixel_size,
			PixelPlatform3D.TILE_PIXEL_SIZE
		),
		"Surf must render on the same pixel scale as the terrain it breaks against."
	)
	assert(
		is_equal_approx(
			shore_wave.shore_foam_sprite().pixel_size,
			PixelPlatform3D.TILE_PIXEL_SIZE
		),
		"Foam must share the terrain pixel scale."
	)
	assert(
		is_equal_approx(shore_wave.foam_offset_pixels(), 16.0),
		"The splash must be seated on the water by its own art base, not the frame."
	)
	assert(
		is_equal_approx(
			shore_wave.global_position.x + shore_wave.shoreline_x,
			0.0
		),
		"The shoreline the crests break against is the sand edge."
	)
	assert(
		shore_wave.foam_body_offset < 0.0,
		"The splash lands seaward of a crest's tip, over the wave's mass."
	)
	assert(
		is_equal_approx(shore_wave.waterline_offset_pixels(), 33.0),
		"Crests must be offset so the clip's own waterline lands on the node origin."
	)
	assert(
		is_equal_approx(shore_wave.global_position.y, 0.0),
		"The surf node sits on the water surface, so crests break in the water."
	)
	for crest_index in range(1, shore_wave.crest_count()):
		assert(
			shore_wave.crest_offsets_x[crest_index]
			> shore_wave.crest_offsets_x[crest_index - 1],
			"Crests must be authored offshore-to-inshore."
		)
		assert(
			shore_wave.crest_sprite(crest_index).global_position.y
			> shore_wave.crest_sprite(crest_index - 1).global_position.y,
			(
				"Each crest nearer the beach must sit higher out of the water. "
				+ "Otherwise a small wave can appear behind a larger one."
			)
		)
	var offshore_crests := 0
	for crest_index in shore_wave.crest_count():
		if not shore_wave.crest_ever_reaches_shore(crest_index):
			offshore_crests += 1
	assert(
		offshore_crests > 0,
		"Some crests must settle offshore, or the splash test proves nothing."
	)
	var seen_peak := 0
	var seen_foam := false
	var seen_settled := false
	var seen_overlapping_crests := false
	var foam_was_playing := false
	for frame in 700:
		await physics_frame
		var active_crests := 0
		var active_peak := false
		for crest_index in shore_wave.crest_count():
			if not shore_wave.crest_is_active(crest_index):
				continue
			active_crests += 1
			var crest_frame := shore_wave.crest_sprite(crest_index).frame
			active_peak = active_peak or crest_frame == shore_wave.peak_frame
			assert(
				crest_frame <= shore_wave.peak_frame,
				"A shore crest must never reach the pack's full-size roller."
			)
			seen_peak = maxi(seen_peak, crest_frame)
			var progress := shore_wave.crest_progress(crest_index)
			if progress > 0.9 and crest_frame == 0:
				seen_settled = true
		seen_overlapping_crests = (
			seen_overlapping_crests
			or (active_crests >= 2 and active_peak)
		)
		var foam_playing := shore_wave.shore_foam_is_playing()
		if foam_playing and not foam_was_playing:
			# The splash is caused by water arriving, so at the instant it starts
			# some crest must actually be at the beach.
			var crest_at_shore := false
			for crest_index in shore_wave.crest_count():
				crest_at_shore = crest_at_shore or shore_wave.crest_reaches_shore(
					crest_index,
					shore_wave.crest_progress(crest_index)
				)
			assert(
				crest_at_shore,
				"The shore splash must only fire when a crest reaches the sand."
			)
			# Arriving is not enough: the wave has to still be there. A crest
			# that peaks early has collapsed by the time it lands, and the
			# splash then plays over empty water.
			var arriving_crest_is_risen := false
			for crest_index in shore_wave.crest_count():
				if not shore_wave.crest_reaches_shore(
					crest_index,
					shore_wave.crest_progress(crest_index)
				):
					continue
				arriving_crest_is_risen = (
					arriving_crest_is_risen
					or shore_wave.crest_sprite(crest_index).frame
					== shore_wave.peak_frame
				)
			for crest_index in shore_wave.crest_count():
				if not shore_wave.crest_reaches_shore(
					crest_index,
					shore_wave.crest_progress(crest_index)
				):
					continue
				assert(
					not shore_wave.crest_sprite(crest_index).visible,
					(
						"A breaking crest must be gone the instant its splash "
						+ "appears, so the wave reads as becoming the effect "
						+ "rather than standing behind it."
					)
				)
				assert(
					absf(
						shore_wave.shore_foam_sprite().global_position.x
						- shore_wave.crest_sprite(crest_index).global_position.x
					) <= absf(shore_wave.foam_body_offset) + 0.05,
					(
						"The splash must land on the crest that caused it, not "
						+ "at a fixed point the wave may not have reached."
					)
				)
			assert(
				arriving_crest_is_risen,
				(
					"The crest landing on the beach must still be at full size "
					+ "when its splash fires, or the two read as unrelated."
				)
			)
		foam_was_playing = foam_playing
		seen_foam = seen_foam or foam_playing
		assert(
			shore_wave.shore_foam_sprite().frame < shore_wave.foam_frame_limit,
			"The shore splash must stay within its authored opening frames."
		)
	assert(
		seen_peak == shore_wave.peak_frame,
		"Crests must swell to their authored peak."
	)
	assert(seen_settled, "Crests must sink back into the water rather than vanish.")
	assert(seen_foam, "Water reaching the beach must land the shore splash.")
	assert(
		seen_overlapping_crests,
		(
			"A new small crest must already be visible while another crest is "
			+ "fully risen, so the surf reads as a continuous sequence rather "
			+ "than one wave on a timer."
		)
	)

	var player := level.player
	var pickup := level.get_node("DoubleJumpPickup") as AbilityPickup3D
	var checkpoint := level.get_node(
		"Checkpoints/PickupCheckpoint"
	) as LevelCheckpoint3D
	assert(not player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not pickup.is_claimed())
	assert(not checkpoint.is_activated())
	var water_splash := level.get_node(
		"WaterDeathSplash"
	) as PixelWaterDeathSplash3D
	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(-0.8, 0.2, 0)))
	for frame in 10:
		await physics_frame
		if player.is_dead():
			break
	assert(player.is_dead(), "Entering the shoreline water must kill the player.")
	assert(player.death_kind() == PlayerCharacter.DEATH_KIND_WATER)
	assert(water_splash.is_playing())
	assert(not player.visible)
	for frame in 40:
		await physics_frame
	assert(not player.is_dead())
	assert(player.visible)
	assert(not water_splash.is_playing())
	assert(absf(player.global_position.x - 1.8) < 0.2)

	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(31.7, 1.34, 0)))
	for frame in 5:
		await physics_frame
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(pickup.is_claimed())
	assert(
		(game_root.get_node("Interface/AbilityTutorial") as Control).visible,
		"Collecting the candidate pickup must explain Double Jump."
	)

	player.reset_at(Transform3D(Basis.IDENTITY, Vector3(36.3, 1.34, 0)))
	for frame in 12:
		await physics_frame
	assert(checkpoint.is_activated())
	assert(level.active_checkpoint_index() == 2)

	player.kill()
	for frame in 40:
		await physics_frame
	assert(not player.is_dead())
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(pickup.is_claimed())
	assert(absf(player.global_position.x - 36.3) < 0.2)

	level._reset_run()
	await physics_frame
	assert(player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(pickup.is_claimed())
	assert(not checkpoint.is_activated())

	game_root.show_level_select()
	game_root.load_developer_level(definition)
	await process_frame
	var fresh_level := game_root.current_level as LevelSession3D
	assert(fresh_level != level)
	assert(not fresh_level.player.has_ability(PlayerAbility.DOUBLE_JUMP))
	assert(not (fresh_level.get_node("DoubleJumpPickup") as AbilityPickup3D).is_claimed())
	assert(game_root.current_world_definition == null)

	print("Arrival / Shoreline slice structure and isolated session validation passed.")
	quit(0)


func _validate_geometry(level: LevelSession3D) -> void:
	var sand := _platform(level, "SandArrival")
	var transition := _platform(level, "ShorelineTransition")
	var approach := _platform(level, "GreenApproach")
	var pickup := _platform(level, "PickupIsland")
	var height := _platform(level, "HeightProof")
	var distance := _platform(level, "DistanceProof")
	var finish := _platform(level, "FinishGround")
	assert(
		is_zero_approx(_gap(sand, transition))
		and is_zero_approx(_gap(transition, approach)),
		"The Green Zone bank must begin directly at the shoreline edge."
	)
	assert(is_equal_approx(sand.size.x, 10.24))
	assert(is_equal_approx(transition.size.x, 3.84))
	assert(is_equal_approx(approach.size.x, 11.52))
	for bank_visual in [sand, transition, approach]:
		assert(
			not bank_visual.collision_enabled,
			"The shoreline bank visuals must use their exact authored colliders."
		)
	var sand_collision := level.get_node("OpeningGroundCollision") as StaticBody3D
	var sand_shape := sand_collision.get_node("Collision") as CollisionShape3D
	var sand_box := sand_shape.shape as BoxShape3D
	assert(sand_collision.global_position.is_equal_approx(Vector3(7.04, -1.28, 0.0)))
	assert(sand_box.size.is_equal_approx(Vector3(14.08, 2.56, 2.0)))
	var rise_collision := level.get_node("GreenRiseCollision") as StaticBody3D
	var rise_shape := rise_collision.get_node("Collision") as CollisionShape3D
	var rise_box := rise_shape.shape as BoxShape3D
	assert(rise_collision.global_position.is_equal_approx(Vector3(19.84, -1.28, 0.0)))
	assert(rise_box.size.is_equal_approx(Vector3(11.52, 3.84, 2.0)))
	assert(
		is_equal_approx(
			_top(approach) - _top(transition),
			PixelPlatform3D.TILE_WORLD_SIZE * 0.5
		)
	)
	assert(is_equal_approx(_gap(approach, pickup), 3.84))
	assert(is_equal_approx(_gap(pickup, height), 3.84))
	assert(
		_top(height) - _top(pickup) > level.player.movement.ideal_jump_height(),
		"The pickup's first proof must exceed a normal Jump's height."
	)
	assert(is_equal_approx(_gap(height, distance), 7.68))
	assert(is_equal_approx(_top(height) - _top(distance), 1.92))
	assert(is_equal_approx(_gap(distance, finish), 2.56))
	for grounded_terrain in [sand, transition]:
		assert(is_equal_approx(grounded_terrain.size.y, 2.56))
		assert(
			is_zero_approx(_top(grounded_terrain)),
			"Natural two-tile terrain must not move its walkable top."
		)
	for raised_terrain in [approach, pickup, finish]:
		assert(is_equal_approx(raised_terrain.size.y, 3.84))
		assert(
			is_equal_approx(
				_top(raised_terrain),
				PixelPlatform3D.TILE_WORLD_SIZE * 0.5
			),
			"The Green Zone route must keep its restrained half-tile shoreline rise."
		)
	assert(is_equal_approx(height.size.y, 1.28))
	assert(is_equal_approx(distance.size.y, 1.28))
	assert(
		level.get_node_or_null("Platforms/HeightProofCatch") == null,
		"The Double Jump proof must not have playable ground beneath it."
	)
	for platform in [sand, transition, approach, pickup, height, distance, finish]:
		assert(
			absf(platform.size.x / PixelPlatform3D.TILE_WORLD_SIZE
			- roundf(platform.size.x / PixelPlatform3D.TILE_WORLD_SIZE)) < EPSILON
		)


func _validate_presentation(level: LevelSession3D) -> void:
	var sand := _platform(level, "SandArrival")
	var transition := _platform(level, "ShorelineTransition")
	var approach := _platform(level, "GreenApproach")
	var finish := _platform(level, "FinishGround")
	assert(
		sand.style.resource_path.ends_with("shoreline_sand.tres"),
		"Only the arrival island should use the sand platform style."
	)
	assert(
		transition.style.resource_path.ends_with("shoreline_to_green.tres"),
		"The final low shoreline tiles must hide their palette change under rock."
	)
	assert(
		approach.style.resource_path.ends_with("green_zone.tres"),
		"The route must visibly transition into Green Zone terrain."
	)
	assert(approach.style.has_deep_row())
	assert(approach.style.has_bottom_row())
	assert(approach.style.body_right.resource_path.ends_with("body_right.png"))
	assert(approach.style.deep.resource_path.ends_with("deep.png"))
	assert(approach.style.bottom.resource_path.ends_with("bottom.png"))
	var rendered_bottom := approach.get_node("Tile_02_01") as Sprite3D
	assert(
		rendered_bottom.texture == approach.style.bottom,
		"Three-row Green Zone terrain must finish with its authored bottom row."
	)
	assert(not sand.cap_right_edge)
	assert(transition.cap_left_edge)
	assert(transition.cap_right_edge)
	assert(approach.cap_left_edge)
	var transition_textures: Array[Texture2D] = [
		transition.style.top_left,
		transition.style.top,
		transition.style.top_right,
		transition.style.body_left,
		transition.style.body,
		transition.style.body_right,
	]
	for texture_index in transition_textures.size():
		var texture := transition_textures[texture_index]
		assert(texture != null)
		var row_name := "top" if texture_index < 3 else "body"
		var column := texture_index if texture_index < 3 else texture_index - 3
		assert(texture.resource_path.ends_with(
			"transition_%s_%d.png" % [row_name, column]
		))
	var sand_top := load(
		"res://assets/art/green_zone/shoreline/tiles/top.png"
	) as Texture2D
	var sand_body := load(
		"res://assets/art/green_zone/shoreline/tiles/body.png"
	) as Texture2D
	_assert_same_pixels(transition.style.top_left, sand_top)
	_assert_same_pixels(transition.style.top, sand_top)
	_assert_same_pixels(transition.style.body_left, sand_body)
	_assert_same_pixels(transition.style.body, sand_body)
	var water := level.get_node("Hazards/ShoreWater") as PixelWaterStrip3D
	assert(is_equal_approx(water.width, 12.8))
	assert(water.body_rows == 3)
	assert(water.frame_count == 4)
	assert(is_equal_approx(water.frame_rate, 8.0))
	assert(water.tile_sheet.resource_path.ends_with("water_tiles.png"))
	assert(water.runtime_tile_count() == 40)
	var surface_tile := water.get_node("Surface_00") as Sprite3D
	var surface_atlas := surface_tile.texture as AtlasTexture
	assert(surface_atlas != null)
	assert(surface_atlas.atlas == water.tile_sheet)
	assert(is_zero_approx(surface_atlas.region.position.y))
	assert(is_equal_approx(
		surface_atlas.region.position.x,
		water.current_frame() * 32.0
	))
	var third_body_tile := water.get_node("Body_03_00") as Sprite3D
	var third_body_atlas := third_body_tile.texture as AtlasTexture
	assert(third_body_atlas != null)
	assert(is_equal_approx(third_body_atlas.region.position.y, 96.0))
	assert(is_equal_approx(
		third_body_atlas.region.position.x,
		water.current_frame() * 32.0
	))
	assert(is_equal_approx(water.global_position.x - water.width * 0.5, -12.8))
	assert(is_zero_approx(water.global_position.x + water.width * 0.5))
	assert(is_zero_approx(water.global_position.y))
	var water_contact := level.get_node(
		"Hazards/ShoreWaterContact"
	) as Hazard3D
	var water_collision := water_contact.get_node("Collision") as CollisionShape3D
	var water_box := water_collision.shape as BoxShape3D
	assert(is_equal_approx(water_contact.global_position.x, -6.4))
	assert(is_equal_approx(water_box.size.x, 12.8))
	assert(water_contact.death_kind == PlayerCharacter.DEATH_KIND_WATER)
	assert(
		water_contact.global_position.y + water_box.size.y * 0.5 < 0.0,
		"Lethal water contact must sit below the visible crest for fair edge play."
	)
	var shore_wave := level.get_node("ShoreWave") as PixelShoreWave3D
	assert(shore_wave != null)
	assert(is_equal_approx(shore_wave.global_position.x, water.global_position.x))
	assert(
		is_equal_approx(shore_wave.global_position.y, 0.0),
		"Surf sits on the water surface so the clip's own waterline lines up."
	)
	assert(
		shore_wave.crest_texture.resource_path.ends_with("wave_start.png"),
		"Crests come from the clip whose low frames are small waves."
	)
	assert(shore_wave.foam_texture.resource_path.ends_with("shore_foam.png"))
	assert(
		shore_wave.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"Shoreline surf is presentation-only and must never affect movement."
	)
	var water_left := water.global_position.x - water.width * 0.5
	var water_right := water.global_position.x + water.width * 0.5
	var foam := shore_wave.shore_foam_sprite()
	assert(
		is_equal_approx(foam.pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE),
		"Foam renders at the terrain pixel scale, not a finer one."
	)
	assert(
		water.face_depth < foam.global_position.z
		and foam.global_position.z < sand.face_depth,
		"The splash is surface spray and stays in front of the water."
	)
	for crest_index in shore_wave.crest_count():
		var crest := shore_wave.crest_sprite(crest_index)
		assert(
			is_equal_approx(crest.pixel_size, PixelPlatform3D.TILE_PIXEL_SIZE),
			"Surf renders at the terrain pixel scale, not a finer one."
		)
		assert(not crest.flip_h, "The source crest already faces the shore.")
		var break_x := (
			shore_wave.global_position.x
			+ shore_wave.crest_offsets_x[crest_index]
			+ shore_wave.crest_travel
		)
		assert(
			break_x > water_left
			and break_x <= water_right + shore_wave.shoreline_wash + EPSILON,
			"Crests may lap onto the sand but never run across the tiles."
		)
		assert(
			foam.render_priority > crest.render_priority,
			"The splash must stay a visible accent in front of the crests."
		)
		assert(
			crest.global_position.z < water.face_depth,
			(
				"Crests render behind the water face so the surface masks a "
				+ "submerged base. Without that the sink does nothing."
			)
		)
		assert(
			crest.render_priority < 0,
			"Depth alone is not enough; the crest must also sort behind the water."
		)
		assert(crest.global_position.z < level.player.get_node(
			"PixelVisual/Body"
		).global_position.z)
	var kill_plane := level.get_node("KillPlane") as Area3D
	var kill_shape := kill_plane.get_node("Collision") as CollisionShape3D
	var kill_box := kill_shape.shape as BoxShape3D
	assert(
		kill_plane.global_position.y + kill_box.size.y * 0.5 < -3.0,
		"The global fall plane must stay beneath later platforming gaps."
	)
	assert(level.get_node_or_null("Props/ArrivalSurfboard") == null)
	assert(level.get_node_or_null("Props/ArrivalUmbrella") == null)
	var transition_talus := level.get_node("Props/TransitionTalus") as Node3D
	var transition_outcrop := transition_talus.get_node(
		"TransitionOutcrop"
	) as Sprite3D
	assert(transition_outcrop.texture.resource_path.ends_with(
		"transition_outcrop.png"
	))
	_assert_sprite_spans_terrain(
		transition_outcrop,
		_top(approach),
		-2.56
	)
	var outcrop_width := (
		float(transition_outcrop.texture.get_width())
		* transition_outcrop.pixel_size
		* transition_outcrop.scale.x
	)
	var outcrop_height := (
		float(transition_outcrop.texture.get_height())
		* transition_outcrop.pixel_size
		* transition_outcrop.scale.y
	)
	var hidden_surface_change_x := _right(transition)
	assert(
		transition_outcrop.global_position.x - outcrop_width * 0.5
		<= hidden_surface_change_x + EPSILON,
		"The outcrop must cover the held-back surface transition."
	)
	assert(
		transition_outcrop.global_position.x + outcrop_width * 0.5
		>= _left(approach) + PixelPlatform3D.TILE_WORLD_SIZE,
		"The outcrop must overlap the Green Zone body, not sit beside it."
	)
	var peak_height := (
		transition_outcrop.global_position.y + outcrop_height * 0.5
	)
	assert(
		peak_height >= _top(approach) - EPSILON
		and peak_height - _top(approach) <= 0.04,
		"The outcrop must meet the restrained Green Zone rise without towering over it."
	)
	assert(
		transition_outcrop.find_children(
			"*", "CollisionObject3D", true, false
		).is_empty(),
		"The embedded outcrop is presentation-only and must not block movement."
	)
	var player_body := level.player.get_node("PixelVisual/Body") as Sprite3D
	assert(transition_outcrop.render_priority < player_body.render_priority)
	assert(transition_outcrop.global_position.z < player_body.global_position.z)
	var talus_rocks: Array[Sprite3D] = []
	var talus_textures := {}
	for child in transition_talus.get_children():
		assert(child is Sprite3D)
		var rock := child as Sprite3D
		talus_rocks.append(rock)
		talus_textures[rock.texture.resource_path] = true
		assert(rock.texture != null)
		assert(rock.scale.x > 0.0 and rock.scale.y > 0.0)
		assert(rock.global_position.z < player_body.global_position.z)
		assert(rock.render_priority < player_body.render_priority)
		assert(
			rock.find_children(
				"*", "CollisionObject3D", true, false
			).is_empty(),
			"The transition talus must remain presentation-only."
		)
	assert(talus_rocks.size() >= 5 and talus_rocks.size() <= 8)
	assert(
		talus_textures.size() >= 5,
		"The talus must use the full matching rock family, not scaled duplicates."
	)
	talus_rocks.sort_custom(func(a: Sprite3D, b: Sprite3D) -> bool:
		return a.global_position.x > b.global_position.x
	)
	assert(talus_rocks.front() == transition_outcrop)
	for rock in talus_rocks:
		assert(
			_talus_sprite_is_supported(rock, talus_rocks, -2.56),
			"%s must be grounded, buried, or visibly supported by the layered pile."
			% rock.name
		)
	for chain_index in range(1, talus_rocks.size()):
		var previous := talus_rocks[chain_index - 1]
		var current := talus_rocks[chain_index]
		assert(_sprite_rendered_width(current) < _sprite_rendered_width(previous))
		assert(_sprite_visible_top(current) < _sprite_visible_top(previous))
		assert(
			_sprite_visible_right(current) >= _sprite_visible_left(previous) + 0.04,
			"The talus must read as one overlapping geological chain."
		)
		assert(
			not is_equal_approx(current.global_position.z, previous.global_position.z),
			"Overlapping talus sprites need distinct depth to avoid flicker."
		)
	assert(
		_sprite_visible_left(talus_rocks.back())
		<= _sprite_visible_left(transition_outcrop) - 4.2,
		"The descending talus must extend meaningfully into the sand body."
	)
	var transition_bush := level.get_node("Props/TransitionBush") as Sprite3D
	var approach_tree := level.get_node("Props/ApproachTree") as Sprite3D
	var approach_tree_bush := level.get_node("Props/ApproachTreeBush") as Sprite3D
	var approach_grass := level.get_node("Props/ApproachGrass") as Sprite3D
	var pickup_bush := level.get_node("Props/PickupBush") as Sprite3D
	var pickup_grass := level.get_node("Props/PickupGrass") as Sprite3D
	var finish_bush := level.get_node("Props/FinishBush") as Sprite3D
	assert(transition_bush.texture.resource_path.ends_with("bush_low.png"))
	assert(approach_tree.texture.resource_path.ends_with("tree_small_grounded.png"))
	assert(approach_tree_bush.texture.resource_path.ends_with("bush_small.png"))
	assert(approach_grass.texture.resource_path.ends_with("grass_tuft_sparse.png"))
	assert(pickup_bush.texture == transition_bush.texture)
	assert(pickup_grass.texture.resource_path.ends_with("grass_tuft_thin.png"))
	assert(finish_bush.texture == approach_tree_bush.texture)
	for approach_prop in [
		transition_bush,
		approach_tree,
		approach_tree_bush,
		approach_grass,
	]:
		_assert_passive_scenery(approach_prop, _top(approach), player_body)
	var pickup_top := _top(_platform(level, "PickupIsland"))
	for pickup_prop in [pickup_bush, pickup_grass]:
		_assert_passive_scenery(pickup_prop, pickup_top, player_body)
	_assert_passive_scenery(finish_bush, _top(finish), player_body)
	var water_splash := level.get_node(
		"WaterDeathSplash"
	) as PixelWaterDeathSplash3D
	var splash_sprite := water_splash.get_node("Sprite") as Sprite3D
	assert(
		splash_sprite.texture.resource_path.ends_with("water_death_splash.png")
	)
	assert(water_splash.frame_count == 6)
	assert(is_equal_approx(water_splash.frame_rate, 12.0))
	_assert_passive_scenery(
		level.get_node("Props/FinishTree") as Sprite3D,
		_top(finish),
		player_body
	)
	var finish_stone := level.get_node("Props/FinishStone") as Sprite3D
	assert(finish_stone.texture.resource_path.ends_with("stone_medium.png"))
	_assert_passive_scenery(
		finish_stone,
		_top(finish),
		player_body
	)
	var background := level.get_node("Background") as PixelBackgroundRig3D
	assert(background != null)
	assert(background.profile != null)
	assert(background.profile.profile_id == &"arrival_shoreline")
	assert(background.profile.validation_errors().is_empty())
	assert(is_equal_approx(background.profile.pixel_size, 0.04))
	assert(background.runtime_layer_count() == 3)
	var expected_paths := PackedStringArray([
		"res://assets/art/green_zone/background/clouds/broad.png",
		"res://assets/art/green_zone/background/clouds/puff.png",
		"res://assets/art/green_zone/background/layer_5.png",
	])
	var expected_sizes := [Vector2i(144, 33), Vector2i(72, 51), Vector2i(576, 324)]
	for layer_index in background.profile.layers.size():
		var layer := background.profile.layers[layer_index]
		assert(layer.texture.resource_path == expected_paths[layer_index])
		assert(
			Vector2i(layer.texture.get_width(), layer.texture.get_height())
			== expected_sizes[layer_index]
		)
		assert(layer.cover_viewport_width == (layer_index == 2))
		assert(
			layer.horizontal_policy
			== (
				PixelBackgroundLayerProfile.HorizontalPolicy.WORLD_LOCKED
				if layer_index < 2
				else PixelBackgroundLayerProfile.HorizontalPolicy.PARALLAX
			)
		)
		assert(
			layer.vertical_policy
			== PixelBackgroundLayerProfile.VerticalPolicy.SCREEN_LOCKED
		)
		var copies := background.runtime_copies(layer_index)
		assert(copies.size() >= 3)
		for sprite in copies:
			assert(is_equal_approx(sprite.pixel_size, 0.04))
			assert(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
			assert(not sprite.shaded)
			assert(
				sprite.cast_shadow
				== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)


func _assert_sprite_grounded(sprite: Sprite3D, support_top: float) -> void:
	assert(sprite != null, "Grounded presentation sprite must exist.")
	assert(sprite.texture != null, "%s must have a texture." % sprite.name)
	var rendered_height := (
		float(sprite.texture.get_height())
		* sprite.pixel_size
		* sprite.scale.y
	)
	assert(
		absf(sprite.global_position.y - rendered_height * 0.5 - support_top) < EPSILON,
		"%s must be explicitly bottom-anchored to its support." % sprite.name
	)


func _assert_passive_scenery(
	sprite: Sprite3D,
	support_top: float,
	player_body: Sprite3D
) -> void:
	_assert_sprite_grounded(sprite, support_top)
	assert(sprite.global_position.z < player_body.global_position.z)
	assert(
		sprite.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"%s must remain non-colliding scenery." % sprite.name
	)


func _sprite_rendered_width(sprite: Sprite3D) -> float:
	return (
		float(sprite.texture.get_width())
		* sprite.pixel_size
		* sprite.scale.x
	)


func _sprite_visible_rect(sprite: Sprite3D) -> Rect2:
	var image := sprite.texture.get_image()
	var opaque_pixels := image.get_used_rect()
	var texture_width := float(sprite.texture.get_width())
	var texture_height := float(sprite.texture.get_height())
	var left_pixel := float(opaque_pixels.position.x)
	var right_pixel := float(opaque_pixels.end.x)
	if sprite.flip_h:
		var flipped_left := texture_width - right_pixel
		right_pixel = texture_width - left_pixel
		left_pixel = flipped_left
	var left := (
		sprite.global_position.x
		+ (left_pixel - texture_width * 0.5)
		* sprite.pixel_size
		* sprite.scale.x
	)
	var right := (
		sprite.global_position.x
		+ (right_pixel - texture_width * 0.5)
		* sprite.pixel_size
		* sprite.scale.x
	)
	var bottom := (
		sprite.global_position.y
		+ (texture_height * 0.5 - float(opaque_pixels.end.y))
		* sprite.pixel_size
		* sprite.scale.y
	)
	var top := (
		sprite.global_position.y
		+ (texture_height * 0.5 - float(opaque_pixels.position.y))
		* sprite.pixel_size
		* sprite.scale.y
	)
	return Rect2(left, bottom, right - left, top - bottom)


func _sprite_visible_left(sprite: Sprite3D) -> float:
	return _sprite_visible_rect(sprite).position.x


func _sprite_visible_right(sprite: Sprite3D) -> float:
	return _sprite_visible_rect(sprite).end.x


func _sprite_visible_top(sprite: Sprite3D) -> float:
	return _sprite_visible_rect(sprite).end.y


func _sprite_visible_bottom(sprite: Sprite3D) -> float:
	return _sprite_visible_rect(sprite).position.y


func _talus_sprite_is_supported(
	sprite: Sprite3D,
	talus_rocks: Array[Sprite3D],
	support_y: float
) -> bool:
	var bottom := _sprite_visible_bottom(sprite)
	if bottom <= support_y + EPSILON:
		return bottom >= support_y - 0.2
	if bottom > support_y + 0.36:
		return false

	var left := _sprite_visible_left(sprite)
	var right := _sprite_visible_right(sprite)
	var support_intervals: Array[Vector2] = []
	for other in talus_rocks:
		if other == sprite:
			continue
		if other.global_position.z <= sprite.global_position.z + EPSILON:
			continue
		if _sprite_visible_bottom(other) > support_y + EPSILON:
			continue
		var overlap_left := maxf(left, _sprite_visible_left(other))
		var overlap_right := minf(right, _sprite_visible_right(other))
		if overlap_right > overlap_left + EPSILON:
			support_intervals.append(Vector2(overlap_left, overlap_right))
	support_intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x
	)
	var covered_until := left
	for interval in support_intervals:
		if interval.x > covered_until + EPSILON:
			return false
		covered_until = maxf(covered_until, interval.y)
		if covered_until >= right - EPSILON:
			return true
	return false


func _assert_same_pixels(actual: Texture2D, expected: Texture2D) -> void:
	assert(actual != null and expected != null)
	var actual_image := actual.get_image()
	var expected_image := expected.get_image()
	assert(actual_image.get_size() == expected_image.get_size())
	actual_image.convert(Image.FORMAT_RGBA8)
	expected_image.convert(Image.FORMAT_RGBA8)
	assert(
		actual_image.get_data() == expected_image.get_data(),
		"The exposed left side of the terrain transition must stay clean sand."
	)


func _assert_sprite_spans_terrain(
	sprite: Sprite3D,
	support_top: float,
	terrain_bottom: float
) -> void:
	assert(sprite != null, "Terrain-spanning presentation sprite must exist.")
	assert(sprite.texture != null, "%s must have a texture." % sprite.name)
	var rendered_height := (
		float(sprite.texture.get_height())
		* sprite.pixel_size
		* sprite.scale.y
	)
	var sprite_top := sprite.global_position.y + rendered_height * 0.5
	var sprite_bottom := sprite.global_position.y - rendered_height * 0.5
	assert(
		sprite_top >= support_top - EPSILON,
		"%s must meet the walkable surface." % sprite.name
	)
	assert(
		sprite_bottom <= terrain_bottom + EPSILON,
		"%s must cover the full visible terrain seam." % sprite.name
	)


func _scoped_group_count(level: LevelSession3D, group: StringName) -> int:
	return get_nodes_in_group(group).filter(
		func(node: Node) -> bool:
			return level.is_ancestor_of(node)
	).size()


func _toggle_gameplay_tools(game_root: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F1
	game_root._unhandled_input(event)


func _platform(level: LevelSession3D, node_name: String) -> PixelPlatform3D:
	return level.get_node("Platforms/%s" % node_name) as PixelPlatform3D


func _left(platform: PixelPlatform3D) -> float:
	return platform.global_position.x - platform.size.x * 0.5


func _right(platform: PixelPlatform3D) -> float:
	return platform.global_position.x + platform.size.x * 0.5


func _top(platform: PixelPlatform3D) -> float:
	return platform.global_position.y + platform.size.y * 0.5


func _gap(left_platform: PixelPlatform3D, right_platform: PixelPlatform3D) -> float:
	return _left(right_platform) - _right(left_platform)
