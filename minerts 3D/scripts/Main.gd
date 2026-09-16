class_name Main
extends Node3D

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var camera: RTSCamera = $Camera3D
@onready var hud: HUD = $HUD

# Containers
@onready var world_container: Node3D = $World
@onready var units_container: Node3D = $Units
@onready var buildings_container: Node3D = $Buildings
@onready var projectiles_container: Node3D = $Projectiles
@onready var zones_container: Node3D = $Zones

# Systems
var terrain_generator: TerrainGenerator
var grid_manager: GridManager
var resource_spawner: ResourceSpawner

var selection_system: SelectionSystem
var construction_system: ConstructionSystem
var gathering_system: GatheringSystem
var lumber_zone_system: LumberZoneSystem
var combat_system: CombatSystem
var raid_system: RaidSystem
var time_of_day_system: TimeOfDaySystem
var farming_system: FarmingSystem
var wildlife_system: WildlifeSystem
var underground_system: UndergroundSystem
var interaction_feedback: InteractionFeedback
var production_system: ProductionSystem
var transport_system: TransportSystem
var goblin_ai: GoblinAISystem
var fog_system: FogOfWarSystem
var terraforming_system: TerraformingSystem

var all_units: Array[Unit] = []
var all_buildings: Array[Building] = []
var guardian_system: GuardianSystem
var simulation_accumulator: float = 0.0
var last_system_usec: Dictionary = {}
var storage_system: StorageSystem
var workshop_system: WorkshopSystem
var network_session: NetworkGameSession
var touch_controls: TouchRTSController
var responsive_hud: ResponsiveHUD
var prop_batches: WorldPropBatches
var unit_visuals: UnitVisualSystem

# Input state
var is_left_mouse_down: bool = false
var left_mouse_start: Vector2 = Vector2.ZERO
var is_marquee_dragging: bool = false
var is_demolish_mode: bool = false
var hovered_demolish_building: Building = null

func _ready() -> void:
	if NetworkManager.in_match:
		FactionEconomy.storage=null
		FactionEconomy.wallets.clear()
		EconomyManager.resources={"wood":120,"stone":60,"food":120,"ore":20,"water":0,"pop":0,"max_pop":10}
		for slot in GameSettings.get_active_slots():
			if slot.get("type")=="player" and slot.get("peer_id",1)!=1:
				FactionEconomy.wallets[NetworkManager.faction_for_peer(slot.peer_id)]=EconomyManager.resources.duplicate()
	_init_core_world()
	_init_systems()
	_spawn_initial_base()
	_connect_hud_events()
	transport_system=TransportSystem.new();add_child(transport_system);transport_system.setup(self)
	production_system=ProductionSystem.new();add_child(production_system);production_system.setup(self)
	farming_system = FarmingSystem.new()
	add_child(farming_system)
	wildlife_system = WildlifeSystem.new()
	add_child(wildlife_system)
	wildlife_system.setup(self)
	underground_system = UndergroundSystem.new()
	add_child(underground_system)
	underground_system.setup(self)
	interaction_feedback = InteractionFeedback.new()
	add_child(interaction_feedback)
	interaction_feedback.setup(self)
	goblin_ai=GoblinAISystem.new();add_child(goblin_ai);goblin_ai.setup(self)
	storage_system=StorageSystem.new();add_child(storage_system);storage_system.setup(self)
	workshop_system=WorkshopSystem.new();add_child(workshop_system);workshop_system.setup(self)
	guardian_system=GuardianSystem.new();add_child(guardian_system);guardian_system.setup(self)
	fog_system.update_fog(all_units, all_buildings, 0.3)
	unit_visuals=UnitVisualSystem.new();add_child(unit_visuals);unit_visuals.setup(self)
	touch_controls=TouchRTSController.new();add_child(touch_controls);touch_controls.setup(self)
	responsive_hud=ResponsiveHUD.new();add_child(responsive_hud);responsive_hud.setup(self)
	if NetworkManager.in_match:
		network_session=NetworkGameSession.new();add_child(network_session);network_session.setup(self)


func _init_core_world() -> void:
	# 1. Grid Manager
	grid_manager = GridManager.new()
	add_child(grid_manager)

	# 2. Terrain Generator
	terrain_generator = TerrainGenerator.new()
	terrain_generator.noise_seed = GameSettings.seed_val
	world_container.add_child(terrain_generator)
	terrain_generator.generate_terrain(grid_manager)

	# 3. Resource Spawner
	resource_spawner = ResourceSpawner.new()
	world_container.add_child(resource_spawner)
	resource_spawner.spawn_world_resources(grid_manager, world_container, terrain_generator)
	var environment_details: EnvironmentDetails = EnvironmentDetails.new()
	world_container.add_child(environment_details)
	environment_details.populate(grid_manager)
	grid_manager.rebuild_astar()

	# 5. Camera terrain tracking (focused on local player's island)
	camera.set_terrain(terrain_generator)
	var local_slot_idx: int = GameSettings.get_local_player_slot_index()
	var participant_spawns: Array = terrain_generator.world_info.get("spawns", [])
	var local_spawn := Vector2i(96, 96)
	if local_slot_idx < participant_spawns.size():
		var s_val = participant_spawns[local_slot_idx]
		local_spawn = Vector2i(s_val[0], s_val[1]) if s_val is Array else s_val
	var focus_y: float = terrain_generator.get_height_at(float(local_spawn.x), float(local_spawn.y))
	camera.target_focus = Vector3(float(local_spawn.x) + 0.5, focus_y, float(local_spawn.y) + 0.5)
	SoundManager.set_camera(camera)


func _init_systems() -> void:
	# Selection
	selection_system = SelectionSystem.new()
	add_child(selection_system)
	selection_system.init_selection(camera, grid_manager, resource_spawner)

	# Construction
	construction_system = ConstructionSystem.new()
	add_child(construction_system)
	construction_system.init_construction(camera, grid_manager, buildings_container)

	# Gathering
	gathering_system = GatheringSystem.new()
	add_child(gathering_system)
	gathering_system.init_gathering(grid_manager, resource_spawner, construction_system)

	# Lumber Zones
	lumber_zone_system = LumberZoneSystem.new()
	add_child(lumber_zone_system)
	lumber_zone_system.init_lumber_zones(camera, grid_manager, resource_spawner, zones_container)

	# Terraforming (Digging Blocks)
	terraforming_system = TerraformingSystem.new()
	add_child(terraforming_system)
	terraforming_system.init_system(grid_manager, terrain_generator, camera, resource_spawner, hud)

	selection_system.lumber_zone_system = lumber_zone_system
	selection_system.terraforming_system = terraforming_system

	# Combat
	combat_system = CombatSystem.new()
	add_child(combat_system)
	combat_system.init_combat(grid_manager, projectiles_container)

	# Raids
	raid_system = RaidSystem.new()
	add_child(raid_system)
	raid_system.init_raid(grid_manager, units_container, world_container)
	if not GameSettings.night_wave_enabled:
		raid_system.set_process(false)

	# Time of Day
	time_of_day_system = TimeOfDaySystem.new()
	add_child(time_of_day_system)
	time_of_day_system.init_lighting(sun_light, world_environment)
	if not GameSettings.day_night_enabled:
		time_of_day_system.set_process(false)

	# Fog of War
	fog_system = FogOfWarSystem.new()
	add_child(fog_system)
	fog_system.init_fog(grid_manager)
	fog_system.apply_world_materials(world_container)
	if not GameSettings.fog_enabled:
		fog_system.set_fog_enabled(false)

	if DisplayServer.get_name()!="headless":
		prop_batches=WorldPropBatches.new();add_child(prop_batches);prop_batches.setup(resource_spawner.resources)

	# Minimap
	hud.minimap.init_minimap(grid_manager, camera, fog_system)

	# Global events
	EventBus.unit_spawned.connect(_on_unit_spawned)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.building_constructed.connect(func(_b): _refresh_population())
	EventBus.building_placed.connect(func(b): all_buildings.append(b))

func _spawn_initial_base() -> void:
	var local_slot_idx: int = GameSettings.get_local_player_slot_index()
	var participant_spawns: Array = terrain_generator.world_info.get("spawns", [])
	var local_spawn := Vector2i(96, 96)
	if local_slot_idx < participant_spawns.size():
		var s_val = participant_spawns[local_slot_idx]
		local_spawn = Vector2i(s_val[0], s_val[1]) if s_val is Array else s_val

	var my_faction: String = "player" if NetworkManager.in_match else GameSettings.player_faction
	var is_goblin_player: bool = (GameSettings.player_faction == "goblin")
	var worker_type: UnitConfigs.UnitType = UnitConfigs.UnitType.GOBLIN_WORKER if is_goblin_player else UnitConfigs.UnitType.WORKER
	var warrior_type: UnitConfigs.UnitType = UnitConfigs.UnitType.GOBLIN_WARRIOR if is_goblin_player else UnitConfigs.UnitType.WARRIOR
	var archer_type: UnitConfigs.UnitType = UnitConfigs.UnitType.GOBLIN_ARCHER if is_goblin_player else UnitConfigs.UnitType.ARCHER

	# Spawn central Campfire on local player's island
	var camp: Building = Building.new()
	camp.faction = my_faction
	buildings_container.add_child(camp)
	var camp_y: float = grid_manager.get_height(float(local_spawn.x) + 0.5, float(local_spawn.y) + 0.5)
	camp.global_position = Vector3(float(local_spawn.x) + 1.0, camp_y, float(local_spawn.y) + 1.0)
	camp.init_building(BuildingConfigs.BuildingType.CAMPFIRE, local_spawn.x, local_spawn.y, true)
	grid_manager.occupy_area(local_spawn.x, local_spawn.y, 2, 2, camp)
	all_buildings.append(camp)
	gathering_system.register_storage(camp)
	EventBus.building_constructed.emit(camp)

	# Spawn 3 starting Workers
	var worker_offsets: Array[Vector3] = [
		Vector3(-1.5, 0, -0.5),
		Vector3(2.5, 0, -0.5),
		Vector3(0.5, 0, 2.5)
	]
	for off in worker_offsets:
		spawn_unit(worker_type, my_faction, camp.global_position + off)

	# Spawn starting Warrior defender
	spawn_unit(warrior_type, my_faction, camp.global_position + Vector3(0.5, 0, -2.5))

	# Spawn starting Archer defender
	spawn_unit(archer_type, my_faction, camp.global_position + Vector3(2.5, 0, -2.5))

	# Spawn other participants on their respective islands
	_spawn_lobby_participants(local_slot_idx, participant_spawns)

func _spawn_lobby_participants(local_idx: int, participant_spawns: Array) -> void:
	var active_slots: Array = GameSettings.get_active_slots()
	for i in range(active_slots.size()):
		if i == local_idx:
			continue
		var slot: Dictionary = active_slots[i]
		var s_pos := Vector2i(402, 80)
		if i < participant_spawns.size():
			var raw_s = participant_spawns[i]
			s_pos = Vector2i(raw_s[0], raw_s[1]) if raw_s is Array else raw_s

		var s_faction: String = NetworkManager.faction_for_peer(slot.get("peer_id",0)) if NetworkManager.in_match and slot.get("type")=="player" else slot.get("faction", "goblin")
		var s_name: String = slot.get("name", "Участник")

		# If goblin AI is managing the primary goblin island at index 1, avoid placing a duplicate campfire
		if s_faction == "goblin" and (i==1 or NetworkManager.in_match):
			continue

		_spawn_participant_camp(s_pos, s_faction, s_name)

func _spawn_participant_camp(coords: Vector2i, faction: String, _bot_name: String) -> void:
	var camp: Building = Building.new()
	camp.faction = faction
	buildings_container.add_child(camp)
	var camp_y: float = grid_manager.get_height(float(coords.x) + 0.5, float(coords.y) + 0.5)
	camp.global_position = Vector3(float(coords.x) + 1.0, camp_y, float(coords.y) + 1.0)
	camp.init_building(BuildingConfigs.BuildingType.CAMPFIRE, coords.x, coords.y, true)
	grid_manager.occupy_area(coords.x, coords.y, 2, 2, camp)
	all_buildings.append(camp)
	fog_system.apply_world_materials(camp)
	EventBus.building_constructed.emit(camp)

	var is_gob: bool = (FactionRules.race(faction) == "goblin")
	var w_type: UnitConfigs.UnitType = UnitConfigs.UnitType.GOBLIN_WORKER if is_gob else UnitConfigs.UnitType.WORKER
	var f_type: UnitConfigs.UnitType = UnitConfigs.UnitType.GOBLIN_WARRIOR if is_gob else UnitConfigs.UnitType.WARRIOR
	var a_type: UnitConfigs.UnitType = UnitConfigs.UnitType.GOBLIN_ARCHER if is_gob else UnitConfigs.UnitType.ARCHER

	for offset in [Vector3(-2.5, 0, -2.5), Vector3(2.5, 0, -2.5), Vector3(-2.5, 0, 2.5)]:
		spawn_unit(w_type, faction, camp.global_position + offset)
	spawn_unit(f_type, faction, camp.global_position + Vector3(0, 0, 3.5))
	spawn_unit(a_type, faction, camp.global_position + Vector3(3.5, 0, 0))


func spawn_unit(type: UnitConfigs.UnitType, faction: String, pos: Vector3) -> Unit:
	var unit: Unit = Unit.new()
	unit.unit_type = type
	unit.faction = faction
	unit.grid_manager = grid_manager
	units_container.add_child(unit)
	pos.y = 0.22 if UnitConfigs.is_vessel(type) else grid_manager.get_height(pos.x, pos.z)
	unit.global_position = pos
	grid_manager.unit_index.invalidate()
	if not UnitConfigs.is_vessel(type) and (not grid_manager.is_walkable(floori(pos.x),floori(pos.z),faction) or not grid_manager.unit_position_free(unit,pos)):
		var found: bool = false
		for radius in range(1,9):
			for dx in range(-radius,radius+1):
				for dz in range(-radius,radius+1):
					if maxi(absi(dx),absi(dz))!=radius:continue
					var point := Vector3(floori(pos.x)+dx+.5,grid_manager.get_height(pos.x+dx,pos.z+dz),floori(pos.z)+dz+.5)
					if absf(point.y-pos.y)<=1 and grid_manager.is_walkable(floori(point.x),floori(point.z),faction) and grid_manager.unit_position_free(unit,point):
						unit.position=point;found=true;break
				if found:break
			if found:break
	grid_manager.unit_index.invalidate()

	all_units.append(unit)
	EventBus.unit_spawned.emit(unit)
	return unit

func _on_unit_spawned(u: Unit) -> void:
	if not all_units.has(u):
		all_units.append(u)
	_refresh_population()

func _on_entity_died(e: Variant) -> void:
	var carcass: Node3D = null
	if e is Unit:
		if transport_system:transport_system.on_death(e)
		all_units.erase(e)
		if e.faction == "enemy" and not e.get_meta("self_destructed", false):
			var winner: String = e.get_meta("last_hit_faction","player")
			FactionEconomy.add(winner,"wood",5);FactionEconomy.add(winner,"stone",3)
			if winner=="player":SoundManager.play_pop();_show_loot(e.global_position)
		if e.config.get("food_loot",0)>0 and wildlife_system:
			carcass=wildlife_system.create_carcass(e)
			SoundManager.play_eat_apple()
		# Clear from lumber zones if assigned
		for z in lumber_zone_system.zones:
			z.assigned_workers.erase(e)
		if terraforming_system:
			terraforming_system.unassign_worker(e)
		var valid_buildings: Array[Building] = []
		for b in all_buildings:
			if is_instance_valid(b):
				valid_buildings.append(b)
				if "assigned_miners" in b and b.assigned_miners is Array:
					b.assigned_miners.erase(e)
		if is_instance_valid(e.garrisoned_tower):
			e.garrisoned_tower.garrisoned_archer = null
			e.garrisoned_tower = null
		all_buildings = valid_buildings
	elif e is Building:
		e.training_queue.clear();e.crafting_queue.clear()
		if is_instance_valid(e.rally_marker):e.rally_marker.queue_free()
		e.eject_all_miners(grid_manager)
		if "garrisoned_archer" in e and is_instance_valid(e.garrisoned_archer):
			e.ungarrison_archer()
		all_buildings.erase(e)
		grid_manager.free_area(e.grid_x, e.grid_z, e.footprint.x, e.footprint.y)

	# Clean up any previously freed entries in all_units & all_buildings
	all_units = all_units.filter(func(u): return is_instance_valid(u))
	all_buildings = all_buildings.filter(func(b): return is_instance_valid(b))

	# Signals are synchronous: detach references before freeing the dead node.
	selection_system.remove_entity(e)
	for u in all_units:
		if is_instance_valid(u) and u.target == e:
			u.target = null
			u.stop()
			if carcass and UnitConfigs.is_worker(u.unit_type):
				u.target=carcass;u.current_order=UnitConfigs.UnitOrder.GATHER
				u.set_meta("gather_kind","food")
	if is_instance_valid(e) and e is CollisionObject3D:
		e.collision_layer = 0
		e.collision_mask = 0
	if is_instance_valid(e) and e is Node:
		e.queue_free()
	_refresh_population()

func _refresh_population() -> void:
	var count: int = 0
	var capacity: int = 10
	for u in all_units:
		if is_instance_valid(u) and u.is_alive and u.faction == "player" and not UnitConfigs.is_vessel(u.unit_type):
			count += 1
	for b in all_buildings:
		if is_instance_valid(b) and b.is_alive and b.is_constructed and b.faction=="player" and b.building_type == BuildingConfigs.BuildingType.HUT:
			capacity += 4
	EconomyManager.update_population(count, capacity)

func _show_loot(pos: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = "+5 Wood  +3 Stone"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.012
	label.modulate = Color("f4d58d")
	label.outline_size = 8
	add_child(label)
	label.global_position = pos + Vector3(0, 2.3, 0)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.5, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.7)
	tween.chain().tween_callback(label.queue_free)

func _connect_hud_events() -> void:
	hud.build_requested.connect(func(type):
		if underground_system and underground_system.cutaway:
			hud.show_banner("Постройки размещаются на поверхности. Нажмите X.")
			return
		if terraforming_system and terraforming_system.is_active:
			terraforming_system.deactivate()
		lumber_zone_system.cancel_zone_placement()
		construction_system.start_placement(type)
		if type == BuildingConfigs.BuildingType.WALL:
			hud.show_banner("Забор: Зажмите ЛКМ для непрерывной постройки | [R]: Поворот на 90° | ПКМ: Отмена")
		else:
			hud.show_banner("ЛКМ: Разместить | [R]: Поворот на 90° | ПКМ: Отмена")
	)

	hud.lumber_zone_tool_requested.connect(func():
		if underground_system and underground_system.cutaway: return
		if terraforming_system and terraforming_system.is_active:
			terraforming_system.deactivate()
		construction_system.cancel_placement()
		lumber_zone_system.start_zone_placement()
	)

	hud.minimap.map_clicked.connect(func(w_pos):
		camera.target_focus = w_pos
	)

	hud.cancel_training_requested.connect(func():
		if is_instance_valid(selection_system.selected_building) and selection_system.selected_building.faction=="player":
			var b: Building=selection_system.selected_building
			if b.building_type==BuildingConfigs.BuildingType.WORKSHOP:workshop_system.cancel(b,b.crafting_queue.size()-1)
			else:production_system.cancel(b)
	)
	hud.unload_requested.connect(func():
		for u in selection_system.selected_units:
			if UnitConfigs.is_vessel(u.unit_type):
				if transport_system.unload(u)==0:hud.show_banner("Для высадки подведите судно к пологому берегу.")
	)
	hud.train_unit_requested.connect(func(type):
		_train_unit(type)
	)

	hud.exit_cave_requested.connect(func():
		for unit in selection_system.selected_units:
			if is_instance_valid(unit) and unit.is_alive and unit.underground_unit:
				underground_system.request_exit(unit)
	)

	hud.gate_toggle_requested.connect(func():
		if selection_system.selected_building and selection_system.selected_building.is_gate:
			selection_system.selected_building.toggle_gate(grid_manager)
			hud._on_selection_changed(selection_system.selected_units, selection_system.selected_building)
	)

	hud.mine_minus_requested.connect(func():
		_handle_mine_minus(selection_system.selected_building)
	)
	hud.mine_plus_requested.connect(func():
		_handle_mine_plus(selection_system.selected_building)
	)
	hud.mine_upgrade_requested.connect(func():
		_handle_mine_upgrade(selection_system.selected_building)
	)
	hud.mine_eject_requested.connect(func():
		if selection_system.selected_building:
			selection_system.selected_building.eject_all_miners(grid_manager)
			hud._on_selection_changed(selection_system.selected_units, selection_system.selected_building)
	)

	# Floating badge signals
	hud.floating_badge.minus_clicked.connect(func():
		if hud.floating_badge.is_mine:
			_handle_mine_minus(hud.floating_badge.target_node as Building)
		else:
			if lumber_zone_system.selected_zone:
				lumber_zone_system.remove_worker(lumber_zone_system.selected_zone)
				hud.floating_badge.update_count(lumber_zone_system.selected_zone.assigned_workers.size(), lumber_zone_system.selected_zone.max_workers)
	)

	hud.floating_badge.plus_clicked.connect(func():
		if hud.floating_badge.is_mine:
			_handle_mine_plus(hud.floating_badge.target_node as Building)
		else:
			if lumber_zone_system.selected_zone:
				lumber_zone_system.add_worker(lumber_zone_system.selected_zone, all_units)
				hud.floating_badge.update_count(lumber_zone_system.selected_zone.assigned_workers.size(), lumber_zone_system.selected_zone.max_workers)
	)

	hud.floating_badge.upgrade_clicked.connect(func():
		if hud.floating_badge.is_mine:
			_handle_mine_upgrade(hud.floating_badge.target_node as Building)
	)

	hud.floating_badge.eject_clicked.connect(func():
		if hud.floating_badge.is_mine and hud.floating_badge.target_node is Building:
			var b: Building = hud.floating_badge.target_node as Building
			b.eject_all_miners(grid_manager)
			hud.floating_badge.update_count(0, b.max_miners)
	)

	hud.floating_badge.delete_clicked.connect(func():
		if lumber_zone_system.selected_zone:
			lumber_zone_system.delete_zone()
			hud.floating_badge.hide_badge()
	)

func _handle_mine_minus(b: Building) -> void:
	if NetworkManager.route_building("mine_minus",b):return
	if not is_instance_valid(b) or b.assigned_miners.is_empty():
		return
	var miner: Unit = b.assigned_miners.pop_back()
	if is_instance_valid(miner):
		var out_x: float = float(b.grid_x) + float(b.footprint.x) + 0.5
		var out_z: float = float(b.grid_z) + float(b.footprint.y) + 0.5
		miner.ungarrison_from_building(Vector3(out_x, grid_manager.get_height(out_x, out_z), out_z))
	SoundManager.play_click()
	EventBus.mine_miner_count_changed.emit(b, b.assigned_miners.size())
	hud._on_selection_changed(selection_system.selected_units, b)
	if hud.floating_badge.visible and hud.floating_badge.target_node == b:
		hud.floating_badge.update_count(b.assigned_miners.size(), b.max_miners)

func _handle_mine_plus(b: Building) -> void:
	if NetworkManager.route_building("mine_plus",b):return
	if not is_instance_valid(b) or b.assigned_miners.size() >= b.max_miners:
		return
	# Find an idle unassigned worker
	var best_w: Unit = null
	var min_d: float = 9999.0
	for u in all_units:
		if is_instance_valid(u) and u.is_alive and u.faction == "player" and u.unit_type == UnitConfigs.UnitType.WORKER:
			if u.assigned_lumber_zone_id == "" and u.mining_building_id == "" and u.state != UnitConfigs.UnitState.MINING_INSIDE:
				var d: float = u.global_position.distance_to(b.global_position)
				if d < min_d:
					min_d = d
					best_w = u

	if best_w:
		if not best_w.get_meta("mining_tool",false):
			if not FactionEconomy.spend(best_w.faction,{"pickaxe":1}):
				hud.show_banner("Изготовьте кирку в мастерской: одна кирка на шахтёра.");return
			best_w.set_meta("mining_tool",true)
		selection_system.cancel_assignments(best_w)
		b.assigned_miners.append(best_w)
		best_w.mining_building_id = str(b.get_instance_id())
		best_w.target = b
		best_w.current_order = UnitConfigs.UnitOrder.MOVE
		var path: Array[Vector3] = grid_manager.find_path(best_w.global_position, b.global_position)
		best_w.set_path(path)
		best_w.state = UnitConfigs.UnitState.MOVING
		SoundManager.play_click()
		EventBus.mine_miner_count_changed.emit(b, b.assigned_miners.size())
		hud._on_selection_changed(selection_system.selected_units, b)
		if hud.floating_badge.visible and hud.floating_badge.target_node == b:
			hud.floating_badge.update_count(b.assigned_miners.size(), b.max_miners)

func _handle_mine_upgrade(b: Building) -> void:
	if NetworkManager.route_building("mine_upgrade",b):return
	if not is_instance_valid(b) or b.level >= 2:
		return
	var upgrade_cost: Dictionary = {"stone": 40, "wood": 20}
	if EconomyManager.spend_resources(upgrade_cost):
		b.upgrade_mine()
		SoundManager.play_build()
		hud._on_selection_changed(selection_system.selected_units, b)
		if hud.floating_badge.visible and hud.floating_badge.target_node == b:
			hud.floating_badge.show_for_mine(b, b.assigned_miners.size(), b.max_miners, camera)

func _train_unit(type: UnitConfigs.UnitType) -> void:
	var error: String = production_system.enqueue(selection_system.selected_building,type)
	if error!="":hud.show_banner(error)
	else:
		SoundManager.play_select()
		SoundManager.play_eat_apple()

func toggle_demolish_mode() -> void:
	set_demolish_mode(not is_demolish_mode)

func set_demolish_mode(active: bool) -> void:
	is_demolish_mode = active
	hovered_demolish_building = null
	if is_demolish_mode:
		if terraforming_system and terraforming_system.is_active:
			terraforming_system.deactivate()
		if construction_system.is_placing():
			construction_system.cancel_placement()
		if lumber_zone_system.is_placing_zone:
			lumber_zone_system.cancel_zone_placement()
		hud.show_banner("Режим сноса: наведите на постройку и нажмите ЛКМ для удаления (ПКМ/ESC — отмена)")
		SoundManager.play_click()
	else:
		hud.show_banner("Режим сноса выключен")
	if hud.skin and hud.skin.demolish_tool_btn:
		hud.skin.demolish_tool_btn.text = "✕  Выйти из сноса" if is_demolish_mode else "🗑️  Снос постройки"

func demolish_selected_building() -> void:
	var b: Building = selection_system.selected_building
	if not is_instance_valid(b) or b.faction != "player":
		return
	var b_name: String = b.config.get("name", "Постройка")
	var is_c: bool = b.is_constructed
	if construction_system.demolish_building(b, all_units):
		selection_system.clear_selection()
		hud._on_selection_changed(selection_system.selected_units, null)
		hud.show_banner("%s %s" % [b_name, "снесена" if is_c else "отменена"])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if hud.skin and camera.command_keys_active and not key_event.ctrl_pressed and not construction_system.is_placing():
				if key_event.physical_keycode in [KEY_Q,KEY_E]:
					hud.skin.command("gather" if key_event.physical_keycode==KEY_Q else "dig");get_viewport().set_input_as_handled();return
				if key_event.physical_keycode==KEY_R and not underground_system.cutaway:
					hud.skin.command("carry");return
			if key_event.physical_keycode == KEY_X or key_event.keycode == KEY_X:
				underground_system.toggle_view()
				return
			if key_event.physical_keycode == KEY_R or key_event.keycode == KEY_R:
				if construction_system.is_placing():
					construction_system.rotate_90()
					return
				for unit in selection_system.selected_units:
					underground_system.request_exit(unit)
				return
			if key_event.physical_keycode == KEY_G or key_event.keycode == KEY_G:
				if terraforming_system:
					if construction_system.is_placing():
						construction_system.cancel_placement()
					if lumber_zone_system.is_placing_zone:
						lumber_zone_system.cancel_zone_placement()
					terraforming_system.toggle_dig_mode()
					get_viewport().set_input_as_handled()
					return
			if key_event.keycode == KEY_O:
				if selection_system.selected_building and selection_system.selected_building.is_gate:
					selection_system.selected_building.toggle_gate(grid_manager)
					hud._on_selection_changed(selection_system.selected_units, selection_system.selected_building)
			elif key_event.physical_keycode in [KEY_DELETE, KEY_BACKSPACE] or key_event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
				if lumber_zone_system.selected_zone:
					lumber_zone_system.delete_zone()
					hud.floating_badge.hide_badge()
					return
				elif is_instance_valid(selection_system.selected_building) and selection_system.selected_building.faction == "player":
					demolish_selected_building()
					return
				else:
					toggle_demolish_mode()
					return
			elif key_event.keycode == KEY_ESCAPE:
				if is_demolish_mode:
					set_demolish_mode(false)
					return
				if terraforming_system and terraforming_system.is_active:
					terraforming_system.deactivate()
				if hud.skin:hud.skin.command("stop")
				construction_system.cancel_placement()
				lumber_zone_system.cancel_zone_placement()
				selection_system.clear_selection()
				hud.floating_badge.hide_badge()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_left_mouse_down(mb.position)
			else:
				_handle_left_mouse_up(mb.position)

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_handle_right_mouse_down(mb.position)

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_mouse_motion(mm.position)

func _handle_left_mouse_down(pos: Vector2) -> void:
	if is_demolish_mode:
		var hit: Dictionary = camera.raycast_objects(pos)
		var collider: Object = hit.get("collider", null)
		var target_b: Building = null
		if collider is Building and collider.faction == "player":
			target_b = collider
		elif collider and collider.get_parent() is Building and collider.get_parent().faction == "player":
			target_b = collider.get_parent()
		if target_b:
			var b_name: String = target_b.config.get("name", "Постройка")
			var is_c: bool = target_b.is_constructed
			interaction_feedback.show_order(target_b.global_position)
			construction_system.demolish_building(target_b, all_units)
			hud.show_banner("%s %s" % [b_name, "снесена" if is_c else "отменена"])
			if not Input.is_key_pressed(KEY_SHIFT):
				set_demolish_mode(false)
		return

	if terraforming_system and terraforming_system.is_active:
		terraforming_system.on_mouse_down(pos)
		return

	if construction_system.is_placing():
		construction_system.start_drag_placement(all_units)
		return

	if lumber_zone_system.is_placing_zone:
		lumber_zone_system.on_mouse_down(pos)
		return

	is_left_mouse_down = true
	left_mouse_start = pos
	is_marquee_dragging = false

func _handle_mouse_motion(pos: Vector2) -> void:
	if is_demolish_mode:
		var hit: Dictionary = camera.raycast_objects(pos)
		var collider: Object = hit.get("collider", null)
		var target_b: Building = null
		if collider is Building and collider.faction == "player":
			target_b = collider
		elif collider and collider.get_parent() is Building and collider.get_parent().faction == "player":
			target_b = collider.get_parent()
		hovered_demolish_building = target_b
		if hovered_demolish_building:
			var b_name: String = hovered_demolish_building.config.get("name", "Постройка")
			var status: String = "Снести готовую: " if hovered_demolish_building.is_constructed else "Отменить стройку: "
			hud.show_banner("ЛКМ — %s%s" % [status, b_name])
		return

	if terraforming_system and terraforming_system.is_active:
		terraforming_system.on_mouse_motion(pos)
		return

	if construction_system.is_placing():
		construction_system.on_drag_motion(pos, all_units)
		return

	if lumber_zone_system.is_placing_zone:
		lumber_zone_system.on_mouse_motion(pos)
		return

	if is_left_mouse_down:
		if not is_marquee_dragging and left_mouse_start.distance_to(pos) > 6.0:
			is_marquee_dragging = true
			hud.selection_box.start_box(left_mouse_start)

		if is_marquee_dragging:
			hud.selection_box.update_box(pos)

	# Hover checks for lumber zone badges
	lumber_zone_system.on_mouse_motion(pos)

func _handle_left_mouse_up(pos: Vector2) -> void:
	if terraforming_system and terraforming_system.is_active:
		terraforming_system.on_mouse_up(all_units)
		return

	if construction_system.is_placing():
		if construction_system.is_drag_building:
			construction_system.finish_drag_placement(all_units)
		return
	if lumber_zone_system.is_placing_zone:
		lumber_zone_system.on_mouse_up(all_units)
		if lumber_zone_system.selected_zone:
			hud.floating_badge.show_for_lumber_zone(
				lumber_zone_system.selected_zone.icon_badge,
				lumber_zone_system.selected_zone.assigned_workers.size(),
				lumber_zone_system.selected_zone.max_workers,
				camera
			)
		return

	if is_marquee_dragging:
		is_marquee_dragging = false
		hud.selection_box.stop_box()
		selection_system.select_units_in_box(left_mouse_start, pos, all_units)
		hud.floating_badge.hide_badge()
	elif is_left_mouse_down:
		# Single click selection
		_handle_single_click(pos)

	is_left_mouse_down = false

func _handle_single_click(pos: Vector2) -> void:
	if hud.skin and hud.skin.command_mode!="":
		_handle_right_mouse_down(pos);hud.skin.command_mode="";return
	# Check if clicked on a Lumber Zone badge
	for z in lumber_zone_system.zones:
		var badge_screen: Vector2 = camera.unproject_position(z.icon_badge.global_position)
		if pos.distance_to(badge_screen) < 32.0:
			lumber_zone_system.select_zone(z)
			hud.floating_badge.show_for_lumber_zone(
				z.icon_badge,
				z.assigned_workers.size(),
				z.max_workers,
				camera
			)
			selection_system.clear_selection()
			return

	var hit: Dictionary = camera.raycast_objects(pos)
	var collider: Object = hit.get("collider", null)

	if collider is Unit:
		selection_system.select_single_unit(collider, Input.is_key_pressed(KEY_SHIFT))
		lumber_zone_system.deselect_zone()
		hud.floating_badge.hide_badge()
		if collider.unit_type == UnitConfigs.UnitType.ZOMBIE:
			SoundManager.play_zombie(collider.global_position)
	elif collider is Building:
		selection_system.select_building(collider)
		lumber_zone_system.deselect_zone()
		if collider.building_type == BuildingConfigs.BuildingType.MINE and collider.is_constructed and collider.faction=="player":
			hud.floating_badge.show_for_mine(collider, collider.assigned_miners.size(), collider.max_miners, camera)
			SoundManager.play_ore_pick(collider.global_position)
		elif collider.building_type == BuildingConfigs.BuildingType.FARM:
			SoundManager.play_eat_apple()
		else:
			hud.floating_badge.hide_badge()
	elif collider and collider.get_parent() is Building:
		var b: Building = collider.get_parent()
		selection_system.select_building(b)
		lumber_zone_system.deselect_zone()
		if b.building_type == BuildingConfigs.BuildingType.MINE and b.is_constructed and b.faction=="player":
			hud.floating_badge.show_for_mine(b, b.assigned_miners.size(), b.max_miners, camera)
			SoundManager.play_ore_pick(b.global_position)
		elif b.building_type == BuildingConfigs.BuildingType.FARM:
			SoundManager.play_eat_apple()
		else:
			hud.floating_badge.hide_badge()
	else:
		selection_system.clear_selection()
		lumber_zone_system.deselect_zone()
		hud.floating_badge.hide_badge()

func _handle_right_mouse_down(pos: Vector2) -> void:
	if is_demolish_mode:
		set_demolish_mode(false)
		return

	if terraforming_system and terraforming_system.is_active:
		terraforming_system.cancel_or_exit()
		return

	var hit: Dictionary = camera.raycast_objects(pos)
	var collider: Object = hit.get("collider", null)
	var ground_p: Vector3 = camera.raycast_ground(pos)

	if network_session and not NetworkManager.applying_command:
		if construction_system.is_placing():construction_system.cancel_placement();return
		if lumber_zone_system.is_placing_zone:lumber_zone_system.cancel_zone_placement();return
		var mode: String="underground" if underground_system.cutaway else hud.skin.command_mode
		network_session.context(ground_p,collider,mode)
		hud.skin.command_mode="";interaction_feedback.show_order(ground_p);return

	if hud.skin and hud.skin.command_mode == "patrol":
		var any_dispatched: bool = false
		for u in selection_system.selected_units:
			if is_instance_valid(u) and u.is_alive and u.faction == "player":
				selection_system.cancel_assignments(u)
				u.patrol_start = u.global_position
				u.patrol_end = ground_p
				u.patrol_to_end = true
				u.patrol_wait_timer = 0.0
				u.current_order = UnitConfigs.UnitOrder.PATROL
				u.target = null
				var path: Array[Vector3] = grid_manager.find_unit_path(u, ground_p, true)
				u.set_path(path)
				u.state = UnitConfigs.UnitState.MOVING
				any_dispatched = true
		hud.skin.command_mode = ""
		if any_dispatched:
			interaction_feedback.show_order(ground_p)
			SoundManager.play_click()
			hud.show_banner("Патрулирование начато")
		return

	# 1. Right-click on an unbuilt ghost building with workers selected dispatches workers to build it (NEVER delete on RMB!)
	var unbuilt_b: Building = null
	if collider is Building and not collider.is_constructed and collider.faction == "player":
		unbuilt_b = collider
	elif collider and collider.get_parent() is Building and not collider.get_parent().is_constructed and collider.get_parent().faction == "player":
		unbuilt_b = collider.get_parent()

	if unbuilt_b:
		var any_worker_dispatched: bool = false
		for u in selection_system.selected_units:
			if is_instance_valid(u) and u.is_alive and u.faction == "player" and UnitConfigs.is_worker(u.unit_type):
				selection_system.cancel_assignments(u)
				u.target = unbuilt_b
				u.current_order = UnitConfigs.UnitOrder.BUILD
				var path: Array[Vector3] = grid_manager.find_path(u.global_position, unbuilt_b.global_position)
				u.set_path(path)
				u.state = UnitConfigs.UnitState.MOVING
				any_worker_dispatched = true
		if any_worker_dispatched:
			interaction_feedback.show_order(unbuilt_b.global_position)
			SoundManager.play_click()
			hud.show_banner("Рабочие отправлены строить")
			return

	if construction_system.is_placing():
		construction_system.cancel_placement()
		return

	if lumber_zone_system.is_placing_zone:
		lumber_zone_system.cancel_zone_placement()
		return

	# 2. Right-click on ground with a production building selected sets rally point
	if selection_system.selected_units.is_empty() and is_instance_valid(selection_system.selected_building) and not underground_system.cutaway:
		var sb: Building = selection_system.selected_building
		if sb.faction == "player" and sb.is_constructed:
			if production_system.set_rally(sb, ground_p):
				interaction_feedback.show_order(ground_p)
				return
	if underground_system.cutaway:
		if collider and collider.has_meta("poi_type") and collider.get_meta("poi_type") == "cave_exit":
			for unit in selection_system.selected_units:
				if is_instance_valid(unit) and unit.is_alive and unit.underground_unit:
					underground_system.request_exit(unit)
			interaction_feedback.show_order(ground_p)
			SoundManager.play_click()
			return
		elif collider is Unit and collider.faction != "player" and collider.visible:
			selection_system._issue_attack_order(collider)
		else:
			var click_cell: Vector2i = Vector2i(floori(ground_p.x), floori(ground_p.z))
			var clicked_exit: bool = false
			for cave in underground_system.caves:
				if (click_cell - cave.entry).length_squared() <= 2:
					clicked_exit = true
					break
			if clicked_exit:
				for unit in selection_system.selected_units:
					if is_instance_valid(unit) and unit.is_alive and unit.underground_unit:
						underground_system.request_exit(unit)
				interaction_feedback.show_order(ground_p)
				SoundManager.play_click()
				return

			for unit in selection_system.selected_units:
				underground_system.issue_order(unit, click_cell)
	else:
		selection_system.handle_right_click(hit, ground_p)
	interaction_feedback.show_order(ground_p)

func _process(delta: float) -> void:

	simulation_accumulator+=delta
	if simulation_accumulator<.05:return
	delta=simulation_accumulator;simulation_accumulator=0.0
	# Tick systems
	if workshop_system:workshop_system.tick(delta)
	if production_system:production_system.tick(delta)
	if transport_system:transport_system.tick(delta)
	all_buildings = all_buildings.filter(func(b): return is_instance_valid(b) and b.is_alive)
	for b in all_buildings:
		if is_instance_valid(b.rally_marker):
			b.rally_marker.visible=(b==selection_system.selected_building and not underground_system.cutaway)
		if b.is_gate and b.is_constructed:
			b.tick_gate(delta, all_units, grid_manager)
	if farming_system:
		farming_system.tick(delta, all_buildings)
	var gathering_start: int = Time.get_ticks_usec()
	gathering_system.process_gathering(delta, all_units)
	last_system_usec["gathering"] = Time.get_ticks_usec()-gathering_start
	var lumber_start: int = Time.get_ticks_usec()
	lumber_zone_system.process_lumber_zones(delta)
	last_system_usec["lumber"] = Time.get_ticks_usec()-lumber_start
	if terraforming_system:
		terraforming_system.tick(delta, all_units)
	var combat_start: int = Time.get_ticks_usec()
	combat_system.process_combat(delta, all_units, all_buildings)
	last_system_usec["combat"] = Time.get_ticks_usec()-combat_start
	var fog_start: int = Time.get_ticks_usec()
	fog_system.update_fog(all_units, all_buildings, delta)
	last_system_usec["fog"] = Time.get_ticks_usec()-fog_start

	# Update UI
	hud.update_time_display(time_of_day_system.current_day, time_of_day_system.get_formatted_time())
	hud.update_raid_display(raid_system, time_of_day_system)
	hud.minimap.update_entities(all_units, all_buildings)
