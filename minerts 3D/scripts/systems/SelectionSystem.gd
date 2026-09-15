class_name SelectionSystem
extends Node

var camera: RTSCamera
var grid_manager: GridManager
var resource_spawner: ResourceSpawner = null

var selected_units: Array[Unit] = []
var selected_building: Building = null
var control_groups: Dictionary = {} # int -> Array[Unit]

var is_box_selecting: bool = false
var box_start_pos: Vector2 = Vector2.ZERO
var box_current_pos: Vector2 = Vector2.ZERO

var last_click_time: float = 0.0
var last_clicked_unit: Unit = null

# Callback references to other systems if needed
var lumber_zone_system: Node = null

func init_selection(cam: RTSCamera, grid_mgr: GridManager, spawner: ResourceSpawner = null) -> void:
	camera = cam
	grid_manager = grid_mgr
	resource_spawner = spawner

func clear_selection() -> void:
	for u in selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	selected_units.clear()

	if selected_building:
		# If there's building visual indicator, clear it
		selected_building = null

	EventBus.selection_changed.emit(selected_units, selected_building)

func select_single_unit(unit: Unit, add_to_selection: bool = false) -> void:
	if not add_to_selection:
		clear_selection()

	if is_instance_valid(unit) and unit.is_alive and unit.visible and unit.faction == "player" and unit.state != UnitConfigs.UnitState.MINING_INSIDE and not selected_units.has(unit):
		selected_units.append(unit)
		unit.set_selected(true)

	SoundManager.play_select()
	EventBus.selection_changed.emit(selected_units, selected_building)

func select_units_in_box(start_screen: Vector2, end_screen: Vector2, all_player_units: Array[Unit]) -> void:
	clear_selection()
	var rect: Rect2 = Rect2(
		minf(start_screen.x, end_screen.x),
		minf(start_screen.y, end_screen.y),
		absf(end_screen.x - start_screen.x),
		absf(end_screen.y - start_screen.y)
	)

	for u in all_player_units:
		if not is_instance_valid(u) or not u.is_alive or u.faction != "player":
			continue
		if u.state == UnitConfigs.UnitState.MINING_INSIDE or not u.visible:
			continue
		var screen_pos: Vector2 = camera.unproject_position(u.global_position)
		if rect.has_point(screen_pos):
			selected_units.append(u)
			u.set_selected(true)

	if not selected_units.is_empty():
		SoundManager.play_select()
	EventBus.selection_changed.emit(selected_units, selected_building)

func select_all_of_type(type: UnitConfigs.UnitType, all_player_units: Array[Unit]) -> void:
	clear_selection()
	for u in all_player_units:
		if is_instance_valid(u) and u.is_alive and u.faction == "player" and u.unit_type == type:
			if u.state != UnitConfigs.UnitState.MINING_INSIDE and u.visible:
				selected_units.append(u)
				u.set_selected(true)

	if not selected_units.is_empty():
		SoundManager.play_select()
	EventBus.selection_changed.emit(selected_units, selected_building)

func select_building(b: Building) -> void:
	clear_selection()
	selected_building = b
	SoundManager.play_select()
	EventBus.selection_changed.emit(selected_units, selected_building)

func set_control_group(group_idx: int) -> void:
	var valid_units: Array[Unit] = []
	for u in selected_units:
		if is_instance_valid(u) and u.is_alive:
			valid_units.append(u)
	control_groups[group_idx] = valid_units

func select_control_group(group_idx: int) -> void:
	if not control_groups.has(group_idx):
		return
	clear_selection()
	var group: Array = control_groups[group_idx]
	for u in group:
		if is_instance_valid(u) and u.is_alive:
			selected_units.append(u)
			u.set_selected(true)
	if not selected_units.is_empty():
		SoundManager.play_select()
	EventBus.selection_changed.emit(selected_units, selected_building)

func handle_right_click(hit_result: Dictionary, ground_pos: Vector3) -> void:
	if selected_units.is_empty():
		return

	var collider: Object = hit_result.get("collider", null)
	if collider is Node3D:
		if not collider.is_visible_in_tree():
			return
		if collider.global_position.y >= -1.0 and (collider is Entity or collider.has_meta("resource_type") or collider.has_meta("poi_type")):
			var tile: Tile = grid_manager.get_tile(floori(collider.position.x), floori(collider.position.z))
			if tile == null or not tile.is_visible:
				return

	# 1. Target Building
	if collider is Building or (collider and collider.get_parent() is Building):
		var target_b: Building = collider if collider is Building else collider.get_parent()
		if is_instance_valid(target_b) and target_b.is_alive:
			_handle_building_target(target_b)
			return

	# 2. Target Entity / Unit
	if collider is Entity or (collider and collider.get_parent() is Entity):
		var target_e: Entity = collider if collider is Entity else collider.get_parent()
		if is_instance_valid(target_e) and target_e.is_alive:
			if target_e is Unit and UnitConfigs.is_vessel(target_e.unit_type) and target_e.faction=="player":
				for u in selected_units.duplicate():grid_manager.transport.board(u,target_e)
				return
			if target_e.faction in ["enemy","neutral","predator","goblin"]:
				_issue_attack_order(target_e)
				return

	# 3. Target Resource (Tree/Bush via collider or its parent)
	if collider and (collider.has_meta("resource_type") or (collider.get_parent() and collider.get_parent().has_meta("resource_type"))):
		var res_node: Node = collider if collider.has_meta("resource_type") else collider.get_parent()
		_issue_gather_order(res_node)
		return

	# 4. Target POI (Chest)
	if collider and (collider.has_meta("poi_type") or (collider.get_parent() and collider.get_parent().has_meta("poi_type"))):
		var poi_node: Node = collider if collider.has_meta("poi_type") else collider.get_parent()
		_issue_poi_order(poi_node)
		return

	# 5. Check Ground Tile for resource or POI
	var gx: int = int(floor(ground_pos.x))
	var gz: int = int(floor(ground_pos.z))
	var tile: Tile = grid_manager.get_tile(gx, gz)
	if tile and tile.is_visible and tile.resource_id != "":
		if resource_spawner and resource_spawner.resources.has(tile.resource_id):
			_issue_gather_order(resource_spawner.resources[tile.resource_id])
			return
		elif resource_spawner and resource_spawner.pois.has(tile.resource_id):
			_issue_poi_order(resource_spawner.pois[tile.resource_id])
			return

	# 6. Otherwise ground move order
	_issue_move_order(ground_pos)

func _handle_building_target(b: Building) -> void:
	if b.faction!="player":
		_issue_attack_order(b)
		return
	if not b.is_constructed:
		# Build order for workers
		for u in selected_units:
			if u.unit_type == UnitConfigs.UnitType.WORKER:
				cancel_assignments(u)
				u.current_order = UnitConfigs.UnitOrder.BUILD
				u.state = UnitConfigs.UnitState.MOVING
				u.target = b
				var path: Array[Vector3] = grid_manager.find_path(u.global_position, b.global_position)
				u.set_path(path)
		SoundManager.play_click()
	elif b.is_gate:
		# Toggle gate
		b.toggle_gate(grid_manager)
		SoundManager.play_click()
	elif b.building_type == BuildingConfigs.BuildingType.MINE:
		# Send workers to garrison
		for u in selected_units:
			if u.unit_type == UnitConfigs.UnitType.WORKER and b.assigned_miners.size() < b.max_miners:
				if not b.assigned_miners.has(u):
					cancel_assignments(u)
					b.assigned_miners.append(u)
					u.target = b
					u.mining_building_id = str(b.get_instance_id())
					u.current_order = UnitConfigs.UnitOrder.MOVE
					var path: Array[Vector3] = grid_manager.find_path(u.global_position, b.global_position)
					u.set_path(path)
					u.state = UnitConfigs.UnitState.MOVING
					EventBus.mine_miner_count_changed.emit(b, b.assigned_miners.size())
		SoundManager.play_click()
	else:
		_issue_move_order(b.global_position)

func cancel_assignments(u: Unit) -> void:
	u.route_version+=1
	if is_instance_valid(grid_manager.transport):grid_manager.transport.cancel_boarding(u)
	# Explicit commands replace persistent jobs as well as the current path.
	if is_instance_valid(grid_manager.underground):
		grid_manager.underground.jobs.erase(u.get_instance_id())
	if lumber_zone_system and u.assigned_lumber_zone_id != "":
		for zone in lumber_zone_system.zones:
			if zone.assigned_workers.has(u):
				zone.assigned_workers.erase(u)
				EventBus.lumber_zone_workers_changed.emit(zone, zone.assigned_workers.size())
	u.assigned_lumber_zone_id = ""
	if u.mining_building_id != "":
		var mine: Object = instance_from_id(int(u.mining_building_id))
		if is_instance_valid(mine) and mine is Building:
			mine.assigned_miners.erase(u)
			EventBus.mine_miner_count_changed.emit(mine, mine.assigned_miners.size())
	u.mining_building_id = ""
	if u.state == UnitConfigs.UnitState.MINING_INSIDE:
		u.visible = true
		u.collision_layer = 2
		u.collision_mask = 2 | 4
		u.state = UnitConfigs.UnitState.IDLE

func _issue_move_order(dest: Vector3) -> void:
	var formation: Array[Vector3] = grid_manager.get_formation_positions(dest, selected_units.size())
	var group: Array[Unit] = []
	var goals: Array[Vector3] = []
	for i in range(selected_units.size()):
		var u: Unit = selected_units[i]
		if not is_instance_valid(u) or not u.is_alive:
			continue
		cancel_assignments(u)
		if UnitConfigs.is_vessel(u.unit_type):
			grid_manager.transport.order_ship(u,dest)
			continue
		var target_pos: Vector3 = formation[i] if i < formation.size() else dest
		if selected_units.size()>=8 and not u.underground_unit:
			u.current_order=UnitConfigs.UnitOrder.MOVE;u.target=null;u.state=UnitConfigs.UnitState.MOVING
			group.append(u);goals.append(target_pos)
			continue
		var path: Array[Vector3] = grid_manager.find_path(u.global_position, target_pos)
		u.set_path(path)
		u.current_order = UnitConfigs.UnitOrder.MOVE
		u.state = UnitConfigs.UnitState.MOVING
		u.target = null
	if not group.is_empty():grid_manager.group_navigation.enqueue(group,goals)
	SoundManager.play_click()

func _issue_gather_order(res_node: Node) -> void:
	for u in selected_units:
		if not is_instance_valid(u) or not u.is_alive:
			continue
		if u.unit_type == UnitConfigs.UnitType.WORKER:
			cancel_assignments(u)
			u.current_order = UnitConfigs.UnitOrder.GATHER
			u.target = res_node
			var res_pos: Vector3 = res_node.global_position if "global_position" in res_node else Vector3.ZERO
			var path: Array[Vector3] = grid_manager.find_interaction_path(u,res_node,2.0)
			u.set_path(path)
			u.state = UnitConfigs.UnitState.MOVING
	SoundManager.play_click()

func _issue_attack_order(target_e: Node3D) -> void:
	for u in selected_units:
		if not is_instance_valid(u) or not u.is_alive:
			continue
		cancel_assignments(u)
		u.current_order = UnitConfigs.UnitOrder.ATTACK
		u.target = target_e
		var path: Array[Vector3] = grid_manager.find_interaction_path(u,target_e,u.attack_range)
		u.set_path(path)
		u.state = UnitConfigs.UnitState.MOVING
	SoundManager.play_attack()

func _issue_poi_order(poi_node: Node) -> void:
	for u in selected_units:
		if not is_instance_valid(u) or not u.is_alive:
			continue
		cancel_assignments(u)
		u.current_order = UnitConfigs.UnitOrder.INTERACT
		u.target = poi_node
		var poi_pos: Vector3 = poi_node.global_position if "global_position" in poi_node else Vector3.ZERO
		var path: Array[Vector3] = grid_manager.find_path(u.global_position, poi_pos)
		u.set_path(path)
		u.state = UnitConfigs.UnitState.MOVING
	SoundManager.play_click()

func remove_entity(entity: Node) -> void:
	var changed: bool = false
	if entity is Unit and selected_units.has(entity):
		selected_units.erase(entity)
		changed = true
	if selected_building == entity:
		selected_building = null
		changed = true
	for group in control_groups.values():
		group.erase(entity)
	if changed:
		EventBus.selection_changed.emit(selected_units, selected_building)
