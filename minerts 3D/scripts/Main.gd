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

var all_units: Array[Unit] = []
var all_buildings: Array[Building] = []
var guardian_system: GuardianSystem
var simulation_accumulator: float = 0.0
var last_system_usec: Dictionary = {}
var prop_batches: WorldPropBatches
var unit_visuals: UnitVisualSystem

# Input state
var is_left_mouse_down: bool = false
var left_mouse_start: Vector2 = Vector2.ZERO
var is_marquee_dragging: bool = false

func _ready() -> void:
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
	guardian_system=GuardianSystem.new();add_child(guardian_system);guardian_system.setup(self)
	fog_system.update_fog(all_units, all_buildings, 0.3)
	unit_visuals=UnitVisualSystem.new();add_child(unit_visuals);unit_visuals.setup(self)

func _init_core_world() -> void:
	# 1. Grid Manager
	grid_manager = GridManager.new()
	add_child(grid_manager)

	# 2. Terrain Generator
	terrain_generator = TerrainGenerator.new()
	world_container.add_child(terrain_generator)
	terrain_generator.generate_terrain(grid_manager)

	# 3. Resource Spawner
	resource_spawner = ResourceSpawner.new()
	world_container.add_child(resource_spawner)
	resource_spawner.spawn_world_resources(grid_manager, world_container)
	var environment_details: EnvironmentDetails = EnvironmentDetails.new()
	world_container.add_child(environment_details)
	environment_details.populate(grid_manager)
	grid_manager.rebuild_astar()

	# 5. Camera terrain tracking
	camera.set_terrain(terrain_generator)
	camera.target_focus = Vector3(96.0, terrain_generator.get_height_at(96.0, 96.0), 96.0)

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
	gathering_system.init_gathering(grid_manager, resource_spawner)

	# Lumber Zones
	lumber_zone_system = LumberZoneSystem.new()
	add_child(lumber_zone_system)
	lumber_zone_system.init_lumber_zones(camera, grid_manager, resource_spawner, zones_container)

	# Combat
	combat_system = CombatSystem.new()
	add_child(combat_system)
	combat_system.init_combat(grid_manager, projectiles_container)

	# Raids
	raid_system = RaidSystem.new()
	add_child(raid_system)
	raid_system.init_raid(grid_manager, units_container, world_container)

	# Time of Day
	time_of_day_system = TimeOfDaySystem.new()
	add_child(time_of_day_system)
	time_of_day_system.init_lighting(sun_light, world_environment)

	# Fog of War
	fog_system = FogOfWarSystem.new()
	add_child(fog_system)
	fog_system.init_fog(grid_manager)
	fog_system.apply_world_materials(world_container)
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
	# Spawn central Campfire at (96, 96)
	var camp: Building = Building.new()
	buildings_container.add_child(camp)
	var camp_y: float = grid_manager.get_height(96.5, 96.5)
	camp.global_position = Vector3(97.0, camp_y, 97.0)
	camp.init_building(BuildingConfigs.BuildingType.CAMPFIRE, 96, 96, true)
	grid_manager.occupy_area(96, 96, 2, 2, camp)
	all_buildings.append(camp)
	gathering_system.register_storage(camp)
	EventBus.building_constructed.emit(camp)

	# Spawn 3 starting Workers
	var worker_offsets: Array[Vector3] = [
		Vector3(94.5, 0, 95.5),
		Vector3(98.5, 0, 95.5),
		Vector3(96.5, 0, 98.5)
	]
	for pos in worker_offsets:
		spawn_unit(UnitConfigs.UnitType.WORKER, "player", pos)

	# Spawn starting Knight Warrior defender
	spawn_unit(UnitConfigs.UnitType.WARRIOR, "player", Vector3(96.5, 0, 93.5))

	# Spawn starting Archer Marksman defender
	spawn_unit(UnitConfigs.UnitType.ARCHER, "player", Vector3(98.5, 0, 93.5))

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
		# Clear from lumber zones if assigned
		for z in lumber_zone_system.zones:
			z.assigned_workers.erase(e)
		var valid_buildings: Array[Building] = []
		for b in all_buildings:
			if is_instance_valid(b):
				valid_buildings.append(b)
				if "assigned_miners" in b and b.assigned_miners is Array:
					b.assigned_miners.erase(e)
		all_buildings = valid_buildings
	elif e is Building:
		e.training_queue.clear()
		if is_instance_valid(e.rally_marker):e.rally_marker.queue_free()
		e.eject_all_miners(grid_manager)
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
		lumber_zone_system.cancel_zone_placement()
		construction_system.start_placement(type)
		if type == BuildingConfigs.BuildingType.WALL:
			hud.show_banner("Забор: Зажмите ЛКМ для непрерывной постройки | [R]: Поворот на 90° | ПКМ: Отмена")
		else:
			hud.show_banner("ЛКМ: Разместить | [R]: Поворот на 90° | ПКМ: Отмена")
	)

	hud.lumber_zone_tool_requested.connect(func():
		if underground_system and underground_system.cutaway: return
		construction_system.cancel_placement()
		lumber_zone_system.start_zone_placement()
	)

	hud.minimap.map_clicked.connect(func(w_pos):
		camera.target_focus = w_pos
	)

	hud.cancel_training_requested.connect(func():
		if is_instance_valid(selection_system.selected_building) and selection_system.selected_building.faction=="player":production_system.cancel(selection_system.selected_building)
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

func _handle_mine_minus(b: Building) -> void:
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
	else:SoundManager.play_select()

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
			if key_event.keycode == KEY_O:
				if selection_system.selected_building and selection_system.selected_building.is_gate:
					selection_system.selected_building.toggle_gate(grid_manager)
					hud._on_selection_changed(selection_system.selected_units, selection_system.selected_building)
			elif key_event.keycode == KEY_ESCAPE:
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
	if construction_system.is_placing():
		if construction_system.is_drag_building:
			construction_system.finish_drag_placement()
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
	elif collider is Building:
		selection_system.select_building(collider)
		lumber_zone_system.deselect_zone()
		if collider.building_type == BuildingConfigs.BuildingType.MINE and collider.is_constructed and collider.faction=="player":
			hud.floating_badge.show_for_mine(collider, collider.assigned_miners.size(), collider.max_miners, camera)
		else:
			hud.floating_badge.hide_badge()
	elif collider and collider.get_parent() is Building:
		var b: Building = collider.get_parent()
		selection_system.select_building(b)
		lumber_zone_system.deselect_zone()
		if b.building_type == BuildingConfigs.BuildingType.MINE and b.is_constructed and b.faction=="player":
			hud.floating_badge.show_for_mine(b, b.assigned_miners.size(), b.max_miners, camera)
		else:
			hud.floating_badge.hide_badge()
	else:
		selection_system.clear_selection()
		lumber_zone_system.deselect_zone()
		hud.floating_badge.hide_badge()

func _handle_right_mouse_down(pos: Vector2) -> void:
	if construction_system.is_placing():
		construction_system.cancel_placement()
		return

	if lumber_zone_system.is_placing_zone:
		lumber_zone_system.cancel_zone_placement()
		return

	var hit: Dictionary = camera.raycast_objects(pos)
	var ground_p: Vector3 = camera.raycast_ground(pos)
	if selection_system.selected_units.is_empty() and is_instance_valid(selection_system.selected_building) and not underground_system.cutaway:
		if production_system.set_rally(selection_system.selected_building,ground_p):interaction_feedback.show_order(ground_p)
		return
	if underground_system.cutaway:
		var collider: Node = hit.get("collider")
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
	if production_system:production_system.tick(delta)
	if transport_system:transport_system.tick(delta)
	for b in all_buildings:
		if is_instance_valid(b) and is_instance_valid(b.rally_marker):b.rally_marker.visible=(b==selection_system.selected_building and not underground_system.cutaway)
	if farming_system:
		farming_system.tick(delta, all_buildings)
	var gathering_start: int = Time.get_ticks_usec()
	gathering_system.process_gathering(delta, all_units)
	last_system_usec["gathering"] = Time.get_ticks_usec()-gathering_start
	var lumber_start: int = Time.get_ticks_usec()
	lumber_zone_system.process_lumber_zones(delta)
	last_system_usec["lumber"] = Time.get_ticks_usec()-lumber_start
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
