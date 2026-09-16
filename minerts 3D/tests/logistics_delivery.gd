extends Node
var game: Main
var failures: int=0
var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok:print("PASS: ",message)
	else:failures+=1;push_error(message)
func place(type: BuildingConfigs.BuildingType,cell: Vector2i) -> Building:
	var b:=Building.new();game.buildings_container.add_child(b);b.init_building(type,cell.x,cell.y,true)
	b.position=Vector3(cell.x+b.footprint.x*.5,game.grid_manager.get_height(cell.x,cell.y),cell.y+b.footprint.y*.5)
	game.all_buildings.append(b);game.grid_manager.occupy_area(cell.x,cell.y,b.footprint.x,b.footprint.y,b);EventBus.building_constructed.emit(b);return b
func _ready() -> void:
	SoundManager.is_muted=true
	game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.goblin_ai.set_process(false);game.goblin_ai.expedition.set_process(false);game.time_of_day_system.set_process(false)
	var base: Vector3=game.all_buildings[0].position
	# Use level, empty sites in the generated starting clearing.
	var sites: Array[Vector2i]=[]
	for x in range(int(base.x)-6,int(base.x)+5,4):
		for z in range(int(base.z)-6,int(base.z)+5,4):
			if game.grid_manager.is_area_buildable(x,z,3,3,false):sites.append(Vector2i(x,z))
	check(sites.size()>=4,"generated starting clearing provides valid logistics test sites")
	if sites.size()<4:get_tree().quit(1);return
	var warehouse:=place(BuildingConfigs.BuildingType.STORAGE,sites[0])
	var mine:=place(BuildingConfigs.BuildingType.MINE,sites[1])
	var farm:=place(BuildingConfigs.BuildingType.FARM,sites[2])
	var well:=place(BuildingConfigs.BuildingType.WELL,sites[3])
	game.set_process(false)
	var worker: Unit=game.all_units.filter(func(u):return UnitConfigs.is_worker(u.unit_type) and u.faction=="player")[0]
	worker.position=warehouse.position+Vector3(1.5,0,0);worker.target=warehouse;worker.current_order=UnitConfigs.UnitOrder.BUILD
	var health_before: float=warehouse.health
	game.combat_system._process_player_combat_unit(worker,10,game.all_units)
	check(warehouse.health==health_before and worker.target==warehouse and worker.current_order==UnitConfigs.UnitOrder.BUILD,"combat never attacks a worker construction target")
	worker.current_order=UnitConfigs.UnitOrder.GATHER
	game.combat_system._process_player_combat_unit(worker,10,game.all_units)
	check(warehouse.health==health_before and worker.target==warehouse,"combat preserves resource delivery orders")
	worker.position=game.production_system.spawn_position(mine,false);worker.current_order=UnitConfigs.UnitOrder.MOVE;worker.target=mine;worker.mining_building_id=str(mine.get_instance_id());mine.assigned_miners.append(worker)
	game.gathering_system._update_mines(3)
	check(mine.buffered_amount()==0,"un-equipped miners cannot produce stone")
	FactionEconomy.add("player","pickaxe",1)
	worker.garrison_in_building(mine)
	var stone_before: int=EconomyManager.get_resource("stone")
	game.gathering_system._update_mines(3)
	check(worker.get_meta("mining_tool",false) and EconomyManager.get_resource("pickaxe")==0,"miner consumes one pickaxe and retains its equipment")
	check(mine.output_buffer.get("stone",0)==1 and EconomyManager.get_resource("stone")==stone_before,"mined stone waits at the mine instead of entering the wallet")
	game.farming_system.tick(21,game.all_buildings)
	check(farm.buffered_amount()==0,"farm waits for its pitchfork")
	FactionEconomy.add("player","pitchfork",1);EconomyManager.resources.water=20
	var food_before: int=EconomyManager.get_resource("food")
	game.farming_system.tick(21,game.all_buildings)
	check(farm.farm_equipped and EconomyManager.get_resource("pitchfork")==0 and farm.output_buffer.get("food",0)==12,"equipped irrigated farm places its harvest in the pickup buffer")
	var source_total: int=mine.buffered_amount()+farm.buffered_amount()
	for u in game.all_units:
		if u.faction=="player" and UnitConfigs.is_worker(u.unit_type) and u!=worker:
			game.selection_system.cancel_assignments(u);u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE;u.stop()
	for i in range(2400):
		await get_tree().physics_frame
		game.gathering_system.process_gathering(1.0/60,game.all_units)
		if EconomyManager.get_resource("food")>=food_before+12 and EconomyManager.get_resource("stone")>stone_before:break
	check(EconomyManager.get_resource("food")>=food_before+12 and farm.buffered_amount()==0,"courier physically collects the harvest and delivers it")
	check(EconomyManager.get_resource("stone")>stone_before,"courier physically delivers mined stone")
	check(warehouse.stored_resources.get("food",0)>0 and warehouse.stored_resources.get("stone",0)>0,"couriers prefer the warehouse over the starter camp")
	var cached: int=EconomyManager.get_resource("food");var lost: int=warehouse.stored_resources.get("food",0)
	warehouse.take_damage(10000)
	check(EconomyManager.get_resource("food")==cached-lost,"destroying a warehouse removes its stock from the wallet")
	print("LOGISTICS DELIVERY CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
