extends Node
func _ready() -> void:
	SoundManager.is_muted=true
	var game: Main = load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.time_of_day_system.time_of_day=.4;game.time_of_day_system.set_process(false);game.time_of_day_system._update_lighting()
	game.camera.target_zoom=25
	game.selection_system.select_single_unit(game.all_units[0],false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1672,941))
	for i in range(180):await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/frontier-hud.png")
	game.hud.skin.category.select(4);game.hud.skin.filter_buildings(4)
	for i in range(4):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/frontier-hud-resources.png")
	print("HUD PREVIEW COMPLETE");get_tree().quit()
