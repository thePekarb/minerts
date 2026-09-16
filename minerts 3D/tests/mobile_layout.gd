extends Node
var game: Main
var failures: int=0
func check(ok: bool,text: String) -> void:
	if ok:print("PASS: ",text)
	else:failures+=1;push_error(text)
func _ready() -> void:
	SoundManager.is_muted=true
	game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.goblin_ai.set_process(false);game.time_of_day_system.set_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var warehouse:=Building.new();game.buildings_container.add_child(warehouse);warehouse.init_building(BuildingConfigs.BuildingType.WORKSHOP,91,101,true);warehouse.position=Vector3(92.5,2,102.5);game.all_buildings.append(warehouse)
	for extent in [Vector2i(896,414),Vector2i(414,896),Vector2i(1194,834),Vector2i(1280,800),Vector2i(1672,941)]:
		get_window().content_scale_size=extent;DisplayServer.window_set_size(extent)
		for i in range(12):await get_tree().process_frame
		game.responsive_hud.layout()
		game.selection_system.select_single_unit(game.all_units[0])
		for i in range(4):await get_tree().process_frame
		var bounds:=get_viewport().get_visible_rect()
		check(bounds.grow(1).encloses(game.hud.inspector.get_global_rect()),"inspector fits %s" % extent)
		game.hud.skin.production_panel.open(warehouse)
		for i in range(4):await get_tree().process_frame
		check(bounds.grow(1).encloses(game.hud.skin.production_panel.get_global_rect()),"production panel fits %s" % extent)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/production-%dx%d.png" % [extent.x,extent.y])
		game.hud.skin.production_panel.close()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://art/test-results/mobile-network/hud-%dx%d.png" % [extent.x,extent.y])
	print("MOBILE LAYOUT FAILURES: ",failures);get_tree().quit(failures)
