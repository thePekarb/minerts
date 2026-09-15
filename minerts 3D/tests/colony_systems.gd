extends Node
var game: Main
var failures: int = 0
var checks: int = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS: ", title)
	else:
		failures += 1
		push_error(title)
func make_building(type: BuildingConfigs.BuildingType, pos: Vector3, complete: bool = true) -> Building:
	var building: Building = Building.new()
	game.buildings_container.add_child(building)
	building.init_building(type, floori(pos.x), floori(pos.z), complete)
	building.position = pos
	game.all_buildings.append(building)
	return building
func _ready() -> void:
	SoundManager.is_muted = true
	game = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.set_process(false)
	game.time_of_day_system.set_process(false)
	game.wildlife_system.set_process(false)
	game.underground_system.set_process(false)
	for unit in game.all_units: unit.set_physics_process(false)
	check(game.fog_system.fog_texture != null and game.fog_system.fog_materials.size() > 100, "world meshes use fog visibility texture")
	check(game.fog_system.get_tile_visibility(4,4) == 0 and game.fog_system.get_tile_visibility(96,96) == 2, "unknown territory and visible base are distinct")
	var scout: Unit = game.all_units[0]
	var old: Vector3 = scout.position
	scout.position = Vector3(70.5, game.grid_manager.get_height(70,70), 70.5)
	game.fog_system.update_fog(game.all_units, game.all_buildings, 0.3)
	scout.position = old
	game.fog_system.update_fog(game.all_units, game.all_buildings, 0.3)
	check(game.fog_system.get_tile_visibility(70,70) == 1, "explored ground remains remembered after leaving")
	var enemy: Unit = game.spawn_unit(UnitConfigs.UnitType.ZOMBIE, "enemy", Vector3(90.5,2,95.5))
	enemy.set_physics_process(false)
	enemy.target = game.all_buildings[0]
	game.combat_system._process_enemy_unit(enemy, 0.5, game.all_units, game.all_buildings)
	check(enemy.target is Unit and enemy.target.faction == "player", "enemy switches from building to nearby player unit")
	var nearest: Unit = game.spawn_unit(UnitConfigs.UnitType.WORKER, "player", Vector3(91.5,2,95.5))
	nearest.set_physics_process(false)
	enemy.target_scan_timer = 0
	game.combat_system._process_enemy_unit(enemy, 0.5, game.all_units, game.all_buildings)
	check(enemy.target == nearest, "enemy retargets to a closer unit")
	check(not game.grid_manager.has_line_of_sight(Vector3(95,-4,95), Vector3(95,2,95)), "combat cannot see across surface and underground layers")
	var path: Array[Vector3] = game.grid_manager.find_path(Vector3(96.5,5,38.5), Vector3(94.5,2,95.5), "enemy")
	var safe: bool = not path.is_empty()
	for i in range(1,path.size()):
		if absf(path[i].y-path[i-1].y)>1.01: safe = false
	check(safe, "routes contain no climb higher than one block")
	var building: Building = make_building(BuildingConfigs.BuildingType.BARRACKS, Vector3(92.5,2,90.5),false)
	scout.position = Vector3(90.5,2,90.5)
	scout.target = building
	scout.current_order = UnitConfigs.UnitOrder.BUILD
	for i in range(121): game.gathering_system._update_unit_build(scout,0.1)
	check(building.is_constructed and scout.current_order == UnitConfigs.UnitOrder.MOVE, "worker completes building from its perimeter and becomes idle")
	var farm: Building = make_building(BuildingConfigs.BuildingType.FARM,Vector3(100,2,90))
	var food: int = EconomyManager.resources.food
	game.farming_system.tick(25,game.all_buildings)
	check(EconomyManager.resources.food == food and farm.production_timer == 0, "farm pauses without a well")
	var well: Building = make_building(BuildingConfigs.BuildingType.WELL,Vector3(106,2,90))
	EconomyManager.resources.water = 4
	game.farming_system.tick(20,game.all_buildings)
	check(EconomyManager.resources.food == food+12, "irrigated farm produces crops")
	check(farm.crop_plants != null and farm.crop_plants.scale.y < 0.2, "harvest resets the separate Blender crop mesh to seedlings")
	game.farming_system.tick(10,game.all_buildings)
	check(farm.crop_plants.scale.y > 0.5 and farm.crop_plants.scale.y < 0.7, "crop mesh grows with the actual production progress")
	well.is_alive = false
	food = EconomyManager.resources.food
	game.farming_system.tick(25,game.all_buildings)
	check(EconomyManager.resources.food == food, "destroying the well stops crop production")
	check(game.wildlife_system.animals.size() >= 12, "huntable wildlife spawns on island")
	var animal: Unit = game.wildlife_system.animals[0]
	var meat: int = animal.config.food_loot
	food = EconomyManager.resources.food
	animal.take_damage(999)
	check(EconomyManager.resources.food == food and game.resource_spawner.resources.values().any(func(r):return is_instance_valid(r) and r.get_meta("resource_type", "")=="food" and r.get_meta("resource_amount", 0)==meat), "hunting leaves species-specific harvestable food")
	var underground: UndergroundSystem = game.underground_system
	var entry: Vector2i = underground.caves[0].entry
	underground.enter(scout,entry)
	check(scout.underground_unit and scout.position.y == -4 and scout.collision_layer == 32, "cave entry changes navigation and collision layer")
	underground.toggle_view()
	check(underground.cutaway and game.camera.underground_view and underground.floor_mesh.visible, "X mode exposes underground layer")
	var dig_target: Vector2i = entry
	while underground.cells.has(dig_target): dig_target.x += 1
	var adjacent: Vector2i = dig_target - Vector2i.RIGHT
	scout.position = Vector3(adjacent.x+0.5,-4,adjacent.y+0.5)
	var stone: int = EconomyManager.resources.stone
	underground.issue_order(scout,dig_target)
	underground._process(2.6)
	check(underground.cells.has(dig_target) and EconomyManager.resources.stone == stone+2, "worker excavates adjacent tunnel cell and yields stone")
	check(not underground.find_path(scout.position,Vector3(dig_target.x+0.5,-4,dig_target.y+0.5)).is_empty(), "dug tunnel immediately joins navigation graph")
	scout.position = Vector3(3.5,-4,3.5) # Keep the spawn-cooldown check outside the player safety radius.
	underground._tick_caves(9)
	var cave: Dictionary = underground.caves[0]
	check(cave.enemies.size()==2 and cave.enemies[0].underground_unit, "random caves host permanent underground monsters")
	for monster in cave.enemies.duplicate(): monster.take_damage(999)
	underground._tick_caves(44)
	check(cave.enemies.is_empty(), "cave respawn respects its cooldown")
	underground._tick_caves(2)
	check(cave.enemies.size()==2, "cave monsters respawn after being killed")
	scout.position=Vector3(entry.x+0.5,-4,entry.y+0.5)
	underground.request_exit(scout)
	underground._process(0.1)
	check(not scout.underground_unit and scout.position.y>=0, "unit can leave the cave through its entrance")
	underground.toggle_view()
	game.underground_system.jobs[nearest.get_instance_id()] = {"unit":weakref(nearest),"target":entry}
	game.selection_system.select_single_unit(nearest)
	game.selection_system._issue_move_order(Vector3(95.5,2,91.5))
	check(not game.underground_system.jobs.has(nearest.get_instance_id()), "new movement order cancels the previous underground job")
	check(game.interaction_feedback.describe(nearest).contains("ЛКМ"), "friendly hover explains selection")
	check(game.interaction_feedback.describe(enemy).contains("атаковать"), "hostile hover explains attack")
	for unit in game.all_units: unit.set_physics_process(false)
	await get_tree().process_frame
	print("COLONY CHECKS: %d | FAILURES: %d" % [checks, failures])
	get_tree().quit(failures)
