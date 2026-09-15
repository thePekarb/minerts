extends SceneTree

const CLIPS: Array[String] = ["Idle","Walk","Run","Attack","Gather","Build"]
const FRAMES: int = 8
var output: String = "res://assets/crowd/"

func _initialize() -> void:call_deferred("bake_all")

func bake_all() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var names: Array[String] = ["worker","scout","knight","archer","zombie","skeleton","spider","creeper","wolf","bear","goblin_worker","goblin_warrior","goblin_archer","goblin_spearman","spider_rider","troll","deer","boar","rabbit","ancient_golem","storm_warden"]
	if not OS.get_cmdline_user_args().is_empty():names.assign(OS.get_cmdline_user_args())
	for name in names:
		if not bake(name):quit(1);return
	quit()

func bake(asset_name: String) -> bool:
	var model: Node3D = FrontierAssets.instantiate_asset(asset_name)
	root.add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer",true,false)
	if player==null:push_error("No animation player: "+asset_name);model.free();return false
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var parts: Array[Dictionary] = []
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mesh: Mesh = node.mesh
		var skeleton: Skeleton3D = node.get_node_or_null(node.skeleton) as Skeleton3D
		if skeleton==null and node.get_parent() is Skeleton3D:skeleton=node.get_parent()
		var tool: int = 0
		var ancestor: Node = node
		while ancestor!=model:
			if ancestor.name.contains("Axe_CTRL"):tool=1
			if ancestor.name.contains("Hammer_CTRL"):tool=2
			ancestor=ancestor.get_parent()
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			var offset: int = vertices.size()
			var material: StandardMaterial3D = node.get_active_material(surface) as StandardMaterial3D
			var flags: int = tool
			if material and material.emission_enabled:flags+=4
			if material and material.metallic>.3:flags+=8
			for i in range(count):
				vertices.append(arrays[Mesh.ARRAY_VERTEX][i]);normals.append(arrays[Mesh.ARRAY_NORMAL][i])
				colors.append(material.albedo_color.srgb_to_linear() if material else Color.WHITE)
				uv.append(Vector2(offset+i,flags))
			if arrays[Mesh.ARRAY_INDEX]!=null:
				for index in arrays[Mesh.ARRAY_INDEX]:indices.append(index+offset)
			else:
				for i in range(count):indices.append(offset+i)
			parts.append({"node":node,"skeleton":skeleton,"skin":node.skin,"arrays":arrays,"offset":offset})
	if vertices.size()>16384:push_error("Crowd texture too wide: "+asset_name);model.free();return false
	var poses: Image = Image.create(vertices.size(),FRAMES*CLIPS.size(),false,Image.FORMAT_RGBAH)
	var normal_poses: Image = Image.create(vertices.size(),FRAMES*CLIPS.size(),false,Image.FORMAT_RGBAH)
	var lengths := PackedFloat32Array()
	var bounds := AABB(Vector3.ZERO,Vector3(.01,.01,.01))
	for clip_index in range(CLIPS.size()):
		var clip: String = CLIPS[clip_index]
		if not player.has_animation(clip):push_error("Missing clip "+asset_name+":"+clip);model.free();return false
		var length: float = player.get_animation(clip).length
		lengths.append(length)
		player.play(clip);player.advance(0)
		for frame in range(FRAMES):
			player.seek(length*frame/FRAMES,true)
			for part in parts:
				var arrays: Array = part.arrays
				var skeleton: Skeleton3D = part.skeleton
				var skin: Skin = part.skin
				var matrices: Array[Transform3D] = []
				if skeleton and skin:
					skeleton.force_update_all_bone_transforms()
					for bind in range(skin.get_bind_count()):
						var bone: int = skin.get_bind_bone(bind)
						if bone<0:bone=skeleton.find_bone(skin.get_bind_name(bind))
						matrices.append(model.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind))
				var transform: Transform3D = model.global_transform.affine_inverse()*part.node.global_transform
				for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
					var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
					var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
					var posed: Vector3 = transform*v
					var normal: Vector3 = transform.basis*n
					if not matrices.is_empty() and arrays[Mesh.ARRAY_BONES]!=null:
						posed=Vector3.ZERO;normal=Vector3.ZERO
						var weights_per_vertex: int = arrays[Mesh.ARRAY_BONES].size()/arrays[Mesh.ARRAY_VERTEX].size()
						for k in range(weights_per_vertex):
							var weight: float = arrays[Mesh.ARRAY_WEIGHTS][i*weights_per_vertex+k]
							if weight<=0:continue
							var bone: int = arrays[Mesh.ARRAY_BONES][i*weights_per_vertex+k]
							posed+=(matrices[bone]*v)*weight;normal+=(matrices[bone].basis*n)*weight
					bounds=bounds.expand(posed)
					poses.set_pixel(part.offset+i,clip_index*FRAMES+frame,Color(posed.x,posed.y,posed.z,1))
					normal=normal.normalized()
					normal_poses.set_pixel(part.offset+i,clip_index*FRAMES+frame,Color(normal.x,normal.y,normal.z,1))
	var arrays: Array = [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV2]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var asset := CrowdAnimationAsset.new()
	asset.mesh=ArrayMesh.new();asset.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	asset.bounds=bounds.grow(.2);asset.mesh.custom_aabb=asset.bounds
	asset.positions=ImageTexture.create_from_image(poses);asset.normals=ImageTexture.create_from_image(normal_poses)
	asset.lengths=lengths;asset.frames_per_clip=FRAMES;asset.source_asset=asset_name
	var error: int = ResourceSaver.save(asset,output+asset_name+".res",ResourceSaver.FLAG_COMPRESS)
	print("BAKED ",asset_name," vertices=",vertices.size()," frames=",FRAMES*CLIPS.size()," bounds=",bounds," result=",error)
	model.free()
	return error==OK
