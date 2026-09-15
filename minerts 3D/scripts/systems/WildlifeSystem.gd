class_name WildlifeSystem
extends Node
var game: Main
var animals: Array[Unit] = []
var predators: Array[Unit] = []
var packs: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var wander_timer: float = 0.0
var last_night: int = -1
func setup(main: Main) -> void:
	game=main;rng.seed=18731
	var islands: Array = game.terrain_generator.world_info.get("islands",[{"center":[96,96],"radius":65}])
	for land in islands:
		var center: Vector3 = Vector3(land.center[0],0,land.center[1])
		for i in range(18 if land.get("id","")=="home" else 8):
			var p: Vector3 = center+Vector3(rng.randf_range(-land.radius*.65,land.radius*.65),0,rng.randf_range(-land.radius*.65,land.radius*.65))
			p=game.grid_manager.find_free_position(p)
			if not game.grid_manager.is_walkable(floori(p.x),floori(p.z)) or Vector2(p.x-96,p.z-96).length()<15:continue
			var type: UnitConfigs.UnitType = [UnitConfigs.UnitType.DEER,UnitConfigs.UnitType.BOAR,UnitConfigs.UnitType.RABBIT][i%3]
			var animal: Unit = game.spawn_unit(type,"neutral",p)
			animals.append(animal)
			animal.health_changed.connect(func(_hp,_max_hp):_react_to_hunter(animal))
	for center in [Vector3(96,0,96),Vector3(402,0,80)]:
		var den: Vector3 = _forest_point(center)
		packs.append({"den":den,"members":[]})
		var bear: Unit = game.spawn_unit(UnitConfigs.UnitType.BEAR,"predator",_forest_point(center))
		bear.set_meta("den",bear.position);predators.append(bear)
	EventBus.entity_died.connect(func(entity):
		if entity is Unit:animals.erase(entity);predators.erase(entity)
	)
func _forest_point(center: Vector3) -> Vector3:
	for attempt in range(200):
		var p: Vector3 = center+Vector3(rng.randf_range(-45,45),0,rng.randf_range(-45,45))
		var tile: Tile = game.grid_manager.get_tile(floori(p.x),floori(p.z))
		if tile and tile.biome==Tile.Biome.FOREST and tile.is_walkable_for() and p.distance_to(center)>24:
			return Vector3(floorf(p.x)+0.5,tile.height,floorf(p.z)+0.5)
	return game.grid_manager.find_free_position(center+Vector3(28,0,18))
func _process(delta: float) -> void:
	wander_timer+=delta
	if wander_timer<0.6:return
	var elapsed: float = wander_timer;wander_timer=0
	var time: float = game.time_of_day_system.time_of_day
	var night: bool = time>=19.0/24 or time<6.0/24
	if night and last_night!=game.time_of_day_system.current_day:
		last_night=game.time_of_day_system.current_day
		for pack in packs:
			pack.members=pack.members.filter(func(u):return is_instance_valid(u) and u.is_alive)
			while pack.members.size()<4:
				var p: Vector3 = game.grid_manager.find_free_position(pack.den+Vector3(pack.members.size(),0,0))
				var wolf: Unit = game.spawn_unit(UnitConfigs.UnitType.WOLF,"predator",p)
				wolf.set_meta("den",pack.den);pack.members.append(wolf);predators.append(wolf)
	for animal in animals:
		if animal.is_alive and animal.state==UnitConfigs.UnitState.IDLE:
			_move_near(animal,animal.position,6)
	for predator in predators:
		if not predator.is_alive:continue
		var active: bool = night or predator.unit_type==UnitConfigs.UnitType.BEAR
		if active:
			var target: Unit = game.combat_system.find_colonist(predator.position,game.all_units,9.0)
			if target:predator.target=target;predator.current_order=UnitConfigs.UnitOrder.ATTACK
			if is_instance_valid(predator.target) and predator.target.is_alive:
				predator.repath_timer=maxf(0,predator.repath_timer-elapsed)
				game.combat_system._attack_or_chase(predator,predator.target,elapsed)
				continue
		else:predator.target=null
		if predator.path.is_empty():
			_move_near(predator,predator.get_meta("den",predator.position),16 if active else 4)
func _move_near(unit: Unit, center: Vector3, radius: float) -> void:
	var dest: Vector3 = game.grid_manager.find_free_position(center+Vector3(rng.randf_range(-radius,radius),0,rng.randf_range(-radius,radius)))
	unit.set_path(game.grid_manager.find_path(unit.position,dest,unit.faction));unit.state=UnitConfigs.UnitState.MOVING
func _react_to_hunter(animal: Unit) -> void:
	if not animal.is_alive or animal.health<=0:return
	var hunter: Unit = game.combat_system.find_colonist(animal.position,game.all_units,15)
	if hunter:
		var direction: Vector3 = (animal.position-hunter.position).normalized()
		var dest: Vector3 = game.grid_manager.find_free_position(animal.position+direction*6)
		animal.set_path(game.grid_manager.find_path(animal.position,dest));animal.state=UnitConfigs.UnitState.MOVING
func create_carcass(animal: Unit) -> Node3D:
	var food: int = animal.config.get("food_loot",0)
	if food<=0:return null
	var pos: Vector3 = game.grid_manager.find_free_position(animal.position)
	var carcass: StaticBody3D = StaticBody3D.new()
	carcass.name="Carcass_%d" % animal.get_instance_id()
	carcass.collision_layer=8;carcass.collision_mask=0
	var model: Node3D = FrontierAssets.instantiate_asset("carcass")
	if not model:model=VoxelMeshFactory.create_box_mesh(Vector3(0.9,0.3,0.5),Color("986255"))
	carcass.add_child(model)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new();box.size=Vector3(1,0.65,0.8)
	shape.shape=box;shape.position.y=0.3;carcass.add_child(shape)
	carcass.position=pos
	carcass.set_meta("resource_type","food");carcass.set_meta("resource_amount",food)
	carcass.set_meta("display_name","Туша: "+animal.config.name)
	carcass.set_meta("res_id",carcass.name)
	carcass.set_meta("grid_x",floori(pos.x));carcass.set_meta("grid_z",floori(pos.z))
	game.world_container.add_child(carcass)
	game.resource_spawner.resources[carcass.name]=carcass
	var tile: Tile = game.grid_manager.get_tile(floori(pos.x),floori(pos.z))
	tile.resource_id=carcass.name
	game.grid_manager.astar.set_point_disabled(game.grid_manager.get_point_id(tile.x,tile.z),true)
	game.grid_manager.invalidate_terrain(Vector2i(tile.x,tile.z))
	game.fog_system.apply_world_materials(carcass)
	return carcass
