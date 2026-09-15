extends Node
var game: Main
var frames: int = 0
var checks: int = 0
var failures: int = 0
var player_hurt: bool = false
var landed: bool = false
var returned: bool = false
func check(ok: bool, title: String) -> void:
	checks+=1
	if ok:print("PASS: ",title)
	else:failures+=1;push_error(title)
func _ready() -> void:
	SoundManager.is_muted=true
	game=load("res://scenes/Main.tscn").instantiate();add_child(game)
	game.goblin_ai.set_process(false);game.time_of_day_system.set_process(false);game.wildlife_system.set_process(false)
	var ai: GoblinAISystem = game.goblin_ai
	ai.economy_age=200;ai.expedition.cave_clock=-1000
	check(game.guardian_system.lairs.size()==2,"two permanent central-island guardians exist")
	var lair: Dictionary = game.guardian_system.lairs[0]
	var golem: Unit = lair.unit.get_ref()
	check(golem.max_health==1100 and golem.armor==8,"stone colossus has a distinct tank profile")
	var warden: Unit = game.guardian_system.lairs[1].unit.get_ref()
	check(warden.attack_range==9 and warden.config.ranged,"storm warden is a distinct ranged guardian")
	var scout: Unit = game.spawn_unit(UnitConfigs.UnitType.WARRIOR,"player",golem.position+Vector3(1,0,0))
	game.guardian_system._charge(lair,scout)
	check(lair.charge>1 and is_instance_valid(lair.warning),"guardian area attack has a visible retreat window")
	scout.position=lair.impact+Vector3(5,0,0);var hp: float = scout.health
	game.guardian_system._impact(lair)
	check(scout.health==hp,"leaving the marked impact zone avoids damage")
	scout.position=lair.impact+Vector3(1,0,0);game.guardian_system._impact(lair)
	check(scout.health<hp,"guardian area attack damages enemies inside the marker")
	scout.take_damage(99999);golem.take_damage(99999)
	game.guardian_system._process(119)
	check(not is_instance_valid(lair.unit.get_ref()) or not lair.unit.get_ref().is_alive,"guardian does not immediately respawn")
	game.guardian_system._process(2)
	check(is_instance_valid(lair.unit.get_ref()) and lair.unit.get_ref().is_alive,"guardian respawns after its lair cooldown")
	var raider: Unit = game.spawn_unit(UnitConfigs.UnitType.ZOMBIE,"enemy",Vector3(300,5,240))
	RaidSystem.scale_enemy(raider,6)
	check(raider.max_health>UnitConfigs.get_config(UnitConfigs.UnitType.ZOMBIE).health*1.5 and raider.attack_damage>UnitConfigs.get_config(UnitConfigs.UnitType.ZOMBIE).damage,"later waves increase individual health, damage and armor")
	raider.take_damage(99999)
	check(game.underground_system.caves.any(func(c):return c.entry.x>370),"goblins have reachable caves on their own island")
	var cave: Dictionary = game.underground_system.caves.filter(func(c):return c.entry.x>370)[0]
	var surveyor: Unit = ai.own_units().filter(func(u):return not UnitConfigs.is_worker(u.unit_type))[0]
	game.underground_system.enter(surveyor,cave.entry)
	check(surveyor.underground_unit and not game.underground_system.cutaway,"bot cave entry does not change the player view")
	game.underground_system.request_exit(surveyor)
	# Provision a fleet to test the real mission state machine, independent of economy pacing.
	for i in range(8):game.spawn_unit(UnitConfigs.UnitType.GOBLIN_WARRIOR,"goblin",Vector3(399.5+i%4,2,84.5+i/4))
	ai.expedition.cave_clock=80;ai.expedition._tick_caves(ai.own_units())
	check(ai.expedition.cave_party.size()==2,"bot assigns a separate reconnaissance party to a cave")
	var shore: Vector3 = ai.expedition.coast(game.terrain_generator.world_info.islands[2])
	var sea: Vector3 = game.grid_manager.nearest_sea_position(shore,3)
	check(shore!=Vector3.INF and sea!=Vector3.INF,"goblin island has a usable embarkation coast")
	game.spawn_unit(UnitConfigs.UnitType.GALLEY,"goblin",sea)
	ai.expedition.visited["crown"]=true
	FactionEconomy.wallets.goblin={"wood":400,"stone":200,"food":400,"ore":40,"water":100}
func _physics_process(_delta: float) -> void:
	frames+=1
	for u in game.all_units:
		if u.faction=="player" and u.health<u.max_health:player_hurt=true
	landed=landed or game.goblin_ai.expedition.landings>0
	returned=returned or (landed and game.goblin_ai.expedition.stage=="idle")
	if frames%1800==0:print("EXPEDITION ",frames/60,"s: ",game.goblin_ai.expedition.stage," cargo ",game.goblin_ai.expedition.ship.passengers.size() if is_instance_valid(game.goblin_ai.expedition.ship) else -1)
	if (landed and game.goblin_ai.expedition.player_sighted and player_hurt and returned) or frames>=18000:
		check(game.goblin_ai.expedition.cave_visits>0,"bot scouts physically enter their cave during the expedition")
		check(landed,"goblin expedition physically sails and disembarks on a new island")
		check(game.goblin_ai.expedition.visited.has("home"),"landing marks the home island as explored by the bot")
		check(game.goblin_ai.expedition.player_sighted,"landing party finds player units through local reconnaissance")
		check(player_hurt,"goblin landing party attacks the player's defenders")
		check(returned,"galley returns to its home port for the next expedition")
		check(game.goblin_ai.own_buildings().any(func(b):return b.is_constructed and b.position.x<192),"expedition worker completes an outpost on the captured coast")
		print("CAMPAIGN CHECKS: %d | FAILURES: %d" % [checks,failures]);get_tree().quit(failures)
