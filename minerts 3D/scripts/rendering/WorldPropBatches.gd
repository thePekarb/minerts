class_name WorldPropBatches
extends Node3D
# Resource bodies and their metadata remain authoritative for selection and harvesting.
# Only their many imported MeshInstance nodes are consolidated into spatial batches.
var groups: Dictionary = {}
var timer: float = 0.0
var instance_count: int = 0
func setup(resources: Dictionary) -> void:
	for object in resources.values():
		if not is_instance_valid(object):continue
		for source in object.find_children("*","MeshInstance3D",true,false):
			if not source.mesh:continue
			var cell := Vector2i(floori(object.position.x/16),floori(object.position.z/16))
			var key: String = "%s:%s" % [source.mesh.get_rid(),cell]
			if not groups.has(key):
				var node := MultiMeshInstance3D.new();var multimesh := MultiMesh.new()
				multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=source.mesh.duplicate()
				for surface in range(source.mesh.get_surface_count()):multimesh.mesh.surface_set_material(surface,source.get_active_material(surface))
				node.multimesh=multimesh;node.position=Vector3(cell.x*16,0,cell.y*16);add_child(node)
				groups[key]={"node":node,"entries":[],"signature":-1}
			var group: Dictionary = groups[key]
			var transform: Transform3D = source.global_transform
			transform.origin-=group.node.position
			group.entries.append({"object":weakref(object),"mesh":weakref(source),"transform":transform})
			source.visible=false;source.set_meta("batched_prop",true)
			instance_count+=1
	update_batches()
func _process(delta: float) -> void:
	timer+=delta
	if timer<.25:return
	timer=0;update_batches()
func update_batches() -> void:
	for group in groups.values():
		var camera: RTSCamera = get_parent().camera
		var near: bool = Vector2(group.node.position.x+8-camera.current_focus.x,group.node.position.z+8-camera.current_focus.z).length()<camera.current_zoom*1.5+32
		group.node.visible=near
		if not near:continue
		var transforms: Array[Transform3D] = []
		var signature: int = 0
		for entry in group.entries:
			var object = entry.object.get_ref()
			var source = entry.mesh.get_ref()
			if not is_instance_valid(object) or not is_instance_valid(source):continue
			var focus: bool = object.get_meta("visual_focus",false)
			source.visible=focus
			if not object.is_visible_in_tree() or focus:continue
			transforms.append(entry.transform);signature=hash([signature,object.get_instance_id()])
		if signature==group.signature:continue
		group.signature=signature
		var mesh: MultiMesh = group.node.multimesh
		mesh.instance_count=transforms.size()
		for i in range(transforms.size()):mesh.set_instance_transform(i,transforms[i])
