extends Node
func _ready() -> void:
	SoundManager.is_muted = true
	var game: Main = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.time_of_day_system.set_process(false)
	game.time_of_day_system.time_of_day = 0.4
	game.time_of_day_system._update_lighting()
	for item in [[BuildingConfigs.BuildingType.BARRACKS, Vector3(93,2,90)], [BuildingConfigs.BuildingType.FARM, Vector3(100,2,93)], [BuildingConfigs.BuildingType.WELL, Vector3(100,2,98)]]:
		var b: Building = Building.new()
		game.buildings_container.add_child(b)
		b.init_building(item[0], floori(item[1].x), floori(item[1].z), true)
		b.position = item[1]
		game.all_buildings.append(b)
	game.camera.target_zoom = 24
	game.fog_system.update_fog(game.all_units,game.all_buildings,0.3)
	for i in range(50): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/colony-surface.png")
	var entry: Vector2i = game.underground_system.caves[0].entry
	var worker: Unit = game.all_units[0]
	game.underground_system.enter(worker,entry)
	game.selection_system.select_single_unit(worker)
	game.underground_system._tick_caves(9)
	game.underground_system.toggle_view()
	game.camera.target_focus = worker.position
	game.camera.target_zoom = 18
	for i in range(50): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/colony-underground.png")
	get_tree().quit()
