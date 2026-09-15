class_name Building
extends StaticBody3D

signal health_changed(current: float, maximum: float)
signal died(building: Building)

@export var building_type: BuildingConfigs.BuildingType = BuildingConfigs.BuildingType.HUT

@export var faction: String = "player"
var training_queue: Array[Dictionary] = []
var rally_point: Vector3 = Vector3.INF
var rally_marker: Node3D
var config: Dictionary = {}
var grid_x: int = 0
var grid_z: int = 0

var health: float = 300.0
var max_health: float = 300.0
var is_alive: bool = true

var is_constructed: bool = false
var construction_progress: float = 0.0
var level: int = 1
var production_timer: float = 0.0
var crop_plants: Node3D
var production_label: Label3D
var production_status: String = ""

# Gate mechanics
var is_gate: bool = false
var is_open: bool = false
var is_gate_locked: bool = false

var footprint: Vector2i = Vector2i(1, 1)
var rotation_degrees_y: int = 0

# Mine garrison mechanics
var assigned_miners: Array[Unit] = []
var max_miners: int = 4
var mine_cycle_timer: float = 0.0

var mesh_root: Node3D
var gate_door: Node3D
var deep_ore_block: Node3D

func init_building(type: BuildingConfigs.BuildingType, gx: int, gz: int, instant: bool = false, rot_deg: int = 0, custom_fp: Vector2i = Vector2i.ZERO) -> void:
	collision_layer = 4
	collision_mask = 0
	building_type = type
	grid_x = gx
	grid_z = gz
	rotation_degrees_y = rot_deg
	config = BuildingConfigs.get_config(type)
	footprint = custom_fp if custom_fp != Vector2i.ZERO else config.get("footprint", Vector2i(1, 1))
	max_health = config.get("max_health", 300.0)
	health = max_health

	is_gate = (type == BuildingConfigs.BuildingType.GATE)
	is_gate_locked = is_gate
	is_constructed = instant or config.get("build_time", 5.0) == 0.0
	construction_progress = 100.0 if is_constructed else 0.0

	_build_visuals()
	_update_construction_visuals()
	if building_type == BuildingConfigs.BuildingType.CAMPFIRE:
		var fire_light: OmniLight3D = OmniLight3D.new()
		fire_light.light_color = Color("ffc07a")
		fire_light.light_energy = 1.8
		fire_light.omni_range = 7.0
		fire_light.position.y = 1.2
		add_child(fire_light)

func _build_visuals() -> void:
	mesh_root = FrontierAssets.create_faction_building(building_type,faction)
	if mesh_root == null: mesh_root = VoxelMeshFactory.create_building_mesh(building_type)
	add_child(mesh_root)

	if building_type == BuildingConfigs.BuildingType.FARM:
		crop_plants = mesh_root.find_child("CropPlants", true, false)
		if crop_plants: crop_plants.scale.y = 0.12

	if is_gate:
		gate_door = mesh_root.find_child("GateDoor", true, false)

	if building_type == BuildingConfigs.BuildingType.MINE:
		deep_ore_block = mesh_root.find_child("DeepOreBlock", true, false)
		if deep_ore_block:
			deep_ore_block.visible = false

	if not find_child("CollisionShape3D", false, false):
		var col: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		var fp: Vector2i = config.get("footprint", Vector2i(1, 1))
		box.size = Vector3(float(fp.x) * 0.95, 2.0, float(fp.y) * 0.95)
		col.shape = box
		col.position.y = 1.0
		add_child(col)

func advance_construction(amount: float) -> bool:
	if is_constructed:
		return true

	construction_progress += amount
	_update_construction_visuals()

	if construction_progress >= 100.0:
		construction_progress = 100.0
		is_constructed = true
		scale = Vector3.ONE
		EventBus.building_constructed.emit(self)
		return true
	return false

func _update_construction_visuals() -> void:
	if not is_constructed:
		var pct: float = clampf(construction_progress / 100.0, 0.25, 1.0)
		scale = Vector3(1.0, pct, 1.0)
	else:
		scale = Vector3.ONE

func toggle_gate(grid_mgr: GridManager = null) -> bool:
	if not is_gate:
		return false
	if is_open:
		is_gate_locked = true
		set_gate_open(false, grid_mgr)
		return false
	else:
		is_gate_locked = false
		set_gate_open(true, grid_mgr)
		return true

func set_gate_open(open_state: bool, grid_mgr: GridManager = null) -> void:
	if not is_gate or is_open == open_state:
		return
	is_open = open_state
	var collision: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if collision:
		collision.set_deferred("disabled", is_open)

	if gate_door:
		gate_door.rotation.y = -PI / 2.0 if is_open else 0.0
		gate_door.position = Vector3(-0.7 if is_open else 0.0, 0.8, 0.7 if is_open else 0.0)

	if grid_mgr:
		var fp: Vector2i = footprint
		for x in range(grid_x, grid_x + fp.x):
			for z in range(grid_z, grid_z + fp.y):
				var tile: Tile = grid_mgr.get_tile(x, z)
				if tile:
					tile.is_gate_open = is_open
					tile.is_gate_locked = is_gate_locked
					grid_mgr.astar.set_point_disabled(grid_mgr.get_point_id(x, z), not is_open)
					grid_mgr.invalidate_terrain(Vector2i(x,z))

func upgrade_mine() -> void:
	if building_type != BuildingConfigs.BuildingType.MINE or level >= 2:
		return
	level = 2
	config["name"] = "Deep Ore Mine"
	if deep_ore_block:
		deep_ore_block.visible = true
	EventBus.building_upgraded.emit(self)

func eject_all_miners(grid_mgr: GridManager) -> void:
	for m in assigned_miners:
		if is_instance_valid(m) and m.is_alive:
			var out_x: float = float(grid_x) + float(footprint.x) + 0.5
			var out_z: float = float(grid_z) + float(footprint.y) + 0.5
			var out_y: float = grid_mgr.get_height(out_x, out_z)
			m.ungarrison_from_building(Vector3(out_x, out_y, out_z))

	assigned_miners.clear()
	EventBus.mine_miner_count_changed.emit(self, 0)

func take_damage(amount: float) -> bool:
	if not is_alive:
		return true
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_alive = false
		died.emit(self)
		EventBus.entity_died.emit(self)
		return true
	return false
