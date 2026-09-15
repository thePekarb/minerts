extends Node
var checks: int = 0
var failures: int = 0
var delivered: int = 0
var carriers: Dictionary = {}
func check(ok: bool,text: String) -> void:
	checks+=1
	if ok:print("PASS: ",text)
	else:failures+=1;push_error(text)
func _ready() -> void:
	SoundManager.is_muted=true
	var game: Main = load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.goblin_ai.set_process(false);game.time_of_day_system.set_process(false)
	var camp: Building = game.all_buildings[0]
	check(camp.position.x==camp.grid_x+camp.footprint.x*.5 and camp.position.z==camp.grid_z+camp.footprint.y*.5,"campfire collider and occupied grid share the same centre")
	var mover: Unit = game.all_units[0]
	mover.position=Vector3(95.5,game.grid_manager.get_height(95,96),95.5)
	mover.set_path(game.grid_manager.find_unit_path(mover,Vector3(95.5,mover.position.y,99.5)));mover.state=UnitConfigs.UnitState.MOVING
	for i in range(180):await get_tree().physics_frame
	check(mover.position.z>99,"worker physically passes the formerly blocked west edge of the campfire")
	var workers: Array[Unit] = []
	for i in range(12):workers.append(game.spawn_unit(UnitConfigs.UnitType.WORKER,"player",Vector3(96.5,0,94.5)))
	var overlaps: int = 0
	for a in range(workers.size()):
		for b in range(a+1,workers.size()):
			if workers[a].position.distance_to(workers[b].position)<.6:overlaps+=1
	check(overlaps==0,"simultaneous spawns occupy separate free positions")
	var trees: Array = game.resource_spawner.resources.values().filter(func(r):return r.get_meta("resource_type","")=="wood" and absf(r.position.y-mover.position.y)<1.1)
	trees.sort_custom(func(a,b):return a.position.distance_squared_to(camp.position)<b.position.distance_squared_to(camp.position))
	game.gathering_system.resources_delivered.connect(func(faction,res,amount):
		if faction=="player" and res=="wood":delivered+=amount
	)
	for i in range(workers.size()):
		var u: Unit = workers[i];u.target=trees[i/3];u.current_order=UnitConfigs.UnitOrder.GATHER
		u.set_path(game.grid_manager.find_interaction_path(u,u.target,2.0));u.state=UnitConfigs.UnitState.MOVING
	for frame in range(4800):
		await get_tree().physics_frame
		if frame%600==0:print("LIVE GATHER ",frame/60,"s delivered ",delivered)
	check(delivered>=120,"twelve workers harvest the real forest and carry wood around the actual campfire")
	var enemy: Unit = game.spawn_unit(UnitConfigs.UnitType.ZOMBIE,"enemy",Vector3(91.5,0,93.5))
	enemy.health=5000;enemy.max_health=5000
	var guards: Array[Unit] = []
	for i in range(12):
		var guard: Unit = game.spawn_unit(UnitConfigs.UnitType.WARRIOR,"player",Vector3(98.5,0,93.5));guard.health=5000
		guard.target=enemy;guard.current_order=UnitConfigs.UnitOrder.ATTACK;guards.append(guard)
	var before: float = enemy.health
	for frame in range(900):await get_tree().physics_frame
	check(enemy.health<before-100,"crowded melee attackers reach a real enemy instead of pursuing its occupied centre")
	print("LIVE NAVIGATION CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
