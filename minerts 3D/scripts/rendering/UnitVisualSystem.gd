class_name UnitVisualSystem
extends Node3D

# Gameplay owns Unit transforms, health and orders. This system only owns their
# presentation; hiding a model never disables navigation, combat or selection.
var game: Node
var assets: Dictionary = {}
var batches: Dictionary = {}
var clock_time: float = 0.0
var mode: int = 0 # 0 adaptive, 1 force baked crowds (profiling), 2 full skeletons.
var batched_count: int = 0
var skeleton_count: int = 0
var culled_count: int = 0
var last_update_usec: int = 0

func setup(owner: Node) -> void:
	game=owner
	set_process(DisplayServer.get_name()!="headless")

func _process(delta: float) -> void:
	clock_time+=delta
	update_visuals()

func _asset(name: String) -> CrowdAnimationAsset:
	if not assets.has(name):
		var path: String = "res://assets/crowd/"+name+".res"
		assets[name]=load(path) if ResourceLoader.exists(path) else null
	return assets[name]

func _present(unit: Unit, skeleton: bool) -> void:
	unit.visual_suspended=not skeleton
	if is_instance_valid(unit.model_root):
		unit.model_root.visible=skeleton
		unit.model_root.process_mode=Node.PROCESS_MODE_INHERIT if skeleton else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(unit.anim_player):unit.anim_player.active=skeleton

func update_visuals() -> void:
	var start: int = Time.get_ticks_usec()
	batched_count=0;skeleton_count=0;culled_count=0
	var groups: Dictionary = {}
	var near_skeletons: int = 0
	for unit in game.all_units:
		if not is_instance_valid(unit):continue
		if not unit.is_alive or not unit.is_visible_in_tree() or is_instance_valid(unit.embarked_in) or unit.state==UnitConfigs.UnitState.MINING_INSIDE:
			_present(unit,false);culled_count+=1;continue
		var on_screen: bool = game.camera.is_position_in_frustum(unit.global_position) or game.camera.is_position_in_frustum(unit.global_position+Vector3.UP*2.5)
		if mode!=2 and not on_screen:
			_present(unit,false);culled_count+=1;continue
		var near: bool = near_skeletons<24 and game.camera.current_zoom<28 and Vector2(unit.position.x-game.camera.current_focus.x,unit.position.z-game.camera.current_focus.z).length()<32
		var name: String = FrontierAssets.unit_asset_name(unit.unit_type,unit.faction)
		var asset: CrowdAnimationAsset = _asset(name) if mode!=2 and not unit.is_selected and not unit.visual_focus and (mode==1 or not near) else null
		if asset==null:
			if near:near_skeletons+=1
			_present(unit,true);skeleton_count+=1;continue
		_present(unit,false);batched_count+=1
		var cell := Vector2i(floori(unit.position.x/32),floori(unit.position.z/32))
		var key: String = "%s:%d:%d" % [name,cell.x,cell.y]
		if not groups.has(key):groups[key]={"asset":asset,"units":[],"cell":cell}
		groups[key].units.append(unit)
	for key in batches.keys():
		if not groups.has(key):batches[key].node.queue_free();batches.erase(key)
	for key in groups:
		var group: Dictionary = groups[key]
		if not batches.has(key):_create_batch(key,group.asset,group.cell)
		var batch: Dictionary = batches[key]
		var count: int = group.units.size()
		if batch.mesh.instance_count<count:
			batch.mesh.instance_count=ceili(count/16.0)*16
		var buffer := PackedFloat32Array()
		buffer.resize(batch.mesh.instance_count*16)
		for i in range(count):
			var unit: Unit = group.units[i]
			var transform: Transform3D = unit.global_transform*unit.model_root.transform
			transform.origin-=batch.node.position
			var b: Basis = transform.basis
			var p: Vector3 = transform.origin
			var clip: int = 0
			var rate: float = 1.0
			if unit.navigation.actual_speed>.1 and unit.state in [UnitConfigs.UnitState.MOVING,UnitConfigs.UnitState.RETURNING_TO_STORAGE,UnitConfigs.UnitState.FLEEING]:clip=2 if unit.speed>5 else 1;rate=unit.speed/3.8
			elif unit.state==UnitConfigs.UnitState.ATTACKING:clip=3;rate=1/maxf(unit.attack_cooldown,.1)
			elif unit.state==UnitConfigs.UnitState.GATHERING:clip=4
			elif unit.state==UnitConfigs.UnitState.BUILDING:clip=5
			var values: Array[float] = [b.x.x,b.y.x,b.z.x,p.x,b.x.y,b.y.y,b.z.y,p.y,b.x.z,b.y.z,b.z.z,p.z,float(clip),rate,float(unit.get_instance_id()%997)*.01,0.0]
			for j in range(16):buffer[i*16+j]=values[j]
		batch.mesh.buffer=buffer
		batch.mesh.visible_instance_count=count
		batch.material.set_shader_parameter("clock_time",clock_time)
	last_update_usec=Time.get_ticks_usec()-start

func _create_batch(key: String, asset: CrowdAnimationAsset, cell: Vector2i) -> void:
	var node := MultiMeshInstance3D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_3D
	mesh.use_custom_data=true;mesh.mesh=asset.mesh
	# Separate spatial batches retain useful frustum culling and small bounds.
	mesh.custom_aabb=AABB(Vector3(-4,-10,-4),Vector3(40,35,40))
	node.multimesh=mesh;node.position=Vector3(cell.x*32,0,cell.y*32)
	var material := ShaderMaterial.new()
	material.shader=load("res://assets/shaders/crowd_animation.gdshader")
	material.set_shader_parameter("pose_positions",asset.positions)
	material.set_shader_parameter("pose_normals",asset.normals)
	material.set_shader_parameter("lengths",asset.lengths)
	material.set_shader_parameter("frames_per_clip",asset.frames_per_clip)
	node.material_override=material
	add_child(node)
	batches[key]={"node":node,"mesh":mesh,"material":material}

func restore_skeletons() -> void:
	for unit in game.all_units:
		if is_instance_valid(unit):_present(unit,true)
	for batch in batches.values():batch.node.queue_free()
	batches.clear()
