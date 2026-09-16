class_name TransportSystem
extends Node
var game: Main
var boarding: Dictionary = {}
func setup(main: Main) -> void:
	game=main
	game.grid_manager.transport=self
func board(unit: Unit, ship: Unit) -> bool:
	if not is_instance_valid(unit) or not is_instance_valid(ship) or unit==ship or unit.faction!=ship.faction or UnitConfigs.is_vessel(unit.unit_type) or unit.underground_unit:return false
	var reserved: int = ship.passengers.size()
	for job in boarding.values():
		if job.ship.get_ref()==ship:reserved+=1
	if reserved>=ship.config.get("capacity",0):return false
	var shore: Vector3 = _landing_cell(ship.position,unit)
	if shore==Vector3.INF:return false
	var path: Array[Vector3] = game.grid_manager.find_path(unit.position,shore,unit.faction)
	if path.is_empty():return false
	game.selection_system.cancel_assignments(unit)
	unit.target=null;unit.current_order=UnitConfigs.UnitOrder.MOVE
	unit.set_path(path);unit.state=UnitConfigs.UnitState.MOVING
	boarding[unit.get_instance_id()]={"unit":weakref(unit),"ship":weakref(ship)}
	return true
func cancel_boarding(unit: Unit) -> void:
	boarding.erase(unit.get_instance_id())
func _landing_cell(pos: Vector3, passenger: Unit = null) -> Vector3:
	var best: Vector3 = Vector3.INF
	var distance: float = INF
	for dx in range(-4,5):
		for dz in range(-4,5):
			var p: Vector3 = Vector3(floorf(pos.x)+dx+0.5,0,floorf(pos.z)+dz+0.5)
			if not game.grid_manager.is_walkable(floori(p.x),floori(p.z)):continue
			p.y=game.grid_manager.get_height(p.x,p.z)
			if p.y>2.0 or Vector2(p.x-pos.x,p.z-pos.z).length()>3.5:continue
			var free: bool = true
			for u in game.all_units:
				if u!=passenger and not u.embarked_in and u.is_alive and u.position.distance_to(p)<0.75:free=false;break
			if free and p.distance_squared_to(pos)<distance:best=p;distance=p.distance_squared_to(pos)
	return best
func unload(ship: Unit) -> int:
	if NetworkManager.route_units("unload",[ship]):return 0
	var count: int = 0
	for unit in ship.passengers.duplicate():
		if not is_instance_valid(unit):ship.passengers.erase(unit);continue
		var shore: Vector3 = _landing_cell(ship.position,unit)
		if shore==Vector3.INF:break
		ship.passengers.erase(unit)
		unit.embarked_in=null;unit.position=shore;unit.stop()
		unit.collision_layer=2;unit.collision_mask=2|4
		unit.visible=not game.underground_system.cutaway
		count+=1
	if count>0:game.grid_manager.unit_index.invalidate()
	return count
func order_ship(ship: Unit, destination: Vector3) -> bool:
	if not UnitConfigs.is_vessel(ship.unit_type):return false
	var land: bool = not game.grid_manager.is_sea_position(destination)
	var water: Vector3 = game.grid_manager.nearest_sea_position(destination,6) if land else Vector3(destination.x,0.22,destination.z)
	if water==Vector3.INF:return false
	var path: Array[Vector3] = game.grid_manager.find_sea_path(ship.position,water)
	if path.is_empty():return false
	ship.target=null;ship.current_order=UnitConfigs.UnitOrder.MOVE
	ship.set_path(path);ship.state=UnitConfigs.UnitState.MOVING
	ship.set_meta("auto_unload",land)
	return true
func tick(_delta: float) -> void:
	for id in boarding.keys():
		var job: Dictionary = boarding[id]
		var unit: Unit = job.unit.get_ref()
		var ship: Unit = job.ship.get_ref()
		if not is_instance_valid(unit) or not is_instance_valid(ship) or not unit.is_alive or not ship.is_alive:
			boarding.erase(id);continue
		if unit.position.distance_to(ship.position)>4.0:continue
		if ship.passengers.size()>=ship.config.get("capacity",0):boarding.erase(id);continue
		unit.stop();unit.target=null
		unit.embarked_in=ship;ship.passengers.append(unit)
		unit.visible=false;unit.collision_layer=0;unit.collision_mask=0
		boarding.erase(id)
		game.selection_system.remove_entity(unit)
	for ship in game.all_units:
		if not UnitConfigs.is_vessel(ship.unit_type):continue
		for unit in ship.passengers:
			if is_instance_valid(unit):unit.position=ship.position
		if ship.path.is_empty() and ship.get_meta("auto_unload",false):
			unload(ship);ship.set_meta("auto_unload",false)
func on_death(unit: Unit) -> void:
	boarding.erase(unit.get_instance_id())
	if is_instance_valid(unit.embarked_in):unit.embarked_in.passengers.erase(unit)
	for passenger in unit.passengers.duplicate():
		if is_instance_valid(passenger) and passenger.is_alive:
			passenger.embarked_in=null
			passenger.take_damage(100000)
	unit.passengers.clear()
