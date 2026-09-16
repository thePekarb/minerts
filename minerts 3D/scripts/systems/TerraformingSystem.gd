class_name TerraformingSystem
extends Node3D

var grid_manager: GridManager
var terrain_generator: TerrainGenerator
var camera: Camera3D
var resource_spawner: ResourceSpawner
var hud: Node

var is_active: bool = false
var is_dragging: bool = false
var drag_start_cell: Vector2i = Vector2i(-1, -1)
var current_hover_cell: Vector2i = Vector2i(-1, -1)

# Visual feedback
var hover_mesh: MeshInstance3D
var drag_preview_mesh: MeshInstance3D
var markers_container: Node3D

var hover_mat: StandardMaterial3D
var drag_mat: StandardMaterial3D
var marker_mat: StandardMaterial3D

# Excavation tasks
# Each task: {
#   "cell": Vector2i,
#   "target_height": int,
#   "worker": Unit,
#   "progress": float,
#   "dig_sound_timer": float,
#   "marker": MeshInstance3D
# }
var tasks: Array[Dictionary] = []
var worker_tasks: Dictionary = {} # worker instance id -> task Dictionary

const DIG_DURATION: float = 2.0

func init_system(gm: GridManager, tg: TerrainGenerator, cam: Camera3D, rs: ResourceSpawner = null, in_hud: Node = null) -> void:
	grid_manager = gm
	terrain_generator = tg
	camera = cam
	resource_spawner = rs
	hud = in_hud

	_setup_visuals()

func _setup_visuals() -> void:
	# Hover material (vivid yellow, semi-transparent, unshaded)
	hover_mat = StandardMaterial3D.new()
	hover_mat.albedo_color = Color(1.0, 0.92, 0.1, 0.45)
	hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Drag selection material (yellow tint, semi-transparent)
	drag_mat = StandardMaterial3D.new()
	drag_mat.albedo_color = Color(1.0, 0.88, 0.0, 0.35)
	drag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Queued excavation marker material
	marker_mat = StandardMaterial3D.new()
	marker_mat.albedo_color = Color(0.95, 0.75, 0.05, 0.3)
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Hover plane mesh
	hover_mesh = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(0.96, 0.96)
	hover_mesh.mesh = plane
	hover_mesh.material_override = hover_mat
	hover_mesh.visible = false
	add_child(hover_mesh)

	# Drag preview mesh
	drag_preview_mesh = MeshInstance3D.new()
	drag_preview_mesh.material_override = drag_mat
	drag_preview_mesh.visible = false
	add_child(drag_preview_mesh)

	# Container for queued markers
	markers_container = Node3D.new()
	markers_container.name = "ExcavationMarkers"
	add_child(markers_container)

func toggle_dig_mode() -> void:
	if is_active:
		deactivate()
	else:
		activate()

func activate() -> void:
	is_active = true
	is_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	if hud and hud.has_method("show_banner"):
		hud.show_banner("Режим раскопок [G]: выделите блоки [ЛКМ] для выкапывания")
	SoundManager.play_click()

func deactivate() -> void:
	is_active = false
	is_dragging = false
	if is_instance_valid(hover_mesh):
		hover_mesh.visible = false
	if is_instance_valid(drag_preview_mesh):
		drag_preview_mesh.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func cancel_or_exit() -> void:
	if is_dragging:
		is_dragging = false
		if is_instance_valid(drag_preview_mesh):
			drag_preview_mesh.visible = false
		if is_instance_valid(hover_mesh):
			hover_mesh.visible = false
	else:
		deactivate()

func is_tile_diggable(cell: Vector2i) -> bool:
	if not grid_manager:
		return false
	if cell.x < 0 or cell.x >= GridManager.GRID_SIZE or cell.y < 0 or cell.y >= GridManager.GRID_SIZE:
		return false
	var tile: Tile = grid_manager.get_tile(cell.x, cell.y)
	if not tile:
		return false
	if tile.building_id != "":
		return false
	if tile.biome == Tile.Biome.WATER:
		return false
	if tile.height <= 1:
		return false
	return true

func is_cell_queued(cell: Vector2i) -> bool:
	for t in tasks:
		if t.cell == cell:
			return true
	return false

func on_mouse_motion(screen_pos: Vector2) -> void:
	if not is_active or not camera or not grid_manager:
		return

	var ground_p: Vector3 = camera.raycast_ground(screen_pos)
	var gx: int = int(floor(ground_p.x))
	var gz: int = int(floor(ground_p.z))
	current_hover_cell = Vector2i(gx, gz)

	if is_dragging:
		if is_instance_valid(hover_mesh):
			hover_mesh.visible = false
		_update_drag_preview(drag_start_cell, current_hover_cell)
	else:
		if is_tile_diggable(current_hover_cell):
			var tile: Tile = grid_manager.get_tile(gx, gz)
			var h: float = float(tile.height) if tile else 0.0
			hover_mesh.global_position = Vector3(float(gx) + 0.5, h + 0.04, float(gz) + 0.5)
			hover_mesh.visible = true
		else:
			hover_mesh.visible = false

func on_mouse_down(screen_pos: Vector2) -> void:
	if not is_active or not camera:
		return

	var ground_p: Vector3 = camera.raycast_ground(screen_pos)
	var gx: int = int(floor(ground_p.x))
	var gz: int = int(floor(ground_p.z))
	drag_start_cell = Vector2i(gx, gz)
	current_hover_cell = drag_start_cell
	is_dragging = true
	if is_instance_valid(hover_mesh):
		hover_mesh.visible = false
	_update_drag_preview(drag_start_cell, drag_start_cell)

func _update_drag_preview(p0: Vector2i, p1: Vector2i) -> void:
	var min_x: int = mini(p0.x, p1.x)
	var max_x: int = maxi(p0.x, p1.x)
	var min_z: int = mini(p0.y, p1.y)
	var max_z: int = maxi(p0.y, p1.y)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0

	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var cell := Vector2i(x, z)
			if is_tile_diggable(cell):
				var tile: Tile = grid_manager.get_tile(x, z)
				var h: float = float(tile.height) + 0.04
				_add_quad(st, Vector3(x + 0.02, h, z + 0.02), Vector3(x + 0.98, h, z + 0.98))
				count += 1

	if count > 0:
		st.generate_normals()
		drag_preview_mesh.mesh = st.commit()
		drag_preview_mesh.material_override = drag_mat
		drag_preview_mesh.visible = true
	else:
		drag_preview_mesh.visible = false

func _add_quad(st: SurfaceTool, p_min: Vector3, p_max: Vector3) -> void:
	var h: float = p_min.y
	var v1: Vector3 = Vector3(p_min.x, h, p_min.z)
	var v2: Vector3 = Vector3(p_max.x, h, p_min.z)
	var v3: Vector3 = Vector3(p_max.x, h, p_max.z)
	var v4: Vector3 = Vector3(p_min.x, h, p_max.z)

	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)

	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v4)

func on_mouse_up(all_units: Array[Unit]) -> void:
	if not is_active or not is_dragging:
		return

	is_dragging = false
	if is_instance_valid(drag_preview_mesh):
		drag_preview_mesh.visible = false

	var min_x: int = mini(drag_start_cell.x, current_hover_cell.x)
	var max_x: int = maxi(drag_start_cell.x, current_hover_cell.x)
	var min_z: int = mini(drag_start_cell.y, current_hover_cell.y)
	var max_z: int = maxi(drag_start_cell.y, current_hover_cell.y)

	if NetworkManager.in_match and not NetworkManager.applying_command:
		NetworkManager.session.send("dig_area",{"from":Vector2i(min_x,min_z),"to":Vector2i(max_x,max_z)});return
	var queued_any: bool = false
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var cell := Vector2i(x, z)
			if is_tile_diggable(cell) and not is_cell_queued(cell):
				_queue_dig_task(cell)
				queued_any = true

	if queued_any:
		SoundManager.play_click()
		dispatch_idle_workers(all_units)

func _queue_dig_task(cell: Vector2i, faction: String="player") -> void:
	var tile: Tile = grid_manager.get_tile(cell.x, cell.y)
	if not tile:
		return

	# Visual marker
	var marker: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(0.92, 0.92)
	marker.mesh = plane
	marker.material_override = marker_mat
	var h: float = float(tile.height) + 0.03
	marker.global_position = Vector3(float(cell.x) + 0.5, h, float(cell.y) + 0.5)
	markers_container.add_child(marker)

	var target_h: int = maxi(1, tile.height - 1)
	var task: Dictionary = {
		"cell": cell,
		"faction": faction,
		"target_height": target_h,
		"worker": null,
		"progress": 0.0,
		"dig_sound_timer": 0.0,
		"marker": marker
	}
	tasks.append(task)

func unassign_worker(u: Unit) -> void:
	if not is_instance_valid(u):
		return
	var uid: int = u.get_instance_id()
	if worker_tasks.has(uid):
		var task: Dictionary = worker_tasks[uid]
		worker_tasks.erase(uid)
		task.worker = null
		task.progress = 0.0
		task.dig_sound_timer = 0.0
		if u.state == UnitConfigs.UnitState.GATHERING:
			u.state = UnitConfigs.UnitState.IDLE

func dispatch_idle_workers(all_units: Array[Unit]) -> void:
	var unassigned_tasks: Array[Dictionary] = []
	for t in tasks:
		if t.worker == null:
			unassigned_tasks.append(t)

	if unassigned_tasks.is_empty():
		return

	for u in all_units:
		if not is_instance_valid(u) or not u.is_alive or not FactionRules.is_colony(u.faction):
			continue
		if not UnitConfigs.is_worker(u.unit_type) or u.underground_unit:
			continue
		if u.assigned_lumber_zone_id != "" or u.mining_building_id != "":
			continue
		if u.state == UnitConfigs.UnitState.IDLE and not worker_tasks.has(u.get_instance_id()):
			var best_task: Dictionary = _find_closest_task(u.global_position, unassigned_tasks.filter(func(t):return t.get("faction","player")==u.faction))
			if not best_task.is_empty():
				_send_worker_to_task(u, best_task)
				unassigned_tasks.erase(best_task)
				if unassigned_tasks.is_empty():
					break

func _find_closest_task(pos: Vector3, task_list: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var min_dist: float = 999999.0
	for t in task_list:
		if t.worker != null:
			continue
		var target_pos: Vector3 = Vector3(float(t.cell.x) + 0.5, 0, float(t.cell.y) + 0.5)
		var d: float = Vector2(pos.x - target_pos.x, pos.z - target_pos.z).length_squared()
		if d < min_dist:
			min_dist = d
			best = t
	return best

func _send_worker_to_task(u: Unit, task: Dictionary) -> void:
	var cell: Vector2i = task.cell
	var target_tile: Tile = grid_manager.get_tile(cell.x, cell.y)
	if not target_tile:
		return

	# Determine standing destination
	var candidates: Array[Vector2i] = [
		cell,
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1)
	]

	var best_dest: Vector3 = Vector3.ZERO
	var best_path: Array[Vector3] = []

	for cand in candidates:
		if cand.x < 0 or cand.x >= GridManager.GRID_SIZE or cand.y < 0 or cand.y >= GridManager.GRID_SIZE:
			continue
		var t: Tile = grid_manager.get_tile(cand.x, cand.y)
		if not t or t.biome == Tile.Biome.WATER:
			continue
		if t.building_id != "" and not t.is_gate:
			continue
		var stand_pos: Vector3 = Vector3(float(cand.x) + 0.5, float(t.height), float(cand.y) + 0.5)
		var p: Array[Vector3] = grid_manager.find_path(u.global_position, stand_pos)
		if not p.is_empty():
			best_dest = stand_pos
			best_path = p
			break

	if not best_path.is_empty():
		task.worker = u
		worker_tasks[u.get_instance_id()] = task
		u.set_path(best_path)
		u.current_order = UnitConfigs.UnitOrder.GATHER
		u.state = UnitConfigs.UnitState.MOVING

func tick(delta: float, all_units: Array[Unit]) -> void:
	var finished_tasks: Array[Dictionary] = []
	for task in tasks:
		var u: Unit = task.worker
		if u == null:
			continue
		if not is_instance_valid(u) or not u.is_alive:
			unassign_worker(u)
			continue

		var cell: Vector2i = task.cell
		var target_pos: Vector3 = Vector3(float(cell.x) + 0.5, grid_manager.get_height(cell.x + 0.5, cell.y + 0.5), float(cell.y) + 0.5)
		var dist: float = Vector2(u.position.x - target_pos.x, u.position.z - target_pos.z).length()

		if dist > 1.35:
			# If worker stopped prematurely or path finished, re-issue path
			if (u.state == UnitConfigs.UnitState.IDLE or u.path.is_empty()) and dist > 1.5:
				_send_worker_to_task(u, task)
		else:
			# In range! Dig block!
			u.stop()
			u.state = UnitConfigs.UnitState.GATHERING

			# Face the block
			var dir: Vector3 = target_pos - u.position
			dir.y = 0
			if dir.length_squared() > 0.001:
				u.rotation.y = atan2(dir.x, dir.z)

			# Dig sound effect
			task.dig_sound_timer += delta
			if task.dig_sound_timer >= 0.6:
				task.dig_sound_timer = 0.0
				SoundManager.play_ore_pick(u.global_position)

			task.progress += delta
			if task.progress >= DIG_DURATION:
				finished_tasks.append(task)

	for task in finished_tasks:
		_complete_task(task, all_units)

	# Try dispatching idle workers to unassigned tasks
	var has_unassigned: bool = false
	for t in tasks:
		if t.worker == null:
			has_unassigned = true
			break
	if has_unassigned:
		dispatch_idle_workers(all_units)

func _complete_task(task: Dictionary, all_units: Array[Unit]) -> void:
	var cell: Vector2i = task.cell
	var target_h: int = task.target_height
	var u: Unit = task.worker

	# Remove visual marker
	if is_instance_valid(task.marker):
		task.marker.queue_free()

	# Remove any resource on this tile so it won't float in mid-air
	var tile: Tile = grid_manager.get_tile(cell.x, cell.y)
	if tile and tile.resource_id != "" and resource_spawner:
		if resource_spawner.resources.has(tile.resource_id):
			var res: Node = resource_spawner.resources[tile.resource_id]
			if is_instance_valid(res):
				res.queue_free()
			resource_spawner.resources.erase(tile.resource_id)
		tile.resource_id = ""

	# Lower terrain height
	terrain_generator.update_tile_height(cell.x, cell.y, target_h, grid_manager)

	# Give stone resource to player
	FactionEconomy.add(task.get("faction","player"), "stone", 2)
	SoundManager.play_ore_pick(Vector3(float(cell.x) + 0.5, float(target_h), float(cell.y) + 0.5))

	# Erase task
	tasks.erase(task)
	if is_instance_valid(u):
		var uid: int = u.get_instance_id()
		worker_tasks.erase(uid)
		u.state = UnitConfigs.UnitState.IDLE
		u.current_order = UnitConfigs.UnitOrder.MOVE

		# Chain worker to next nearest task
		var next_task: Dictionary = _find_closest_task(u.global_position, tasks.filter(func(t):return t.get("faction","player")==u.faction))
		if not next_task.is_empty() and next_task.worker == null:
			_send_worker_to_task(u, next_task)
