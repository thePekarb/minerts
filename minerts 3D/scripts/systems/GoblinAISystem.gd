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
const PLAN: Array[BuildingConfigs.BuildingType] = [BuildingConfigs.BuildingType.HUT,BuildingConfigs.BuildingType.WELL,BuildingConfigs.BuildingType.FARM,BuildingConfigs.BuildingType.MINE,BuildingConfigs.BuildingType.BARRACKS,BuildingConfigs.BuildingType.STORAGE,BuildingConfigs.BuildingType.PORT,BuildingConfigs.BuildingType.TOWER]
func setup(main: Main) -> void:
	game=main;rng.seed=71024;FactionEconomy.reset_bot()
	place(BuildingConfigs.BuildingType.CAMPFIRE,Vector2i(402,80),true)
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
	var farm_count: int = buildings.filter(func(b):return b.building_type==BuildingConfigs.BuildingType.FARM and b.is_constructed).size()
	for b in buildings:
		if not b.is_constructed or not b.training_queue.is_empty():continue
		if b.building_type==BuildingConfigs.BuildingType.CAMPFIRE and workers.size()<10:
			game.production_system.enqueue(b,UnitConfigs.UnitType.GOBLIN_WORKER)
		elif b.building_type==BuildingConfigs.BuildingType.BARRACKS and units.size()<28 and farm_count>0:
			var next: UnitConfigs.UnitType = ARMY[army_cursor%ARMY.size()]
			var wallet: Dictionary = FactionEconomy.resources("goblin")
			var soldiers: int = units.filter(func(u):return not UnitConfigs.is_worker(u.unit_type) and not UnitConfigs.is_vessel(u.unit_type)).size()
			var reserve: int = 0 if soldiers<4 else (25 if needed==null else 55)
			if soldiers>=9 and buildings.any(func(p):return p.building_type==BuildingConfigs.BuildingType.PORT and p.is_constructed) and not units.any(func(v):return UnitConfigs.is_vessel(v.unit_type)):reserve=maxi(reserve,110)
			if wallet.wood-UnitConfigs.get_config(next).cost.get("wood",0)>=reserve and wallet.food>=45:
				if game.production_system.enqueue(b,next)=="":army_cursor+=1
		elif b.building_type==BuildingConfigs.BuildingType.PORT and not units.any(func(u):return UnitConfigs.is_vessel(u.unit_type)) and farm_count>=2:
			game.production_system.enqueue(b,UnitConfigs.UnitType.GALLEY)
	for b in buildings:
		if b.building_type==BuildingConfigs.BuildingType.MINE and b.is_constructed and b.assigned_miners.size()<2 and workers.size()>=7:
			for u in workers:
				if u.current_order==UnitConfigs.UnitOrder.BUILD or u.mining_building_id!="" or u.inventory.get("amount",0)>0:continue
				var route: Array[Vector3] = game.grid_manager.find_unit_path(u,b.position,true)
				if route.is_empty():continue
				game.selection_system.cancel_assignments(u)
				u.mining_building_id=str(b.get_instance_id());b.assigned_miners.append(u)
				u.target=b;u.current_order=UnitConfigs.UnitOrder.MOVE;u.set_path(route);u.state=UnitConfigs.UnitState.MOVING;break
		if b.building_type==BuildingConfigs.BuildingType.MINE and b.level==1 and FactionEconomy.resources("goblin").wood>120 and FactionEconomy.spend("goblin",b.config.get("upgrade_cost",{"wood":40,"stone":30})):b.upgrade_mine()
	for i in range(workers.size()):
		var u: Unit = workers[i]
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
	if game.production_system.population("goblin")>=game.production_system.capacity("goblin")-2 and counts.get(BuildingConfigs.BuildingType.HUT,0)<6:return BuildingConfigs.BuildingType.HUT
	if counts.get(BuildingConfigs.BuildingType.FARM,0)<2 and counts.has(BuildingConfigs.BuildingType.MINE):return BuildingConfigs.BuildingType.FARM
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
			var destination: Vector3 = game.grid_manager.find_free_position(center+Vector3(rng.randf_range(-25,25),0,rng.randf_range(-25,25)))
			u.current_order=UnitConfigs.UnitOrder.PATROL;u.target=null;u.set_path(game.grid_manager.find_unit_path(u,destination,true));u.state=UnitConfigs.UnitState.MOVING
func find_site(type: BuildingConfigs.BuildingType) -> Vector2i:
	var fp: Vector2i = BuildingConfigs.get_config(type).footprint
	for radius in range(5,60 if type==BuildingConfigs.BuildingType.PORT else 26,3):
		for dx in range(-radius,radius+1,3):
			for dz in range(-radius,radius+1,3):
				if maxi(absi(dx),absi(dz))<radius-2:continue
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
		if b.building_type==BuildingConfigs.BuildingType.CAMPFIRE:camp=b;break
	if not camp:return
	for i in range(mini(24,3+last_raid_day*2)):
		var spawn: Vector3 = game.grid_manager.find_free_position(center+Vector3(0,0,-34-i))
		var enemy: Unit = game.spawn_unit(UnitConfigs.UnitType.SKELETON if i%4==3 else UnitConfigs.UnitType.ZOMBIE,"enemy",spawn)
		RaidSystem.scale_enemy(enemy,last_raid_day)
		enemy.set_meta("goblin_raid",true);enemy.target=camp;enemy.current_order=UnitConfigs.UnitOrder.ATTACK
		enemy.set_path(game.grid_manager.find_path(enemy.position,camp.position,"enemy"));enemy.state=UnitConfigs.UnitState.MOVING
