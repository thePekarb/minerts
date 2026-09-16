class_name FogOfWarSystem
extends Node

signal visibility_updated

var visible_cells: Dictionary = {}
var dirty_cells: Dictionary = {}
var static_objects: Array[Node3D] = []
var fog_image: Image
var fog_texture: ImageTexture
var material_cache: Dictionary = {}
var fog_materials: Array[ShaderMaterial] = []
var underground_view: bool = false
var grid_manager: GridManager
var update_timer: float = 0.0
const MAX_SIGHT_CACHE: int = 2048
var sight_cache: Dictionary = {}
var sight_revision: int = -1
var cache_enabled: bool = true
var ray_checks: int = 0
var cache_hits: int = 0
var texture_uploads: int = 0
var last_update_usec: int = 0

# Visibility matrix: 0 = hidden, 1 = explored (shrouded), 2 = currently visible
var visibility_grid: PackedByteArray = PackedByteArray()
var fog_enabled: bool = true

func init_fog(grid_mgr: GridManager) -> void:
	grid_manager = grid_mgr
	visible_cells.clear()
	dirty_cells.clear()
	sight_cache.clear()
	sight_revision = -1
	visibility_grid.resize(GridManager.GRID_SIZE * GridManager.GRID_SIZE)
	visibility_grid.fill(0)
	fog_image = Image.create(GridManager.GRID_SIZE, GridManager.GRID_SIZE, false, Image.FORMAT_R8)
	fog_image.fill(Color.BLACK)
	fog_texture = ImageTexture.create_from_image(fog_image)

func set_fog_enabled(is_enabled: bool) -> void:
	fog_enabled = is_enabled
	if not fog_enabled:
		if visibility_grid.size() == GridManager.GRID_SIZE * GridManager.GRID_SIZE:
			visibility_grid.fill(2)
		if fog_image:
			fog_image.fill(Color(1.0, 0, 0, 1.0))
			if fog_texture:
				fog_texture.update(fog_image)
		if grid_manager and not grid_manager.tiles.is_empty():
			for x in range(GridManager.GRID_SIZE):
				for z in range(GridManager.GRID_SIZE):
					var t: Tile = grid_manager.get_tile(x, z)
					if t:
						t.is_explored = true
						t.is_visible = true
		for o in static_objects:
			if is_instance_valid(o):
				o.visible = true
		visibility_updated.emit()

func update_fog(all_units: Array[Unit], all_buildings: Array[Building], delta: float) -> void:
	if not fog_enabled:
		for u in all_units:
			if is_instance_valid(u) and u.is_alive and not u.underground_unit:
				u.visible = true
		for b in all_buildings:
			if is_instance_valid(b) and b.is_alive:
				b.visible = true
		for o in static_objects:
			if is_instance_valid(o):
				o.visible = true
		visibility_updated.emit()
		return

	update_timer += delta
	if update_timer < 0.25: # Run 4 times per second for peak efficiency
		return
	update_timer = 0.0
	var started: int = Time.get_ticks_usec()
	var previous_visible: Dictionary = visible_cells.duplicate()


	# Only visit changed cells, independent of archipelago size.
	dirty_cells=visible_cells.duplicate()
	for i in visible_cells:
		visibility_grid[i]=1
		var tile: Tile = grid_manager.get_tile(i%GridManager.GRID_SIZE,int(i/GridManager.GRID_SIZE))
		if tile:tile.is_visible=false
	visible_cells.clear()

	# Reveal around player units
	for u in all_units:
		if not is_instance_valid(u) or not u.is_alive or u.faction != "player":
			continue
		if u.state == UnitConfigs.UnitState.MINING_INSIDE or u.underground_unit or is_instance_valid(u.embarked_in):
			continue
		var gx: int = int(floor(u.global_position.x))
		var gz: int = int(floor(u.global_position.z))
		var radius: int = int(u.config.get("vision_range", 6.0))
		_reveal_circle(gx, gz, radius)

	# Reveal around player buildings
	for b in all_buildings:
		if not is_instance_valid(b) or not b.is_alive or b.faction!="player":
			continue
		var radius: int = int(b.config.get("vision_range", 7.0))
		_reveal_circle(b.grid_x, b.grid_z, radius)

	# Hide enemy units if not in visible tile
	for u in all_units:
		if is_instance_valid(u) and u.is_alive and u.faction != "player":
			if u.underground_unit:
				continue
			var egx: int = int(floor(u.global_position.x))
			var egz: int = int(floor(u.global_position.z))
			var vis: int = get_tile_visibility(egx, egz)
			u.visible = (vis == 2) and not underground_view and not u.underground_unit and not is_instance_valid(u.embarked_in) and u.state!=UnitConfigs.UnitState.MINING_INSIDE

	# A stationary observer must not upload an identical mask every tick.
	for index in previous_visible:
		if visible_cells.has(index):dirty_cells.erase(index)
	for index in dirty_cells:
		var state: int = visibility_grid[index]
		fog_image.set_pixel(index%GridManager.GRID_SIZE,int(index/GridManager.GRID_SIZE),Color(1.0 if state==2 else 0.32,0,0,1))
	for building in all_buildings:
		if not is_instance_valid(building) or building.faction=="player":continue
		var known: bool = false
		for dx in range(building.footprint.x):
			for dz in range(building.footprint.y):
				if get_tile_visibility(building.grid_x+dx,building.grid_z+dz)>0:known=true
		building.visible=known and not underground_view

	for object in static_objects:
		if is_instance_valid(object):
			var known: bool = get_tile_visibility(floori(object.position.x), floori(object.position.z)) > 0
			if object.visible!=known:object.visible=known
	if not dirty_cells.is_empty():
		fog_texture.update(fog_image)
		texture_uploads += 1
	last_update_usec = Time.get_ticks_usec() - started
	visibility_updated.emit()

func _reveal_circle(cx: int, cz: int, radius: int) -> void:
	if sight_revision != grid_manager.terrain_revision:
		sight_cache.clear()
		sight_revision = grid_manager.terrain_revision
	var key := Vector3i(cx, cz, radius)
	var cells: PackedInt32Array
	if cache_enabled and sight_cache.has(key):
		cells = sight_cache[key]
		# Refresh insertion order, bounding both memory and time spent on old scouts.
		sight_cache.erase(key)
		sight_cache[key] = cells
		cache_hits += 1
	else:
		cells = _calculate_sight(cx, cz, radius)
		if cache_enabled:
			if sight_cache.size() >= MAX_SIGHT_CACHE:
				sight_cache.erase(sight_cache.keys()[0])
			sight_cache[key] = cells
	for index in cells:
		if visible_cells.has(index):continue
		visibility_grid[index] = 2
		visible_cells[index] = true
		dirty_cells[index] = true
		var tile: Tile = grid_manager.get_tile(index % GridManager.GRID_SIZE, int(index / GridManager.GRID_SIZE))
		if tile:
			tile.is_explored = true
			tile.is_visible = true

func _calculate_sight(cx: int, cz: int, radius: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var r2: int = radius * radius
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz <= r2 and _vision_clear(cx, cz, cx + dx, cz + dz):
				var x: int = cx + dx
				var z: int = cz + dz
				if x >= 0 and x < GridManager.GRID_SIZE and z >= 0 and z < GridManager.GRID_SIZE:
					cells.append(z * GridManager.GRID_SIZE + x)
	return cells

func get_tile_visibility(gx: int, gz: int) -> int:
	if not fog_enabled:
		return 2
	if gx < 0 or gx >= GridManager.GRID_SIZE or gz < 0 or gz >= GridManager.GRID_SIZE:
		return 0
	return visibility_grid[gz * GridManager.GRID_SIZE + gx]


func _vision_clear(sx: int, sz: int, tx: int, tz: int) -> bool:
	ray_checks += 1
	var source: Tile = grid_manager.get_tile(sx, sz)
	var target_tile: Tile = grid_manager.get_tile(tx, tz)
	if source == null or target_tile == null:
		return false
	var distance: float = Vector2(tx - sx, tz - sz).length()
	for i in range(2, int(ceil(distance))):
		var t: float = float(i) / distance
		var tile: Tile = grid_manager.get_tile(roundi(lerpf(sx, tx, t)), roundi(lerpf(sz, tz, t)))
		if tile == null:
			return false
		var eye_height: float = lerpf(source.height + 1.8, target_tile.height + 0.8, t)
		if tile.height > eye_height or (i > 2 and tile.building_id != "" and tile.building_id != target_tile.building_id and not tile.is_gate_open):
			return false
	return true

func apply_world_materials(node: Node, terrain_parent: bool = false) -> void:
	var is_terrain: bool = terrain_parent or node is TerrainChunk
	if node is Node3D and (node.has_meta("resource_type") or node.has_meta("poi_type") or node.name.begins_with("Altar_")):
		if not static_objects.has(node): static_objects.append(node)
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		node.material_override.set_shader_parameter("visibility_map", fog_texture)
		fog_materials.append(node.material_override)
		return
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
		if mesh:
			for index in range(mesh.get_surface_count()):
				var original: Material = mesh.surface_get_material(index)
				if original is ShaderMaterial:
					continue
				var cache_key: String = str(original.get_rid())+str(is_terrain) if original else str(is_terrain)
				var material: ShaderMaterial = material_cache.get(cache_key,ShaderMaterial.new())
				material_cache[cache_key]=material
				material.shader = load("res://assets/shaders/world_fog.gdshader")
				material.set_meta("fog_world", true)
				material.set_shader_parameter("visibility_map", fog_texture)
				material.set_shader_parameter("terrain", is_terrain)
				if original is StandardMaterial3D:
					material.set_shader_parameter("base_color", original.albedo_color)
				if not fog_materials.has(material):fog_materials.append(material)
				if node is MeshInstance3D:
					node.set_surface_override_material(index, material)
				else:
					# Shared mesh must be duplicated before changing its material.
					if index == 0:
						node.multimesh.mesh = mesh.duplicate()
					node.multimesh.mesh.surface_set_material(index, material)
	for child in node.get_children():
		apply_world_materials(child, is_terrain)

func set_surface_transparent(enabled: bool) -> void:
	underground_view = enabled
	for material in fog_materials:
		if material.get_meta("fog_world", false):
			material.shader = load("res://assets/shaders/world_fog_cutaway.gdshader" if enabled else "res://assets/shaders/world_fog.gdshader")
		material.set_shader_parameter("surface_alpha", 0.08 if enabled else 1.0)
