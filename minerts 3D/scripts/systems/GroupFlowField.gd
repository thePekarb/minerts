class_name GroupFlowField
extends RefCounted

var grid: GridManager
var revision: int
var allowed_regions: Dictionary = {}
var distances: Dictionary = {}
var next_cell: Dictionary = {}
var heap: Array[Vector2] = []
var settled: Dictionary = {}
var ready: bool = false
var expanded: int = 0
var goal_id: int

func _init(owner: GridManager, goal: int, origins: Array[int]) -> void:
	grid=owner;revision=grid.terrain_revision;goal_id=goal
	for origin in origins:
		for region in grid.hierarchy.component_route(origin,goal):allowed_regions[region]=true
	if allowed_regions.is_empty():ready=true;return
	distances[goal]=0.0
	_push(goal,0.0)

func _push(id: int, cost: float) -> void:
	heap.append(Vector2(id,cost))
	var i: int = heap.size()-1
	while i>0:
		var parent: int = (i-1)/2
		if heap[parent].y<=cost:break
		heap[i]=heap[parent];i=parent
	heap[i]=Vector2(id,cost)

func _pop() -> Vector2:
	var top: Vector2 = heap[0]
	var last: Vector2 = heap.pop_back()
	if heap.is_empty():return top
	var i: int = 0
	while i*2+1<heap.size():
		var child: int = i*2+1
		if child+1<heap.size() and heap[child+1].y<heap[child].y:child+=1
		if heap[child].y>=last.y:break
		heap[i]=heap[child];i=child
	heap[i]=last
	return top

func advance(budget_usec: int = 1000) -> void:
	if ready:return
	if revision!=grid.terrain_revision:ready=true;return
	var begin: int = Time.get_ticks_usec()
	while not heap.is_empty() and Time.get_ticks_usec()-begin<budget_usec:
		var entry: Vector2 = _pop()
		var id: int = int(entry.x)
		if settled.has(id):continue
		settled[id]=true;expanded+=1
		for neighbor in grid.astar.get_point_connections(id):
			if grid.astar.is_point_disabled(neighbor) or not allowed_regions.has(grid.hierarchy.region_of(neighbor)):continue
			var cost: float = distances[id]+grid.astar.get_point_position(id).distance_to(grid.astar.get_point_position(neighbor))
			if cost < distances.get(neighbor,INF):
				distances[neighbor]=cost;next_cell[neighbor]=id;_push(neighbor,cost)
	ready=heap.is_empty()

func route(origin: int, destination: Vector3, approach_radius: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if revision!=grid.terrain_revision or not ready or not settled.has(origin):return result
	var current: int = origin
	while true:
		var point: Vector3 = grid.astar.get_point_position(current)
		if grid.astar.is_point_disabled(current):return []
		result.append(point)
		if point.distance_to(destination)<approach_radius or current==goal_id:break
		if not next_cell.has(current) or result.size()>settled.size():return []
		current=next_cell[current]
	var tail: Array[Vector3] = grid.find_path(result.back(),destination)
	if tail.is_empty():return []
	if not tail.is_empty():tail.remove_at(0)
	result.append_array(tail)
	return result
