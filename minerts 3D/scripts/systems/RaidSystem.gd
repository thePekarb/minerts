class_name RaidSystem
extends Node

var grid_manager: GridManager
var units_container: Node3D
var world_container: Node3D

const ALTAR_POSITIONS: Array[Vector2i] = [
	Vector2i(96, 38), Vector2i(154, 96), Vector2i(96, 154), Vector2i(38, 96)
]

var altar_nodes: Array[Node3D] = []
const WARNING_TIME: float = 17.0 / 24.0
const RAID_TIME: float = 19.5 / 24.0

var active_altar_positions: Array[Vector3] = []
var current_wave: int = 0
var has_spawned_night_wave: bool = false
var has_played_dusk_horn: bool = false

# Array of all active enemies
var enemy_units: Array[Unit] = []
var reinforcements: Array[Dictionary] = []
var reinforcement_timer: float = 0.0

func init_raid(grid_mgr: GridManager, u_container: Node3D, w_container: Node3D = null) -> void:
	grid_manager = grid_mgr
	units_container = u_container
	world_container = w_container if w_container else u_container

	_build_altars()
	EventBus.entity_died.connect(func(entity):
		if entity is Unit:
			enemy_units.erase(entity)
			if enemy_units.is_empty() and reinforcements.is_empty():
				active_altar_positions.clear()
	)

	EventBus.time_of_day_changed.connect(_on_time_changed)
	EventBus.day_passed.connect(_on_day_passed)

func _build_altars() -> void:
	for pos_2d in ALTAR_POSITIONS:
		var gx: int = pos_2d.x
		var gz: int = pos_2d.y
		var gy: float = grid_manager.get_height(float(gx) + 0.5, float(gz) + 0.5)

		var altar_root: Node3D = Node3D.new()
		altar_root.name = "Altar_%d_%d" % [gx, gz]
		altar_root.position = Vector3(float(gx) + 0.5, gy, float(gz) + 0.5)

		# 1. Base stone steps
		var base_mesh: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(2.4, 0.4, 2.4), Color("1e293b"), 0.9, 0.1)
		base_mesh.position.y = 0.2
		altar_root.add_child(base_mesh)

		var mid_step: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(1.8, 0.4, 1.8), Color("334155"), 0.8, 0.2)
		mid_step.position.y = 0.6
		altar_root.add_child(mid_step)

		# 2. Obsidian Pillar / Monolith
		var pillar: MeshInstance3D = VoxelMeshFactory.create_box_mesh(Vector3(0.8, 2.0, 0.8), Color("0f172a"), 0.5, 0.5)
		pillar.position.y = 1.8
		altar_root.add_child(pillar)

		# 3. Floating Blood Gem / Altar Crystal (Glowing emissive crimson)
		var gem: MeshInstance3D = MeshInstance3D.new()
		var box_gem: BoxMesh = BoxMesh.new()
		box_gem.size = Vector3(0.45, 0.45, 0.45)
		var gem_mat: StandardMaterial3D = StandardMaterial3D.new()
		gem_mat.albedo_color = Color("dc2626")
		gem_mat.emission_enabled = true
		gem_mat.emission = Color("ef4444")
		gem_mat.emission_energy_multiplier = 2.5
		gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gem.mesh = box_gem
		gem.material_override = gem_mat
		gem.position = Vector3(0.0, 3.2, 0.0)
		gem.rotation = Vector3(deg_to_rad(45.0), deg_to_rad(45.0), 0.0)
		altar_root.add_child(gem)

		# 4. Ominous Red OmniLight
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color("ef4444")
		light.light_energy = 2.0
		light.omni_range = 8.0
		light.position = Vector3(0.0, 3.2, 0.0)
		altar_root.add_child(light)

		world_container.add_child(altar_root)
		altar_nodes.append(altar_root)

func _on_time_changed(time_norm: float) -> void:
	# Thresholds stay eligible until midnight, even after a long frame/time jump.
	# Only day_passed resets the guards; each calendar day gets one wave.
	if time_norm >= WARNING_TIME and not has_played_dusk_horn:
		has_played_dusk_horn = true
		SoundManager.play_horn()
		EventBus.raid_warning.emit("Ночь приближается. Волна монстров начнётся в 19:30!")
	if time_norm >= RAID_TIME and not has_spawned_night_wave:
		spawn_night_wave()

func _on_day_passed(_day: int) -> void:
	has_spawned_night_wave = false
	has_played_dusk_horn = false

func spawn_night_wave() -> void:
	has_spawned_night_wave = true
	current_wave += 1
	# Total wave size keeps growing; only 64 raiders need active navigation at once.
	var composition: Array[UnitConfigs.UnitType] = []
	for i in range(4+(current_wave-1)*6):
		var type: UnitConfigs.UnitType = UnitConfigs.UnitType.ZOMBIE
		if current_wave>=2 and i%6==3:type=UnitConfigs.UnitType.SKELETON
		if current_wave>=2 and i%6==4:type=UnitConfigs.UnitType.SPIDER
		if current_wave>=3 and i%6==5:type=UnitConfigs.UnitType.CREEPER
		composition.append(type)
	EventBus.raid_spawned.emit(current_wave, composition.size())
	SoundManager.play_zombie()
	var base_pos: Vector3 = Vector3(GridManager.CENTER + 0.5, 2, GridManager.CENTER + 0.5)
	var active_altars: int = mini(1 + int((current_wave - 1) / 2), ALTAR_POSITIONS.size())
	for i in range(composition.size()):
		var coords: Vector2i = ALTAR_POSITIONS[(i % active_altars + current_wave - 1) % ALTAR_POSITIONS.size()]
		var origin: Vector3 = Vector3(coords.x + 0.5, 5, coords.y + 0.5)
		if not active_altar_positions.has(origin):
			active_altar_positions.append(origin)
		reinforcements.append({"type":composition[i],"origin":origin,"base":base_pos,"index":i,"wave":current_wave})
	_spawn_reinforcements(64)

func _spawn_and_dispatch_enemy(type: UnitConfigs.UnitType, altar_pos: Vector3, base_pos: Vector3, offset_idx: int, wave: int = -1) -> void:
	var enemy: Unit = Unit.new()
	enemy.unit_type = type
	enemy.faction = "enemy"
	enemy.grid_manager = grid_manager
	units_container.add_child(enemy)

	var angle: float = float(offset_idx) * 1.05
	var rad: float = 1.5 + float(offset_idx % 3) * 0.5
	var spawn_p: Vector3 = altar_pos + Vector3(cos(angle) * rad, 0, sin(angle) * rad)
	spawn_p.y = grid_manager.get_height(spawn_p.x, spawn_p.z)
	enemy.global_position = grid_manager.find_free_position(spawn_p)
	for radius in range(1,7):
		if grid_manager.unit_position_free(enemy,enemy.position):break
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var point: Vector3 = grid_manager.find_free_position(spawn_p+Vector3(dx,0,dz))
				if grid_manager.unit_position_free(enemy,point):enemy.position=point;break
			if grid_manager.unit_position_free(enemy,enemy.position):break

	scale_enemy(enemy,current_wave if wave<0 else wave)
	enemy_units.append(enemy)
	EventBus.unit_spawned.emit(enemy)

	# Dispatch march toward base
	var path: Array[Vector3] = grid_manager.find_path(enemy.global_position, base_pos, "enemy")
	if not path.is_empty():
		enemy.set_path(path)
		enemy.current_order = UnitConfigs.UnitOrder.ATTACK
		enemy.state = UnitConfigs.UnitState.MOVING

static func scale_enemy(enemy: Unit, wave: int) -> void:
	var level: int = maxi(0,wave-1)
	enemy.max_health*=1.0+level*0.12;enemy.health=enemy.max_health
	enemy.attack_damage*=1.0+level*0.10
	enemy.armor+=floorf(level/4.0)
	enemy.config["blast_damage"]=enemy.config.get("blast_damage",65.0)*(1.0+level*0.10)
	enemy.set_meta("wave_level",wave)

func _process(delta: float) -> void:
	reinforcement_timer+=delta
	if reinforcement_timer<0.5:return
	reinforcement_timer=0.0
	_spawn_reinforcements(4)
func _spawn_reinforcements(budget: int) -> void:
	while not reinforcements.is_empty() and enemy_units.size()<64 and budget>0:
		var job: Dictionary = reinforcements.pop_front()
		_spawn_and_dispatch_enemy(job.type,job.origin,job.base,job.index,job.wave)
		budget-=1
func remaining_enemies() -> int:
	return enemy_units.size()+reinforcements.size()
