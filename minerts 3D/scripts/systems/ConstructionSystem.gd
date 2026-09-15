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

	SoundManager.play_build()
	EventBus.building_placed.emit(building)

	# Dispatch any nearby idle worker to construct
	_dispatch_builder(building, all_player_units)

	# If shift not pressed and keep_placing not requested, finish placement
	if not keep_placing and not Input.is_key_pressed(KEY_SHIFT):
		cancel_placement()

	return true

func start_drag_placement(all_player_units: Array[Unit]) -> void:
	if not is_placing():
		return
	if active_building_type == BuildingConfigs.BuildingType.WALL:
		is_drag_building = true
		if try_place(all_player_units, true):
			last_placed_cell = Vector2i(current_grid_x, current_grid_z)
	else:
		try_place(all_player_units, false)

func on_drag_motion(mouse_screen_pos: Vector2, all_player_units: Array[Unit]) -> void:
	if not is_placing():
		return
	update_ghost(mouse_screen_pos)
	if not is_drag_building or active_building_type != BuildingConfigs.BuildingType.WALL:
		return

	var curr_cell: Vector2i = Vector2i(current_grid_x, current_grid_z)
	if curr_cell == last_placed_cell:
		return

	var cfg: Dictionary = BuildingConfigs.get_config(active_building_type)
	var cost: Dictionary = cfg.get("cost", {})
	if not EconomyManager.can_afford(cost):
		is_drag_building = false
		return

	var line: Array[Vector2i] = _get_line_cells(last_placed_cell, curr_cell)
	for cell in line:
		if cell == last_placed_cell:
			continue
		current_grid_x = cell.x
		current_grid_z = cell.y
		var fp: Vector2i = get_current_footprint()
		var can_build: bool = grid_manager.is_area_buildable(current_grid_x, current_grid_z, fp.x, fp.y)
		var unit_blocked: bool = false
		for unit in all_player_units:
			if unit.is_alive and not unit.underground_unit and Rect2(current_grid_x, current_grid_z, fp.x, fp.y).has_point(Vector2(unit.position.x, unit.position.z)):
				unit_blocked = true
				break
		if can_build and not unit_blocked and EconomyManager.can_afford(cost):
			is_valid_placement = true
			if try_place(all_player_units, true):
				last_placed_cell = cell
		elif not EconomyManager.can_afford(cost):
			is_drag_building = false
			break

	# Restore ghost to current mouse position
	update_ghost(mouse_screen_pos)

func finish_drag_placement() -> void:
	is_drag_building = false
	last_placed_cell = Vector2i(-9999, -9999)
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

func _dispatch_builder(b: Building, all_player_units: Array[Unit]) -> void:
	var closest_worker: Unit = null
	var min_dist: float = 9999.0
	var best_path: Array[Vector3] = []

	for u in all_player_units:
		if is_instance_valid(u) and u.is_alive and u.faction == "player" and u.unit_type == UnitConfigs.UnitType.WORKER:
			if u.state == UnitConfigs.UnitState.IDLE and not u.underground_unit and u.assigned_lumber_zone_id == "" and u.mining_building_id == "":
				var d: float = u.global_position.distance_to(b.global_position)
				if d < min_dist:
					var candidate_path: Array[Vector3] = grid_manager.find_path(u.global_position, b.global_position)
					if not candidate_path.is_empty():
						min_dist = d
						closest_worker = u
						best_path = candidate_path

	if closest_worker:
		closest_worker.current_order = UnitConfigs.UnitOrder.BUILD
		closest_worker.target = b
		closest_worker.set_path(best_path)
		closest_worker.state = UnitConfigs.UnitState.MOVING

func _apply_ghost_material(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_ghost_material(child, mat)
