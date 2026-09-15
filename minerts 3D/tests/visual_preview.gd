extends Node

func _ready() -> void:
	var game: Main = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.time_of_day_system.set_process(false)
	game.selection_system.select_single_unit(game.all_units[0])
	game.all_units[0].take_damage(20)
	for i in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/frontier-game-day.png")
	game.time_of_day_system.time_of_day = 0.85
	game.time_of_day_system._update_lighting()
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/frontier-game-night.png")
	# Staged construction preview, separate from the actual starting settlement.
	game.time_of_day_system.time_of_day = 0.42
	game.time_of_day_system._update_lighting()
	for item in [[BuildingConfigs.BuildingType.HUT, Vector2i(91, 89)], [BuildingConfigs.BuildingType.BARRACKS, Vector2i(95, 89)], [BuildingConfigs.BuildingType.TOWER, Vector2i(101, 93)], [BuildingConfigs.BuildingType.STORAGE, Vector2i(90, 98)], [BuildingConfigs.BuildingType.MINE, Vector2i(100, 99)]]:
		var b: Building = Building.new()
		game.buildings_container.add_child(b)
		b.init_building(item[0], item[1].x, item[1].y, true)
		b.global_position = Vector3(item[1].x + 1, game.grid_manager.get_height(item[1].x, item[1].y), item[1].y + 1)
	game.camera.target_zoom = 20.0
	for i in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/frontier-settlement-preview.png")
	get_tree().quit()
