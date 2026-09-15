extends Node3D
var grid: GridManager
var checks: int = 0
var failures: int = 0
var units: Array[Unit] = []
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS: ", title)
	else:
		failures += 1
		push_error(title)
func spawn(pos: Vector3, dest: Vector3, type: UnitConfigs.UnitType = UnitConfigs.UnitType.WORKER) -> Unit:
	var unit: Unit = load("res://scenes/entities/Unit.tscn").instantiate()
	unit.unit_type=type
	unit.grid_manager = grid
	unit.position = pos
	add_child(unit)
	unit.set_path(grid.find_path(pos,dest))
	unit.state = UnitConfigs.UnitState.MOVING
	units.append(unit)
	return unit
func _ready() -> void:
	SoundManager.is_muted = true
	grid = GridManager.new()
	add_child(grid)
	var tiles: Array = []
	for x in range(GridManager.GRID_SIZE):
		var row: Array = []
		for z in range(GridManager.GRID_SIZE):
			var h: int = 0
			if x >= 10 and x <= 14 and z >= 5 and z <= 8: h = 1
			if x >= 20 and x <= 25 and z >= 5 and z <= 15: h = 2
			if x >= 20 and x <= 25 and z == 16: h = 1
			row.append(Tile.new(x,z,h,Tile.Biome.PLAINS,x>=3 and x<=32 and z>=3 and z<=32))
		tiles.append(row)
	grid.init_grid(tiles)
	var jumper: Unit = spawn(Vector3(8.5,0,6.5),Vector3(12.5,1,6.5))
	var climber: Unit = spawn(Vector3(17.5,0,10.5),Vector3(23.5,2,10.5))
	check(climber.path.any(func(p): return p.z >= 16), "tall plateau route uses the low ramp around the cliff")
	var jumped: bool = false
	for i in range(600):
		await get_tree().physics_frame
		jumped = jumped or jumper.jump_progress < 1
	check(jumped and jumper.position.distance_to(Vector3(12.5,1,6.5))<0.3, "worker actually jumps a waist-high block and reaches its destination")
	check(climber.position.distance_to(Vector3(23.5,2,10.5))<0.3, "worker follows the detour and climbs two separate low steps")
	jumper.queue_free()
	climber.queue_free()
	units.clear()
	for i in range(3):
		spawn(Vector3(6.5+i*1.5,0,23.5),Vector3(25.5+i*1.5,0,23.5),[UnitConfigs.UnitType.WORKER,UnitConfigs.UnitType.SPIDER,UnitConfigs.UnitType.TROLL][i])
		spawn(Vector3(25.5+i*1.5,0,23.5),Vector3(6.5+i*1.5,0,23.5),[UnitConfigs.UnitType.GOBLIN_WARRIOR,UnitConfigs.UnitType.BEAR,UnitConfigs.UnitType.SKELETON][i])
	for i in range(1200): await get_tree().physics_frame
	var arrived: int = 0
	for u in units:
		if u.position.distance_to(u.destination)<0.4: arrived+=1
		else: print("TRAFFIC STUCK: ",u.position," destination ",u.destination," state ",u.state)
	check(arrived==6, "mixed unit types pass each other without permanent deadlock")
	for u in units: u.queue_free()
	units.clear()
	await get_tree().physics_frame
	for z in range(3,33):
		if z == 24: continue
		grid.set_tile_occupied(17,z,"test_wall")
		var wall: StaticBody3D = StaticBody3D.new()
		wall.collision_layer=4
		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size=Vector3(0.95,2,0.95)
		col.shape=shape
		wall.add_child(col)
		wall.position=Vector3(17.5,1,z+0.5)
		add_child(wall)
	for i in range(6): spawn(Vector3(12.5,0,21.5+i),Vector3(23.5,0,21.5+i))
	for i in range(1200): await get_tree().physics_frame
	arrived=0
	for u in units:
		if u.position.distance_to(u.destination)<0.4: arrived+=1
		else: print("GATE STUCK: ",u.position," destination ",u.destination," state ",u.state)
	check(arrived==6, "six workers queue through a one-cell gate and reach separate positions")
	for u in units: u.queue_free()
	units.clear()
	await get_tree().physics_frame
	for i in range(3):
		spawn(Vector3(12.5,0,22.5+i),Vector3(24.5,0,22.5+i))
		spawn(Vector3(24.5,0,26.5+i),Vector3(12.5,0,26.5+i))
	for i in range(2400):await get_tree().physics_frame
	arrived=0
	for u in units:
		if u.position.distance_to(u.destination)<0.4:arrived+=1
		else:print("TWO WAY STUCK: ",u.position," goal ",u.destination," waiting ",u.navigation.waiting_for_gate)
	check(arrived==6,"opposing groups share a narrow gate without circular reservations")
	for u in units:u.queue_free()
	units.clear();await get_tree().physics_frame
	var idle: Unit = spawn(Vector3(17.5,0,24.5),Vector3(17.5,0,24.5));idle.stop()
	var passer: Unit = spawn(Vector3(12.5,0,24.5),Vector3(23.5,0,24.5))
	for i in range(1200):await get_tree().physics_frame
	check(passer.position.distance_to(passer.destination)<0.4,"idle ally clears a gate for a unit carrying out a move order")
	for u in units:u.queue_free()
	units.clear();await get_tree().physics_frame
	var building: Building = Building.new()
	add_child(building)
	building.init_building(BuildingConfigs.BuildingType.BARRACKS,22,23,false)
	building.position=Vector3(23.5,0,24.5)
	grid.occupy_area(22,23,3,3,building)
	var builder: Unit = spawn(Vector3(12.5,0,25.5),building.position)
	builder.target=building
	builder.current_order=UnitConfigs.UnitOrder.BUILD
	var gathering: GatheringSystem = GatheringSystem.new()
	gathering.grid_manager=grid
	add_child(gathering)
	for i in range(1500):
		await get_tree().physics_frame
		gathering._update_unit_build(builder,1.0/60)
	check(building.is_constructed and builder.state==UnitConfigs.UnitState.IDLE, "builder navigates the gate and finishes a barracks at its perimeter")
	print("NAVIGATION CHECKS: %d | FAILURES: %d" % [checks, failures])
	get_tree().quit(failures)
