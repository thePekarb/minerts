class_name GridManager
extends Node

const GRID_SIZE: int = 512
const CENTER: int = 96 # Home settlement; world midpoint is GRID_SIZE / 2.
var tiles: Array = [] # 2D Array [x][z]
var underground: Node
var passage_claims: Dictionary = {}
var astar: AStar3D = AStar3D.new()
var unit_index: UnitSpatialIndex = UnitSpatialIndex.new()
var terrain_revision: int = 0
const MAX_PATH_CACHE: int = 128
var path_cache: Dictionary = {}
var path_cache_enabled: bool = true
var path_cache_bypass: bool = false
var path_cache_hits: int = 0
var surface_astar_searches: int = 0
var hierarchy: HierarchicalNavigation
var group_navigation: GroupNavigation
var hierarchy_enabled: bool = true
var closed_player_gates: Dictionary = {}

func invalidate_terrain(cell: Vector2i = Vector2i(-1,-1)) -> void:
	# Includes occluder changes (construction, destruction and opening gates).
	terrain_revision += 1
	path_cache.clear()
	if hierarchy:
		if cell.x>=0:hierarchy.mark_cell(cell.x,cell.y)
		else:hierarchy.mark_all()

func surface_path(start_id: int, end_id: int) -> PackedVector3Array:
	var key := Vector2i(start_id, end_id)
	if path_cache_enabled and not path_cache_bypass and path_cache.has(key):
		var cached: PackedVector3Array = path_cache[key]
		var valid: bool = true
		var previous: int = -1
		# Validate against the live graph, including callers that temporarily block
		# cells. Never let a cached route reopen a gate or cut through a new wall.
		for point in cached:
			var id: int = get_point_id(floori(point.x), floori(point.z))
			if not astar.has_point(id) or astar.is_point_disabled(id) or astar.get_point_position(id) != point or (previous >= 0 and not astar.are_points_connected(previous, id)):
				valid = false
				break
			previous = id
		path_cache.erase(key)
		if valid:
			path_cache[key] = cached
			path_cache_hits += 1
			return cached
	var result := PackedVector3Array()
	var use_hierarchy: bool = hierarchy_enabled and hierarchy!=null and hierarchy.dirty.is_empty() and not path_cache_bypass and hierarchy.region_of(start_id)>=0 and hierarchy.region_of(end_id)>=0 and astar.get_point_position(start_id).distance_to(astar.get_point_position(end_id))>32.0
	if use_hierarchy:
		result=hierarchy.find_path(start_id,end_id)
		for point in result:
			if astar.is_point_disabled(get_point_id(floori(point.x),floori(point.z))):
				hierarchy.mark_all();use_hierarchy=false;break
	if not use_hierarchy:
		surface_astar_searches += 1
		result = astar.get_point_path(start_id, end_id)
	if path_cache_enabled and not path_cache_bypass and not result.is_empty():
		if path_cache.size() >= MAX_PATH_CACHE:
			path_cache.erase(path_cache.keys()[0])
		path_cache[key] = result
	return result

func _ready() -> void:
	hierarchy=HierarchicalNavigation.new(self)
	group_navigation=GroupNavigation.new(self)

func _process(_delta: float) -> void:
	if tiles.is_empty():return
	hierarchy.process_budget(2000)
	group_navigation.tick(2000)

func init_grid(grid_tiles: Array) -> void:
	tiles = grid_tiles
	rebuild_astar()

func get_tile(x: int, z: int) -> Tile:
	if x < 0 or x >= GRID_SIZE or z < 0 or z >= GRID_SIZE:
		return null
	return tiles[x][z]

func is_valid_coord(x: int, z: int) -> bool:
	return x >= 0 and x < GRID_SIZE and z >= 0 and z < GRID_SIZE

func find_nearest_walkable(cell: Vector2i, max_radius: int = 8, faction: String = "player") -> Vector2i:
	for radius in range(0, max_radius + 1):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius: continue
				var cx: int = cell.x + dx
				var cz: int = cell.y + dz
				if is_walkable(cx, cz, faction):
					return Vector2i(cx, cz)
	return Vector2i(-1, -1)

func get_height(x: float, z: float) -> float:
	var ix: int = int(floor(x))
	var iz: int = int(floor(z))
	var tile: Tile = get_tile(ix, iz)
	return float(tile.height) if tile else 0.0

func is_walkable(x: int, z: int, faction: String = "player") -> bool:
	var tile: Tile = get_tile(x, z)
	if not tile:
		return false
	return tile.is_walkable_for(faction)

func get_point_id(x: int, z: int) -> int:
	return x * 1000 + z

func rebuild_astar() -> void:
	invalidate_terrain()
	astar.clear()

	# Add points for all tiles
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var tile: Tile = tiles[x][z]
			var id: int = get_point_id(x, z)
			var pos: Vector3 = Vector3(float(x) + 0.5, float(tile.height), float(z) + 0.5)
			astar.add_point(id, pos)
			if not tile.is_walkable_for():
				astar.set_point_disabled(id, true)
			if tile.is_gate and not tile.is_gate_open:
				closed_player_gates[id] = true

	# Connect forward neighbors (bidirectional connects both ways)
	var forward_dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1)
	]

	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var tile: Tile = tiles[x][z]
			var id1: int = get_point_id(x, z)

			for d in forward_dirs:
				var nx: int = x + d.x
				var nz: int = z + d.y
				if nx >= 0 and nx < GRID_SIZE and nz >= 0 and nz < GRID_SIZE:
					var n_tile: Tile = tiles[nx][nz]
					if abs(n_tile.height - tile.height) <= 1:
						var id2: int = get_point_id(nx, nz)
						astar.connect_points(id1, id2, true)

func update_tile_height(x: int, z: int, new_height: int) -> void:
	var tile: Tile = get_tile(x, z)
	if not tile:
		return
	tile.height = new_height
	if tile.biome == Tile.Biome.ROCK and new_height <= 2:
		tile.biome = Tile.Biome.PLAINS

	var id1: int = get_point_id(x, z)
	if astar.has_point(id1):
		var pos: Vector3 = Vector3(float(x) + 0.5, float(tile.height), float(z) + 0.5)
		astar.set_point_position(id1, pos)

		var dirs: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
		]
		for d in dirs:
			var nx: int = x + d.x
			var nz: int = z + d.y
			if nx >= 0 and nx < GRID_SIZE and nz >= 0 and nz < GRID_SIZE:
				var n_tile: Tile = tiles[nx][nz]
				var id2: int = get_point_id(nx, nz)
				if astar.has_point(id2):
					if abs(n_tile.height - tile.height) <= 1:
						astar.connect_points(id1, id2, true)
					else:
						astar.disconnect_points(id1, id2, true)

	invalidate_terrain(Vector2i(x, z))


func set_tile_occupied(x: int, z: int, building_id: String, is_gate: bool = false) -> void:
	var tile: Tile = get_tile(x, z)
	if not tile:
		return
	tile.building_id = building_id
	invalidate_terrain(Vector2i(x,z))
	tile.is_gate = is_gate
	tile.is_gate_locked = is_gate
	tile.is_gate_open = false
	tile.walkable = (building_id == "" or is_gate)

	var id: int = get_point_id(x, z)
	if astar.has_point(id):
		astar.set_point_disabled(id, not tile.is_walkable_for())
	if is_gate:
		closed_player_gates[id] = true

func is_area_buildable(gx: int, gz: int, width: int, depth: int, require_visible: bool = true) -> bool:
	var base_tile: Tile = get_tile(gx, gz)
	if base_tile == null:
		return false
	for x in range(gx, gx + width):
		for z in range(gz, gz + depth):
			var tile: Tile = get_tile(x, z)
			if not tile or not tile.walkable or tile.building_id != "" or tile.resource_id != "":
				return false
			if tile.height != base_tile.height or (require_visible and not tile.is_visible):
				return false
			if tile.biome == Tile.Biome.WATER:
				return false
	return true

func occupy_area(gx: int, gz: int, width: int, depth: int, building: Variant, is_gate: bool = false) -> void:
	var b_id: String = str(building.get_instance_id()) if building is Object else str(building)
	for x in range(gx, gx + width):
		for z in range(gz, gz + depth):
			set_tile_occupied(x, z, b_id, is_gate)

func free_tile(x: int, z: int) -> void:
	var tile: Tile = get_tile(x, z)
	if not tile:
		return
	invalidate_terrain(Vector2i(x,z))
	tile.building_id = ""
	tile.is_gate = false
	tile.is_gate_open = false
	tile.is_gate_locked = false
	tile.resource_id = ""
	tile.walkable = (tile.biome != Tile.Biome.WATER)

	var id: int = get_point_id(x, z)
	closed_player_gates.erase(id)
	if astar.has_point(id):
		astar.set_point_disabled(id, not tile.is_walkable_for())

func free_area(gx: int, gz: int, width: int, depth: int) -> void:
	for x in range(gx, gx + width):
		for z in range(gz, gz + depth):
			free_tile(x, z)

func get_formation_positions(center: Vector3, unit_count: int, spacing: float = 1.2) -> Array[Vector3]:
	var offsets: Array[Vector2] = get_formation_offsets(unit_count, spacing)
	var positions: Array[Vector3] = []
	var used: Dictionary = {}
	for off in offsets:
		var px: float = center.x + off.x
		var pz: float = center.z + off.y
		var chosen: Vector2i = Vector2i(floori(px), floori(pz))
		var found: bool = false
		for radius in range(8):
			for dx in range(-radius, radius+1):
				for dz in range(-radius, radius+1):
					var cell: Vector2i = Vector2i(floori(px)+dx, floori(pz)+dz)
					if not used.has(cell) and is_walkable(cell.x,cell.y):
						chosen=cell
						found=true
						break
				if found: break
			if found: break
		used[chosen]=true
		positions.append(Vector3(chosen.x+0.5,get_height(chosen.x,chosen.y),chosen.y+0.5))
	return positions

func find_path(start_pos: Vector3, target_pos: Vector3, faction: String = "player") -> Array[Vector3]:
	if start_pos.y < -1.0 and is_instance_valid(underground):
		return underground.find_path(start_pos, target_pos)
	var sx: int = int(floor(start_pos.x))
	var sz: int = int(floor(start_pos.z))
	var tx: int = int(floor(target_pos.x))
	var tz: int = int(floor(target_pos.z))

	sx = clamp(sx, 0, GRID_SIZE - 1)
	sz = clamp(sz, 0, GRID_SIZE - 1)
	tx = clamp(tx, 0, GRID_SIZE - 1)
	tz = clamp(tz, 0, GRID_SIZE - 1)

	if sx == tx and sz == tz and is_walkable(tx, tz, faction):
		return [target_pos]

	# Target might be an obstacle (e.g. tree, building, wall)
	var target_tile: Tile = get_tile(tx, tz)
	var is_gate_target: bool = (target_tile != null and target_tile.is_gate and faction == "player")
	var is_target_obstacle: bool = target_tile != null and not is_gate_target and (not target_tile.is_walkable_for(faction) or astar.is_point_disabled(get_point_id(tx,tz)))

	var start_id: int = get_point_id(sx, sz)
	var end_id: int = get_point_id(tx, tz)

	var was_start_disabled: bool = astar.is_point_disabled(start_id)
	if was_start_disabled:
		astar.set_point_disabled(start_id, false)

	# For player pathfinding, temporarily enable closed player gates so paths can be planned through them
	var temp_opened_gates: Array[int] = []
	var prev_cache_bypass: bool = path_cache_bypass
	if faction == "player" and not closed_player_gates.is_empty():
		for pid in closed_player_gates.keys():
			if astar.has_point(pid) and astar.is_point_disabled(pid):
				astar.set_point_disabled(pid, false)
				temp_opened_gates.append(pid)
		if not temp_opened_gates.is_empty():
			path_cache_bypass = true

	# Search the full perimeter, including large buildings, and test reachability.
	var candidates: Array[int] = []
	var path_pts := PackedVector3Array()
	if is_target_obstacle:
		for radius in range(1, 5):
			for dx in range(-radius, radius + 1):
				for dz in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dz)) != radius:
						continue
					if is_walkable(tx + dx, tz + dz, faction) and not astar.is_point_disabled(get_point_id(tx+dx,tz+dz)):
						candidates.append(get_point_id(tx + dx, tz + dz))
			if candidates.size() >= 4:
				break
		candidates.sort_custom(func(a, b): return astar.get_point_position(a).distance_squared_to(start_pos) < astar.get_point_position(b).distance_squared_to(start_pos))
		for candidate in candidates:
			path_pts = surface_path(start_id, candidate)
			if not path_pts.is_empty():
				end_id = candidate
				break

	if not astar.has_point(start_id) or not astar.has_point(end_id):
		if was_start_disabled: astar.set_point_disabled(start_id, true)
		for pid in temp_opened_gates:
			if astar.has_point(pid): astar.set_point_disabled(pid, true)
		path_cache_bypass = prev_cache_bypass
		return []

	if astar.is_point_disabled(end_id):
		if was_start_disabled: astar.set_point_disabled(start_id, true)
		for pid in temp_opened_gates:
			if astar.has_point(pid): astar.set_point_disabled(pid, true)
		path_cache_bypass = prev_cache_bypass
		return []
	if path_pts.is_empty(): path_pts = surface_path(start_id, end_id)

	if was_start_disabled:
		astar.set_point_disabled(start_id, true)
	for pid in temp_opened_gates:
		if astar.has_point(pid):
			astar.set_point_disabled(pid, true)
	path_cache_bypass = prev_cache_bypass

	var result: Array[Vector3] = []
	for p in path_pts:
		result.append(Vector3(p.x, get_height(p.x, p.z), p.z))

	if was_start_disabled and result.size() > 1:
		result.remove_at(0)

	# If path is found, append precise target position
	if not result.is_empty() and not is_target_obstacle:
		result[result.size() - 1] = Vector3(target_pos.x, get_height(target_pos.x, target_pos.z), target_pos.z)

	return result

static func get_formation_offsets(unit_count: int, spacing: float = 1.2) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if unit_count <= 1:
		offsets.append(Vector2.ZERO)
		return offsets

	var cols: int = int(ceil(sqrt(float(unit_count))))
	var rows: int = int(ceil(float(unit_count) / float(cols)))

	var off_x: float = -float(cols - 1) * spacing * 0.5
	var off_z: float = -float(rows - 1) * spacing * 0.5

	var count: int = 0
	for r in range(rows):
		for c in range(cols):
			if count >= unit_count:
				break
			offsets.append(Vector2(off_x + c * spacing, off_z + r * spacing))
			count += 1
	return offsets

func find_free_position(near: Vector3) -> Vector3:
	for radius in range(0, 8):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var x: int = int(floor(near.x)) + dx
				var z: int = int(floor(near.z)) + dz
				if is_walkable(x, z):
					return Vector3(x + 0.5, get_height(x, z), z + 0.5)
	return near

func can_step(from: Vector3, to: Vector3, faction: String = "player") -> bool:
	if from.y < -1.0 and is_instance_valid(underground):
		return underground.is_open(Vector2i(floori(to.x), floori(to.z)))
	var a: Tile = get_tile(floori(from.x), floori(from.z))
	var b: Tile = get_tile(floori(to.x), floori(to.z))
	if a == null or b == null or absi(a.height - b.height) > 1:
		return false
	if faction == "player" and b.is_gate:
		return true
	return b.is_walkable_for(faction)

func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	if (from.y < -1.0) != (to.y < -1.0):
		return false
	var steps: int = maxi(1, int(from.distance_to(to) * 2))
	for i in range(1, steps):
		var point: Vector3 = from.lerp(to, float(i) / steps)
		if from.y < -1.0:
			if is_instance_valid(underground) and not underground.is_open(Vector2i(floori(point.x), floori(point.z))):
				return false
		else:
			var tile: Tile = get_tile(floori(point.x), floori(point.z))
			if tile == null or tile.height > point.y + 1.3 or (tile.building_id != "" and not tile.is_gate_open):
				return false
	return true

var sea_astar: AStar3D
var transport: Node
func is_sea_position(pos: Vector3) -> bool:
	for dx in [-0.45,0.45]:
		for dz in [-0.45,0.45]:
			var tile: Tile = get_tile(floori(pos.x+dx),floori(pos.z+dz))
			if tile==null or tile.height>0:return false
	return true
func nearest_sea_position(pos: Vector3, radius_limit: int = 8) -> Vector3:
	var best: Vector3 = Vector3.INF
	var distance: float = INF
	for dx in range(-radius_limit,radius_limit+1):
		for dz in range(-radius_limit,radius_limit+1):
			var p: Vector3 = Vector3(floorf(pos.x)+dx+0.5,0.22,floorf(pos.z)+dz+0.5)
			if is_sea_position(p) and p.distance_squared_to(pos)<distance:
				best=p;distance=p.distance_squared_to(pos)
	return best
func _sea_segment_clear(a: Vector3, b: Vector3) -> bool:
	var steps: int = maxi(1,ceili(a.distance_to(b)*2))
	for i in range(steps+1):
		if not is_sea_position(a.lerp(b,float(i)/steps)):return false
	return true
func _init_sea_navigation() -> void:
	sea_astar=AStar3D.new()
	# Two-cell water graph; every edge is checked against the full-resolution coast.
	for x in range(1,GRID_SIZE-1,2):
		for z in range(1,GRID_SIZE-1,2):
			var p: Vector3 = Vector3(x+0.5,0.22,z+0.5)
			if is_sea_position(p):sea_astar.add_point(get_point_id(x,z),p)
	for id in sea_astar.get_point_ids():
		var p: Vector3 = sea_astar.get_point_position(id)
		for d in [Vector2i(2,0),Vector2i(0,2)]:
			var next: int = get_point_id(floori(p.x)+d.x,floori(p.z)+d.y)
			if sea_astar.has_point(next) and _sea_segment_clear(p,sea_astar.get_point_position(next)):sea_astar.connect_points(id,next)
func find_sea_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not is_sea_position(from) or not is_sea_position(to):return result
	if sea_astar==null:_init_sea_navigation()
	var a: int = sea_astar.get_closest_point(from)
	var b: int = sea_astar.get_closest_point(to)
	if a<0 or b<0:return result
	if not _sea_segment_clear(from,sea_astar.get_point_position(a)) or not _sea_segment_clear(sea_astar.get_point_position(b),to):return result
	for p in sea_astar.get_point_path(a,b):result.append(p)
	if not result.is_empty():result.append(Vector3(to.x,0.22,to.z))
	return result
func is_coastal_site(x: int,z: int,width: int,depth: int) -> bool:
	for dx in range(-1,width+1):
		for dz in range(-1,depth+1):
			if dx>=0 and dx<width and dz>=0 and dz<depth:continue
			var tile: Tile = get_tile(x+dx,z+dz)
			if tile!=null and tile.height==0:return true
	return false

func unit_position_free(unit: Unit, point: Vector3) -> bool:
	for other in unit_index.query(get_tree(), point, 1.0):
		if other==unit or not unit.navigation.same_layer(other):continue
		var spacing: float = unit.navigation_radius+other.navigation_radius+0.08
		if Vector2(point.x-other.position.x,point.z-other.position.z).length()<spacing:return false
	return true

func motion_clear(unit: Unit, from: Vector3, to: Vector3) -> bool:
	var steps: int = maxi(1,ceili(from.distance_to(to)*5))
	var radius: float = unit.navigation_radius+0.035
	for i in range(1,steps+1):
		var point: Vector3 = from.lerp(to,float(i)/steps)
		if UnitConfigs.is_vessel(unit.unit_type):
			if not is_sea_position(point):return false
			continue
		if not can_step(from,point,unit.faction):return false
		# Check the body's width, not only the tile underneath its centre.
		var cur_tile: Tile = get_tile(floori(point.x), floori(point.z))
		var from_tile: Tile = get_tile(floori(from.x), floori(from.z))
		var is_doorway: bool = (cur_tile != null and cur_tile.is_gate) or (from_tile != null and from_tile.is_gate)
		var check_radius: float = 0.10 if is_doorway else radius
		for off in [Vector2(check_radius,0),Vector2(-check_radius,0),Vector2(0,check_radius),Vector2(0,-check_radius),Vector2(check_radius,check_radius)*0.707,Vector2(-check_radius,check_radius)*0.707,Vector2(check_radius,-check_radius)*0.707,Vector2(-check_radius,-check_radius)*0.707]:
			var edge: Vector3 = point+Vector3(off.x,0,off.y)
			if not can_step(from,edge,unit.faction):
				# Permit an already overlapping spawn to move out, never farther in.
				var old_edge: Vector3 = from+Vector3(off.x,0,off.y)
				if can_step(from,old_edge,unit.faction) or Vector2i(floori(edge.x),floori(edge.z))!=Vector2i(floori(old_edge.x),floori(old_edge.z)):return false
	return true

func find_unit_path(unit: Unit, goal: Vector3, avoid_units: bool = false, adjust_goal: bool = true) -> Array[Vector3]:
	if goal==Vector3.INF:return []
	var ship: bool = UnitConfigs.is_vessel(unit.unit_type)
	if ship and sea_astar==null:_init_sea_navigation()
	var graph: AStar3D = sea_astar if ship else (underground.astar if unit.underground_unit and is_instance_valid(underground) else astar)
	var disabled: Array[int] = []
	var previous_bypass: bool = path_cache_bypass
	path_cache_bypass = path_cache_bypass or avoid_units
	if avoid_units:
		for other in unit_index.query(get_tree(),unit.position,8.0)+unit_index.query(get_tree(),goal,2.0):
			if other==unit or not unit.navigation.same_layer(other):continue
			if other.navigation.actual_speed>0.2 and other.navigation.stalled_for<0.5:continue
			if other.position.distance_squared_to(unit.position)>49 and other.position.distance_squared_to(goal)>4:continue
			var id: int = graph.get_closest_point(other.position) if ship else (underground._id(Vector2i(floori(other.position.x),floori(other.position.z))) if unit.underground_unit else get_point_id(floori(other.position.x),floori(other.position.z)))
			if Vector2i(floori(other.position.x),floori(other.position.z)) in [Vector2i(floori(unit.position.x),floori(unit.position.z)),Vector2i(floori(goal.x),floori(goal.z))]:continue
			if graph.has_point(id) and not graph.is_point_disabled(id):
				graph.set_point_disabled(id,true);disabled.append(id)
	var result: Array[Vector3] = find_sea_path(unit.position,goal) if ship else find_path(unit.position,goal,unit.faction)
	if adjust_goal and avoid_units and is_instance_valid(unit.target) and (result.is_empty() or not unit_position_free(unit,result.back())):
		var alternatives: Array[Vector3] = []
		for dx in range(-2,3):
			for dz in range(-2,3):
				var point: Vector3 = Vector3(floorf(goal.x)+dx+0.5,goal.y,floorf(goal.z)+dz+0.5)
				if (is_sea_position(point) if ship else _navigation_cell_open(unit,point)) and unit_position_free(unit,point):alternatives.append(point)
		alternatives.sort_custom(func(a,b):return a.distance_squared_to(goal)<b.distance_squared_to(goal))
		for point in alternatives:
			var route: Array[Vector3] = find_sea_path(unit.position,point) if ship else find_path(unit.position,point,unit.faction)
			if not route.is_empty():result=route;break
	for id in disabled:graph.set_point_disabled(id,false)
	path_cache_bypass = previous_bypass
	return result

func _navigation_cell_open(unit: Unit, point: Vector3) -> bool:
	return underground.is_open(Vector2i(floori(point.x),floori(point.z))) if unit.underground_unit and is_instance_valid(underground) else is_walkable(floori(point.x),floori(point.z),unit.faction)

func _narrow_cell(unit: Unit, cell: Vector2i) -> bool:
	var p: Vector3 = Vector3(cell.x+0.5,unit.position.y,cell.y+0.5)
	if not _navigation_cell_open(unit,p):return false
	var horizontal: bool = _navigation_cell_open(unit,p+Vector3.RIGHT) and _navigation_cell_open(unit,p+Vector3.LEFT)
	var vertical: bool = _navigation_cell_open(unit,p+Vector3.FORWARD) and _navigation_cell_open(unit,p+Vector3.BACK)
	return (horizontal and not _navigation_cell_open(unit,p+Vector3.FORWARD) and not _navigation_cell_open(unit,p+Vector3.BACK)) or (vertical and not _navigation_cell_open(unit,p+Vector3.RIGHT) and not _navigation_cell_open(unit,p+Vector3.LEFT))

func wait_for_passage(unit: Unit) -> bool:
	if UnitConfigs.is_vessel(unit.unit_type) or unit.waypoint_index<unit.navigation.yield_steps:return false
	for index in range(unit.waypoint_index,mini(unit.path.size(),unit.waypoint_index+5)):
		var entry: Vector3 = unit.path[index]
		if unit.position.distance_to(entry)>2.8:continue
		var cell: Vector2i = Vector2i(floori(entry.x),floori(entry.z))
		if not _narrow_cell(unit,cell):continue
		# Reserve the whole corridor as one resource; never acquire several locks in opposite order.
		var cells: Dictionary = {cell:true}
		var todo: Array[Vector2i] = [cell]
		var key: int = get_point_id(cell.x,cell.y)
		while not todo.is_empty() and cells.size()<128:
			var current: Vector2i = todo.pop_back()
			key=mini(key,get_point_id(current.x,current.y))
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var next: Vector2i = current+direction
				if not cells.has(next) and _narrow_cell(unit,next):cells[next]=true;todo.append(next)
		if unit.underground_unit:key+=1000000
		var owner: Unit = passage_claims[key].get_ref() if passage_claims.has(key) else null
		if is_instance_valid(owner):
			var approaching: bool = false
			for i in range(owner.waypoint_index,mini(owner.path.size(),owner.waypoint_index+6)):
				if cells.has(Vector2i(floori(owner.path[i].x),floori(owner.path[i].z))):approaching=true;break
			if not owner.is_alive or owner.underground_unit!=unit.underground_unit or (not approaching and not cells.has(Vector2i(floori(owner.position.x),floori(owner.position.z)))):owner=null
		if not is_instance_valid(owner):
			owner=unit
			for other in get_tree().get_nodes_in_group("units"):
				if other!=unit and unit.navigation.same_layer(other) and cells.has(Vector2i(floori(other.position.x),floori(other.position.z))):owner=other;break
			passage_claims[key]=weakref(owner)
		if owner!=unit:return true
	return false


# Per-target interaction positions are reserved by live orders, not by path obstacles.
# Moving neighbours stay in local avoidance and never invalidate the terrain graph.
var approach_claims: Dictionary = {}
var last_claim_sweep: int = 0

func interaction_distance(point: Vector3, target: Node3D) -> float:
	if target is Building:
		return Vector2(maxf(0,absf(point.x-target.position.x)-target.footprint.x*.5),maxf(0,absf(point.z-target.position.z)-target.footprint.y*.5)).length()
	return point.distance_to(target.position)

func interaction_reach(unit: Unit) -> float:
	if unit.current_order==UnitConfigs.UnitOrder.ATTACK:return unit.attack_range
	if unit.current_order==UnitConfigs.UnitOrder.BUILD:return 1.1
	if unit.target is Building:return 1.5
	return 2.0

func find_interaction_path(unit: Unit, target: Node3D, reach: float) -> Array[Vector3]:
	if not is_instance_valid(target):return []
	var candidates: Array[Vector3] = []
	var extent: int = ceili(reach)+1
	if target is Building:extent+=maxi(target.footprint.x,target.footprint.y)/2
	var key: int = target.get_instance_id()
	# Remove stale targets and orders, bounding the reservation table to live activity.
	var sweep: bool = Time.get_ticks_msec()-last_claim_sweep>3000
	if sweep:last_claim_sweep=Time.get_ticks_msec()
	for id in (approach_claims.keys() if sweep else [key]):
		if not approach_claims.has(id):continue
		var entries: Dictionary = approach_claims[id]
		for cell in entries.keys():
			var owner: Unit = entries[cell].get_ref()
			if not is_instance_valid(owner) or not owner.is_alive or not is_instance_valid(owner.target) or owner.target.get_instance_id()!=id or owner.current_order==UnitConfigs.UnitOrder.MOVE:entries.erase(cell)
		if entries.is_empty():approach_claims.erase(id)
	if not approach_claims.has(key):approach_claims[key]={}
	var claims: Dictionary = approach_claims[key]
	for dx in range(-extent,extent+1):
		for dz in range(-extent,extent+1):
			var cell := Vector2i(floori(target.position.x)+dx,floori(target.position.z)+dz)
			var point := Vector3(cell.x+.5,-4.0 if unit.underground_unit else get_height(cell.x,cell.y),cell.y+.5)
			if not _navigation_cell_open(unit,point):continue
			var distance: float = interaction_distance(point,target)
			# Arrival tolerance is 0.16: reserve enough slack to actually enter reach.
			if distance>reach-.25 or absf(point.y-target.position.y)>1.1:continue
			if target is Unit and distance<unit.navigation_radius+target.navigation_radius+.12:continue
			if claims.has(cell) and claims[cell].get_ref()!=unit:continue
			candidates.append(point)
	candidates.sort_custom(func(a,b):return a.distance_squared_to(unit.position)<b.distance_squared_to(unit.position))
	var attempts: int = 0
	for point in candidates:
		if not unit_position_free(unit,point):continue
		var route: Array[Vector3] = find_unit_path(unit,point,unit.position.distance_squared_to(point)<144,false)
		attempts+=1
		if not route.is_empty():
			for cell in claims.keys():
				if claims[cell].get_ref()==unit:claims.erase(cell)
			claims[Vector2i(floori(point.x),floori(point.z))]=weakref(unit)
			return route
		if attempts>=8:break
	return []
