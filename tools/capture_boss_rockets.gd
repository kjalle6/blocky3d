extends SceneTree
## Rocket salvo at normal gameplay zoom in Boss Arena WIP. Run with -Visual.
## Saves frames from launch, early, mid and late flight under build/previews/boss_rockets.
const OUTPUT := "res://build/previews/boss_rockets"
const MOMENTS := [0.05, 0.1, 0.17, 0.25, 0.5, 0.8, 1.2]

func _init() -> void:
	call_deferred("_run")
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("Boss rocket capture timed out.")
		quit(1))

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var game: Node = load("res://scenes/app/game_root.tscn").instantiate()
	game.persist_progression = false
	root.add_child(game)
	await process_frame
	for candidate in game.developer_level_definitions:
		if candidate.level_id == &"dev_boss_arena_wip": game.load_developer_level(candidate)
	for i in 30: await process_frame
	var level: LevelSession3D = game.current_level
	var boss: Node = level.get_node("GreenZoneBoss")
	level.get_node("BossLabController").test_missile_ripple(-1.0)
	while boss.missiles_fired == 0:
		await physics_frame
	var start := Time.get_ticks_msec()
	for moment in MOMENTS:
		while Time.get_ticks_msec() - start < moment * 1000.0:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/salvo_%03d.png" % [OUTPUT, int(moment * 100)]
		assert(root.get_texture().get_image().save_png(path) == OK)
	print("Captured the boss rocket salvo at ", MOMENTS, " s after the first launch.")
	quit(0)
