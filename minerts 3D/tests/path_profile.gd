extends Node

func _ready() -> void:
	SoundManager.is_muted=true
	var grid := GridManager.new();add_child(grid);grid.set_process(false)
	var tiles: Array = []
	for x in range(GridManager.GRID_SIZE):
		var row: Array = []
		for z in range(GridManager.GRID_SIZE):row.append(Tile.new(x,z,0,Tile.Biome.PLAINS,x>=2 and x<190 and z>=2 and z<190))
		tiles.append(row)
	grid.init_grid(tiles)
	for x in [47,95,143]:
		for z in range(2,155):grid.set_tile_occupied(x,z,"wall")
	var begin: int = Time.get_ticks_usec()
	while not grid.hierarchy.dirty.is_empty():grid.hierarchy.process_budget(100000)
	print("HIERARCHY BUILD MS: ",(Time.get_ticks_usec()-begin)/1000.0)
	grid.path_cache_enabled=false
	var goal := Vector3(175.5,0,30.5)
	var goal_id: int = grid.get_point_id(175,30)
	var report: Array[Dictionary] = []
	for count in [50,200,1000]:
		var origins: Array[int] = []
		for i in range(count):origins.append(grid.get_point_id(10+i%25,10+(i/25)%30))
		for mode in ["native","hierarchical","flow"]:
			begin=Time.get_ticks_usec()
			var field: GroupFlowField
			if mode=="flow":
				field=GroupFlowField.new(grid,goal_id,origins)
				while not field.ready:field.advance(100000)
			var points: int = 0
			for origin in origins:
				if mode=="native":points+=grid.astar.get_point_path(origin,goal_id).size()
				elif mode=="hierarchical":points+=grid.hierarchy.find_path(origin,goal_id).size()
				else:points+=field.route(origin,goal,20).size()
			var sample: Dictionary = {"requests":count,"mode":mode,"total_ms":(Time.get_ticks_usec()-begin)/1000.0,"path_points":points,"field_cells":field.expanded if field else 0}
			print("PATH PROFILE ",JSON.stringify(sample));report.append(sample)
	var file := FileAccess.open("res://art/test-results/path_profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	get_tree().quit()
