extends Node3D
var grid: GridManager
var gathering: GatheringSystem
var units: Array[Unit] = []
var checks: int = 0
var failures: int = 0
var delivered: int = 0
func check(ok: bool,title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)
func spawn(pos: Vector3) -> Unit:
	var u: Unit = load("res://scenes/entities/Unit.tscn").instantiate();u.grid_manager=grid;u.position=pos;add_child(u);units.append(u);return u
func _ready() -> void:
	SoundManager.is_muted=true
	grid=GridManager.new();add_child(grid)
	var tiles: Array = []
	for x in range(GridManager.GRID_SIZE):
		var row: Array = []
		for z in range(GridManager.GRID_SIZE):row.append(Tile.new(x,z,0,Tile.Biome.PLAINS,x>=3 and x<=40 and z>=3 and z<=40))
		tiles.append(row)
	grid.init_grid(tiles)
	gathering=GatheringSystem.new();gathering.grid_manager=grid;add_child(gathering)
	gathering.resources_delivered.connect(func(_faction,resource,amount):
		if resource=="wood":delivered+=amount
	)
	var storage: Building = Building.new();add_child(storage);storage.init_building(BuildingConfigs.BuildingType.STORAGE,12,20,true);storage.position=Vector3(13,0,21);grid.occupy_area(12,20,2,2,storage);gathering.register_storage(storage)
	for i in range(8):
		var u: Unit = spawn(Vector3(8.5+i,0,17.5))
		var tree: StaticBody3D = StaticBody3D.new();add_child(tree);tree.position=Vector3(29.5+i%4,0,18.5+(i/4)*3)
		tree.set_meta("resource_type","wood");tree.set_meta("resource_amount",200)
		var cell: Tile = grid.get_tile(floori(tree.position.x),floori(tree.position.z));cell.resource_id=str(tree.get_instance_id());grid.astar.set_point_disabled(grid.get_point_id(cell.x,cell.z),true)
		u.target=tree;u.current_order=UnitConfigs.UnitOrder.GATHER;u.set_path(grid.find_path(u.position,tree.position));u.state=UnitConfigs.UnitState.MOVING
	for i in range(3600):
		await get_tree().physics_frame
		gathering.process_gathering(1.0/60,units)
	if delivered<8*14:
		print("DELIVERY DEBUG ",delivered)
		for u in units:print(u.position," ",u.state," goal ",u.destination," inventory ",u.inventory," path ",u.path.slice(u.waypoint_index,u.waypoint_index+6)," vel ",u.velocity," stall ",u.navigation.stalled_for)
	check(delivered>=8*14,"eight workers navigate crowded resource sites and deliver their full loads")
	check(is_instance_valid(storage) and not storage.is_queued_for_deletion(),"storage survives simultaneous interrupted deliveries")
	for u in units:u.queue_free()
	units.clear();await get_tree().physics_frame
	var mover: Unit = spawn(Vector3(7.5,0,7.5));mover.set_path(grid.find_path(mover.position,Vector3(35.5,0,7.5)));mover.state=UnitConfigs.UnitState.MOVING
	for i in range(120):await get_tree().physics_frame
	for z in range(3,12):
		grid.set_tile_occupied(21,z,"new-wall")
		var wall: StaticBody3D = StaticBody3D.new();wall.collision_layer=4;add_child(wall);wall.position=Vector3(21.5,1,z+0.5)
		var collision: CollisionShape3D = CollisionShape3D.new();var shape: BoxShape3D = BoxShape3D.new();shape.size=Vector3(.95,2,.95);collision.shape=shape;wall.add_child(collision)
	for i in range(1800):await get_tree().physics_frame
	check(mover.position.distance_to(Vector3(35.5,0,7.5))<0.4,"a newly placed obstacle triggers a detour without cancelling the order")
	mover.position=Vector3(6.5,0,30.5);mover.stop();mover.target=storage;mover.current_order=UnitConfigs.UnitOrder.GATHER;mover.inventory={"type":"wood","amount":9};mover.state=UnitConfigs.UnitState.RETURNING_TO_STORAGE
	var before: int = delivered
	for i in range(1500):
		await get_tree().physics_frame
		gathering.process_gathering(1.0/60,units)
	check(delivered==before+9 and mover.inventory.amount==0,"a carrier with a lost route replans and delivers its cargo")
	var miner: Unit = spawn(Vector3(37.5,0,37.5))
	var mine: Building = Building.new();add_child(mine);mine.init_building(BuildingConfigs.BuildingType.MINE,4,4,true);mine.position=Vector3(5,0,5);gathering.active_mines.append(mine);mine.assigned_miners.append(miner);miner.path.clear()
	gathering._update_mines(0.1)
	check(miner.state!=UnitConfigs.UnitState.MINING_INSIDE,"an empty path never teleports a distant worker into a mine")
	print("JOB NAVIGATION CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
