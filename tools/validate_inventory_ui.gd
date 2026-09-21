extends SceneTree
## Inventory pause ownership, assignment vs consumption, and reward receipt lifecycle.


func _init() -> void:
	call_deferred("_run")
	create_timer(15.0, true).timeout.connect(func() -> void: quit(1))


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	# Exercise the menu handler deterministically; MCP covers real viewport routing.
	root.get_node("GameRoot/CampaignMenu")._input(event)


func _run() -> void:
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	assert(InputMap.action_has_event("inventory", tab), "Tab must open inventory.")
	var app := preload("res://scenes/app/game_root.tscn").instantiate()
	app.persist_progression = false
	root.add_child(app)
	app.load_developer_room()
	await process_frame
	await physics_frame
	var session: LevelSession3D = app.current_level
	var player := session.player
	var menu: CanvasLayer = app.campaign_menu
	player.health.reset(100, 25)
	_press(&"inventory")
	await process_frame
	assert(paused and menu.page == "inventory")
	var position := player.global_position
	Input.action_press("move_right")
	await create_timer(0.1, true).timeout
	Input.action_release("move_right")
	assert(player.global_position == position, "Inventory freezes the player.")
	var panel: PanelContainer = menu.inventory_panel
	(panel.get("_item_buttons")[&"basic_heal"] as Button).grab_focus()
	(panel.get("_item_buttons")[&"medical_bag"] as Button).mouse_entered.emit()
	assert(panel.get("_selected") == &"medical_bag", "Hover changes the assignment target without clicking.")
	_press(&"quick_item_2")
	await process_frame
	assert(player.inventory.quick_slots[1] == &"medical_bag")
	assert(player.inventory.count(&"medical_bag") == 2 and player.health.current == 25,
		"Assigning with E while paused must not heal or spend an item.")
	(panel.get("_item_buttons")[&"large_heal_test"] as Button).mouse_entered.emit()
	_press(&"quick_item_1")
	assert(player.inventory.quick_slots[0] == &"large_heal_test", "Q assigns the newly hovered item.")
	(panel.get("_grid").get_child(player.inventory.quantities.size()) as Button).mouse_entered.emit()
	_press(&"quick_item_2")
	assert(player.inventory.quick_slots[1] == &"medical_bag" and player.health.current == 25,
		"Hovering an empty cell must not assign the previous item or consume anything.")
	(panel.get("_item_buttons")[&"medical_bag"] as Button).mouse_entered.emit()
	panel._sort_items(1)
	assert(panel.get("_grid").get_child(0).name == "Item_handgun_ammo", "Quantity sort puts the largest stack first.")
	panel._sort_items(2)
	assert(panel.get("_grid").get_child(0).name == "Item_medical_bag", "Healing sort puts the strongest medicine first.")
	assert(panel.get("_selected") == &"medical_bag" and player.inventory.quick_slots[1] == &"medical_bag",
		"Sorting preserves the selected item and quick-slot references.")
	assert(player.inventory.count(&"medical_bag") == 2 and player.health.current == 25,
		"Sorting is presentation only.")
	panel._sort_items(0)
	# Overflow changes only the one grid's scroll range, never the window size.
	var old_size := panel.size
	var grid: GridContainer = panel.get("_grid")
	for index in 20:
		grid.add_child(grid.get_child(29).duplicate())
	await process_frame
	await process_frame
	var scroll: ScrollContainer = panel.get("_scroll")
	var handle: VSlider = panel.get("_scroll_handle")
	assert(panel.size == old_size and handle.editable)
	assert(handle.size.y * handle.scale.y == scroll.size.y, "The whole scrollbar must be hittable.")
	var native_bar := scroll.get_v_scroll_bar()
	var overflow := native_bar.max_value - native_bar.page
	assert(overflow > 0)
	handle.value = 0
	assert(scroll.scroll_vertical == roundi(overflow), "Dragging down reaches the final grid row.")
	scroll.scroll_vertical = 0
	assert(is_equal_approx(handle.value, handle.max_value), "Wheel/native scrolling updates the visible handle.")
	panel.get("_item_menu").id_pressed.emit(0)
	assert(player.inventory.quick_slots[0] == &"medical_bag" and player.health.current == 25
		and player.inventory.count(&"medical_bag") == 2, "Context assignment must not consume or heal.")
	await process_frame
	await process_frame
	assert(grid.get_child_count() == 30 and not handle.editable, "Short inventories keep one fixed window.")
	_press(&"inventory")
	await process_frame
	assert(not paused and menu.page.is_empty())
	Input.action_press("quick_item_2")
	await physics_frame
	await process_frame
	Input.action_release("quick_item_2")
	assert(player.health.current == 100 and player.inventory.count(&"medical_bag") == 1,
		"E must use the selected 75-HP item after resuming.")
	menu.show_pause()
	menu.show_inventory()
	_press(&"ui_cancel")
	assert(paused and menu.page == "pause", "Inventory opened from pause returns to pause.")
	menu.close()
	var chest := session.get_node("HealingChestFixture") as ItemReward3D
	var before := player.inventory.count(&"basic_heal")
	assert(chest.collect())
	assert(player.inventory.count(&"basic_heal") == before + 1)
	assert(app.loot_receipt.visible and app.loot_receipt.get("_items")[&"basic_heal"] == 1)
	assert(not chest.collect() and app.loot_receipt.get("_items")[&"basic_heal"] == 1,
		"Duplicate collection must not duplicate either rewards or their receipt.")
	menu.show_inventory()
	var remaining: float = app.loot_receipt.get("_remaining")
	await create_timer(0.1, true).timeout
	assert(is_equal_approx(remaining, app.loot_receipt.get("_remaining")),
		"Receipt time must pause with the inventory.")
	menu.close()
	session._reset_run()
	assert(not app.loot_receipt.visible, "Reset clears old notifications.")
	player.inventory.reset()
	menu.show_inventory()
	assert(paused and panel.get("_selected") == &"", "Empty inventory remains usable.")
	_press(&"ui_cancel")
	assert(not paused)
	app.load_level("arrival_shoreline")
	await process_frame
	assert(not app.loot_receipt.visible and app.current_level.player.inventory.count(&"medical_bag") == 0)
	app.free()
	print("Inventory UI passed: Tab/pause, Q/E assignment, 75-HP use, nested menus, chest receipt, empty inventory and session cleanup.")
	quit()
