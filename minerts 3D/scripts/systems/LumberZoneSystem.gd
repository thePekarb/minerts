class_name LumberZoneSystem
extends Node

class LumberZone:
	var id: String
	var center: Vector3
	var radius: float
	var max_workers: int = 5
	var assigned_workers: Array[Unit] = []
	var visual_ring: MeshInstance3D
	var icon_badge: Node3D
	var is_hovered: bool = false
	var is_selected: bool = false

var camera: RTSCamera
var grid_manager: GridManager
var resource_spawner: ResourceSpawner
var zones_container: Node3D

var zones: Array[LumberZone] = []
var is_placing_zone: bool = false
var is_dragging: bool = false
var drag_center: Vector3 = Vector3.ZERO
var drag_radius: float = 3.0
var preview_ring: MeshInstance3D = null

var hovered_zone: LumberZone = null
var selected_zone: LumberZone = null

func init_lumber_zones(cam: RTSCamera, grid_mgr: GridManager, spawner: ResourceSpawner, container: Node3D) -> void:
	camera = cam
	grid_manager = grid_mgr
	resource_spawner = spawner
	zones_container = container
	_create_preview_ring()

func _create_preview_ring() -> void:
	preview_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 2.9
	torus.outer_radius = 3.1
	torus.rings = 32
	preview_ring.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.77, 0.37, 0.8) # #22c55e
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_ring.material_override = mat
	preview_ring.visible = false
	add_child(preview_ring)

func start_zone_placement() -> void:
	is_placing_zone = true
	is_dragging = false
	preview_ring.visible = false

func cancel_zone_placement() -> void:
	is_placing_zone = false
	is_dragging = false
	preview_ring.visible = false

func on_mouse_down(screen_pos: Vector2) -> void:
	if not is_placing_zone:
		return
	is_dragging = true
	drag_center = camera.raycast_ground(screen_pos)
	drag_radius = 3.0
	preview_ring.global_position = drag_center + Vector3(0, 0.1, 0)
	preview_ring.visible = true
	_update_ring_mesh(preview_ring, drag_radius)

func on_mouse_motion(screen_pos: Vector2) -> void:
	if not is_placing_zone:
		_check_hover_zones(screen_pos)
		return

	if is_dragging:
		var current_p: Vector3 = camera.raycast_ground(screen_pos)
		var diff: Vector3 = current_p - drag_center
		diff.y = 0.0
		drag_radius = clampf(diff.length(), 2.0, 15.0)
		_update_ring_mesh(preview_ring, drag_radius)

func on_mouse_up(all_player_units: Array[Unit]) -> void:
	if not is_placing_zone or not is_dragging:
		return

	# Finalize zone
	create_zone(drag_center, drag_radius, all_player_units)
	is_placing_zone = false
	is_dragging = false
	preview_ring.visible = false

func create_zone(center: Vector3, radius: float, all_player_units: Array[Unit]) -> LumberZone:
	var zone: LumberZone = LumberZone.new()
	zone.id = "lz_" + str(Time.get_ticks_msec())
	zone.center = center
	zone.radius = radius

	# Create visual ring (hidden by default)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius - 0.1
	torus.outer_radius = radius + 0.1
	torus.rings = 32
	ring.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.4, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.visible = false
	zones_container.add_child(ring)
	ring.global_position = center + Vector3(0, 0.1, 0)
	zone.visual_ring = ring

	# 3D floating axe icon badge
	var badge: Node3D = Node3D.new()
	var axe_mesh: Node3D = VoxelMeshFactory.create_icon_badge("axe")
	badge.add_child(axe_mesh)
	zones_container.add_child(badge)
	badge.global_position = center + Vector3(0, 2.5, 0)
	zone.icon_badge = badge

	zones.append(zone)
	SoundManager.play_click()

	# Auto-select the newly placed zone
	select_zone(zone)
	return zone

func _update_ring_mesh(ring_inst: MeshInstance3D, rad: float) -> void:
	var torus: TorusMesh = ring_inst.mesh as TorusMesh
	if not torus:
		torus = TorusMesh.new()
		ring_inst.mesh = torus
	torus.inner_radius = rad - 0.1
	torus.outer_radius = rad + 0.1

func _check_hover_zones(screen_pos: Vector2) -> void:
	var prev_hover: LumberZone = hovered_zone
	hovered_zone = null

	var hit: Dictionary = camera.raycast_objects(screen_pos)
	var collider: Object = hit.get("collider", null)

	# Check screen distance to zone badges
	for z in zones:
		var badge_screen: Vector2 = camera.unproject_position(z.icon_badge.global_position)
		if screen_pos.distance_to(badge_screen) < 32.0:
			hovered_zone = z
			break

	if hovered_zone != prev_hover:
		if prev_hover and prev_hover != selected_zone:
			prev_hover.visual_ring.visible = false
		if hovered_zone:
			hovered_zone.visual_ring.visible = true

func select_zone(zone: LumberZone) -> void:
	if selected_zone and selected_zone != zone:
		selected_zone.visual_ring.visible = false
	selected_zone = zone
	if selected_zone:
		selected_zone.visual_ring.visible = true
	EventBus.lumber_zone_selected.emit(zone)

func deselect_zone() -> void:
	if selected_zone:
		selected_zone.visual_ring.visible = false
		selected_zone = null
	EventBus.lumber_zone_selected.emit(null)

func add_worker(zone: LumberZone, all_player_units: Array[Unit]) -> bool:
	if not zone or zone.assigned_workers.size() >= zone.max_workers:
		return false

	var best_worker: Unit = null
	var min_dist: float = 9999.0

	for u in all_player_units:
		if is_instance_valid(u) and u.is_alive and u.faction == "player" and u.unit_type == UnitConfigs.UnitType.WORKER:
			if u.assigned_lumber_zone_id == "" and u.mining_building_id == "" and u.state != UnitConfigs.UnitState.MINING_INSIDE:
				var d: float = u.global_position.distance_to(zone.center)
				if d < min_dist:
					min_dist = d
					best_worker = u

	if best_worker:
		best_worker.assigned_lumber_zone_id = zone.id
		zone.assigned_workers.append(best_worker)
		SoundManager.play_click()
		EventBus.lumber_zone_workers_changed.emit(zone, zone.assigned_workers.size())
		_dispatch_worker_to_tree(best_worker, zone)
		return true

	return false

func remove_worker(zone: LumberZone) -> bool:
	if not zone or zone.assigned_workers.is_empty():
		return false

	var worker: Unit = zone.assigned_workers.pop_back()
	if is_instance_valid(worker):
		worker.assigned_lumber_zone_id = ""
		worker.stop()
	SoundManager.play_click()
	EventBus.lumber_zone_workers_changed.emit(zone, zone.assigned_workers.size())
	return true

func process_lumber_zones(delta: float) -> void:
	# Subtle floating animation for zone badges
	var t: float = float(Time.get_ticks_msec()) * 0.003
	for z in zones:
		if z.icon_badge:
			z.icon_badge.position.y = z.center.y + 2.5 + sin(t) * 0.15

		# Manage assigned workers
		for w in z.assigned_workers:
			if not is_instance_valid(w) or not w.is_alive:
				continue
			if w.state == UnitConfigs.UnitState.IDLE:
				_dispatch_worker_to_tree(w, z)

func _dispatch_worker_to_tree(u: Unit, zone: LumberZone) -> void:
	if u.navigation.retry_after>0:return
	u.navigation.retry_after=1.0
	var closest_tree: Node = null
	var min_dist: float = 9999.0

	for res_id in resource_spawner.resources:
		var res: Node = resource_spawner.resources[res_id]
		if is_instance_valid(res) and res.get_meta("resource_type", "") == "wood":
			var pos: Vector3 = res.global_position
			var dist_to_center: float = Vector2(pos.x - zone.center.x, pos.z - zone.center.z).length()
			if dist_to_center <= zone.radius:
				var dist_to_u: float = u.global_position.distance_to(pos)
				if dist_to_u < min_dist:
					min_dist = dist_to_u
					closest_tree = res

	if closest_tree:
		u.current_order = UnitConfigs.UnitOrder.GATHER
		u.target = closest_tree
		var path: Array[Vector3] = grid_manager.find_interaction_path(u,closest_tree,2.0)
		u.set_path(path)
		u.state = UnitConfigs.UnitState.MOVING
