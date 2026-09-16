extends Node

func _ready() -> void:
	SoundManager.is_muted = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var ipad_size := Vector2i(1194, 834)
	get_window().content_scale_size = ipad_size
	DisplayServer.window_set_size(ipad_size)

	# 1. Capture MainMenu
	var menu: MainMenu = load("res://scenes/MainMenu.tscn").instantiate()
	add_child(menu)
	for i in range(15):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-menu.png")
	
	# Capture match settings
	menu.set_state("match_settings")
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-match-settings.png")
	
	# Capture lobby
	menu.set_state("lobby")
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-lobby.png")
	
	menu.queue_free()
	for i in range(5):
		await get_tree().process_frame
		
	# 2. Capture Main Game
	var game: Main = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.goblin_ai.set_process(false)
	game.time_of_day_system.set_process(false)
	game.time_of_day_system.time_of_day = 0.35
	game.time_of_day_system._update_lighting()
	
	for i in range(25):
		await get_tree().process_frame
		
	game.responsive_hud.layout()
	if not game.all_units.is_empty():
		game.selection_system.select_single_unit(game.all_units[0], false)
	for i in range(10):
		await get_tree().process_frame
		
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-gameplay.png")
	
	# Open build dock
	game.responsive_hud.build_open = true
	game.responsive_hud.layout()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-build-dock.png")
	game.responsive_hud.build_open = false
	game.responsive_hud.layout()
	
	# Select a building (Workshop)
	var workshop := Building.new()
	game.buildings_container.add_child(workshop)
	workshop.init_building(BuildingConfigs.BuildingType.WORKSHOP, 91, 101, true)
	workshop.position = Vector3(92.5, 2, 102.5)
	game.all_buildings.append(workshop)
	
	game.selection_system.clear_selection()
	game.selection_system.select_building(workshop)
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-building-inspector.png")
	
	# Open workshop production queue modal
	game.hud.skin.production_panel.open(workshop)
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-production.png")
	game.hud.skin.production_panel.close()

	# Create Barracks and open Unit Recruitment Queue
	var barracks := Building.new()
	game.buildings_container.add_child(barracks)
	barracks.init_building(BuildingConfigs.BuildingType.BARRACKS, 95, 101, true)
	barracks.position = Vector3(96.5, 2, 102.5)
	game.all_buildings.append(barracks)
	game.hud.skin.production_panel.open(barracks)
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/ipad-recruitment.png")
	
	print("ALL IPAD SCREENSHOTS CAPTURED SUCCESSFULLY")
	get_tree().quit(0)
