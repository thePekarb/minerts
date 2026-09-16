class_name ConstructionSystem
extends Node

var camera: RTSCamera
var grid_manager: GridManager
var buildings_container: Node3D

var active_building_type: Variant = null # BuildingConfigs.BuildingType or null
var ghost_mesh_root: Node3D = null
var ghost_valid_mat: StandardMaterial3D
var ghost_invalid_mat: StandardMaterial3D

var rotation_degrees_y: int = 0 # 0, 90, 180, 270
var current_grid_x: int = -1
var current_grid_z: int = -1
var is_valid_placement: bool = false

# Continuous wall drag-building
var is_drag_building: bool = false
var last_placed_cell: Vector2i = Vector2i(-9999, -9999)
var wall_preview_ghosts: Array[Node3D] = []

# Array of all buildings currently in the game
var buildings: Array[Building] = []

func init_construction(cam: RTSCamera, grid_mgr: GridManager, container: Node3D) -> void:
	camera = cam
	grid_manager = grid_mgr
	buildings_container = container

	ghost_valid_mat = StandardMaterial3D.new()
	ghost_valid_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.6)
	ghost_valid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_valid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	ghost_invalid_mat = StandardMaterial3D.new()
	ghost_invalid_mat.albedo_color = Color(0.9, 0.2, 0.2, 0.6)
	ghost_invalid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_invalid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func start_placement(type: BuildingConfigs.BuildingType) -> void:
	cancel_placement()
	active_building_type = type

	ghost_mesh_root = VoxelMeshFactory.create_building_mesh(type)
	ghost_mesh_root.rotation.y = deg_to_rad(rotation_degrees_y)
	_apply_ghost_material(ghost_mesh_root, ghost_valid_mat)
	add_child(ghost_mesh_root)

func cancel_placement() -> void:
	is_drag_building = false
	last_placed_cell = Vector2i(-9999, -9999)
	if ghost_mesh_root:
		ghost_mesh_root.queue_free()
		ghost_mesh_root = null
	active_building_type = null

func is_placing() -> bool:
	return active_building_type != null

func rotate_90() -> void:
	if not is_placing():
		return
	rotation_degrees_y = (rotation_degrees_y + 90) % 360
	if ghost_mesh_root:
		ghost_mesh_root.rotation.y = deg_to_rad(rotation_degrees_y)
	if camera and camera.get_viewport():
		update_ghost(camera.get_viewport().get_mouse_position())
	SoundManager.play_click()

func get_current_footprint() -> Vector2i:
	if active_building_type == null:
		return Vector2i.ONE
	var cfg: Dictionary = BuildingConfigs.get_config(active_building_type)
	var base_fp: Vector2i = cfg.get("footprint", Vector2i(1, 1))
	if rotation_degrees_y in [90, 270]:
		return Vector2i(base_fp.y, base_fp.x)
	return base_fp

func update_ghost(mouse_screen_pos: Vector2) -> void:
	if active_building_type == null or not ghost_mesh_root:
		return

	var ground_pos: Vector3 = camera.raycast_ground(mouse_screen_pos)
	var gx: int = int(floor(ground_pos.x))
	var gz: int = int(floor(ground_pos.z))

	current_grid_x = gx
	current_grid_z = gz

	var fp: Vector2i = get_current_footprint()

	var center_x: float = float(gx) + float(fp.x) * 0.5
	var center_z: float = float(gz) + float(fp.y) * 0.5
	var center_y: float = grid_manager.get_height(center_x, center_z)

	ghost_mesh_root.global_position = Vector3(center_x, center_y, center_z)
	ghost_mesh_root.rotation.y = deg_to_rad(rotation_degrees_y)

	# Check placement validity
	var cfg: Dictionary = BuildingConfigs.get_config(active_building_type)
	var can_afford: bool = EconomyManager.can_afford(cfg.get("cost", {}))
	var space_free: bool = grid_manager.is_area_buildable(gx, gz, fp.x, fp.y)

	if active_building_type==BuildingConfigs.BuildingType.PORT:
		space_free=space_free and grid_manager.is_coastal_site(gx,gz,fp.x,fp.y)
	is_valid_placement = can_afford and space_free

	_apply_ghost_material(ghost_mesh_root, ghost_valid_mat if is_valid_placement else ghost_invalid_mat)

func try_place(all_player_units: Array[Unit], keep_placing: bool = false) -> bool:
	if not is_placing() or not is_valid_placement:
		return false

	var cfg: Dictionary = BuildingConfigs.get_config(active_building_type)
	var fp: Vector2i = get_current_footprint()
	if not grid_manager.is_area_buildable(current_grid_x, current_grid_z, fp.x, fp.y):
		return false
	if active_building_type==BuildingConfigs.BuildingType.PORT and not grid_manager.is_coastal_site(current_grid_x,current_grid_z,fp.x,fp.y):return false
	for unit in all_player_units:
		if unit.is_alive and not unit.underground_unit and Rect2(current_grid_x, current_grid_z, fp.x, fp.y).has_point(Vector2(unit.position.x, unit.position.z)):
			return false
	if NetworkManager.in_match and not NetworkManager.applying_command and is_instance_valid(NetworkManager.session):
		NetworkManager.session.send("place",{"type":int(active_building_type),"cell":Vector2i(current_grid_x,current_grid_z),"rotation":rotation_degrees_y})
		if not keep_placing:cancel_placement()
		return true
	if not EconomyManager.spend_resources(cfg.get("cost", {})):
		return false

	var center_x: float = float(current_grid_x) + float(fp.x) * 0.5
	var center_z: float = float(current_grid_z) + float(fp.y) * 0.5
	var center_y: float = grid_manager.get_height(center_x, center_z)

	var building: Building = Building.new()
	buildings_container.add_child(building)
	building.global_position = Vector3(center_x, center_y, center_z)
	building.rotation.y = deg_to_rad(rotation_degrees_y)
	building.init_building(active_building_type, current_grid_x, current_grid_z, false, rotation_degrees_y, fp)
	buildings.append(building)

	# Mark tiles
	var is_gate: bool = (active_building_type == BuildingConfigs.BuildingType.GATE)
	grid_manager.occupy_area(current_grid_x, current_grid_z, fp.x, fp.y, building, is_gate)

	SoundManager.play_build(building.global_position)
	EventBus.building_placed.emit(building)

	# Dispatch any nearby idle worker to construct
	dispatch_idle_workers_to_queue(all_player_units)

	# If shift not pressed and keep_placing not requested, finish placement
	if not keep_placing and not Input.is_key_pressed(KEY_SHIFT):
		cancel_placement()

	return true

func demolish_building(b: Building, all_player_units: Array[Unit], refund_ratio: float = 0.75) -> bool:
	if NetworkManager.route_building("demolish",b):return true
	if not is_instance_valid(b) or not FactionRules.is_colony(b.faction):
		return false
	var cfg: Dictionary = BuildingConfigs.get_config(b.building_type)
	var cost: Dictionary = cfg.get("cost", {})
	var ratio: float = 1.0 if not b.is_constructed else refund_ratio
	var stock: Dictionary=b.stored_resources.duplicate()
	# Remove the old ledger contribution before moving stock elsewhere. Never refund
	# into the depot being demolished, and never count its contents a second time.
	b.is_alive=false
	if is_instance_valid(FactionEconomy.storage):FactionEconomy.storage._on_death(b)
	for res in stock:FactionEconomy.add(b.faction,res,stock[res])
	for res in cost:
		var amount: int=int(round(float(cost[res])*ratio))
		if amount>0:FactionEconomy.add(b.faction,res,amount)
	for res in b.output_buffer:FactionEconomy.add(b.faction,res,b.output_buffer[res])
	b.output_buffer.clear()
	for job in b.training_queue+b.crafting_queue:
		for res in job.cost:FactionEconomy.add(b.faction,res,job.cost[res])
	# Eject any garrisoned miners
	if b.has_method("eject_all_miners"):
		b.eject_all_miners(grid_manager)
	# Eject any garrisoned archer
	if "garrisoned_archer" in b and is_instance_valid(b.garrisoned_archer):
		b.ungarrison_archer()
	# Free rally marker
	if is_instance_valid(b.rally_marker):
		b.rally_marker.queue_free()
	# Clear training & crafting queues
	b.training_queue.clear()
	b.crafting_queue.clear()
	# Free grid cells
	grid_manager.free_area(b.grid_x, b.grid_z, b.footprint.x, b.footprint.y)
	# Detach workers targeting this building
	for u in all_player_units:
		if is_instance_valid(u) and u.target == b:
			u.target = null
			u.current_order = UnitConfigs.UnitOrder.MOVE
			u.state = UnitConfigs.UnitState.IDLE
	b.is_alive = false
	buildings.erase(b)
	if is_instance_valid(get_parent()) and "all_buildings" in get_parent() and get_parent().all_buildings is Array:
		get_parent().all_buildings.erase(b)
	EventBus.entity_died.emit(b)
	SoundManager.play_pop()
	b.queue_free()
	return true

func cancel_unbuilt_building(b: Building, all_player_units: Array[Unit]) -> bool:
	if not is_instance_valid(b) or b.faction != "player" or b.is_constructed:
		return false
	return demolish_building(b, all_player_units, 1.0)

func get_next_unbuilt_building(faction: String = "player") -> Building:
	var earliest_b: Building = null
	var min_id: int = 999999999
	for b in buildings:
		if is_instance_valid(b) and b.is_alive and not b.is_constructed and b.faction == faction:
			if b.placement_id < min_id:
				min_id = b.placement_id
				earliest_b = b
	return earliest_b

func dispatch_idle_workers_to_queue(all_player_units: Array[Unit]) -> void:
	var pending: Array[Building] = []
	for b in buildings:
		if is_instance_valid(b) and b.is_alive and not b.is_constructed and b.faction == "player":
			pending.append(b)
	if pending.is_empty():
		return
	pending.sort_custom(func(a, b): return a.placement_id < b.placement_id)

	for u in all_player_units:
		if is_instance_valid(u) and u.is_alive and u.faction == "player" and u.unit_type == UnitConfigs.UnitType.WORKER:
			if u.state == UnitConfigs.UnitState.IDLE and not u.underground_unit and u.assigned_lumber_zone_id == "" and u.mining_building_id == "":
				for b in pending:
					var path: Array[Vector3] = grid_manager.find_path(u.global_position, b.global_position)
					if not path.is_empty():
						u.current_order = UnitConfigs.UnitOrder.BUILD
						u.target = b
						u.set_path(path)
						u.state = UnitConfigs.UnitState.MOVING
						break

func start_drag_placement(all_player_units: Array[Unit]) -> void:
	if not is_placing():
		return
	if active_building_type == BuildingConfigs.BuildingType.WALL:
		is_drag_building = true
		last_placed_cell = Vector2i(current_grid_x, current_grid_z)
		_update_wall_preview_line(last_placed_cell, last_placed_cell, all_player_units)
	else:
		try_place(all_player_units, false)

func on_drag_motion(mouse_screen_pos: Vector2, all_player_units: Array[Unit]) -> void:
	if not is_placing():
		return
	update_ghost(mouse_screen_pos)
	if is_drag_building and active_building_type == BuildingConfigs.BuildingType.WALL:
		var curr_cell: Vector2i = Vector2i(current_grid_x, current_grid_z)
		_update_wall_preview_line(last_placed_cell, curr_cell, all_player_units)

func _clear_wall_previews() -> void:
	for g in wall_preview_ghosts:
		if is_instance_valid(g):
			g.queue_free()
	wall_preview_ghosts.clear()

func _update_wall_preview_line(p0: Vector2i, p1: Vector2i, all_player_units: Array[Unit]) -> void:
	if ghost_mesh_root:
		ghost_mesh_root.visible = false
	var line: Array[Vector2i] = _get_line_cells(p0, p1)

	while wall_preview_ghosts.size() < line.size():
		var new_g: Node3D = VoxelMeshFactory.create_building_mesh(BuildingConfigs.BuildingType.WALL)
		add_child(new_g)
		wall_preview_ghosts.append(new_g)

	var cfg_wall: Dictionary = BuildingConfigs.get_config(BuildingConfigs.BuildingType.WALL)
	var wood_cost_per_wall: int = cfg_wall.get("cost", {}).get("wood", 10)
	var avail_wood: int = EconomyManager.resources.get("wood", 0)
	for i in range(wall_preview_ghosts.size()):
		if i < line.size():
			var cell: Vector2i = line[i]
			var g: Node3D = wall_preview_ghosts[i]
			g.visible = true
			var wx: float = float(cell.x) + 0.5
			var wz: float = float(cell.y) + 0.5
			var wy: float = grid_manager.get_height(wx, wz)
			g.global_position = Vector3(wx, wy, wz)
			g.rotation.y = deg_to_rad(rotation_degrees_y)

			var can_build: bool = grid_manager.is_area_buildable(cell.x, cell.y, 1, 1)
			for b in buildings:
				if is_instance_valid(b) and b.is_alive and b.grid_x == cell.x and b.grid_z == cell.y:
					can_build = false
					break
			var unit_blocked: bool = false
			for u in all_player_units:
				if is_instance_valid(u) and u.is_alive and not u.underground_unit and floori(u.position.x) == cell.x and floori(u.position.z) == cell.y:
					unit_blocked = true
					break

			var needed_wood: int = (i + 1) * wood_cost_per_wall
			var can_afford: bool = (avail_wood >= needed_wood)
			var valid: bool = can_build and not unit_blocked and can_afford
			_apply_ghost_material(g, ghost_valid_mat if valid else ghost_invalid_mat)
		else:
			wall_preview_ghosts[i].visible = false

func finish_drag_placement(all_player_units: Array[Unit] = []) -> void:
	if is_drag_building and active_building_type == BuildingConfigs.BuildingType.WALL:
		var line: Array[Vector2i] = _get_line_cells(last_placed_cell, Vector2i(current_grid_x, current_grid_z))
		_clear_wall_previews()
		var placed_any: bool = false
		for cell in line:
			current_grid_x = cell.x
			current_grid_z = cell.y
			var fp: Vector2i = get_current_footprint()
			if grid_manager.is_area_buildable(cell.x, cell.y, fp.x, fp.y):
				var unit_blocked: bool = false
				for u in all_player_units:
					if is_instance_valid(u) and u.is_alive and not u.underground_unit and Rect2(cell.x, cell.y, fp.x, fp.y).has_point(Vector2(u.position.x, u.position.z)):
						unit_blocked = true
						break
				if not unit_blocked:
					var cfg: Dictionary = BuildingConfigs.get_config(active_building_type)
					if NetworkManager.in_match and not NetworkManager.applying_command:
						NetworkManager.session.send("place",{"type":int(active_building_type),"cell":cell,"rotation":rotation_degrees_y});placed_any=true;continue
					if EconomyManager.spend_resources(cfg.get("cost", {})):
						var center_x: float = float(cell.x) + float(fp.x) * 0.5
						var center_z: float = float(cell.y) + float(fp.y) * 0.5
						var center_y: float = grid_manager.get_height(center_x, center_z)
						var building: Building = Building.new()
						buildings_container.add_child(building)
						building.global_position = Vector3(center_x, center_y, center_z)
						building.rotation.y = deg_to_rad(rotation_degrees_y)
						building.init_building(active_building_type, cell.x, cell.y, false, rotation_degrees_y, fp)
						buildings.append(building)
						grid_manager.occupy_area(cell.x, cell.y, fp.x, fp.y, building, false)
						EventBus.building_placed.emit(building)
						placed_any = true

		is_drag_building = false
		last_placed_cell = Vector2i(-9999, -9999)
		if placed_any:
			SoundManager.play_build()
			dispatch_idle_workers_to_queue(all_player_units)

		if not Input.is_key_pressed(KEY_SHIFT):
			cancel_placement()
		else:
			if ghost_mesh_root:
				ghost_mesh_root.visible = true
	else:
		is_drag_building = false
		if not Input.is_key_pressed(KEY_SHIFT):
			cancel_placement()

func _get_line_cells(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if p0.x == -9999:
		cells.append(p1)
		return cells
	var dx: int = absi(p1.x - p0.x)
	var dz: int = absi(p1.y - p0.y)
	var sx: int = 1 if p0.x < p1.x else -1
	var sz: int = 1 if p0.y < p1.y else -1
	var err: int = dx - dz
	var curr: Vector2i = p0
	while true:
		cells.append(curr)
		if curr == p1:
			break
		var e2: int = 2 * err
		if e2 > -dz:
			err -= dz
			curr.x += sx
		if e2 < dx:
			err += dx
			curr.y += sz
	return cells

func _apply_ghost_material(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_ghost_material(child, mat)
