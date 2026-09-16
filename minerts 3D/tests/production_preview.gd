extends Node
func _ready() -> void:
	SoundManager.is_muted=true
	var game: Main=load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.goblin_ai.set_process(false);game.time_of_day_system.set_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1672,941))
	var shop:=Building.new();game.buildings_container.add_child(shop);shop.init_building(BuildingConfigs.BuildingType.WORKSHOP,91,100,true);shop.position=Vector3(92.5,2,101.5);game.all_buildings.append(shop)
	var store:=Building.new();game.buildings_container.add_child(store);store.init_building(BuildingConfigs.BuildingType.STORAGE,92,90,true);store.position=Vector3(93,2,91);game.all_buildings.append(store);EventBus.building_constructed.emit(store)
	FactionEconomy.add("player","wood",160);FactionEconomy.add("player","stone",100);FactionEconomy.add("player","ore",40);FactionEconomy.add("player","food",60)
	for key in EquipmentConfigs.ITEMS:game.workshop_system.enqueue(shop,key)
	game.hud.skin.production_panel.open(shop)
	for i in range(120):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/workshop-queue.png")
	game.hud.skin.production_panel.close()
	var camp: Building=game.all_buildings[0]
	for i in range(3):
		var hut:=Building.new();game.buildings_container.add_child(hut);hut.init_building(BuildingConfigs.BuildingType.HUT,106+i*3,100,true);hut.position=Vector3(107+i*3,2,101);game.all_buildings.append(hut);EventBus.building_constructed.emit(hut)
	FactionEconomy.add("player","axe",3)
	game.production_system.enqueue(camp,UnitConfigs.UnitType.WORKER);game.production_system.enqueue(camp,UnitConfigs.UnitType.SCOUT)
	game.hud.skin.production_panel.open(camp)
	for i in range(30):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/recruit-queue.png")
	game.hud.skin.production_panel.close();game.selection_system.select_building(store)
	game.interaction_feedback.set_process(false);game.interaction_feedback.set_hover(null)
	game.storage_system.deposit(store,"wood",110);game.storage_system.deposit(store,"stone",90);game.storage_system.deposit(store,"food",100)
	game.camera.target_focus=store.position;game.camera.target_zoom=10
	for i in range(120):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/storage-stock.png")
	print("PRODUCTION PREVIEW COMPLETE");get_tree().quit()
