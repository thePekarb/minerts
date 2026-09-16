extends Node
var game: Main
var frames: int = 0
var checks: int = 0
var failures: int = 0
var produced: Dictionary = {}
var built: Dictionary = {}
var raiders_seen: bool = false
var bot_hurt: bool = false
var delivered_wood: int = 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)
func _ready() -> void:
	SoundManager.is_muted=true
	game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.time_of_day_system.time_of_day=.25
	game.gathering_system.resources_delivered.connect(func(faction,resource,amount):
		if faction=="goblin" and resource=="wood":delivered_wood+=amount
	)
	EventBus.unit_spawned.connect(func(u):
		if u.faction=="goblin":produced[u.unit_type]=true
	)
	EventBus.building_constructed.connect(func(b):
		if b.faction=="goblin":built[b.building_type]=true
	)
func _physics_process(_delta: float) -> void:
	frames+=1
	for u in game.all_units:
		if u.get_meta("goblin_raid",false):raiders_seen=true
		if u.faction=="goblin" and u.health<u.max_health:bot_hurt=true
	if frames%1800==0:
		print("BOT STATE @ ",frames/60," s: buildings ",built.keys()," units ",produced.keys()," wallet ",FactionEconomy.resources("goblin")," population ",game.goblin_ai.own_units().size())
		for b in game.goblin_ai.own_buildings():
			if not b.is_constructed:print("UNFINISHED: ",b.building_type," at ",b.position," progress ",b.construction_progress)
		print("NEEDED: ",game.goblin_ai._next_building(game.goblin_ai.own_buildings(),game.goblin_ai.own_units().size())," center ",game.goblin_ai.center)
	if frames>=25200:
		check(built.has(BuildingConfigs.BuildingType.BARRACKS),"AI worker physically completes the barracks")
		check(built.has(BuildingConfigs.BuildingType.FARM) and built.has(BuildingConfigs.BuildingType.WELL),"AI establishes its irrigated food economy")
		check(built.has(BuildingConfigs.BuildingType.PORT),"AI develops a coastal port")
		check(produced.has(UnitConfigs.UnitType.GOBLIN_WORKER),"AI replenishes its workforce through timed recruitment")
		check(GoblinAISystem.ARMY.all(func(type):return produced.has(type)),"AI produces all five military roles through the real queue")
		check(game.goblin_ai.explored.size()>500,"AI units explore their island")
		check(raiders_seen and bot_hurt,"night monsters actually engage the goblin settlement")
		check(not game.goblin_ai.own_units().is_empty() and game.goblin_ai.own_buildings().any(func(b):return b.building_type==BuildingConfigs.BuildingType.CAMPFIRE),"goblin settlement survives a complete night")
		check(delivered_wood>300,"workers deliver enough resources for sustained development")
		for u in game.goblin_ai.own_units():
			if UnitConfigs.is_worker(u.unit_type):print("WORKER: ",u.position," state ",u.state," order ",u.current_order," target ",u.target," inventory ",u.inventory)
		print("DELIVERED WOOD: ",delivered_wood)
		print("SIMULATION CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
