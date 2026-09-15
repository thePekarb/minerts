extends Node
func _ready() -> void:
 SoundManager.is_muted=true
 var game: Main = load("res://scenes/Main.tscn").instantiate();add_child(game)
 game.goblin_ai.set_process(false);game.time_of_day_system.set_process(false)
 game.time_of_day_system.time_of_day=.40;game.time_of_day_system._update_lighting()
 var coords: Vector2i = Vector2i(-1,-1)
 for x in range(158,179):
  for z in range(75,115):
   if game.grid_manager.is_area_buildable(x,z,3,2,false) and game.grid_manager.is_coastal_site(x,z,3,2):coords=Vector2i(x,z);break
  if coords.x>=0:break
 if coords.x<0:push_error("No preview coast");get_tree().quit(1);return
 var port: Building = Building.new();game.buildings_container.add_child(port);port.init_building(BuildingConfigs.BuildingType.PORT,coords.x,coords.y,true)
 port.position=Vector3(coords.x+1.5,game.grid_manager.get_height(coords.x,coords.y),coords.y+1);game.all_buildings.append(port)
 game.grid_manager.occupy_area(coords.x,coords.y,3,2,port)
 EconomyManager.add_resource("wood",400);EconomyManager.add_resource("stone",100);EconomyManager.add_resource("food",100)
 var ship: Unit = game.spawn_unit(UnitConfigs.UnitType.GALLEY,"player",game.production_system.spawn_position(port,true))
 game.production_system.enqueue(port,UnitConfigs.UnitType.BOAT);game.production_system.enqueue(port,UnitConfigs.UnitType.GALLEY)
 game.selection_system.select_building(port)
 game.camera.target_focus=port.position;game.camera.target_zoom=19;game.camera.target_yaw=PI*.5
 for i in range(60):await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://art/archipelago-port.png")
 var units: Array[Unit] = game.goblin_ai.own_units()
 var observer: Unit = game.spawn_unit(UnitConfigs.UnitType.SCOUT,"player",Vector3(402,2,84))
 for item in [[BuildingConfigs.BuildingType.BARRACKS,Vector2i(395,75)],[BuildingConfigs.BuildingType.FARM,Vector2i(406,77)],[BuildingConfigs.BuildingType.WELL,Vector2i(407,83)]]:game.goblin_ai.place(item[0],item[1],true)
 observer.config["vision_range"]=16
 game.camera.target_focus=Vector3(402,2,80);game.camera.target_zoom=20;game.camera.target_yaw=-PI*.25;game.selection_system.clear_selection()
 for i in range(60):await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://art/archipelago-goblins.png")
 get_tree().quit()
