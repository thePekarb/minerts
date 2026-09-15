class_name VillagerFactory
extends RefCounted

static var _cached_scene: PackedScene = null

static func get_villager_scene() -> PackedScene:
	if _cached_scene != null:
		return _cached_scene

	# 1. Try ResourceLoader (if imported by editor)
	if ResourceLoader.exists("res://assets/models/villager.glb"):
		var res: Resource = load("res://assets/models/villager.glb")
		if res is PackedScene:
			_cached_scene = res
			return _cached_scene

	# 2. Try GLTFDocument (runtime loader directly from .glb file)
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var path: String = "res://assets/models/villager.glb"
	var err: Error = gltf.append_from_file(path, state)
	if err == OK:
		var root_node: Node3D = gltf.generate_scene(state) as Node3D
		if root_node:
			var scene: PackedScene = PackedScene.new()
			scene.pack(root_node)
			_cached_scene = scene
			return _cached_scene

	return null

static func create_villager_unit(type: UnitConfigs.UnitType, faction: String) -> Dictionary:
	var scene: PackedScene = get_villager_scene()
	if not scene:
		return {}

	var root: Node3D = scene.instantiate() as Node3D
	root.name = "VillagerModel"
	# Scale villager model to ~1.4m height to match 1.3m collision capsule and grid
	root.scale = Vector3(0.55, 0.55, 0.55)

	var anim_player: AnimationPlayer = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		for anim_name in anim_player.get_animation_list():
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim:
				if "Walk" in anim_name or "Run" in anim_name:
					anim.loop_mode = Animation.LOOP_LINEAR
				else:
					anim.loop_mode = Animation.LOOP_NONE

	var axe_ctrl: Node3D = root.find_child("Axe_CTRL", true, false) as Node3D
	var hammer_ctrl: Node3D = root.find_child("Hammer_CTRL", true, false) as Node3D
	if axe_ctrl:
		axe_ctrl.visible = false
	if hammer_ctrl:
		hammer_ctrl.visible = false

	# Customize materials and equipment
	_customize_villager(root, type, faction)

	return {
		"root": root,
		"anim_player": anim_player,
		"axe_ctrl": axe_ctrl,
		"hammer_ctrl": hammer_ctrl
	}

static func _customize_villager(root: Node3D, type: UnitConfigs.UnitType, faction: String) -> void:
	if faction == "enemy":
		var tunic_col: Color = Color("7f1d1d") # Blood red
		var skin_col: Color = Color("6b21a8") # Corrupted purple skin
		if type == UnitConfigs.UnitType.ENEMY_FAST:
			tunic_col = Color("3b0764")
			skin_col = Color("991b1b")

		_set_mesh_material(root, "Tunic_Torso", tunic_col)
		_set_mesh_material(root, "Tunic_Skirt", tunic_col)
		_set_mesh_material(root, "HeadMesh", skin_col)
		_set_mesh_material(root, "Hand_R_Mesh", skin_col)
		_set_mesh_material(root, "Hand_L_Mesh", skin_col)
		_set_mesh_material(root, "Forearm_R_Mesh", skin_col)
		_set_mesh_material(root, "Forearm_L_Mesh", skin_col)
		_set_mesh_material(root, "Nose", skin_col)
		_set_mesh_material(root, "Ear_R", skin_col)
		_set_mesh_material(root, "Ear_L", skin_col)

		# Glowing crimson demonic eyes
		_set_mesh_material(root, "Eye_L", Color("ef4444"), 0.0, 0.4, Color("ef4444"))
		_set_mesh_material(root, "Eye_R", Color("ef4444"), 0.0, 0.4, Color("ef4444"))

	else:
		# Player faction
		match type:
			UnitConfigs.UnitType.WORKER:
				_set_mesh_material(root, "Tunic_Torso", Color("2563eb")) # Royal Blue
				_set_mesh_material(root, "Tunic_Skirt", Color("1d4ed8"))

			UnitConfigs.UnitType.SCOUT:
				_set_mesh_material(root, "Tunic_Torso", Color("16a34a")) # Swift Green
				_set_mesh_material(root, "Tunic_Skirt", Color("15803d"))

			UnitConfigs.UnitType.GUARD, UnitConfigs.UnitType.WARRIOR:
				# Steel plate mail
				_set_mesh_material(root, "Tunic_Torso", Color("64748b"), 0.75, 0.35)
				_set_mesh_material(root, "Tunic_Skirt", Color("475569"), 0.75, 0.35)
				_add_warrior_equipment(root)

			UnitConfigs.UnitType.ARCHER:
				# Leather archer armor
				_set_mesh_material(root, "Tunic_Torso", Color("d97706"), 0.0, 0.8)
				_set_mesh_material(root, "Tunic_Skirt", Color("b45309"), 0.0, 0.8)
				_add_archer_equipment(root)

static func _set_mesh_material(root: Node3D, mesh_name: String, col: Color, metallic: float = 0.0, roughness: float = 0.8, emissive: Color = Color.BLACK) -> void:
	var mesh_inst: MeshInstance3D = root.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh_inst:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.metallic = metallic
		mat.roughness = roughness
		if emissive != Color.BLACK:
			mat.emission_enabled = true
			mat.emission = emissive
			mat.emission_energy_multiplier = 2.5
		mesh_inst.material_override = mat

static func _add_warrior_equipment(root: Node3D) -> void:
	var head_bone: Node3D = root.find_child("Head", true, false) as Node3D
	if head_bone:
		var helm: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.38, 0.26, 0.38)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color("94a3b8")
		mat.metallic = 0.8
		mat.roughness = 0.3
		helm.mesh = box
		helm.material_override = mat
		helm.position = Vector3(0.0, 0.18, 0.0)
		head_bone.add_child(helm)

	var left_hand: Node3D = root.find_child("Hand.L", true, false) as Node3D
	if left_hand:
		var shield: MeshInstance3D = MeshInstance3D.new()
		var s_box: BoxMesh = BoxMesh.new()
		s_box.size = Vector3(0.08, 0.55, 0.45)
		var s_mat: StandardMaterial3D = StandardMaterial3D.new()
		s_mat.albedo_color = Color("334155")
		s_mat.metallic = 0.5
		s_mat.roughness = 0.4
		shield.mesh = s_box
		shield.material_override = s_mat
		shield.position = Vector3(0.12, 0.0, 0.0)
		left_hand.add_child(shield)

static func _add_archer_equipment(root: Node3D) -> void:
	var left_hand: Node3D = root.find_child("Hand.L", true, false) as Node3D
	if left_hand:
		var bow: MeshInstance3D = MeshInstance3D.new()
		var bow_mesh: BoxMesh = BoxMesh.new()
		bow_mesh.size = Vector3(0.06, 0.75, 0.06)
		var b_mat: StandardMaterial3D = StandardMaterial3D.new()
		b_mat.albedo_color = Color("78350f")
		bow.mesh = bow_mesh
		bow.material_override = b_mat
		bow.position = Vector3(0.08, 0.0, 0.0)
		left_hand.add_child(bow)
