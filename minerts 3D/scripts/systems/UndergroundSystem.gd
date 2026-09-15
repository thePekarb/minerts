class_name UndergroundSystem
extends Node3D

const FLOOR_Y: float = -4.0
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var game: Main
var cells: Dictionary = {}
var discovered: Dictionary = {}
var caves: Array[Dictionary] = []
var jobs: Dictionary = {}
var astar: AStar3D = AStar3D.new()
var cutaway: bool = false
var rock_backdrop: MeshInstance3D
var floor_mesh: MeshInstance3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var timer: float = 0.0
var hint: Label
var exit_nodes: Array[Node3D] = []

func setup(main: Main) -> void:
	game = main
	game.grid_manager.underground = self
	rng.randomize()
	for center in [Vector2i(109, 96), Vector2i(76, 83), Vector2i(121, 122), Vector2i(62, 121), Vector2i(133, 66), Vector2i(418,92), Vector2i(384,66), Vector2i(293,306)]:
		var entry_pos: Vector3 = game.grid_manager.find_free_position(Vector3(center.x + 0.5, 0, center.y + 0.5))
		var entry: Vector2i = Vector2i(floori(entry_pos.x), floori(entry_pos.z))
		var cave: Dictionary = {"entry": entry, "cells": [], "enemies": [], "respawn": 8.0}
		var cursor: Vector2i = entry
		for step in range(35):
			cursor += DIRS[rng.randi_range(0, 3)]
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var cell: Vector2i = cursor + Vector2i(dx, dz)
					if cell.distance_to(cursor) <= 2.5 and cell.x > 2 and cell.y > 2 and cell.x < GridManager.GRID_SIZE-2 and cell.y < GridManager.GRID_SIZE-2 and game.grid_manager.get_height(cell.x,cell.y)>0:
						cells[cell] = true
						if not cave.cells.has(cell): cave.cells.append(cell)
		cells[entry] = true
		caves.append(cave)
		_make_entry(entry_pos, entry)
		_make_exit(entry)
	_rebuild_navigation()
	floor_mesh = MeshInstance3D.new()
	add_child(floor_mesh)
	floor_mesh.visible = false
	rock_backdrop = MeshInstance3D.new()
	var rock_plane: PlaneMesh = PlaneMesh.new()
	rock_plane.size = Vector2(GridManager.GRID_SIZE,GridManager.GRID_SIZE)
	rock_backdrop.mesh = rock_plane
	var rock_material: StandardMaterial3D = StandardMaterial3D.new()
	rock_material.albedo_color = Color("111a25")
	rock_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rock_material.disable_fog = true
	rock_backdrop.material_override = rock_material
	rock_backdrop.position = Vector3(GridManager.GRID_SIZE*0.5,FLOOR_Y-0.05,GridManager.GRID_SIZE*0.5)
	add_child(rock_backdrop)
	rock_backdrop.visible = false
	hint = Label.new()
	hint.position = Vector2(18, 135)
	hint.visible=false
	hint.text = "X: разрез земли · ПКМ рабочим: идти / копать · R: выйти на поверхность"
	hint.add_theme_font_size_override("font_size", 16)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(hint)

func _make_exit(cell: Vector2i) -> void:
	var exit_body: StaticBody3D = StaticBody3D.new()
	exit_body.name = "CaveExit_%d_%d" % [cell.x, cell.y]
	exit_body.collision_layer = 8
	exit_body.collision_mask = 0
	exit_body.set_meta("poi_type", "cave_exit")
	exit_body.set_meta("exit_cell", cell)
	exit_body.set_meta("display_name", "▲ Выход на поверхность · ПКМ: подняться")
	add_child(exit_body)
	var exit_pos: Vector3 = Vector3(cell.x + 0.5, FLOOR_Y, cell.y + 0.5)
	exit_body.global_position = exit_pos

	# Collision box for picking underground
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.4, 4.2, 1.4)
	shape.shape = box
	shape.position.y = 2.1
	exit_body.add_child(shape)

	# 1. Wooden platform base
	var ladder_color: Color = Color("8c5e39")
	var dark_wood: Color = Color("5c3a21")
	var platform: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(1.1, 0.12, 1.1), ladder_color)
	platform.position = Vector3(0.0, 0.06, 0.0)
	exit_body.add_child(platform)

	# 2. Wooden ladder side rails from floor (-4.0) up to surface
	var rail_left: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(0.08, 4.2, 0.08), dark_wood)
	rail_left.position = Vector3(-0.35, 2.1, 0.0)
	exit_body.add_child(rail_left)

	var rail_right: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(0.08, 4.2, 0.08), dark_wood)
	rail_right.position = Vector3(0.35, 2.1, 0.0)
	exit_body.add_child(rail_right)

	# Ladder steps / rungs
	for r in range(1, 10):
		var rung: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(0.66, 0.06, 0.06), ladder_color)
		rung.position = Vector3(0.0, float(r) * 0.42, 0.0)
		exit_body.add_child(rung)

	# 3. Daylight shaft from surface entrance
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.8
	cyl.height = 4.2
	shaft.mesh = cyl
	var shaft_mat: StandardMaterial3D = StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.18)
	shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft.material_override = shaft_mat
	shaft.position = Vector3(0.0, 2.1, 0.0)
	exit_body.add_child(shaft)

	# Warm daylight illumination
	var daylight: OmniLight3D = OmniLight3D.new()
	daylight.position = Vector3(0.0, 2.6, 0.0)
	daylight.light_color = Color("fff3d0")
	daylight.light_energy = 1.6
	daylight.omni_range = 6.5
	exit_body.add_child(daylight)

	# 4. Floating 3D billboard label
	var label: Label3D = Label3D.new()
	label.text = "▲ ВЫХОД НА ПОВЕРХНОСТЬ"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.012
	label.modulate = Color("ffe082")
	label.outline_size = 6
	label.position = Vector3(0.0, 2.5, 0.0)
	exit_body.add_child(label)

	exit_body.visible = false
	exit_nodes.append(exit_body)

func _make_entry(pos: Vector3, cell: Vector2i) -> void:
	var entry: StaticBody3D = StaticBody3D.new()
	entry.collision_layer = 8
	entry.collision_mask = 0
	entry.set_meta("poi_type", "cave_entrance")
	entry.set_meta("entry_cell", cell)
	entry.set_meta("display_name", "Вход в пещеру · ПКМ: спуститься")
	game.world_container.add_child(entry)
	entry.global_position = pos
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.1, 0.5, 1.1)
	shape.shape = box
	shape.position.y = 0.25
	entry.add_child(shape)
	var rim: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(1.2, 0.2, 1.2), Color("776b61"))
	entry.add_child(rim)
	var hole: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(0.85, 0.05, 0.85), Color("121c26"))
	hole.position.y = 0.12
	entry.add_child(hole)
	var label: Label3D = Label3D.new()
	label.text = "▼ ПЕЩЕРА"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.012
	label.position.y = 0.8
	entry.add_child(label)
	game.fog_system.apply_world_materials(entry)
	# Entrances are protected from later building placement.
	game.grid_manager.get_tile(cell.x, cell.y).resource_id = "cave_entrance"
	game.grid_manager.astar.set_point_disabled(game.grid_manager.get_point_id(cell.x, cell.y), true)
	game.grid_manager.invalidate_terrain(cell)

func is_open(cell: Vector2i) -> bool:
	return cells.has(cell)

func _id(cell: Vector2i) -> int:
	return cell.x * GridManager.GRID_SIZE + cell.y

func _rebuild_navigation() -> void:
	astar.clear()
	for cell in cells:
		astar.add_point(_id(cell), Vector3(cell.x + 0.5, FLOOR_Y, cell.y + 0.5))
	for cell in cells:
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			if cells.has(cell + direction):
				astar.connect_points(_id(cell), _id(cell + direction))

func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var start: Vector2i = Vector2i(floori(from.x), floori(from.z))
	var end: Vector2i = Vector2i(floori(to.x), floori(to.z))
	var result: Array[Vector3] = []
	if cells.has(start) and cells.has(end):
		for point in astar.get_point_path(_id(start), _id(end)):
			result.append(point)
	return result

func toggle_view() -> void:
	cutaway = not cutaway
	game.fog_system.set_surface_transparent(cutaway)
	game.camera.underground_view = cutaway
	floor_mesh.visible = cutaway
	rock_backdrop.visible = cutaway
	for e in exit_nodes:
		if is_instance_valid(e):
			e.visible = cutaway
	game.buildings_container.visible = not cutaway
	game.construction_system.cancel_placement()
	game.lumber_zone_system.cancel_zone_placement()
	hint.visible=cutaway
	hint.text = "ПОДЗЕМЕЛЬЕ · ПКМ по лестнице (▲ ВЫХОД) или [R]: на поверхность · X: разрез" if cutaway else "X: разрез земли · ПКМ на входе: спуститься"
	_update_visibility()

func issue_order(unit: Unit, target: Vector2i) -> bool:
	if unit.faction != "player": return false
	if target.x < 3 or target.y < 3 or target.x > 188 or target.y > 188: return false
	if not cells.has(target) and unit.unit_type != UnitConfigs.UnitType.WORKER:
		game.hud.show_banner("Копать тоннели могут только рабочие.")
		return false
	if cells.has(target): target = _free_cell_near(target,unit)
	game.selection_system.cancel_assignments(unit)
	unit.stop()
	unit.current_order = UnitConfigs.UnitOrder.MOVE
	unit.target = null
	var entry: Vector2i = caves[0].entry
	var best: float = INF
	for cave in caves:
		var d: float = unit.global_position.distance_squared_to(Vector3(cave.entry.x, unit.global_position.y, cave.entry.y))
		if d < best:
			best = d
			entry = cave.entry
	jobs[unit.get_instance_id()] = {"unit": weakref(unit), "target": target, "entry": entry, "dig_timer": 0.0}
	SoundManager.play_ore_pick(Vector3(target.x + 0.5, FLOOR_Y, target.y + 0.5))
	if not unit.underground_unit:
		unit.set_path(game.grid_manager.find_path(unit.global_position, Vector3(entry.x + 0.5, 0, entry.y + 0.5)))
		unit.state = UnitConfigs.UnitState.MOVING
	return true

func enter(unit: Unit, entry: Vector2i) -> void:
	unit.stop()
	unit.underground_unit = true
	unit.collision_layer = 32
	unit.collision_mask = 32
	var spawn_cell: Vector2i = _free_cell_near(entry,unit)
	unit.global_position = Vector3(spawn_cell.x + 0.5, FLOOR_Y, spawn_cell.y + 0.5)
	game.grid_manager.unit_index.invalidate()
	unit.jump_progress = 1.0
	if unit.faction == "player" and not unit.has_node("CaveLantern"):
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "CaveLantern"
		light.position.y = 1.2
		light.light_color = Color("ffd5a0")
		light.light_energy = 1.0
		light.omni_range = 6.0
		unit.add_child(light)
	if unit.has_node("CaveLantern"):
		unit.get_node("CaveLantern").visible = true

func request_exit(unit: Unit) -> void:
	if not unit.underground_unit: return
	for cave in caves:
		var dest: Vector3 = Vector3(cave.entry.x + 0.5, FLOOR_Y, cave.entry.y + 0.5)
		if unit.global_position.distance_to(dest) < 1.2:
			unit.stop()
			jobs[unit.get_instance_id()] = {"unit": weakref(unit), "exit": cave.entry}
			return
		var path: Array[Vector3] = find_path(unit.global_position, dest)
		if not path.is_empty():
			game.selection_system.cancel_assignments(unit)
			unit.target = null
			unit.current_order = UnitConfigs.UnitOrder.MOVE
			jobs[unit.get_instance_id()] = {"unit": weakref(unit), "exit": cave.entry}
			unit.set_path(path)
			unit.state = UnitConfigs.UnitState.MOVING
			return

func _process(delta: float) -> void:
	for id in jobs.keys():
		var job: Dictionary = jobs[id]
		var unit: Unit = job.unit.get_ref()
		if not is_instance_valid(unit) or not unit.is_alive:
			jobs.erase(id)
			continue
		if job.has("exit"):
			var pos: Vector3 = Vector3(job.exit.x + 0.5, FLOOR_Y, job.exit.y + 0.5)
			if unit.global_position.distance_to(pos) < 1.2:
				unit.stop()
				unit.underground_unit = false
				if unit.has_node("CaveLantern"): unit.get_node("CaveLantern").visible = false
				unit.collision_layer = 2
				unit.collision_mask = 2 | 4
				unit.global_position = game.grid_manager.find_free_position(Vector3(pos.x, 0, pos.z))
				game.grid_manager.unit_index.invalidate()
				jobs.erase(id)
				SoundManager.play_pop()
			continue
		if not unit.underground_unit:
			if Vector2(unit.position.x - job.entry.x - 0.5, unit.position.z - job.entry.y - 0.5).length() < 2.2:
				enter(unit, job.entry)
			else: continue
		var target: Vector2i = job.target
		var current: Vector2i = Vector2i(floori(unit.position.x), floori(unit.position.z))
		if cells.has(target):
			if current == target:
				jobs.erase(id)
			elif unit.path.is_empty():
				unit.set_path(find_path(unit.position, Vector3(target.x + 0.5, FLOOR_Y, target.y + 0.5)))
				unit.state = UnitConfigs.UnitState.MOVING
				if unit.path.is_empty():
					game.hud.show_banner("Пещеры ещё не соединены. Прокопайте проход через породу.")
					jobs.erase(id)
			continue
		# Excavate a continuous Manhattan tunnel, one adjacent block at a time.
		var step: Vector2i = current + (Vector2i(signi(target.x - current.x), 0) if current.x != target.x else Vector2i(0, signi(target.y - current.y)))
		if not cells.has(step):
			unit.stop()
			unit.state = UnitConfigs.UnitState.GATHERING
			job.dig_timer += delta
			if job.dig_timer >= 2.5:
				job.dig_timer = 0.0
				cells[step] = true
				discovered[step] = true
				EconomyManager.add_resource("stone", 2)
				SoundManager.play_ore_pick(Vector3(step.x + 0.5, FLOOR_Y, step.y + 0.5))
				_rebuild_navigation()
				_rebuild_visuals()
		else:
			if unit.path.is_empty():
				unit.set_path(find_path(unit.position, Vector3(step.x + 0.5, FLOOR_Y, step.y + 0.5)))
				unit.state = UnitConfigs.UnitState.MOVING
	timer += delta
	if timer >= 0.3:
		_tick_caves(timer)
		timer = 0.0
		_update_visibility()

func _tick_caves(delta: float) -> void:
	var changed: bool = false
	for unit in game.all_units:
		if unit.faction == "player" and unit.underground_unit:
			for dx in range(-6, 7):
				for dz in range(-6, 7):
					var cell: Vector2i = Vector2i(floori(unit.position.x) + dx, floori(unit.position.z) + dz)
					if cells.has(cell) and dx * dx + dz * dz < 36 and game.grid_manager.has_line_of_sight(unit.position, Vector3(cell.x+0.5,FLOOR_Y,cell.y+0.5)):
						if not discovered.has(cell): changed = true
						discovered[cell] = true
	for cave in caves:
		if game.grid_manager.get_tile(cave.entry.x, cave.entry.y).is_explored:
			for cell in cave.cells:
				if cell.distance_to(cave.entry) < 3:
					if not discovered.has(cell): changed = true
					discovered[cell] = true
		cave.enemies = cave.enemies.filter(func(u): return is_instance_valid(u) and u.is_alive)
		if cave.enemies.is_empty():
			cave.respawn -= delta
			if cave.respawn <= 0:
				for i in range(2):
					var safe_cells: Array = cave.cells.filter(func(cell):
						for observer in game.all_units:
							if observer.faction == "player" and observer.underground_unit and observer.position.distance_to(Vector3(cell.x+0.5,FLOOR_Y,cell.y+0.5)) < 5.0:
								return false
						return true
					)
					if safe_cells.is_empty(): continue
					var cell: Vector2i = safe_cells[rng.randi_range(0, safe_cells.size()-1)]
					var enemy: Unit = game.spawn_unit(UnitConfigs.UnitType.SPIDER if i == 0 else UnitConfigs.UnitType.ZOMBIE, "enemy", Vector3(cell.x + 0.5, 0, cell.y + 0.5))
					enter(enemy, cell)
					cave.enemies.append(enemy)
				cave.respawn = 45.0
		for enemy in cave.enemies:
			if not is_instance_valid(enemy.target) and enemy.path.is_empty():
				var cell: Vector2i = cave.cells[rng.randi_range(0, cave.cells.size() - 1)]
				enemy.set_path(find_path(enemy.position, Vector3(cell.x + 0.5, FLOOR_Y, cell.y + 0.5)))
				enemy.state = UnitConfigs.UnitState.MOVING
	if changed: _rebuild_visuals()

func _update_visibility() -> void:
	for unit in game.all_units:
		if not unit.underground_unit:
			if unit.faction == "player": unit.visible = not cutaway
			continue
		var seen: bool = unit.faction == "player"
		if not seen:
			for observer in game.all_units:
				if observer.faction == "player" and observer.underground_unit and observer.position.distance_to(unit.position) < 7 and game.grid_manager.has_line_of_sight(observer.position, unit.position):
					seen = true
		unit.visible = cutaway and seen

func _rebuild_visuals() -> void:
	if floor_mesh == null: return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in discovered:
		var x: float = cell.x
		var z: float = cell.y
		st.set_color(Color(0.075, 0.095, 0.12))
		_quad(st, Vector3(x,FLOOR_Y,z), Vector3(x+1,FLOOR_Y,z), Vector3(x+1,FLOOR_Y,z+1), Vector3(x,FLOOR_Y,z+1))
		for d in DIRS:
			if not cells.has(cell+d):
				var a: Vector3
				var b: Vector3
				if d.x != 0:
					a = Vector3(x+(1 if d.x>0 else 0),FLOOR_Y,z)
					b = a + Vector3(0,0,1)
				else:
					a = Vector3(x,FLOOR_Y,z+(1 if d.y>0 else 0))
					b = a + Vector3(1,0,0)
				st.set_color(Color(0.18, 0.21, 0.24))
				_quad(st, a,b,b+Vector3.UP*1.1,a+Vector3.UP*1.1)
	st.generate_normals()
	floor_mesh.mesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	floor_mesh.material_override = mat
	var map_image: Image = Image.create(GridManager.GRID_SIZE, GridManager.GRID_SIZE, false, Image.FORMAT_RGBA8)
	map_image.fill(Color("101820"))
	for cell in discovered:
		map_image.set_pixel(cell.x, cell.y, Color("82949b"))
	game.hud.minimap.underground_texture = ImageTexture.create_from_image(map_image)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a,b,c,a,c,d]: st.add_vertex(point)

func _free_cell_near(center: Vector2i, unit: Unit) -> Vector2i:
	for radius in range(4):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var cell: Vector2i = center + Vector2i(dx,dz)
				if not cells.has(cell): continue
				var occupied: bool = false
				var position_3d: Vector3 = Vector3(cell.x+0.5,FLOOR_Y,cell.y+0.5)
				for other in game.all_units:
					if other != unit and other.is_alive and other.underground_unit and other.position.distance_to(position_3d)<0.75:
						occupied=true
				for id in jobs:
					if id != unit.get_instance_id() and jobs[id].get("target",Vector2i(-1,-1))==cell: occupied=true
				if not occupied and not find_path(Vector3(center.x+0.5,FLOOR_Y,center.y+0.5),position_3d).is_empty(): return cell
	return center
