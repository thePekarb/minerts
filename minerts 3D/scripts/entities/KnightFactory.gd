class_name KnightFactory
extends RefCounted

static var _cached_scene: PackedScene = null

static func get_knight_scene() -> PackedScene:
	if _cached_scene != null:
		return _cached_scene

	# 1. Try ResourceLoader (if imported by editor)
	if ResourceLoader.exists("res://assets/models/knight.glb"):
		var res: Resource = load("res://assets/models/knight.glb")
		if res is PackedScene:
			_cached_scene = res
			return _cached_scene

	# 2. Try GLTFDocument (runtime loader directly from .glb file)
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var path: String = "res://assets/models/knight.glb"
	var err: Error = gltf.append_from_file(path, state)
	if err == OK:
		var root_node: Node3D = gltf.generate_scene(state) as Node3D
		if root_node:
			var scene: PackedScene = PackedScene.new()
			scene.pack(root_node)
			_cached_scene = scene
			return _cached_scene

	return null

static func create_knight_unit(faction: String = "player") -> Dictionary:
	var scene: PackedScene = get_knight_scene()
	if not scene:
		return {}

	var root: Node3D = scene.instantiate() as Node3D
	root.name = "KnightModel"
	# Scale knight model to ~1.4m height to match 1.3m collision capsule and grid
	root.scale = Vector3(0.55, 0.55, 0.55)

	var anim_player: AnimationPlayer = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		for anim_name in anim_player.get_animation_list():
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim:
				if "Walk" in anim_name or "Run" in anim_name or "Idle" in anim_name:
					anim.loop_mode = Animation.LOOP_LINEAR
				else:
					anim.loop_mode = Animation.LOOP_NONE

	var sword_ctrl: Node3D = root.find_child("Sword_CTRL", true, false) as Node3D

	# Customize if enemy champion / dark knight
	if faction == "enemy":
		_customize_dark_knight(root)

	return {
		"root": root,
		"anim_player": anim_player,
		"sword_ctrl": sword_ctrl
	}

static func _customize_dark_knight(root: Node3D) -> void:
	_set_mesh_material(root, "Chest_Plate", Color("18181b"), 0.8, 0.3)
	_set_mesh_material(root, "Belly_Plate", Color("27272a"), 0.8, 0.3)
	_set_mesh_material(root, "Helmet", Color("09090b"), 0.9, 0.2)
	_set_mesh_material(root, "Tabard", Color("450a0a"), 0.0, 0.9)
	_set_mesh_material(root, "Back_Cape", Color("450a0a"), 0.0, 0.9)
	_set_mesh_material(root, "Plume", Color("dc2626"), 0.0, 0.5, Color("ef4444"))
	_set_mesh_material(root, "Visor", Color("ef4444"), 0.0, 0.2, Color("ef4444"))

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
