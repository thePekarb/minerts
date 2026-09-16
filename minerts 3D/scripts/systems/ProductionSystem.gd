class_name ProductionSystem
extends Node
var game: Main
const MAX_QUEUE: int = 6
func setup(main: Main) -> void:
	game=main
func permitted(building: Building, type: UnitConfigs.UnitType) -> bool:
	if not building.is_constructed or not building.is_alive:return false
	if building.building_type==BuildingConfigs.BuildingType.PORT:return UnitConfigs.is_vessel(type)
	var is_goblin: bool = FactionRules.race(building.faction)=="goblin"
	if is_goblin:
		if building.building_type in [BuildingConfigs.BuildingType.CAMPFIRE,BuildingConfigs.BuildingType.HUT]:return type==UnitConfigs.UnitType.GOBLIN_WORKER
		return building.building_type==BuildingConfigs.BuildingType.BARRACKS and type in [UnitConfigs.UnitType.GOBLIN_WARRIOR,UnitConfigs.UnitType.GOBLIN_ARCHER,UnitConfigs.UnitType.GOBLIN_SPEARMAN,UnitConfigs.UnitType.SPIDER_RIDER,UnitConfigs.UnitType.TROLL]
	if building.building_type in [BuildingConfigs.BuildingType.CAMPFIRE,BuildingConfigs.BuildingType.HUT]:return type in [UnitConfigs.UnitType.WORKER,UnitConfigs.UnitType.SCOUT]
	return building.building_type==BuildingConfigs.BuildingType.BARRACKS and type in [UnitConfigs.UnitType.WARRIOR,UnitConfigs.UnitType.ARCHER]
func population(faction: String, include_queue: bool = true) -> int:
	var total: int = 0
	for unit in game.all_units:
		if is_instance_valid(unit) and unit.is_alive and unit.faction==faction and not UnitConfigs.is_vessel(unit.unit_type):total+=1
	if include_queue:
		for b in game.all_buildings:
			if is_instance_valid(b) and b.faction==faction and b.is_alive:
				for job in b.training_queue:
					if not UnitConfigs.is_vessel(job.type):total+=1
	return total
func capacity(faction: String) -> int:
	var total: int = 10
	for b in game.all_buildings:
		if is_instance_valid(b) and b.is_alive and b.is_constructed and b.faction==faction and b.building_type==BuildingConfigs.BuildingType.HUT:total+=4
	return total
func enqueue(building: Building, type: UnitConfigs.UnitType) -> String:
	if NetworkManager.route_building("train",building,{"type":int(type)}):return ""
	if not is_instance_valid(building) or not permitted(building,type):return "Выберите подходящее готовое здание."
	if building.training_queue.size()>=MAX_QUEUE:return "Очередь заполнена (6 мест)."
	if not UnitConfigs.is_vessel(type) and population(building.faction)>=capacity(building.faction):return "Нет свободных мест населения. Постройте хижину."
	var equipment: Dictionary=EquipmentConfigs.required(type)
	if not FactionEconomy.can_afford(building.faction,equipment):return "Сначала изготовьте: "+EquipmentConfigs.cost_text(equipment)
	var cost: Dictionary = UnitConfigs.get_config(type).get("cost",{}).duplicate()
	for key in equipment:cost[key]=cost.get(key,0)+equipment[key]
	if not FactionEconomy.spend(building.faction,cost):return "Недостаточно ресурсов."
	building.training_queue.append({"type":type,"cost":cost.duplicate(),"progress":0.0,"duration":UnitConfigs.training_time(type)})
	return ""
func cancel(building: Building, index: int = -1) -> void:
	if NetworkManager.route_building("cancel",building,{"index":index}):return
	if not is_instance_valid(building) or building.training_queue.is_empty():return
	if index<0:index=building.training_queue.size()-1
	if index>=building.training_queue.size():return
	var job: Dictionary = building.training_queue[index]
	for key in job.cost:FactionEconomy.add(building.faction,key,job.cost[key])
	building.training_queue.remove_at(index)
func tick(delta: float) -> void:
	for b in game.all_buildings.duplicate():
		if not is_instance_valid(b) or not b.is_alive or not b.is_constructed or b.training_queue.is_empty():continue
		var job: Dictionary = b.training_queue[0]
		if not UnitConfigs.is_vessel(job.type) and population(b.faction,false)>=capacity(b.faction):continue
		job.progress=minf(job.duration,job.progress+delta)
		if job.progress<job.duration:continue
		var spawn: Vector3 = spawn_position(b,UnitConfigs.is_vessel(job.type))
		if spawn==Vector3.INF:continue # A blocked doorway/berth keeps the completed unit queued.
		b.training_queue.pop_front()
		var unit: Unit = game.spawn_unit(job.type,b.faction,spawn)
		if b.rally_point!=Vector3.INF:
			if UnitConfigs.is_vessel(unit.unit_type):game.transport_system.order_ship(unit,b.rally_point)
			else:
				var path: Array[Vector3] = game.grid_manager.find_path(unit.global_position,b.rally_point,b.faction)
				unit.set_path(path)
				unit.current_order = UnitConfigs.UnitOrder.MOVE
				unit.state = UnitConfigs.UnitState.MOVING
func spawn_position(building: Building, vessel: bool) -> Vector3:
	for radius in range(2,8):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				if maxi(absi(dx),absi(dz))!=radius:continue
				var point: Vector3 = Vector3(floorf(building.position.x)+dx+0.5,0,floorf(building.position.z)+dz+0.5)
				if vessel:
					if not game.grid_manager.is_sea_position(point):continue
					point.y=0.22
				else:
					if not game.grid_manager.is_walkable(floori(point.x),floori(point.z),building.faction):continue
					point.y=game.grid_manager.get_height(point.x,point.z)
					if game.grid_manager.find_path(point,building.position,building.faction).is_empty():continue
				var free: bool = true
				for u in game.all_units:
					if u.is_alive and not u.embarked_in and u.position.distance_to(point)<1.0:free=false;break
				if free:return point
	return Vector3.INF
func set_rally(building: Building, destination: Vector3) -> bool:
	if NetworkManager.route_building("rally",building,{"point":destination}):return true
	if not is_instance_valid(building) or not FactionRules.is_colony(building.faction) or not building.is_constructed:return false
	if building.building_type==BuildingConfigs.BuildingType.PORT:
		destination=game.grid_manager.nearest_sea_position(destination,8)
		if destination==Vector3.INF:return false
	else:
		var cell: Vector2i = Vector2i(floori(destination.x), floori(destination.z))
		if not game.grid_manager.is_valid_coord(cell.x, cell.y):
			return false
		if not game.grid_manager.is_walkable(cell.x, cell.y, building.faction):
			var free_cell: Vector2i = game.grid_manager.find_nearest_walkable(cell, 4, building.faction)
			if free_cell.x >= 0:
				destination = Vector3(free_cell.x + 0.5, game.grid_manager.get_height(free_cell.x, free_cell.y), free_cell.y + 0.5)
			else:
				return false
		else:
			destination.y = game.grid_manager.get_height(cell.x, cell.y)
	building.rally_point=destination
	if not is_instance_valid(building.rally_marker):
		var marker: Node3D = Node3D.new()
		game.add_child(marker)
		var pole: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(0.08,1.4,0.08),Color("d97706"))
		pole.position.y=0.7;marker.add_child(pole)
		var flag: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(0.7,0.4,0.06),Color("22c55e"))
		flag.position=Vector3(0.35,1.15,0);marker.add_child(flag)
		building.rally_marker=marker
	building.rally_marker.position=destination
	building.rally_marker.visible = true
	SoundManager.play_click()
	return true
func queue_text(building: Building) -> String:
	if building.training_queue.is_empty():return "Очередь пуста · ПКМ на карте: точка сбора"
	var names: Array[String] = []
	for i in range(building.training_queue.size()):
		var job: Dictionary = building.training_queue[i]
		names.append("%s%s" % [UnitConfigs.get_config(job.type).name," (%d с)" % ceili(job.duration-job.progress) if i==0 else ""])
	return " → ".join(names)
