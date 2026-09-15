extends Node3D
var checks: int = 0
var failures: int = 0
var grid: GridManager

func check(ok: bool,title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)
func flush_hierarchy() -> void:
	while not grid.hierarchy.dirty.is_empty():grid.hierarchy.process_budget(100000)
func valid_route(route: Array) -> bool:
	for i in range(route.size()):
		var p: Vector3 = route[i]
		if not grid.is_walkable(floori(p.x),floori(p.z)):return false
		if i>0 and not grid.can_step(route[i-1],p):return false
	return not route.is_empty()
func _ready() -> void:
	SoundManager.is_muted=true
	grid=GridManager.new();add_child(grid)
	var tiles: Array = []
	for x in range(GridManager.GRID_SIZE):
		var row: Array = []
		for z in range(GridManager.GRID_SIZE):row.append(Tile.new(x,z,0,Tile.Biome.PLAINS,x>=2 and x<158 and z>=2 and z<95))
		tiles.append(row)
	grid.init_grid(tiles)
	for x in [35,67,99]:
		for z in range(2,80):grid.set_tile_occupied(x,z,"wall")
	flush_hierarchy()
	var from := Vector3(10.5,0,10.5)
	var goal := Vector3(140.5,0,10.5)
	var before: int = grid.surface_astar_searches
	var route: Array[Vector3] = grid.find_path(from,goal)
	check(valid_route(route),"hierarchical route goes around three walls crossing cluster interiors")
	check(grid.hierarchy.searches>0 and grid.surface_astar_searches==before,"long route uses the abstract graph and local searches")
	check(route.back()==goal,"hierarchical refinement retains the precise destination")
	var native: PackedVector3Array = grid.astar.get_point_path(grid.get_point_id(10,10),grid.get_point_id(140,10))
	check(route.size()<native.size()*1.8,"hierarchical detour remains bounded against native A-star")
	var rebuilt: int = grid.hierarchy.rebuild_count
	grid.set_tile_occupied(12,10,"dynamic")
	check(grid.hierarchy.dirty.size()==1,"one construction cell invalidates only its own cluster")
	flush_hierarchy()
	check(grid.hierarchy.rebuild_count==rebuilt+1 and valid_route(grid.find_path(from,goal)),"local cluster rebuild preserves neighboring portal connectivity")
	for z in range(2,95):grid.set_tile_occupied(120,z,"closed-barrier")
	flush_hierarchy()
	check(grid.find_path(from,goal).is_empty(),"separated components never create fictitious cluster passages")
	for z in range(78,86):grid.free_tile(120,z)
	flush_hierarchy()
	check(valid_route(grid.find_path(from,goal)),"opening a passage reconnects the component graph")
	var units: Array[Unit] = []
	var goals: Array[Vector3] = []
	for i in range(50):
		var u: Unit = load("res://scenes/entities/Unit.tscn").instantiate()
		u.grid_manager=grid;u.position=Vector3(5.5+i%10,0,25.5+i/10);add_child(u)
		u.current_order=UnitConfigs.UnitOrder.MOVE;u.state=UnitConfigs.UnitState.MOVING
		units.append(u);goals.append(Vector3(138.5+i%10,0,20.5+i/10))
	grid.group_navigation.enqueue(units,goals)
	units[0].stop()
	var canceled: Vector3 = units[0].position
	for i in range(2000):
		await get_tree().physics_frame
		if grid.group_navigation.jobs.is_empty():break
	check(grid.group_navigation.jobs.is_empty(),"budgeted field construction and route assignment finish")
	check(grid.group_navigation.fields_built==1 and grid.group_navigation.shared_routes==49,"49 distinct starting cells share one reverse flow field")
	check(units[0].path.is_empty() and units[0].position==canceled,"an obsolete queued move cannot overwrite a stop order")
	check(units[1].destination==goals[1] and units[49].destination==goals[49],"flow field preserves separate formation slots")
	check(units.slice(1).all(func(u):return valid_route(u.path)),"all group routes obey the same obstacle and step rules")
	var arrived: int = 0
	for frame in range(12000):
		await get_tree().physics_frame
		if frame%600==0:
			arrived=0
			for i in range(1,units.size()):
				if units[i].position.distance_to(goals[i])<.5:arrived+=1
			print("GROUP JOURNEY: ",frame/60," seconds, arrived ",arrived,"/49")
			if arrived==49:break
	arrived=0
	for i in range(1,units.size()):
		if units[i].position.distance_to(goals[i])<.5:arrived+=1
	check(arrived==49,"all 49 actors physically follow the shared field around walls into separate formation slots")
	if arrived<49:
		for i in range(1,units.size()):
			if units[i].position.distance_to(goals[i])>.5:print("MISSED ",i," pos ",units[i].position," goal ",goals[i]," destination ",units[i].destination," state ",units[i].state," remaining ",units[i].path.size()-units[i].waypoint_index," yield ",units[i].navigation.yield_return)
	var field := GroupFlowField.new(grid,grid.get_point_id(140,20),[grid.get_point_id(10,30)])
	grid.set_tile_occupied(121,80,"new-wall")
	field.advance()
	check(field.route(grid.get_point_id(10,30),goal,20).is_empty(),"a field built against an old world revision is rejected")
	print("HIERARCHICAL FLOW CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
