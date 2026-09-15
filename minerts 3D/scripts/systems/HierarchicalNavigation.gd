class_name HierarchicalNavigation
extends RefCounted

const SIZE: int = 16
const COLS: int = GridManager.GRID_SIZE / SIZE
var grid: GridManager
var regions := PackedInt32Array()
var graph := AStar3D.new()
var clusters: Dictionary = {}
var portals: Dictionary = {}
var local_cache: Dictionary = {}
const MAX_LOCAL_GRAPHS: int = 64
var dirty: Dictionary = {}
var searches: int = 0
var local_searches: int = 0
var rebuild_count: int = 0
var last_build_usec: int = 0

func _init(owner: GridManager) -> void:
	grid = owner
	regions.resize(GridManager.GRID_SIZE * GridManager.GRID_SIZE)
	regions.fill(-1)
	mark_all()

func mark_all() -> void:
	for c in range(COLS * COLS):dirty[c] = true

func mark_cell(x: int, z: int) -> void:
	if x < 0 or z < 0 or x >= GridManager.GRID_SIZE or z >= GridManager.GRID_SIZE:return
	dirty[cluster_of(Vector2i(x,z))] = true

func cluster_of(cell: Vector2i) -> int:
	return (cell.x / SIZE) * COLS + cell.y / SIZE

func region_of(id: int) -> int:
	if id<0 or id/1000>=GridManager.GRID_SIZE or id%1000>=GridManager.GRID_SIZE:return -1
	return regions[(id / 1000) * GridManager.GRID_SIZE + id % 1000]

func process_budget(budget_usec: int = 2000) -> void:
	var start: int = Time.get_ticks_usec()
	while not dirty.is_empty() and Time.get_ticks_usec()-start < budget_usec:
		var c: int = dirty.keys()[0]
		dirty.erase(c)
		_rebuild_cluster(c)
	last_build_usec = Time.get_ticks_usec()-start

func _rebuild_cluster(c: int) -> void:
	rebuild_count += 1
	if clusters.has(c):
		for region in clusters[c].regions:
			for neighbor in graph.get_point_connections(region):
				portals.erase(Vector2i(region,neighbor));portals.erase(Vector2i(neighbor,region))
			graph.remove_point(region)
	local_cache.erase(c)
	var local: AStar3D = _build_local(c)
	var origin := Vector2i((c / COLS)*SIZE,(c % COLS)*SIZE)
	for x in range(origin.x,origin.x+SIZE):
		for z in range(origin.y,origin.y+SIZE):
			regions[x*GridManager.GRID_SIZE+z] = -1
	var component_ids: Array[int] = []
	for id in local.get_point_ids():
		if region_of(id)>=0:continue
		var region: int = c*SIZE*SIZE+component_ids.size()
		component_ids.append(region)
		var queue: Array[int] = [id]
		var sum := Vector3.ZERO
		var count: int = 0
		regions[(id/1000)*GridManager.GRID_SIZE+id%1000] = region
		while not queue.is_empty():
			var current: int = queue.pop_back()
			sum += local.get_point_position(current);count += 1
			for neighbor in local.get_point_connections(current):
				if region_of(neighbor)<0:
					regions[(neighbor/1000)*GridManager.GRID_SIZE+neighbor%1000] = region
					queue.append(neighbor)
		graph.add_point(region,sum/count)
	clusters[c] = {"regions":component_ids}
	# Each crossing stores both exact cells, not a fictitious cluster-centre edge.
	for id in local.get_point_ids():
		var cell := Vector2i(id/1000,id%1000)
		if cell.x%SIZE not in [0,SIZE-1] and cell.y%SIZE not in [0,SIZE-1]:continue
		for neighbor in grid.astar.get_point_connections(id):
			var nc := Vector2i(neighbor/1000,neighbor%1000)
			if cluster_of(nc)==c or grid.astar.is_point_disabled(neighbor):continue
			var a: int = region_of(id)
			var b: int = region_of(neighbor)
			if b<0 or not graph.has_point(b):continue
			graph.connect_points(a,b)
			var key := Vector2i(a,b)
			if not portals.has(key):portals[key]=[];portals[Vector2i(b,a)]=[]
			portals[key].append(Vector2i(id,neighbor))
			portals[Vector2i(b,a)].append(Vector2i(neighbor,id))

func component_route(start: int, goal: int) -> PackedInt64Array:
	if not dirty.is_empty():return PackedInt64Array()
	var a: int = region_of(start)
	var b: int = region_of(goal)
	if a<0 or b<0:return PackedInt64Array()
	return graph.get_id_path(a,b)

func find_path(start: int, goal: int) -> PackedVector3Array:
	searches += 1
	var chain: PackedInt64Array = component_route(start,goal)
	var result := PackedVector3Array()
	if chain.is_empty():return result
	var cursor: int = start
	for i in range(chain.size()-1):
		var best := Vector2i(-1,-1)
		var score: float = INF
		for pair in portals.get(Vector2i(chain[i],chain[i+1]),[]):
			var cost: float = grid.astar.get_point_position(cursor).distance_to(grid.astar.get_point_position(pair.x))+grid.astar.get_point_position(pair.y).distance_to(grid.astar.get_point_position(goal))*.2
			if cost<score:score=cost;best=pair
		if best.x<0:return PackedVector3Array()
		var part: PackedVector3Array = _local_path(cursor,best.x)
		if part.is_empty():return PackedVector3Array()
		_append(result,part)
		result.append(grid.astar.get_point_position(best.y));cursor=best.y
	var last: PackedVector3Array = _local_path(cursor,goal)
	if last.is_empty():return PackedVector3Array()
	_append(result,last)
	return result

func _local_path(start: int, goal: int) -> PackedVector3Array:
	local_searches += 1
	var c: int = cluster_of(Vector2i(start/1000,start%1000))
	if not local_cache.has(c):
		if local_cache.size()>=MAX_LOCAL_GRAPHS:local_cache.erase(local_cache.keys()[0])
		local_cache[c]=_build_local(c)
	var local: AStar3D = local_cache[c]
	local_cache.erase(c);local_cache[c]=local
	return local.get_point_path(start,goal)

func _append(result: PackedVector3Array, part: PackedVector3Array) -> void:
	# Packed arrays are passed by reference here; remove the repeated boundary point.
	for point in part:
		if result.is_empty() or result[result.size()-1]!=point:result.append(point)

func _build_local(c: int) -> AStar3D:
	var local := AStar3D.new()
	var origin := Vector2i((c / COLS)*SIZE,(c % COLS)*SIZE)
	for x in range(origin.x,origin.x+SIZE):
		for z in range(origin.y,origin.y+SIZE):
			var id: int = grid.get_point_id(x,z)
			if grid.astar.has_point(id) and not grid.astar.is_point_disabled(id):local.add_point(id,grid.astar.get_point_position(id))
	for id in local.get_point_ids():
		for neighbor in grid.astar.get_point_connections(id):
			if local.has_point(neighbor):local.connect_points(id,neighbor)
	return local
