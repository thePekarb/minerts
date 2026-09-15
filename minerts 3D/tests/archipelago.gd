extends Node
var game: Main
var checks: int = 0
var failures: int = 0
func check(ok: bool, description: String) -> void:
	checks+=1
	if ok:print("PASS: ",description)
	else:failures+=1;push_error(description)
func make_building(type: BuildingConfigs.BuildingType,coords: Vector2i,faction: String="player") -> Building:
	var b: Building = Building.new();b.faction=faction
	game.buildings_container.add_child(b);b.init_building(type,coords.x,coords.y,true)
	b.position=Vector3(coords.x+b.footprint.x*.5,game.grid_manager.get_height(coords.x,coords.y),coords.y+b.footprint.y*.5)
	game.grid_manager.occupy_area(coords.x,coords.y,b.footprint.x,b.footprint.y,b)
	game.all_buildings.append(b);EventBus.building_constructed.emit(b)
	return b
func find_coast(center: Vector2i) -> Vector2i:
	for x in range(maxi(2,center.x-85),mini(GridManager.GRID_SIZE-4,center.x+85)):
		for z in range(maxi(2,center.y-85),mini(GridManager.GRID_SIZE-4,center.y+85)):
			if not game.grid_manager.is_area_buildable(x,z,3,2,false) or not game.grid_manager.is_coastal_site(x,z,3,2):continue
			if not game.grid_manager.find_path(Vector3(center.x,game.grid_manager.get_height(center.x,center.y),center.y),Vector3(x+.5,1,z+.5)).is_empty():return Vector2i(x,z)
	return Vector2i(-1,-1)
func _ready() -> void:
	SoundManager.is_muted=true
	game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.set_process(false);game.goblin_ai.set_process(false)
	game.time_of_day_system.set_process(false);game.wildlife_system.set_process(false);game.underground_system.set_process(false)
	for u in game.all_units:u.set_physics_process(false)
	check(GridManager.GRID_SIZE==512 and game.terrain_generator.world_info.islands.size()==6,"six-island archipelago preserves the home island at the map edge")
	check(game.terrain_generator.world_info.islands[1].radius>game.terrain_generator.world_info.islands[0].radius,"central treasure island is larger than the home island")
	check(game.resource_spawner.pois.values().filter(func(p):return p.position.x>200).size()>=4,"central island contains collectable treasure chests")
	check(game.all_buildings.any(func(b):return b.faction=="goblin") and game.goblin_ai.own_units().size()==6,"independent goblin settlement starts on its own island")
	check(game.grid_manager.find_path(Vector3(96.5,2,95.5),Vector3(402.5,2,78.5)).is_empty(),"land units cannot walk between islands")
	var food: int = EconomyManager.resources.food
	var hunter: Unit = game.all_units[0]
	var prey: Unit = game.spawn_unit(UnitConfigs.UnitType.DEER,"neutral",Vector3(92.5,2,95.5));prey.set_physics_process(false)
	hunter.target=prey;hunter.current_order=UnitConfigs.UnitOrder.ATTACK
	prey.take_damage(999)
	check(EconomyManager.resources.food==food,"animal death leaves harvestable food instead of instant resources")
	check(hunter.target is Node3D and hunter.target.get_meta("resource_type","")=="food" and hunter.current_order==UnitConfigs.UnitOrder.GATHER,"worker hunter automatically starts butchering the carcass")
	var carcass: Node3D = hunter.target
	hunter.position=carcass.position+Vector3(1,0,0)
	game.gathering_system._update_unit_gather(hunter,1.1)
	check(hunter.inventory.amount==2 and carcass.get_meta("resource_amount")==16,"butchering transfers a finite amount of food into worker inventory")
	game.gathering_system._send_to_storage(hunter)
	hunter.position=game.all_buildings[0].position+Vector3(-1.5,0,0)
	game.gathering_system._update_unit_gather(hunter,0.1)
	check(EconomyManager.resources.food==food+2 and hunter.inventory.amount==0,"harvested meat must be delivered to storage")
	var camp: Building = game.all_buildings[0]
	hunter.target=camp;hunter.current_order=UnitConfigs.UnitOrder.GATHER;hunter.state=UnitConfigs.UnitState.IDLE
	hunter.inventory={"type":"wood","amount":6}
	var timber: int = EconomyManager.resources.wood
	game.gathering_system._update_unit_gather(hunter,1.1)
	check(not camp.is_queued_for_deletion() and EconomyManager.resources.wood==timber+6,"interrupted delivery never treats the storage building as a resource")
	var expired: Node3D = Node3D.new();add_child(expired);hunter.target=expired;expired.free()
	hunter.state=UnitConfigs.UnitState.IDLE
	game.gathering_system._update_unit_gather(hunter,0.1)
	check(is_instance_valid(camp),"depleted shared resource targets can be safely replaced")
	var count: int = game.all_units.size()
	check(game.production_system.enqueue(camp,UnitConfigs.UnitType.WORKER)=="" and game.all_units.size()==count,"training queues a unit without spawning it immediately")
	check(game.production_system.population("player")==EconomyManager.current_population+1,"queued recruits reserve population capacity")
	game.production_system.set_rally(camp,Vector3(94.5,2,91.5))
	game.production_system.tick(7)
	check(game.all_units.size()==count,"recruit stays in training until its timer completes")
	game.production_system.tick(1.1)
	var recruit: Unit = game.all_units.back();recruit.set_physics_process(false)
	check(game.all_units.size()==count+1 and camp.training_queue.is_empty() and not recruit.path.is_empty(),"completed recruit spawns and walks toward the rally point")
	var before: int = EconomyManager.resources.food
	game.production_system.enqueue(camp,UnitConfigs.UnitType.WORKER);game.production_system.cancel(camp)
	check(EconomyManager.resources.food==before and camp.training_queue.is_empty(),"cancelled recruitment refunds cost and frees queue reservation")
	var bot_camp: Building = game.goblin_ai.own_buildings()[0]
	before=EconomyManager.resources.food
	game.production_system.enqueue(bot_camp,UnitConfigs.UnitType.GOBLIN_WORKER)
	check(EconomyManager.resources.food==before and FactionEconomy.resources("goblin").food==162,"goblin production spends only its own resources")
	check(not game.grid_manager.is_coastal_site(90,90,3,2),"ports cannot be placed inland")
	var coast: Vector2i = find_coast(Vector2i(96,96))
	check(coast.x>=0,"home island has a reachable buildable coast for a port")
	if coast.x>=0:
		var port: Building = make_building(BuildingConfigs.BuildingType.PORT,coast)
		EconomyManager.add_resource("wood",200)
		check(game.production_system.enqueue(port,UnitConfigs.UnitType.BOAT)=="","port accepts a timed boat order")
		game.production_system.tick(18.1)
		var ship: Unit = game.all_units.back();ship.set_physics_process(false)
		check(UnitConfigs.is_vessel(ship.unit_type) and game.grid_manager.is_sea_position(ship.position),"port launches completed boat into water")
		var shore: Vector3 = game.transport_system._landing_cell(ship.position,hunter)
		check(shore!=Vector3.INF,"launched boat is close enough to a safe embarkation shore")
		if shore!=Vector3.INF:
			hunter.position=shore;hunter.stop()
			check(game.transport_system.board(hunter,ship),"worker can receive a boarding order at a coast")
			game.transport_system.tick(0.1)
			check(hunter.embarked_in==ship and ship.passengers.has(hunter) and hunter.collision_layer==0,"embarked passengers are stored aboard and stop colliding on land")
			check(game.transport_system.unload(ship)==1 and hunter.embarked_in==null and hunter.collision_layer==2,"passenger disembarks onto a free land cell")
		var other_coast: Vector3 = game.grid_manager.nearest_sea_position(Vector3(348,0,80),12)
		var route: Array[Vector3] = game.grid_manager.find_sea_path(ship.position,other_coast)
		check(not route.is_empty() and route.all(func(p):return game.grid_manager.is_sea_position(p)),"ship finds an all-water route between home and goblin islands")
	game.time_of_day_system.time_of_day=20.0/24
	game.wildlife_system._process(1)
	check(game.wildlife_system.packs.all(func(p):return p.members.size()==4),"night creates roaming wolf packs in the forests")
	check(game.wildlife_system.predators.any(func(u):return u.unit_type==UnitConfigs.UnitType.BEAR),"bears inhabit the forest")
	var wood: int = EconomyManager.resources.wood
	game.goblin_ai._process(2)
	check(game.goblin_ai.own_buildings().any(func(b):return not b.is_constructed),"goblin AI spends resources and places a real construction site")
	check(EconomyManager.resources.wood==wood and game.goblin_ai.own_units().any(func(u):return u.current_order==UnitConfigs.UnitOrder.BUILD),"bot dispatches its worker without touching the player economy")
	check(game.all_units.any(func(u):return u.get_meta("goblin_raid",false)),"goblin colony receives its own nightly monster attack")
	check(not game.fog_system.get_tile_visibility(402,80)==2,"bot vision does not reveal its island to the player")
	hunter.position=Vector3(402.5,2,85.5);hunter.config["vision_range"]=10
	game.fog_system.update_fog(game.all_units,game.all_buildings,0.3)
	check(bot_camp.visible and game.fog_system.get_tile_visibility(bot_camp.grid_x,bot_camp.grid_z)==2,"foreign buildings cannot occlude their own visible footprint")
	for asset in ["wolf","bear","goblin_worker","goblin_warrior","goblin_archer","goblin_spearman","spider_rider","troll","boat","galley","port","goblin_port"]:
		var model: Node3D = FrontierAssets.instantiate_asset(asset)
		check(model!=null,"Blender MCP asset loads: "+asset)
		if model:model.free()
	print("ARCHIPELAGO CHECKS: %d | FAILURES: %d" % [checks,failures])
	get_tree().quit(failures)
