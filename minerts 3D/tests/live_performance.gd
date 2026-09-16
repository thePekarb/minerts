extends Node
var game: Main
var results: Array[Dictionary] = []
func measure(label: String) -> void:
	for i in range(30):await get_tree().process_frame
	var frames: Array[float] = []
	var physics: Array[float] = []
	var systems: Dictionary = {}
	var draws: float = 0
	for i in range(90):
		var started: int = Time.get_ticks_usec()
		await get_tree().process_frame
		frames.append((Time.get_ticks_usec()-started)/1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for key in game.last_system_usec:systems[key]=maxf(systems.get(key,0),game.last_system_usec[key]/1000.0)
	frames.sort();physics.sort()
	var row: Dictionary = {"scenario":label,"p50_ms":frames[45],"p95_ms":frames[85],"p99_ms":frames[88],"physics_p95_ms":physics[85],"peak_system_ms":systems,"navigation_usec":Unit.navigation_profile.duplicate(),"draw_calls":draws/90,"units":game.all_units.size(),"buildings":game.all_buildings.size(),"skeletons":game.unit_visuals.skeleton_count,"baked":game.unit_visuals.batched_count}
	results.append(row);print("LIVE PROFILE ",JSON.stringify(row))
func _ready() -> void:
	SoundManager.is_muted=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1672,941))
	game.camera.target_zoom=35;game.time_of_day_system.set_process(false);game.goblin_ai.set_process(false)
	await measure("settlement_balanced")
	for i in range(120):
		var u: Unit = game.spawn_unit(UnitConfigs.UnitType.ARCHER if i%4==0 else UnitConfigs.UnitType.WARRIOR,"player",Vector3(82.5+i%15,0,86.5+i/15))
		u.max_health=10000;u.health=10000
	for x in range(85,111,5):
		for z in range(106,117,5):
			if not game.grid_manager.is_area_buildable(x,z,2,2):continue
			var b:=Building.new();game.buildings_container.add_child(b);b.init_building(BuildingConfigs.BuildingType.HUT,x,z,true)
			b.position=Vector3(x+1,game.grid_manager.get_height(x,z),z+1);game.all_buildings.append(b);game.grid_manager.occupy_area(x,z,2,2,b)
	for i in range(64):
		var u: Unit = game.spawn_unit(UnitConfigs.UnitType.SKELETON if i%4==0 else UnitConfigs.UnitType.ZOMBIE,"enemy",Vector3(103.5+i%8,0,83.5+i/8))
		u.max_health=10000;u.health=10000
	await measure("184_combatants_fog_buildings_balanced")
	game.hud.skin.set_quality(2);game.unit_visuals.mode=2
	await measure("same_battle_native_resolution_skeletons")
	game.hud.skin.set_quality(0);game.unit_visuals.mode=0
	await measure("same_battle_balanced_again")
	# Populate only genuinely free level sites, without placing colliders on actors.
	for x in range(60,133,3):
		for z in range(60,133,3):
			if game.all_buildings.size()>=40:break
			if not game.grid_manager.is_area_buildable(x,z,2,2,false):continue
			var area := Rect2(x-.6,z-.6,3.2,3.2)
			if game.all_units.any(func(u):return is_instance_valid(u) and not u.underground_unit and area.has_point(Vector2(u.position.x,u.position.z))):continue
			var b:=Building.new();game.buildings_container.add_child(b);b.init_building(BuildingConfigs.BuildingType.HUT,x,z,true)
			b.position=Vector3(x+1,game.grid_manager.get_height(x,z),z+1);game.all_buildings.append(b);game.grid_manager.occupy_area(x,z,2,2,b)
	game.camera.target_zoom=55
	await measure("city_40_buildings_battle_fog_balanced")
	await RenderingServer.frame_post_draw;RenderingServer.force_draw()
	game.get_viewport().get_texture().get_image().save_png("res://art/live-battle.png")
	var file:=FileAccess.open("res://art/test-results/live_performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("LIVE PERFORMANCE COMPLETE");get_tree().quit()
