extends Node

var failures: int = 0
var checks: int = 0
var game: Main

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func unit(type: UnitConfigs.UnitType, faction: String, pos: Vector3) -> Unit:
	var result: Unit = game.spawn_unit(type, faction, pos)
	result.set_physics_process(false)
	return result

func building(type: BuildingConfigs.BuildingType, coords: Vector2i) -> Building:
	var result: Building = Building.new()
	game.buildings_container.add_child(result)
	result.init_building(type, coords.x, coords.y, true)
	var fp: Vector2i = result.config.footprint
	result.global_position = Vector3(coords.x + fp.x * 0.5, game.grid_manager.get_height(coords.x, coords.y), coords.y + fp.y * 0.5)
	game.all_buildings.append(result)
	game.grid_manager.occupy_area(coords.x, coords.y, fp.x, fp.y, result, result.is_gate)
	return result

func _ready() -> void:
	SoundManager.is_muted = true
	game = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	game.set_process(false)
	game.time_of_day_system.set_process(false)
	for u in game.all_units:
		u.set_physics_process(false)
	check(game.terrain_generator.chunks.size() > 144 and game.terrain_generator.chunks.size() < 1024, "archipelago creates land chunks and skips empty sea chunks")
	var highest: int = 0
	var biomes: Dictionary = {}
	for x in range(GridManager.GRID_SIZE):
		for z in range(GridManager.GRID_SIZE):
			var tile: Tile = game.grid_manager.get_tile(x, z)
			highest = maxi(highest, tile.height)
			biomes[tile.biome] = true
	check(highest >= 10 and biomes.size() == 7, "highlands and all seven biomes present")
	for coords in RaidSystem.ALTAR_POSITIONS:
		var path: Array[Vector3] = game.grid_manager.find_path(Vector3(coords.x + 0.5, 5, coords.y + 0.5), Vector3(96.5, 2, 96.5), "enemy")
		check(not path.is_empty(), "altar %s has a route to base" % coords)
	for type in [UnitConfigs.UnitType.WORKER, UnitConfigs.UnitType.WARRIOR, UnitConfigs.UnitType.ARCHER, UnitConfigs.UnitType.SCOUT, UnitConfigs.UnitType.ZOMBIE, UnitConfigs.UnitType.SKELETON, UnitConfigs.UnitType.SPIDER, UnitConfigs.UnitType.CREEPER]:
		var model: Dictionary = FrontierAssets.create_unit(type, "player" if type < 4 else "enemy")
		var animations: AnimationPlayer = model.anim_player
		check(model.root.has_meta("frontier_animations") and animations != null and animations.has_animation("Walk") and animations.has_animation("Attack"), "Blender rig and animations for unit %s" % type)
		if type == UnitConfigs.UnitType.WORKER:
			check(model.axe_ctrl != null and model.hammer_ctrl != null, "worker has independently controlled tools")
		model.root.free()
	var worker_for_tools: Unit = game.all_units[0]
	worker_for_tools.state = UnitConfigs.UnitState.GATHERING
	worker_for_tools._update_animation_and_tools(0.01)
	check(worker_for_tools.axe_ctrl.visible and not worker_for_tools.hammer_ctrl.visible, "gathering shows axe only")
	worker_for_tools.state = UnitConfigs.UnitState.BUILDING
	worker_for_tools._update_animation_and_tools(0.01)
	check(worker_for_tools.hammer_ctrl.visible and not worker_for_tools.axe_ctrl.visible, "construction shows hammer only")
	worker_for_tools.state = UnitConfigs.UnitState.IDLE
	var resource: StaticBody3D = StaticBody3D.new()
	game.world_container.add_child(resource)
	resource.global_position = worker_for_tools.global_position + Vector3(0.5, 0, 0)
	resource.set_meta("resource_type", "wood")
	resource.set_meta("resource_amount", 50)
	worker_for_tools.target = resource
	worker_for_tools.inventory = {"type": "wood", "amount": 12}
	worker_for_tools.gather_timer = 1.0
	game.gathering_system._update_unit_gather(worker_for_tools, 0.01)
	check(worker_for_tools.inventory.amount == 14 and resource.get_meta("resource_amount") == 48, "worker capacity and remaining resource stock are respected")
	worker_for_tools.inventory = {"type": "", "amount": 0}
	worker_for_tools.target = null
	worker_for_tools.stop()
	resource.queue_free()
	var knight: Unit = unit(UnitConfigs.UnitType.WARRIOR, "player", Vector3(92.5, 2, 92.5))
	knight.take_damage(10)
	check(knight.health == knight.max_health - 7, "knight armor reduces incoming damage")
	var skeleton: Unit = unit(UnitConfigs.UnitType.SKELETON, "enemy", Vector3(92.5, 2, 87.5))
	skeleton.target = knight
	skeleton.attack_timer = skeleton.attack_cooldown
	var before_projectiles: int = game.projectiles_container.get_child_count()
	game.combat_system._process_enemy_unit(skeleton, 0.01, game.all_units, game.all_buildings)
	check(game.projectiles_container.get_child_count() == before_projectiles + 1, "skeleton fires an actual arrow")
	var gate: Building = building(BuildingConfigs.BuildingType.GATE, Vector2i(90, 96))
	check(not game.grid_manager.is_walkable(90, 96), "closed gate blocks navigation")
	gate.toggle_gate(game.grid_manager)
	check(game.grid_manager.is_walkable(90, 96) and game.grid_manager.is_walkable(91, 96), "open gate releases entire footprint")
	check(not game.grid_manager.astar.is_point_disabled(game.grid_manager.get_point_id(91, 96)), "open gate updates AStar")
	gate.toggle_gate(game.grid_manager)
	check(game.grid_manager.astar.is_point_disabled(game.grid_manager.get_point_id(90, 96)), "closing gate updates AStar")
	var mine_a: Building = building(BuildingConfigs.BuildingType.MINE, Vector2i(88, 90))
	var mine_b: Building = building(BuildingConfigs.BuildingType.MINE, Vector2i(88, 93))
	mine_a.upgrade_mine()
	check(mine_b.level == 1 and mine_b.config.name == "Stone Mine", "mine upgrade does not mutate other mine configs")
	var worker: Unit = game.all_units[0]
	mine_a.assigned_miners.append(worker)
	worker.mining_building_id = str(mine_a.get_instance_id())
	worker.state = UnitConfigs.UnitState.MINING_INSIDE
	worker.visible = false
	mine_a.take_damage(9999)
	check(worker.visible and worker.mining_building_id == "" and worker.state == UnitConfigs.UnitState.IDLE, "destroyed mine ejects surviving workers")
	var victim: Unit = unit(UnitConfigs.UnitType.ZOMBIE, "player", Vector3(103, 2, 96))
	var distant: Unit = unit(UnitConfigs.UnitType.ZOMBIE, "player", Vector3(110, 2, 96))
	var creeper: Unit = unit(UnitConfigs.UnitType.CREEPER, "enemy", Vector3(102, 2, 96))
	creeper.target = victim
	game.combat_system._process_enemy_unit(creeper, 0.01, game.all_units, game.all_buildings)
	check(creeper.fuse_timer == 0.0 and creeper.blast_warning != null, "creeper starts a visible fuse before damage")
	var victim_hp: float = victim.health
	game.combat_system._process_enemy_unit(creeper, 0.8, game.all_units, game.all_buildings)
	check(victim.health == victim_hp and creeper.is_alive, "fuse grants time to retreat or kill creeper")
	var wood: int = EconomyManager.resources.wood
	game.combat_system._process_enemy_unit(creeper, 0.9, game.all_units, game.all_buildings)
	check(not creeper.is_alive and victim.health < victim_hp, "creeper explodes and damages nearby units")
	check(distant.health == distant.max_health, "blast excludes targets outside radius")
	check(EconomyManager.resources.wood == wood, "self-detonation does not grant kill loot")
	var defused: Unit = unit(UnitConfigs.UnitType.CREEPER, "enemy", Vector3(102, 2, 97))
	defused.target = victim
	game.combat_system._process_enemy_unit(defused, 0.01, game.all_units, game.all_buildings)
	victim_hp = victim.health
	defused.take_damage(999)
	check(victim.health == victim_hp, "killing creeper during fuse prevents explosion")
	var wall: Building = building(BuildingConfigs.BuildingType.WALL, Vector2i(101, 94))
	var bomber: Unit = unit(UnitConfigs.UnitType.CREEPER, "enemy", Vector3(101.5, 2, 95.5))
	bomber.target = wall
	bomber.fuse_timer = 1.59
	game.combat_system._process_enemy_unit(bomber, 0.02, game.all_units, game.all_buildings)
	check(wall.health < wall.max_health, "explosion damages fortifications")
	game.raid_system.current_wave = 2
	game.raid_system.spawn_night_wave()
	var kinds: Dictionary = {}
	for enemy in game.raid_system.enemy_units:
		kinds[enemy.unit_type] = true
	check(kinds.has(UnitConfigs.UnitType.ZOMBIE) and kinds.has(UnitConfigs.UnitType.SKELETON) and kinds.has(UnitConfigs.UnitType.SPIDER) and kinds.has(UnitConfigs.UnitType.CREEPER), "third wave includes all four enemy roles")
	await get_tree().process_frame
	if not SoundManager.is_muted:
		SoundManager.toggle_mute()
	await get_tree().create_timer(0.1).timeout
	game.queue_free()
	await get_tree().process_frame
	print("FRONTIER CHECKS: %d | FAILURES: %d" % [checks, failures])
	get_tree().quit(failures)
