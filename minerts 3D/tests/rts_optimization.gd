extends Node3D

class ProbeUnit extends Unit:
	func _ready() -> void:
		add_to_group("units")
		navigation = UnitNavigation.new(self)
		config = {"vision_range": 8}
	func _physics_process(_delta: float) -> void: pass
	func _process(_delta: float) -> void: pass

var checks: int = 0
var failures: int = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS: ", title)
	else: failures += 1; push_error(title)

func _ready() -> void:
	SoundManager.is_muted = true
	var grid := GridManager.new()
	add_child(grid)
	var tiles: Array = []
	for x in range(GridManager.GRID_SIZE):
		var row: Array = []
		for z in range(GridManager.GRID_SIZE):
			row.append(Tile.new(x,z,0,Tile.Biome.PLAINS,true))
		tiles.append(row)
	grid.init_grid(tiles)
	var units: Array[Unit] = []
	for i in range(1024):
		var unit := ProbeUnit.new()
		unit.position = Vector3(20.5+(i%32)*8,0,20.5+(i/32)*8)
		unit.grid_manager = grid
		add_child(unit)
		units.append(unit)
	# Include close neighbors across a bucket boundary, and dense overlap.
	units[1].position = units[0].position+Vector3(.7,0,0)
	units[2].position = units[0].position+Vector3(5.9,0,0)
	grid.unit_index.rebuild(units)
	var exact: Array = []
	var started: int = Time.get_ticks_usec()
	for unit in units:
		var ids: Array = []
		for other in units:
			if other != unit and unit.position.distance_squared_to(other.position)<36:ids.append(other.get_instance_id())
		ids.sort();exact.append(ids)
	var naive_usec: int = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	var identical: bool = true
	for i in range(units.size()):
		var ids: Array = []
		for other in grid.unit_index.query(get_tree(),units[i].position,6):
			if other != units[i] and units[i].position.distance_squared_to(other.position)<36:ids.append(other.get_instance_id())
		ids.sort()
		identical = identical and ids == exact[i]
	var spatial_usec: int = Time.get_ticks_usec()-started
	check(identical,"spatial queries preserve exact neighbors for 1024 actors, including cell borders")
	check(grid.unit_index.rebuilds==1,"1024 actors share one spatial snapshot")
	check(grid.unit_index.candidates_examined<1024*1024/20,"distributed crowd requires fewer than 5 percent of all-pairs candidates")
	print("BENCH SPATIAL: naive_us=%d indexed_us=%d candidates=%d all_pairs=%d" % [naive_usec,spatial_usec,grid.unit_index.candidates_examined,1024*1024])
	var freed: Unit = units.pop_back()
	var old_pos: Vector3 = freed.position
	freed.free()
	check(grid.unit_index.query(get_tree(),old_pos,6).all(func(u):return is_instance_valid(u)),"freed units in a snapshot are safely ignored")
	units[1].underground_unit = true
	units[0].set_path([units[0].position+Vector3.RIGHT])
	units[0].navigation.tick(.2)
	check(not units[0].navigation.nearby.has(units[1]) and units[0].navigation.nearby.has(units[2]),"local navigation separates underground actors from surface neighbors")
	units[2].ungarrison_from_building(Vector3(490.5,0,490.5))
	check(grid.unit_index.query(get_tree(),units[2].position,1).has(units[2]),"teleport out of a garrison invalidates the spatial snapshot immediately")
	for unit in units:unit.free()
	units.clear()
	grid.unit_index.invalidate()
	check(grid.unit_index.query(get_tree(),Vector3(20,0,20),6).is_empty(),"spatial snapshot can be rebuilt after despawning a crowd")

	var from := Vector3(20.5,0,20.5)
	var to := Vector3(48.5,0,20.5)
	var route: Array[Vector3] = grid.find_path(from,to)
	for i in range(49):grid.find_path(from,to+Vector3(.001*i,0,0))
	check(grid.surface_astar_searches==1 and grid.path_cache_hits==49,"50 repeated cell-to-cell requests share one A-star solution and retain precise endpoints")
	check(grid.find_path(from,to+Vector3(.04,0,0)).back().is_equal_approx(to+Vector3(.04,0,0)),"shared cached route retains each order's exact destination")
	grid.set_tile_occupied(34,20,"wall")
	var detour: Array[Vector3] = grid.find_path(from,to)
	check(not detour.is_empty() and detour.all(func(p):return floori(p.x)!=34 or floori(p.z)!=20),"construction invalidates cached routes and replans around the wall")
	grid.free_tile(34,20)
	route = grid.find_path(from,to)
	grid.astar.set_point_disabled(grid.get_point_id(34,20),true)
	detour = grid.find_path(from,to)
	check(detour.all(func(p):return floori(p.x)!=34 or floori(p.z)!=20),"live graph validation rejects a directly blocked cached route")
	grid.astar.set_point_disabled(grid.get_point_id(34,20),false)
	for x in range(140):grid.find_path(from,Vector3(60.5+x,0,22.5))
	check(grid.path_cache.size()<=GridManager.MAX_PATH_CACHE,"path cache has a fixed memory bound")

	var fog := FogOfWarSystem.new()
	add_child(fog);fog.init_fog(grid)
	for i in range(50):
		var unit := ProbeUnit.new()
		unit.grid_manager=grid;unit.faction="player"
		unit.position=Vector3(80.5+i%5,0,80.5+i/5)
		add_child(unit);units.append(unit)
	var buildings: Array[Building] = []
	fog.cache_enabled=false
	started=Time.get_ticks_usec()
	for i in range(5):fog.update_fog(units,buildings,.25)
	var los_naive_usec: int = Time.get_ticks_usec()-started
	var expected := fog.visibility_grid.duplicate()
	var naive_rays: int = fog.ray_checks
	fog.init_fog(grid);fog.cache_enabled=true;fog.ray_checks=0;fog.texture_uploads=0
	started=Time.get_ticks_usec()
	for i in range(5):fog.update_fog(units,buildings,.25)
	var los_cached_usec: int = Time.get_ticks_usec()-started
	check(expected==fog.visibility_grid,"cached and uncached height-aware fog produce identical visibility")
	check(fog.ray_checks*5==naive_rays,"stationary observers reuse their raycasts across five visibility ticks")
	check(fog.texture_uploads==1,"unchanged visibility uploads its texture only once")
	check(fog.fog_image.get_data().size()==512*512,"single-channel fog mask consumes 256 KiB instead of 1 MiB")
	print("BENCH LOS: uncached_us=%d cached_us=%d uncached_rays=%d cached_rays=%d" % [los_naive_usec,los_cached_usec,naive_rays,fog.ray_checks])
	for unit in units:unit.free()
	units.clear()
	var observer := ProbeUnit.new()
	observer.faction="player";observer.position=Vector3(80.5,0,80.5);observer.grid_manager=grid
	add_child(observer);units.append(observer)
	fog.init_fog(grid)
	fog.update_fog(units,buildings,.25)
	check(fog.get_tile_visibility(87,80)==2,"observer sees open ground within sight range")
	for z in range(72,89):grid.set_tile_occupied(84,z,"occluder")
	fog.update_fog(units,buildings,.25)
	check(fog.get_tile_visibility(87,80)==1,"new wall invalidates sight cache and hides previously explored ground")
	for z in range(72,89):grid.free_tile(84,z)
	fog.update_fog(units,buildings,.25)
	check(fog.get_tile_visibility(87,80)==2,"removed wall restores sight on the next visibility tick")
	observer.position=Vector3(200.5,0,200.5)
	fog.update_fog(units,buildings,.25)
	check(fog.get_tile_visibility(80,80)==1 and fog.get_tile_visibility(200,200)==2 and fog.get_tile_visibility(400,400)==0,"moving observers preserve explored, current and unknown states")
	for i in range(300):fog._reveal_circle(i+10,300,1)
	check(fog.sight_cache.size()<=FogOfWarSystem.MAX_SIGHT_CACHE,"sight cache remains bounded during long exploration")
	print("RTS OPTIMIZATION CHECKS: %d | FAILURES: %d" % [checks,failures])
	get_tree().quit(failures)
