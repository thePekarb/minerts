class_name GoblinAISystem
extends Node
var game: Main
var center: Vector3 = Vector3(402.5,2,80.5)
var think_timer: float = 0.0
var last_raid_day: int = -1
var explored: Dictionary = {}
var strategy: String = "Основание поселения"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var army_cursor: int = 0
var expedition: GoblinExpeditionSystem
var economy_age: float = 0.0
var site_retry: float = 0.0
const ARMY: Array[UnitConfigs.UnitType] = [UnitConfigs.UnitType.GOBLIN_WARRIOR,UnitConfigs.UnitType.GOBLIN_ARCHER,UnitConfigs.UnitType.GOBLIN_SPEARMAN,UnitConfigs.UnitType.SPIDER_RIDER,UnitConfigs.UnitType.TROLL]
const PLAN: Array[BuildingConfigs.BuildingType] = [BuildingConfigs.BuildingType.HUT,BuildingConfigs.BuildingType.WORKSHOP,BuildingConfigs.BuildingType.MINE,BuildingConfigs.BuildingType.STORAGE,BuildingConfigs.BuildingType.BARRACKS,BuildingConfigs.BuildingType.WELL,BuildingConfigs.BuildingType.FARM,BuildingConfigs.BuildingType.PORT,BuildingConfigs.BuildingType.TOWER]
func setup(main: Main) -> void:
	game=main;rng.seed=71024;FactionEconomy.reset_bot()
	var g_spawn := Vector2i(402, 80)
	if game.terrain_generator and not game.terrain_generator.world_info.is_empty():
		var raw_g = game.terrain_generator.world_info.get("goblin_spawn", [402, 80])
		if raw_g is Array and raw_g.size() >= 2:
			g_spawn = Vector2i(raw_g[0], raw_g[1])
		elif raw_g is Vector2i:
			g_spawn = raw_g
	if NetworkManager.in_match:
		var bot_index: int=-1
		var slots: Array=GameSettings.get_active_slots()
		for i in range(slots.size()):
			if slots[i].get("type")=="bot" and slots[i].get("faction")=="goblin":bot_index=i;break
		if bot_index<0:set_process(false);return
		var raw_spawn=game.terrain_generator.world_info.spawns[bot_index]
		g_spawn=Vector2i(raw_spawn[0],raw_spawn[1]) if raw_spawn is Array else raw_spawn
	var gy: float = game.grid_manager.get_height(g_spawn.x, g_spawn.y)
	center = Vector3(float(g_spawn.x) + 0.5, gy, float(g_spawn.y) + 0.5)
	place(BuildingConfigs.BuildingType.CAMPFIRE, g_spawn, true)
	for offset in [Vector3(-3,0,-2),Vector3(3,0,-2),Vector3(-3,0,2),Vector3(3,0,2)]:
		game.spawn_unit(UnitConfigs.UnitType.GOBLIN_WORKER,"goblin",center+offset)
	game.spawn_unit(UnitConfigs.UnitType.GOBLIN_WARRIOR,"goblin",center+Vector3(0,0,-4))
	game.spawn_unit(UnitConfigs.UnitType.GOBLIN_ARCHER,"goblin",center+Vector3(2,0,-4))
	expedition=GoblinExpeditionSystem.new();add_child(expedition);expedition.setup(self)

func own_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for u in game.all_units:
		if is_instance_valid(u) and u.is_alive and u.faction=="goblin":result.append(u)
	return result
func own_buildings() -> Array[Building]:
	var result: Array[Building] = []
	for b in game.all_buildings:
		if is_instance_valid(b) and b.is_alive and b.faction=="goblin":result.append(b)
	return result
func place(type: BuildingConfigs.BuildingType, coords: Vector2i, instant: bool = false) -> Building:
	var b: Building = Building.new();b.faction="goblin"
	game.buildings_container.add_child(b)
	b.init_building(type,coords.x,coords.y,instant)
	var fp: Vector2i = b.config.footprint
	b.position=Vector3(coords.x+fp.x*.5,game.grid_manager.get_height(coords.x,coords.y),coords.y+fp.y*.5)
	game.grid_manager.occupy_area(coords.x,coords.y,fp.x,fp.y,b,b.is_gate)
	game.all_buildings.append(b)
	game.fog_system.apply_world_materials(b)
	if instant:EventBus.building_constructed.emit(b)
	return b
func _process(delta: float) -> void:
	economy_age+=delta;think_timer+=delta;site_retry=maxf(0,site_retry-delta)
	if think_timer<1.0:return
	think_timer=0
	var units: Array[Unit] = own_units()
	var buildings: Array[Building] = own_buildings()
	if units.is_empty():strategy="Поселение уничтожено";return
	var workers: Array[Unit] = []
	for u in units:
		if not is_instance_valid(u.embarked_in) and not u.underground_unit:
			for dx in range(-6,7):
				for dz in range(-6,7):explored[Vector2i(floori(u.position.x)+dx,floori(u.position.z)+dz)]=true
		if UnitConfigs.is_worker(u.unit_type) and not u.get_meta("mission",false):workers.append(u)
	if game.time_of_day_system.time_of_day>=19.5/24 and last_raid_day!=game.time_of_day_system.current_day:
		last_raid_day=game.time_of_day_system.current_day;_spawn_night_attack(buildings)
	var needed: Variant = _next_building(buildings,units.size())
	var unfinished: Array[Building] = []
	for b in buildings:
		if not b.is_constructed:unfinished.append(b)
	if needed!=null and unfinished.size()<2 and workers.size()>=4 and site_retry<=0:
		var cfg: Dictionary = BuildingConfigs.get_config(needed)
		if FactionEconomy.can_afford("goblin",cfg.cost):
			var spot: Vector2i = find_site(needed)
			if spot.x>=0 and FactionEconomy.spend("goblin",cfg.cost):unfinished.append(place(needed,spot))
			else:site_retry=8.0
	for b in unfinished:
		if workers.any(func(u):return u.target==b and u.current_order==UnitConfigs.UnitOrder.BUILD):continue
		var candidates: Array[Unit] = workers.duplicate()
		candidates.sort_custom(func(a,c):return a.position.distance_squared_to(b.position)<c.position.distance_squared_to(b.position))
		for u in candidates:
			if u.mining_building_id!="" or u.current_order==UnitConfigs.UnitOrder.BUILD or u.inventory.get("amount",0)>0:continue
			var route: Array[Vector3] = game.grid_manager.find_unit_path(u,b.position,true)
			if route.is_empty():continue
			game.selection_system.cancel_assignments(u)
			u.target=b;u.current_order=UnitConfigs.UnitOrder.BUILD;u.set_path(route);u.state=UnitConfigs.UnitState.MOVING;break
	_plan_equipment(buildings,workers)
	var local_workers: int=workers.filter(func(u):return u.position.distance_squared_to(center)<10000).size()
	var worker_goal: int=10 if buildings.any(func(b):return b.building_type==BuildingConfigs.BuildingType.BARRACKS and b.is_constructed) else 6
	var farm_count: int = buildings.filter(func(b):return b.building_type==BuildingConfigs.BuildingType.FARM and b.is_constructed).size()
	for b in buildings:
		if not b.is_constructed or not b.training_queue.is_empty():continue
		if b.building_type==BuildingConfigs.BuildingType.CAMPFIRE and b.position.distance_squared_to(center)<10000 and local_workers<worker_goal:
			game.production_system.enqueue(b,UnitConfigs.UnitType.GOBLIN_WORKER)
		elif b.building_type==BuildingConfigs.BuildingType.BARRACKS and units.size()<28:
			var next: UnitConfigs.UnitType = ARMY[army_cursor%ARMY.size()]
			var wallet: Dictionary = FactionEconomy.resources("goblin")
			var soldiers: int = units.filter(func(u):return not UnitConfigs.is_worker(u.unit_type) and not UnitConfigs.is_vessel(u.unit_type)).size()
			var reserve: int = 0 if soldiers<4 else (25 if needed==null else maxi(55,BuildingConfigs.get_config(needed).cost.get("wood",0)))
			if soldiers>=5 and buildings.any(func(p):return p.building_type==BuildingConfigs.BuildingType.PORT and p.is_constructed) and not units.any(func(v):return UnitConfigs.is_vessel(v.unit_type)):reserve=maxi(reserve,110)
			if wallet.wood-UnitConfigs.get_config(next).cost.get("wood",0)>=reserve and wallet.food>=45:
				if game.production_system.enqueue(b,next)=="":army_cursor+=1
		elif b.building_type==BuildingConfigs.BuildingType.PORT and not units.any(func(u):return UnitConfigs.is_vessel(u.unit_type)) and farm_count>=2:
			game.production_system.enqueue(b,UnitConfigs.UnitType.GALLEY)
	for b in buildings:
		if b.building_type==BuildingConfigs.BuildingType.MINE and b.is_constructed and b.assigned_miners.size()<(2 if local_workers>=7 else 1) and local_workers>=5:
			for u in workers:
				if u.current_order==UnitConfigs.UnitOrder.BUILD or u.mining_building_id!="" or u.inventory.get("amount",0)>0:continue
				var route: Array[Vector3] = game.grid_manager.find_unit_path(u,b.position,true)
				if route.is_empty():continue
				game.selection_system.cancel_assignments(u)
				u.mining_building_id=str(b.get_instance_id());b.assigned_miners.append(u)
				u.target=b;u.current_order=UnitConfigs.UnitOrder.MOVE;u.set_path(route);u.state=UnitConfigs.UnitState.MOVING;break
		if b.building_type==BuildingConfigs.BuildingType.MINE and b.level==1 and buildings.any(func(ready):return ready.building_type==BuildingConfigs.BuildingType.BARRACKS and ready.is_constructed) and FactionEconomy.resources("goblin").stone>=65 and FactionEconomy.resources("goblin").wood>120 and FactionEconomy.spend("goblin",b.config.get("upgrade_cost",{"wood":40,"stone":30})):b.upgrade_mine()
	for i in range(workers.size()):
		var u: Unit = workers[i]
		# Keep one available courier for farm/mine output instead of assigning every worker to wood.
		if i==workers.size()-1 and workers.size()>=5 and buildings.any(func(b):return b.building_type in [BuildingConfigs.BuildingType.FARM,BuildingConfigs.BuildingType.MINE]):
			if u.state==UnitConfigs.UnitState.IDLE and u.inventory.amount==0 and u.mining_building_id=="":u.current_order=UnitConfigs.UnitOrder.MOVE;u.target=null
			continue
		if u.mining_building_id!="" or u.current_order==UnitConfigs.UnitOrder.BUILD or u.state not in [UnitConfigs.UnitState.IDLE,UnitConfigs.UnitState.DEFENDING]:continue
		if u.inventory.get("amount",0)>0:u.current_order=UnitConfigs.UnitOrder.GATHER;game.gathering_system._send_to_storage(u);continue
		u.set_meta("gather_kind","food" if i%4==2 and FactionEconomy.resources("goblin").food<75 else "wood")
		var best: Node3D
		var score: float = INF
		var candidates: Array = []
		for resource in game.resource_spawner.resources.values():
			if is_instance_valid(resource) and resource.get_meta("resource_type","")==u.get_meta("gather_kind") and resource.position.distance_squared_to(u.position)<6400:candidates.append(resource)
		candidates.sort_custom(func(a,b):return a.position.distance_squared_to(u.position)<b.position.distance_squared_to(u.position))
		for resource in candidates.slice(0,18):
			var assigned: int = workers.filter(func(w):return w.target==resource).size()
			var d: float = u.position.distance_to(resource.position)+assigned*6.0
			if d<score and not game.grid_manager.find_path(u.position,resource.position,"goblin").is_empty():best=resource;score=d
		if best:
			u.target=best;u.current_order=UnitConfigs.UnitOrder.GATHER;u.set_path(game.grid_manager.find_unit_path(u,best.position,true));u.state=UnitConfigs.UnitState.MOVING
	_defend_and_patrol(units)
	strategy="Хозяйство: %d рабочих, %d ферм · %s" % [workers.size(),farm_count,expedition.phase]

func _next_building(buildings: Array[Building], population: int) -> Variant:
	var counts: Dictionary = {}
	for b in buildings:counts[b.building_type]=counts.get(b.building_type,0)+1
	var local_free: int=0
	for b in buildings:
		if b.is_constructed and b.position.distance_squared_to(center)<10000:local_free+=b.storage_free()
	if game.storage_system and local_free<80 and not buildings.any(func(b):return b.building_type==BuildingConfigs.BuildingType.STORAGE and not b.is_constructed):return BuildingConfigs.BuildingType.STORAGE
	if game.production_system.population("goblin")>=game.production_system.capacity("goblin")-2 and counts.get(BuildingConfigs.BuildingType.HUT,0)<6:return BuildingConfigs.BuildingType.HUT
	if counts.get(BuildingConfigs.BuildingType.FARM,0)==1 and counts.has(BuildingConfigs.BuildingType.WELL) and counts.has(BuildingConfigs.BuildingType.BARRACKS):return BuildingConfigs.BuildingType.FARM
	for type in PLAN:
		if not counts.has(type):return type
	if counts.get(BuildingConfigs.BuildingType.FARM,0)<3:return BuildingConfigs.BuildingType.FARM
	if counts.get(BuildingConfigs.BuildingType.TOWER,0)<2:return BuildingConfigs.BuildingType.TOWER
	return null

func _defend_and_patrol(units: Array[Unit]) -> void:
	var threats: Array[Unit] = []
	for enemy in game.all_units:
		if enemy.faction not in ["enemy","predator","player"] or enemy.underground_unit or is_instance_valid(enemy.embarked_in):continue
		if enemy.position.distance_squared_to(center)>1600:continue
		for scout in units:
			if scout.underground_unit or is_instance_valid(scout.embarked_in):continue
			if scout.position.distance_squared_to(enemy.position)<144 and game.grid_manager.has_line_of_sight(scout.position,enemy.position):threats.append(enemy);break
	for u in units:
		if UnitConfigs.is_vessel(u.unit_type) or u.underground_unit or u.get_meta("mission",false):continue
		if UnitConfigs.is_worker(u.unit_type):
			if not threats.is_empty() and threats.any(func(e):return e.position.distance_squared_to(u.position)<36) and u.state!=UnitConfigs.UnitState.MINING_INSIDE:
				game.selection_system.cancel_assignments(u);u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE
				u.set_path(game.grid_manager.find_unit_path(u,center+Vector3(0,0,5),true));u.state=UnitConfigs.UnitState.FLEEING
			continue
		if not threats.is_empty():
			threats.sort_custom(func(a,b):return a.position.distance_squared_to(u.position)<b.position.distance_squared_to(u.position))
			u.target=threats[0];u.current_order=UnitConfigs.UnitOrder.ATTACK
		elif u.state==UnitConfigs.UnitState.IDLE:
			var destination: Vector3 = game.grid_manager.find_free_position(center+Vector3(rng.randf_range(-12,12),0,rng.randf_range(-12,12)))
			u.current_order=UnitConfigs.UnitOrder.PATROL;u.target=null;u.set_path(game.grid_manager.find_unit_path(u,destination,true));u.state=UnitConfigs.UnitState.MOVING
func find_site(type: BuildingConfigs.BuildingType) -> Vector2i:
	var fp: Vector2i = BuildingConfigs.get_config(type).footprint
	for radius in range(4,60 if type==BuildingConfigs.BuildingType.PORT else 36):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				if maxi(absi(dx),absi(dz))!=radius:continue
				var x: int = floori(center.x)+dx;var z: int = floori(center.z)+dz
				if not game.grid_manager.is_area_buildable(x,z,fp.x,fp.y,false):continue
				# Keep one-cell lanes between construction sites.
				var clearance: bool = true
				for px in range(x-1,x+fp.x+1):
					for pz in range(z-1,z+fp.y+1):
						var tile: Tile = game.grid_manager.get_tile(px,pz)
						if tile and tile.building_id!="":clearance=false
				if not clearance:continue
				if type==BuildingConfigs.BuildingType.FARM and not own_buildings().any(func(b):return b.building_type==BuildingConfigs.BuildingType.WELL and b.position.distance_to(Vector3(x+1.5,2,z+1.5))<12):continue
				if type==BuildingConfigs.BuildingType.PORT and not game.grid_manager.is_coastal_site(x,z,fp.x,fp.y):continue
				var occupied: bool = false
				for u in game.all_units:
					if not u.embarked_in and Rect2(x-.4,z-.4,fp.x+.8,fp.y+.8).has_point(Vector2(u.position.x,u.position.z)):occupied=true;break
				if not occupied and not game.grid_manager.find_path(center,Vector3(x+.5,game.grid_manager.get_height(x,z),z+.5),"goblin").is_empty():return Vector2i(x,z)
	return Vector2i(-1,-1)
func _spawn_night_attack(buildings: Array[Building]) -> void:
	var camp: Building
	for b in buildings:
		if b.building_type==BuildingConfigs.BuildingType.CAMPFIRE and (camp==null or b.position.distance_squared_to(center)<camp.position.distance_squared_to(center)):camp=b
	if not camp:return
	for i in range(mini(24,3+last_raid_day*2)):
		var spawn: Vector3 = game.grid_manager.find_free_position(center+Vector3(0,0,-34-i))
		var enemy: Unit = game.spawn_unit(UnitConfigs.UnitType.SKELETON if i%4==3 else UnitConfigs.UnitType.ZOMBIE,"enemy",spawn)
		RaidSystem.scale_enemy(enemy,last_raid_day)
		enemy.set_meta("goblin_raid",true);enemy.target=camp;enemy.current_order=UnitConfigs.UnitOrder.ATTACK
		enemy.set_path(game.grid_manager.find_path(enemy.position,camp.position,"enemy"));enemy.state=UnitConfigs.UnitState.MOVING

func _plan_equipment(buildings: Array[Building],workers: Array[Unit]) -> void:
	if not game.workshop_system:return
	var wanted: Dictionary={}
	var local_workers: int=workers.filter(func(u):return u.position.distance_squared_to(center)<10000).size()
	var worker_goal: int=10 if buildings.any(func(b):return b.building_type==BuildingConfigs.BuildingType.BARRACKS and b.is_constructed) else 6
	if local_workers<worker_goal:wanted["axe"]=1
	wanted["pitchfork"]=buildings.filter(func(b):return b.building_type==BuildingConfigs.BuildingType.FARM and not b.farm_equipped).size()
	if buildings.any(func(b):return b.building_type==BuildingConfigs.BuildingType.MINE):wanted["pickaxe"]=maxi(0,(2 if local_workers>=7 else 1)-workers.filter(func(u):return u.get_meta("mining_tool",false)).size())
	var reserve: int=0
	var needed: Variant=_next_building(buildings,own_units().size())
	var soldiers: int=own_units().filter(func(u):return not UnitConfigs.is_worker(u.unit_type) and not UnitConfigs.is_vessel(u.unit_type)).size()
	if soldiers>=4 and needed!=null:reserve=BuildingConfigs.get_config(needed).cost.get("wood",0)
	if soldiers>=5 and buildings.any(func(b):return b.building_type==BuildingConfigs.BuildingType.PORT and b.is_constructed) and not own_units().any(func(u):return UnitConfigs.is_vessel(u.unit_type)):reserve=maxi(reserve,110)
	for key in EquipmentConfigs.required(ARMY[army_cursor%ARMY.size()]):
		if FactionEconomy.resources("goblin").wood-EquipmentConfigs.ITEMS[key].cost.wood>=reserve:wanted[key]=1
	for key in wanted:
		if FactionEconomy.resources("goblin").get(key,0)+game.workshop_system.queued("goblin",key)>=wanted[key]:continue
		for b in buildings:
			if b.building_type==BuildingConfigs.BuildingType.WORKSHOP and b.is_constructed and b.crafting_queue.size()<3:
				game.workshop_system.enqueue(b,key);break
