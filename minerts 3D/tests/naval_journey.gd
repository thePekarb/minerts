extends Node
var game: Main
var ship: Unit
var passengers: Array[Unit] = []
var destination: Vector3
var frames: int = 0
var failures: int = 0
var checks: int = 0
var started: bool = false
var left_home: bool = false
func check(ok: bool,title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)
func coast_near(center: Vector3, home: bool) -> Vector3:
	for dx in range(-12,13):
		for dz in range(-20,21):
			var p: Vector3 = Vector3(center.x+dx+.5,0.22,center.z+dz+.5)
			if not game.grid_manager.is_sea_position(p):continue
			var shore: Vector3 = game.transport_system._landing_cell(p)
			if shore==Vector3.INF:continue
			var origin: Vector3 = Vector3(96.5,2,95.5) if home else Vector3(402.5,2,78.5)
			if not game.grid_manager.find_path(origin,shore).is_empty():return p
	return Vector3.INF
func _ready() -> void:
	SoundManager.is_muted=true;game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.set_process(false);game.goblin_ai.set_process(false);game.wildlife_system.set_process(false);game.underground_system.set_process(false);game.time_of_day_system.set_process(false)
	for u in game.all_units:u.set_physics_process(false)
	var start: Vector3 = coast_near(Vector3(170,0,96),true)
	var end: Vector3 = coast_near(Vector3(350,0,80),false)
	check(start!=Vector3.INF and end!=Vector3.INF,"two islands have physically accessible landing shores")
	if start==Vector3.INF or end==Vector3.INF:get_tree().quit(1);return
	ship=game.spawn_unit(UnitConfigs.UnitType.GALLEY,"player",start)
	for i in range(3):
		var u: Unit = game.all_units[i]
		u.stop();u.target=null;u.current_order=UnitConfigs.UnitOrder.MOVE
		u.position=game.transport_system._landing_cell(ship.position,u)
		check(game.transport_system.board(u,ship),"passenger %d boards galley" % (i+1))
		game.transport_system.tick(0.1);passengers.append(u)
	check(ship.passengers.size()==3,"galley carries the whole selected squad")
	destination=game.transport_system._landing_cell(end)
	check(game.transport_system.order_ship(ship,destination),"land destination creates a sailing and disembarkation order")
	started=true
func _physics_process(delta: float) -> void:
	if not started:return
	frames+=1;game.transport_system.tick(delta)
	if ship.position.x>200:left_home=true
	if frames%1800==0:print("VOYAGE: ",frames/60," s ",ship.position," remaining waypoints ",ship.path.size()-ship.waypoint_index)
	if ship.path.is_empty() or frames>=10800:
		check(left_home,"galley physically leaves the home island")
		check(ship.position.distance_to(destination)<5.0,"galley reaches the far shore through water")
		check(ship.passengers.is_empty() and passengers.all(func(u):return u.embarked_in==null and game.grid_manager.is_walkable(floori(u.position.x),floori(u.position.z))),"all passengers automatically disembark on the destination island")
		var separated: bool = true
		for a in range(passengers.size()):
			for b in range(a+1,passengers.size()):
				if passengers[a].position.distance_to(passengers[b].position)<0.6:separated=false
		check(separated,"disembarked squad occupies separate free cells")
		print("NAVAL CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
