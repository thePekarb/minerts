class_name GoblinExpeditionSystem
extends Node
var ai: GoblinAISystem
var game: Main
var phase: String = "Разведка родного острова"
var stage: String = "idle"
var timer: float = 0.0
var elapsed: float = 0.0
var ship: Unit
var squad: Array[Unit] = []
var visited: Dictionary = {"goblin":true}
var island: Dictionary = {}
var landing: Vector3 = Vector3.INF
var home_berth: Vector3 = Vector3.INF
var coast_cache: Dictionary = {}
var cave_party: Array[Unit] = []
var cave_target: Dictionary = {}
var cave_clock: float = 0.0
var cave_visits: int = 0
var landings: int = 0
var player_sighted: bool = false

func setup(owner: GoblinAISystem) -> void:
	ai=owner;game=ai.game

func _process(delta: float) -> void:
	timer+=delta;elapsed+=delta;cave_clock+=delta
	if timer<1.5:return
	timer=0
	var units: Array[Unit] = ai.own_units()
	_tick_caves(units)
	_tick_garrisons(units)
	squad=squad.filter(func(u):return is_instance_valid(u) and u.is_alive)
	if stage!="idle" and (not is_instance_valid(ship) or not ship.is_alive):
		for u in squad:u.set_meta("mission",u.has_meta("island_goal"))
		squad.clear();stage="idle";elapsed=0
	if stage=="idle":
		if ai.economy_age<180:return
		var army: Array[Unit] = []
		for u in units:
			if not UnitConfigs.is_worker(u.unit_type) and not UnitConfigs.is_vessel(u.unit_type) and not u.underground_unit and not u.get_meta("mission",false):army.append(u)
		if army.size()<7:return # Retain at least four defenders at home.
		for u in units:
			if u.unit_type==UnitConfigs.UnitType.GALLEY and u.passengers.is_empty():ship=u;break
		if not is_instance_valid(ship):return
		island=_next_island()
		if island.is_empty():return
		landing=coast(island)
		if landing==Vector3.INF:visited[island.id]=true;return
		home_berth=ship.position
		squad.assign(army.slice(0,mini(6,army.size()-4)))
		for u in units:
			if UnitConfigs.is_worker(u.unit_type) and not u.get_meta("mission",false) and u.mining_building_id=="" and u.inventory.get("amount",0)==0 and u.current_order!=UnitConfigs.UnitOrder.BUILD:squad.append(u);break
		for u in squad:
			game.selection_system.cancel_assignments(u);u.set_meta("mission",true);u.target=null
			game.transport_system.board(u,ship)
		stage="loading";elapsed=0;phase="Погрузка экспедиции: "+island.name
	elif stage=="loading":
		for u in squad:
			if not is_instance_valid(u.embarked_in) and not game.transport_system.boarding.has(u.get_instance_id()):game.transport_system.board(u,ship)
		if ship.passengers.size()>=mini(4,squad.size()) and (ship.passengers.size()==squad.size() or elapsed>35):
			for u in squad:
				if not is_instance_valid(u.embarked_in):game.transport_system.cancel_boarding(u);u.set_meta("mission",false)
			squad=squad.filter(func(u):return is_instance_valid(u.embarked_in))
			if game.transport_system.order_ship(ship,landing):stage="sailing";elapsed=0;phase="Переход к острову: "+island.name
		elif elapsed>90:
			for u in squad:game.transport_system.cancel_boarding(u);u.set_meta("mission",false)
			game.transport_system.unload(ship);squad.clear();stage="idle";elapsed=0
	elif stage=="sailing":
		if ship.path.is_empty():
			game.transport_system.unload(ship)
			if ship.passengers.is_empty():
				for u in squad:u.set_meta("island_goal",Vector3(island.center[0],0,island.center[1]))
				visited[island.id]=true;landings+=1;stage="exploring";elapsed=0;phase="Разведка и захват: "+island.name
		elif elapsed>160:game.transport_system.order_ship(ship,landing);elapsed=0
	elif stage=="exploring":
		for u in squad:
			if is_instance_valid(u.embarked_in):continue
			var enemy: Unit = game.combat_system._find_nearest_target(u.position,game.all_units,"enemy",u.config.get("vision_range",8),true)
			if enemy:
				if enemy.faction=="player":player_sighted=true
				if not UnitConfigs.is_worker(u.unit_type):u.target=enemy;u.current_order=UnitConfigs.UnitOrder.ATTACK
				continue
			if u.current_order==UnitConfigs.UnitOrder.ATTACK and is_instance_valid(u.target):continue
			if UnitConfigs.is_worker(u.unit_type):
				if _establish_outpost(u):continue
			var hostile_building: Building
			for b in game.all_buildings:
				if not is_instance_valid(b) or not b.is_alive: continue
				if b.faction=="player" and u.position.distance_to(b.position)<11:hostile_building=b;break
			if hostile_building:
				player_sighted=true;u.target=hostile_building;u.current_order=UnitConfigs.UnitOrder.ATTACK;continue
			if u.path.is_empty():
				var c: Vector3 = Vector3(island.center[0],0,island.center[1])
				var point: Vector3 = game.grid_manager.find_free_position(c+Vector3(ai.rng.randf_range(-18,18),0,ai.rng.randf_range(-18,18)))
				u.current_order=UnitConfigs.UnitOrder.PATROL;u.set_path(game.grid_manager.find_unit_path(u,point,true));u.state=UnitConfigs.UnitState.MOVING
		if elapsed>110 or squad.is_empty():
			# Landed troops keep their orders and outpost; the galley returns for reinforcements.
			if game.transport_system.order_ship(ship,home_berth):stage="returning";elapsed=0;phase="Возвращение за подкреплением"
	elif stage=="returning" and ship.path.is_empty():
		squad.clear();stage="idle";elapsed=0

func _next_island() -> Dictionary:
	var options: Array = game.terrain_generator.world_info.islands.filter(func(i):return not visited.has(i.id))
	if options.is_empty():return game.terrain_generator.world_info.islands[0] # Reinforce the assault after reconnaissance.
	options.sort_custom(func(a,b):return Vector2(a.center[0]-ai.center.x,a.center[1]-ai.center.z).length_squared()<Vector2(b.center[0]-ai.center.x,b.center[1]-ai.center.z).length_squared())
	return options[0]

func coast(data: Dictionary) -> Vector3:
	if coast_cache.has(data.id):return coast_cache[data.id]
	var candidates: Array[Vector3] = []
	var cx: int = data.center[0];var cz: int = data.center[1];var radius: int = data.radius+7
	for x in range(maxi(2,cx-radius),mini(GridManager.GRID_SIZE-2,cx+radius)):
		for z in range(maxi(2,cz-radius),mini(GridManager.GRID_SIZE-2,cz+radius)):
			if not game.grid_manager.is_walkable(x,z) or game.grid_manager.get_height(x,z)>2:continue
			if not game.grid_manager.is_coastal_site(x,z,1,1):continue
			candidates.append(Vector3(x+0.5,game.grid_manager.get_height(x,z),z+0.5))
	candidates.sort_custom(func(a,b):return a.distance_squared_to(ai.center)<b.distance_squared_to(ai.center))
	for point in candidates:
		var water: Vector3 = game.grid_manager.nearest_sea_position(point,3)
		if water==Vector3.INF or water.distance_to(point)>3.8:continue
		var origin: Vector3 = Vector3(cx+0.5,game.grid_manager.get_height(cx,cz),cz+0.5)
		if game.grid_manager.find_path(origin,point,"goblin").is_empty():continue
		coast_cache[data.id]=point;return point
	return Vector3.INF

func _establish_outpost(worker: Unit) -> bool:
	if worker.current_order==UnitConfigs.UnitOrder.BUILD and is_instance_valid(worker.target):return true
	if ai.own_buildings().any(func(b):return b.position.distance_to(landing)<16):return false
	for dx in range(-6,7):
		for dz in range(-6,7):
			var cell: Vector2i = Vector2i(floori(landing.x)+dx,floori(landing.z)+dz)
			if not game.grid_manager.is_area_buildable(cell.x,cell.y,2,2,false):continue
			var occupied: bool = false
			for unit in game.all_units:
				if not unit.underground_unit and not is_instance_valid(unit.embarked_in) and Rect2(cell.x-.4,cell.y-.4,2.8,2.8).has_point(Vector2(unit.position.x,unit.position.z)):occupied=true;break
			if occupied:continue
			if game.grid_manager.find_path(worker.position,Vector3(cell.x+1,worker.position.y,cell.y+1),"goblin").is_empty():continue
			var cost: Dictionary = BuildingConfigs.get_config(BuildingConfigs.BuildingType.STORAGE).cost
			if not FactionEconomy.spend("goblin",cost):return false
			var b: Building = ai.place(BuildingConfigs.BuildingType.STORAGE,cell)
			worker.target=b;worker.current_order=UnitConfigs.UnitOrder.BUILD;worker.set_path(game.grid_manager.find_unit_path(worker,b.position,true));worker.state=UnitConfigs.UnitState.MOVING
			return true
	return false

func _tick_caves(units: Array[Unit]) -> void:
	cave_party=cave_party.filter(func(u):return is_instance_valid(u) and u.is_alive)
	if cave_party.is_empty():
		if ai.economy_age<100 or cave_clock<75:return
		var fighters: Array[Unit] = []
		for u in units:
			if not UnitConfigs.is_worker(u.unit_type) and not UnitConfigs.is_vessel(u.unit_type) and not u.get_meta("mission",false) and u.position.distance_to(ai.center)<30:fighters.append(u)
		if fighters.size()<5:return
		for cave in game.underground_system.caves:
			if Vector2(cave.entry.x-ai.center.x,cave.entry.y-ai.center.z).length()<40:cave_target=cave;break
		if cave_target.is_empty():return
		cave_party.assign(fighters.slice(0,2));cave_clock=0
		for u in cave_party:
			u.set_meta("mission",true);u.set_meta("cave_survey",true);game.selection_system.cancel_assignments(u)
			u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE
			u.set_path(game.grid_manager.find_unit_path(u,Vector3(cave_target.entry.x+0.5,2,cave_target.entry.y+0.5),true));u.state=UnitConfigs.UnitState.MOVING
		return
	for u in cave_party:
		var entry: Vector3 = Vector3(cave_target.entry.x+0.5,u.position.y,cave_target.entry.y+0.5)
		if not u.underground_unit:
			if cave_clock>60:u.set_meta("mission",false);u.set_meta("cave_survey",false)
			elif u.position.distance_to(entry)<2.0:game.underground_system.enter(u,cave_target.entry);cave_visits+=1
		elif cave_clock>60 or u.health<u.max_health*.35:game.underground_system.request_exit(u)
		elif u.path.is_empty() and not (u.current_order==UnitConfigs.UnitOrder.ATTACK and is_instance_valid(u.target)):
			var cell: Vector2i = cave_target.cells[ai.rng.randi_range(0,cave_target.cells.size()-1)]
			u.current_order=UnitConfigs.UnitOrder.PATROL;u.set_path(game.grid_manager.find_unit_path(u,Vector3(cell.x+0.5,-4,cell.y+0.5),true));u.state=UnitConfigs.UnitState.MOVING
	cave_party=cave_party.filter(func(u):return u.get_meta("cave_survey",false))

func _tick_garrisons(units: Array[Unit]) -> void:
	for u in units:
		if not u.has_meta("island_goal") or squad.has(u) or u.underground_unit or is_instance_valid(u.embarked_in):continue
		if u.current_order==UnitConfigs.UnitOrder.ATTACK and is_instance_valid(u.target):continue
		var hostile: Unit = game.combat_system._find_nearest_target(u.position,game.all_units,"enemy",12,true)
		if hostile and not UnitConfigs.is_worker(u.unit_type):
			u.target=hostile;u.current_order=UnitConfigs.UnitOrder.ATTACK
			if hostile.faction=="player":player_sighted=true
			continue
		for b in game.all_buildings:
			if not is_instance_valid(b) or not b.is_alive: continue
			if b.faction=="player" and u.position.distance_to(b.position)<12:
				u.target=b;u.current_order=UnitConfigs.UnitOrder.ATTACK;player_sighted=true;break
		if u.current_order==UnitConfigs.UnitOrder.ATTACK and is_instance_valid(u.target):continue
		if u.path.is_empty():
			var center: Vector3 = u.get_meta("island_goal")
			var point: Vector3 = game.grid_manager.find_free_position(center+Vector3(ai.rng.randf_range(-14,14),0,ai.rng.randf_range(-14,14)))
			u.target=null;u.current_order=UnitConfigs.UnitOrder.PATROL;u.set_path(game.grid_manager.find_unit_path(u,point,true));u.state=UnitConfigs.UnitState.MOVING
